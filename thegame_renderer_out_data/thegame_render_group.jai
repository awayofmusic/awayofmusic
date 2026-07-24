#import "Sort";
#import "Math";

// #load "thegame_renderer_data.jai";

//TODO could make these u8 for data compaction
Face :: struct($vert_count : int) {
	face_verts : [vert_count] int;
	color : Vector4F;
	//TODO add per face normals for shading
}

CubeTriMesh :: FaceVertexMesh(8, 12, 3, Vector3F);
//Note : this is for right left coordinate system
//TODO should we make a 4D face-vertex mesh?
//TODO compute normals for each triangle face
CUBE_TRI_FACE :: CubeTriMesh.{
	.[.{0.5, 0.5, 0.5}, .{-0.5, 0.5, 0.5}, .{-0.5, -0.5, 0.5}, .{0.5, -0.5, 0.5},
	  .{0.5, 0.5, -0.5}, .{-0.5, 0.5, -0.5}, .{-0.5, -0.5, -0.5}, .{0.5, -0.5, -0.5}],
	  
	.[.{.[0, 1, 2], LBLUE_V}, .{.[0, 2, 3], WHITE_V},
	  .{.[4, 0, 3], GREY_V}, .{.[4, 3, 7], LIGHT_BROWN},
	  .{.[5, 4, 7], GREY_DARKER_V}, .{.[5, 7, 6], FGREEN_V},
	  .{.[1, 5, 6], ORANGE_V}, .{.[1, 6, 2], GREENC_V},
	  .{.[4, 5, 1], RED_V}, .{.[4, 1, 0], GREY_V}, //top face
	  .{.[2, 6, 7], WHITE_V}, .{.[2, 7, 3], FGREEN_V}]
};

//Note : this is for right hand coordinate system
CUBE_TRI_FACE_Z_BACK :: CubeTriMesh.{
	.[.{0.5, 0.5, -0.5}, .{-0.5, 0.5, -0.5}, .{-0.5, -0.5, -0.5}, .{0.5, -0.5, -0.5},
	  .{0.5, 0.5, 0.5}, .{-0.5, 0.5, 0.5}, .{-0.5, -0.5, 0.5}, .{0.5, -0.5, 0.5}],
	  
	.[.{.[0, 1, 2], LBLUE_V}, .{.[0, 2, 3], WHITE_V},
	  .{.[4, 0, 3], GREY_V}, .{.[4, 3, 7], LIGHT_BROWN},
	  .{.[5, 4, 7], GREY_DARKER_V}, .{.[5, 7, 6], FGREEN_V}, 
	  .{.[1, 5, 6], ORANGE_V}, .{.[1, 6, 2], GREENC_V},
	  .{.[4, 5, 1], RED_V}, .{.[4, 1, 0], GREY_V}, //top face
	  .{.[2, 6, 7], WHITE_V}, .{.[2, 7, 3], FGREEN_V}]
};

//TODO vertices and faces should be centered around 0 and not start from 0
CUBE_SQUARE_FACE :: FaceVertexMesh(8, 6, 2, Vector3F).{
	.[.{0, 0, 0}, .{1, 0, 0}, .{0, 1, 0}, .{0, 0, 1},
	  .{1, 1, 0}, .{0, 1, 1}, .{1, 0, 1}, .{1, 1, 1}],

	.[.{.[0, 4], LIGHT_BROWN}, .{.[0, 5], LIGHT_BROWN},
	  .{.[1, 7], LIGHT_BROWN}, .{.[0, 6], LIGHT_BROWN},
	  .{.[2, 7], LIGHT_BROWN}, .{.[3, 7], LIGHT_BROWN}]
};

//TODO make a tesseract mesh with triangular faces
TesseractEdgeMesh :: FaceVertexMesh(16, 32, 2, Vector4F);
TESSERACT_VERT_EDGES :: TesseractEdgeMesh.{
	.[.{-0.5,-0.5,-0.5,-0.5}, 
	  .{-0.5,-0.5,-0.5, 0.5}, 
	  .{-0.5,-0.5, 0.5,-0.5}, 
	  .{-0.5,-0.5, 0.5, 0.5},
	  .{-0.5, 0.5,-0.5,-0.5}, 
	  .{-0.5, 0.5,-0.5, 0.5}, 
	  .{-0.5, 0.5, 0.5,-0.5}, 
	  .{-0.5, 0.5, 0.5, 0.5},
	  .{ 0.5,-0.5,-0.5,-0.5}, 
	  .{ 0.5,-0.5,-0.5, 0.5}, 
	  .{ 0.5,-0.5, 0.5,-0.5}, 
	  .{ 0.5,-0.5, 0.5, 0.5}, 
	  .{ 0.5, 0.5,-0.5,-0.5}, 
	  .{ 0.5, 0.5,-0.5, 0.5}, 
	  .{ 0.5, 0.5, 0.5,-0.5}, 
	  .{ 0.5, 0.5, 0.5, 0.5}], 
	  
	.[.{.[0,  1], GREY_V}, 
	  .{.[2,  3], GREY_V},
	  .{.[4,  5], GREY_V},
	  .{.[6,  7], GREY_V},
	  .{.[0,  2], GREY_V},
	  .{.[4,  6], GREY_V},
	  .{.[1,  3], GREY_V},
	  .{.[5,  7], GREY_V},
	  .{.[0,  4], GREY_V},
	  .{.[2,  6], GREY_V},
	  .{.[1,  5], GREY_V},
	  .{.[3,  7], GREY_V},
	  .{.[6, 14], GREY_V},
	  .{.[7, 15], GREY_V},
	  .{.[10, 2], GREY_V},
	  .{.[11, 3], GREY_V},
	  .{.[14,10], GREY_V},
	  .{.[15,11], GREY_V},
	  .{.[10,11], GREY_V},
	  .{.[14,15], GREY_V},
	  .{.[12,14], GREY_V},
	  .{.[12,13], GREY_V},
	  .{.[13,15], GREY_V},
	  .{.[8 ,10], GREY_V},
	  .{.[9 ,11], GREY_V},
	  .{.[8 ,12], GREY_V},
	  .{.[8 , 9], GREY_V},
	  .{.[0 , 8], GREY_V},
	  .{.[1 , 9], GREY_V},
	  .{.[9 ,13], GREY_V},
	  .{.[4 ,12], GREY_V},
	  .{.[5 ,13], GREY_V}]
};

FaceVertexMesh :: struct($vert_count : int, $face_count : int, $face_size : int, $vert_type : Type) {
	vertices : [vert_count] vert_type;
	faces : [face_count] Face(face_size);
}

//TODO Leaving this here for now but we can likely remove since the enum version works with dll
//TODO a non-compile-typed version of this function can be the only call
//point from the game to the renderer
//TODO should we set the RenderHeader systematically in here later?
#if 0 {
PushRenderEntry :: (group : *RenderGroup, $type : Type) -> *RenderEntry(type) {
	// assert(group.render_count + 1 <= group.render_sort_buffer.count, 
	// 		"render_count is % and render_sort_buffer.count is %\n", group.render_count, group.render_sort_buffer.count);
	//TODO could replace this with RenderHeader
	element : *RenderEntry(type);
	size := size_of(RenderEntry(type));
	if group.render_push_buffer.used + size < group.render_push_buffer.size {
		element = cast(*RenderEntry(type)) (group.render_push_buffer.base + group.render_push_buffer.used);
		element.type = type;
		group.render_push_buffer.used += size;

		array_add(*group.render_sort_buffer, *element.header);
	} else {
		assert(!"No memory left in render group");
	}	
	return element;
}

PushShaderEntries :: (group : *RenderGroup, text_order : int, color_order : int, flush_order : int) {
	PushSetShaderText(group, text_order);
	PushSetShaderColor(group, color_order);
	PushImmediateFlush(group, flush_order);
}

PushImmediateFlush :: (group : *RenderGroup, order : int = 0) {
	flush : *RenderEntry(RImmediateFlush) = PushRenderEntry(group, RImmediateFlush);
	flush.order = order;
}

PushSetShaderText :: (group : *RenderGroup, order : int = 0) {
	text_color : *RenderEntry(RSetShaderText) = PushRenderEntry(group, RSetShaderText);
	text_color.order = order;
}

PushSetShaderColor :: (group : *RenderGroup, order : int = 0) {
	shader_color : *RenderEntry(RSetShaderColor) = PushRenderEntry(group, RSetShaderColor);
	shader_color.order = order;
}

//TODO could do this directly based on render group coordinates/bounds
PushSetScissor :: (
	x0 : float, y0 : float, x1 : float, y1 : float,
	group : *RenderGroup,
	order : int = 0)
{
	push_set_scissor : *RenderEntry(RSetScissor) = PushRenderEntry(group, RSetScissor);
	push_set_scissor.data.x0 = x0;
	push_set_scissor.data.y0 = y0;
	push_set_scissor.data.x1 = x1;
	push_set_scissor.data.y1 = y1;
	push_set_scissor.order = order;
}

PushClearScissor :: (group : *RenderGroup, order : int = 0)
{
	push_clear_scissor : *RenderEntry(RClearScissor) = PushRenderEntry(group, RClearScissor);	
	push_clear_scissor.order = order;
}

PushClear :: (color : Vector4F, group : *RenderGroup, order : int = 0) {
	clear : *RenderEntry(RClear) = PushRenderEntry(group, RClear);
	clear.color = color;
	clear.order = order;
}

PushText :: (offset : Vector2F, text_string : string, color : Vector4F, group : *RenderGroup, order : int = 0) {
	text : *RenderEntry(RText) = PushRenderEntry(group, RText);
	text.basis = *group.default_basis;
	text.offset = offset;
	text.color = color;
	text.order = order;
	//TODO where should we store this, currently storing it right after the RenderEntry(RText)
	//probably worth reconsidering once we optimize the renderer
	//if we only have 1 array for triangles and 1 array for text and 1 array for bitmaps, etc...
	//TODO why not just copy the string data pointer and count itself?
	text.data.text.data = PushArray(*group.render_push_buffer, u8, text_string.count);
	text.data.text.count = text_string.count;
	memcpy(text.data.text.data, text_string.data, text_string.count);
}

//TODO should we transform to viewport space in the Push functions?
PushLine :: (offset : Vector2F, end : Vector2F, color : Vector4F, group : *RenderGroup, order : int = 0) {
	line : *RenderEntry(RLine) = PushRenderEntry(group, RLine);
	line.basis = *group.default_basis;
	line.offset = offset;
	line.color = color;
	line.order = order;
	line.data.end = end;
}


PushRectangle :: (rect : Rectangle2, color : Vector4F, group : *RenderGroup, order : int = 0) {
	entry_rect : *RenderEntry(RRectangle) = PushRenderEntry(group, RRectangle);
	entry_rect.basis = *group.default_basis;
	entry_rect.offset = GetCenter(rect);
	entry_rect.color = color;
	entry_rect.order = order;
	entry_rect.data.rect = rect;
}

//TODO should make a pure 2D version
//TODO check for invalid trianglaes? with NANs and infinities
//Note : x and y are pixels and z is for the depth buffer
//Therefore this function takes in an already projected triangle
PushFilledTriangle :: (triangle : Triangle3F, color : Vector4F, group : *RenderGroup, 
					   shade : Vector3F = Vector3F.{1,1,1}, order : int = 0) {
	rect : *RenderEntry(RTriangle) = PushRenderEntry(group, RTriangle);
	rect.basis = *group.default_basis;
	rect.order = order;
	rect.color = color;
	rect.data.shade = shade;
	rect.data.triangle = triangle;
}

} else {
PushRenderEntry :: (group : *RenderGroup, $render_type : RenderType) -> *RenderHeader {
	// assert(group.render_count + 1 <= group.render_sort_buffer.count, 
	// 		"render_count is % and render_sort_buffer.count is %\n", group.render_count, group.render_sort_buffer.count);
	//TODO could replace this with RenderHeader
	render_header : *RenderHeader;
	// size := size_of(type);
	size : s64 = SizeOfRenderType(render_type);
	if group.render_push_buffer.used + size < group.render_push_buffer.size {
		render_header = cast(*RenderHeader) (group.render_push_buffer.base + group.render_push_buffer.used);
		// render_header.type = type;
		render_header.render_type = render_type;
		group.render_push_buffer.used += size;

		array_add(*group.render_sort_buffer, render_header);
	} else {
		assert(!"No memory left in render group");
	}	
	return render_header;
}

PushShaderEntries :: (group : *RenderGroup, text_order : int, color_order : int, flush_order : int) {
	PushSetShaderText(group, text_order);
	PushSetShaderColor(group, color_order);
	PushImmediateFlush(group, flush_order);
}

PushImmediateFlush :: (group : *RenderGroup, order : int = 0) {
	flush := cast(*RImmediateFlush) PushRenderEntry(group, RenderType.IMMEDIATE_FLUSH);
	// flush := cast(*RImmediateFlush) PushRenderEntry(group, RImmediateFlush);
	flush.order = order;
}

PushSetShaderText :: (group : *RenderGroup, order : int = 0) {
	text_color := cast(*RSetShaderText) PushRenderEntry(group, RenderType.SET_SHADER_TEXT);
	// text_color := cast(*RSetShaderText) PushRenderEntry(group, RSetShaderText);
	text_color.order = order;
}

PushSetShaderColor :: (group : *RenderGroup, order : int = 0) {
	shader_color := cast(*RSetShaderColor) PushRenderEntry(group, RenderType.SET_SHADER_COLOR);
	// shader_color := cast(*RSetShaderColor) PushRenderEntry(group, RSetShaderColor);
	shader_color.order = order;
}

//TODO could do this directly based on render group coordinates/bounds
PushSetScissor :: (
	x0 : float, y0 : float, x1 : float, y1 : float,
	group : *RenderGroup,
	order : int = 0)
{
	push_set_scissor := cast(*RSetScissor) PushRenderEntry(group, RenderType.SET_SCISSOR);
	// push_set_scissor := cast(*RSetScissor) PushRenderEntry(group, RSetScissor);
	push_set_scissor.x0 = x0;
	push_set_scissor.y0 = y0;
	push_set_scissor.x1 = x1;
	push_set_scissor.y1 = y1;
	push_set_scissor.order = order;
}

PushClearScissor :: (group : *RenderGroup, order : int = 0)
{
	push_clear_scissor := cast(*RClearScissor) PushRenderEntry(group, RenderType.CLEAR_SCISSOR);	
	// push_clear_scissor := cast(*RClearScissor) PushRenderEntry(group, RClearScissor);	
	push_clear_scissor.order = order;
}

PushClear :: (color : Vector4F, group : *RenderGroup, order : int = 0) {
	clear := cast(*RClear) PushRenderEntry(group, RenderType.CLEAR);
	// clear := cast(*RClear) PushRenderEntry(group, RClear);
	clear.color = color;
	clear.order = order;
}

PushText :: (offset : Vector2F, text_string : string, color : Vector4F, group : *RenderGroup, order : int = 0) {
	text := cast(*RText) PushRenderEntry(group, RenderType.TEXT);
	// text := cast(*RText) PushRenderEntry(group, RText);
	text.offset = offset;
	text.color = color;
	text.order = order;
	//TODO where should we store this, currently storing it right after the RenderEntry(RText)
	//probably worth reconsidering once we optimize the renderer
	//if we only have 1 array for triangles and 1 array for text and 1 array for bitmaps, etc...
	//TODO why not just copy the string data pointer and count itself?
	text.text.data = PushArray(*group.render_push_buffer, u8, text_string.count);
	text.text.count = text_string.count;
	/*DOC : if count == 0 then this works but if data == null and count > 0 then this fails
	which it should because then we have an invalid string
	so we dont have to check if text_string.count == 0 and return
	we could assert text_string.data != null but it would crash in the same place anyways i think.
	*/
	memcpy(text.text.data, text_string.data, text_string.count);
}

//TODO should we transform to viewport space in the Push functions?
PushLine :: (offset : Vector2F, end : Vector2F, color : Vector4F, group : *RenderGroup, order : int = 0) {
	line := cast(*RLine) PushRenderEntry(group, RenderType.LINE);
	// line := cast(*RLine) PushRenderEntry(group, RLine);
	line.offset = offset;
	line.color = color;
	line.order = order;
	line.end = end;
}


PushRectangle :: (rect : Rectangle2, color : Vector4F, group : *RenderGroup, order : int = 0) {
	entry_rect := cast(*RRectangle) PushRenderEntry(group, RenderType.RECTANGLE);
	// entry_rect := cast(*RRectangle) PushRenderEntry(group, RRectangle);
	entry_rect.color = color;
	entry_rect.order = order;
	entry_rect.rect = rect;
}

//TODO should make a pure 2D version
//TODO check for invalid trianglaes? with NANs and infinities
//Note : x and y are pixels and z is for the depth buffer
//Therefore this function takes in an already projected triangle
PushFilledTriangle :: (triangle : Triangle3F, color : Vector4F, group : *RenderGroup, 
					   shade : Vector3F = Vector3F.{1,1,1}, order : int = 0) {
	rect := cast(*RTriangle) PushRenderEntry(group, RenderType.TRIANGLE);
	// rect := cast(*RTriangle) PushRenderEntry(group, RTriangle);
	rect.order = order;
	rect.color = color;
	rect.shade = shade;
	rect.triangle = triangle;
}
}

PushTriangle2D :: (tri : Triangle2F, color : Vector4F, group : *RenderGroup, shade := Vector3F.{1,1,1}, order : int = 0) {
	viewport_tri := ViewportOffset(tri, group);
	PushFilledTriangle(MakeTriangle3F(viewport_tri), color, group, shade, order);
}

PushSetScissor :: inline (rect : Rectangle2, group : *RenderGroup, order : int = 0) {
	PushSetScissor(rect.min.x, rect.min.y, rect.max.x, rect.max.y, group, order);
}

PushRectangle :: inline (offset : Vector2F, dim : Vector2F, color : Vector4F, group : *RenderGroup, order : int = 0) {
	rect : Rectangle2 = RectCenterDim(offset, dim);	
	PushRectangle(rect, color, group, order);
}

PushRectangleOutline :: (offset : Vector2F, dim : Vector2F, color : Vector4F, 
						 group : *RenderGroup, r : float = 2.0, order : int = 0) 
{
	rect : Rectangle2 = RectCenterDim(offset, dim);
	#if 1 {
	PushRectangleOutline(rect, color, group, r, order);
	} else {
	//TODO Remove this once we know the top one is working
	R : float = r / group.pixels_per_square;
	PushRectangle(RectMinMax(MakeV2F(rect.min.x - R/2.0, rect.min.y - R/2.0), MakeV2F(rect.min.x + R/2.0, rect.max.y + R/2.0)), color, group, order);
	PushRectangle(RectMinMax(MakeV2F(rect.min.x - R/2.0, rect.min.y - R/2.0), MakeV2F(rect.max.x + R/2.0, rect.min.y + R/2.0)), color, group, order);
	PushRectangle(RectMinMax(MakeV2F(rect.max.x - R/2.0, rect.min.y - R/2.0), MakeV2F(rect.max.x + R/2.0, rect.max.y + R/2.0)), color, group, order);
	PushRectangle(RectMinMax(MakeV2F(rect.min.x - R/2.0, rect.max.y - R/2.0), MakeV2F(rect.max.x + R/2.0, rect.max.y + R/2.0)), color, group, order);
	}
}

PushRectangleOutline :: (rect : Rectangle2, color : Vector4F, 
						 group : *RenderGroup, r : float = 2.0, order : int = 0) 
{
	R : float = r / group.pixels_per_square;
	#if 1 {
	PushRectangle(RectLeftOutline(rect,R), color, group, order);
	PushRectangle(RectBottomOutline(rect,R), color, group, order);
	PushRectangle(RectRightOutline(rect,R), color, group, order);
	PushRectangle(RectTopOutline(rect,R), color, group, order);
	} else {
	//TODO Remove this once we know the top one is working
	PushRectangle(RectMinMax(MakeV2F(rect.min.x - R/2.0, rect.min.y - R/2.0), MakeV2F(rect.min.x + R/2.0, rect.max.y + R/2.0)), color, group, order);
	PushRectangle(RectMinMax(MakeV2F(rect.min.x - R/2.0, rect.min.y - R/2.0), MakeV2F(rect.max.x + R/2.0, rect.min.y + R/2.0)), color, group, order);
	PushRectangle(RectMinMax(MakeV2F(rect.max.x - R/2.0, rect.min.y - R/2.0), MakeV2F(rect.max.x + R/2.0, rect.max.y + R/2.0)), color, group, order);
	PushRectangle(RectMinMax(MakeV2F(rect.min.x - R/2.0, rect.max.y - R/2.0), MakeV2F(rect.max.x + R/2.0, rect.max.y + R/2.0)), color, group, order);
	}
}
RectRenderLeftOutline :: inline (rect : Rectangle2, r : float, pixels_per_square : float) -> Rectangle2 {
	return RectLeftOutline(rect, r / pixels_per_square);
}
RectRenderBottomOutline :: inline (rect : Rectangle2, r : float, pixels_per_square : float) -> Rectangle2 {
	return RectBottomOutline(rect, r / pixels_per_square);
}
RectRenderRightOutline :: inline (rect : Rectangle2, r : float, pixels_per_square : float) -> Rectangle2 {
	return RectRightOutline(rect, r / pixels_per_square);
}
RectRenderTopOutline :: inline (rect : Rectangle2, r : float, pixels_per_square : float) -> Rectangle2 {
	return RectTopOutline(rect, r / pixels_per_square);
}

PushCircleOutline :: inline (c : Circle2, color : Vector4F, render_group : *RenderGroup,
	res : int = 20, r : float = 0.05, shade := Vector3F.{1,1,1}, order : int = 0) 
{
	PushCircleOutline(c.pos, c.radius, color, render_group, res, r, shade, order);
}
//TODO Can also pass in r
PushCircleOutline :: (pos : Vector2F, radius : float, color : Vector4F, render_group : *RenderGroup,
	res : int = 20, r : float = 0.05, shade := Vector3F.{1,1,1}, order : int = 0) 
{
	PushQuadLineViewport(
		pos + GetCirclePoint((res-1) / cast(float) res) * radius, 
		pos + GetCirclePoint(0) * radius, 
		color, r, render_group, shade, order);
	for 1..res-1 {
		PushQuadLineViewport(
			pos + GetCirclePoint(it / cast(float) res) * radius, 
			pos + GetCirclePoint((it-1) / cast(float) res) * radius, 
			color, r, render_group, shade, order);
	}
}

PushCircle :: inline (c : Circle2, color : Vector4F, render_group : *RenderGroup,
	res : int = 20,  shade := Vector3F.{1,1,1}, order : int = 0) 
{
	PushCircle(c.pos, c.radius, color, render_group, res, shade, order);
}
//TODO Can do this call with RootsOfUnity as well maybe even passed in for efficiency.
PushCircle :: (pos : Vector2F, radius : float, color : Vector4F, render_group : *RenderGroup,
	res : int = 20, shade := Vector3F.{1,1,1}, order : int = 0) 
{
	t := MakeTriangle2F(pos,
		pos + GetCirclePoint((res-1) / cast(float) res) * radius, 
		pos + GetCirclePoint(0) * radius);
	ViewportOffset(*t, render_group);
	//TODO Can push 2D triangles in here once we update the renderer to have separate 2d triangles from 3d
	PushFilledTriangle(MakeTriangle3F(t), color, render_group, shade, order);
	for 1..res-1 {
		t = MakeTriangle2F(pos,
			pos + GetCirclePoint((it-1) / cast(float) res) * radius, 
			pos + GetCirclePoint(it / cast(float) res) * radius);
		ViewportOffset(*t, render_group);
		PushFilledTriangle(MakeTriangle3F(t), color, render_group, shade, order);
	}
}


//RENDERING (should eventually put in own file / module)
//TODO structure this for jai and then read in header and bits and print out to screen buffer
BitmapHeader :: struct {
    fileType : u16;
    fileSize : u32 #align 2;
    reserved1 : u16 #align 6;
    reserved2 : u16 #align 8;
    bitmapOffset : u32 #align 10;
    size : u32 #align 14;
    width : s32 #align 18;
    height : s32 #align 22;
    planes : u16 #align 26;
    bitsPerPixel : u16 #align 28;
    compression : u32 #align 30;
    sizeOfBitmap : u32 #align 34;
    horzResolution : s32 #align 38;
    vertResolution : s32 #align 42;
    colorsUsed : u32 #align 46;
    colorsImportant : u32 #align 50;

    redMask : u32 #align 54;
    greenMask : u32 #align 58;
    blueMask : u32 #align 62;
};

#if 0 {
//TODO this should probably be passed in by platform since it is likely
//that other platforms will have different rgba order than windows
LoadBitmap :: (file_name : string, read_entire_file : ReadFileType) -> RenderBuffer {
    result : RenderBuffer;

    debug_read_file : DebugReadFileResult = read_entire_file(file_name);
    bitmap_header := cast(*BitmapHeader) debug_read_file.Contents;

    assert(bitmap_header.compression == 3);

    pixels := cast(*u32) ((cast(*u8) debug_read_file.Contents) + bitmap_header.bitmapOffset);
    result.bitmap = pixels;
    result.width = bitmap_header.width;
    result.height = bitmap_header.height;

    ColorMaskToShift :: inline (mask : u32) -> u32 {
        shift : u32 = mask;
        if mask - 0xff == 0 {
            shift = 0;
        }
        else if mask - 0xff00 == 0 {
            shift = 8;
        }
        else if mask - 0xff0000 == 0 {
            shift = 16;
        }
        else if mask - 0xff000000 == 0 {
            shift = 24;
        }
        return shift;
    }

    alpha_mask := ~(bitmap_header.redMask | bitmap_header.greenMask | bitmap_header.blueMask);
    red_shift := ColorMaskToShift(bitmap_header.redMask);
    green_shift := ColorMaskToShift(bitmap_header.greenMask);
    blue_shift := ColorMaskToShift(bitmap_header.blueMask);
    alpha_shift := ColorMaskToShift(alpha_mask); 

    total_pixel_num := bitmap_header.width * bitmap_header.height;
    //TODO we just point directly to the bitmap memory for now but we could copy it over to
    //our memory like we did below as well
    // game_state.Bitmap = cast(*u32) PushArray(*game_state.Memory, size_of(u32), total_pixel_num); //32 bits per pixel
    pixel_num : int;
    while pixel_num < total_pixel_num {
        defer pixel_num += 1;
        //Here we convert from the bitmap pixel (defined by bitmap header masks above)
        //to windows pixel which is 0xaarrggbb
        blue_value : u32 = ((pixels[pixel_num] >> blue_shift) & 0xFF);
        green_value : u32 = ((pixels[pixel_num] >> green_shift) & 0xFF) << 8;
        red_value : u32 = ((pixels[pixel_num] >> red_shift) & 0xFF) << 16;
        alpha_value : u32 = ((pixels[pixel_num] >> alpha_shift) & 0xFF) << 24;
        pixel_color_adjusted : u32 = red_value | green_value | blue_value | alpha_value;
        result.bitmap[pixel_num] = pixel_color_adjusted;
    }
    return result;
}
}

SetDepthValue :: inline (x : int, y : int, value : float, render_buffer : *RenderBuffer) {
	point : int = y * render_buffer.width + x;
	render_buffer.depth_buffer[point] = value;
}

GetDepthValue :: inline (x : int, y : int, render_buffer : RenderBuffer) -> float {
	point : int = y * render_buffer.width + x;
	result : float = render_buffer.depth_buffer[point];
	return result;
}

PushCross :: (center : Vector2F, width : float, height : float, color : Vector4F,
              render_group : *RenderGroup, R : float = 0.2, order : int = 0)
{
    horizontal : Rectangle2 = RectCenterDim(center, MakeV2F(width, R));
    PushRectangle(horizontal, color, render_group, order);

    vertical : Rectangle2 = RectCenterDim(center, MakeV2F(R, height));
    PushRectangle(vertical, color, render_group, order);
}

PushRenderX :: (
	x_pos : Vector2F,
	x_dim : Vector2F,
	color : Vector4F,
	render_group : *RenderGroup,
	render_order : int, 
	width_factor : float = 1.0,
	thickness_factor : float = 0.11)
{
   x_dim_factor : Vector2F = x_dim;
   x_dim_factor.x *= width_factor;
   x_dim_factor.y *= thickness_factor;
   TransformAndPushQuad(x_pos, x_dim_factor, color, render_group,
   	ROTATE_45, order=render_order);
   TransformAndPushQuad(x_pos, x_dim_factor, color, render_group,
   	ROTATE_NEG45, order=render_order);
}
PushRenderX :: inline (
	x_rect : Rectangle2,
	color : Vector4F,
	render_group : *RenderGroup,
	render_order : int, 
	width_factor : float = 1.0,
	thickness_factor : float = 0.11)
{
	PushRenderX(GetCenter(x_rect), GetDim(x_rect), color, render_group, render_order, width_factor, thickness_factor);
}


PushRectangleWireMesh :: (rect : Rectangle2, color : Vector4F, render_group : *RenderGroup) {
	minx_maxy := MakeV2F(rect.min.x, rect.max.y);
	maxx_miny := MakeV2F(rect.max.x, rect.min.y);
	PushLine(rect.min, minx_maxy, color, render_group);
	PushLine(rect.min, maxx_miny, color, render_group);
	PushLine(minx_maxy, rect.max, color, render_group);	
	PushLine(maxx_miny, rect.max, color, render_group);		
}

PushRectangleWireMesh :: (center : Vector2F, dim : Vector2F, color : Vector4F, render_group : *RenderGroup) {
	rect : Rectangle2 = RectCenterDim(center, dim);
	PushRectangleWireMesh(rect, color, render_group);
}

PushTriangleWireMesh :: inline (triangle : Triangle2F, color : Vector4F, render_group : *RenderGroup, order : int = 0) {
	PushTriangleWireQuadMesh(triangle.a, triangle.b, triangle.c, color, render_group, order);
}

PushTriangleWireQuadMesh :: inline (v0 : Vector2F, v1 : Vector2F, v2 : Vector2F, color : Vector4F, render_group : *RenderGroup, order : int = 0) {
	PushQuadLine(v0, v1, color, 0.2, render_group, order = order);
	PushQuadLine(v0, v2, color, 0.2, render_group, order = order);
	PushQuadLine(v1, v2, color, 0.2, render_group, order = order);
}

PushTriangleWireMesh :: inline (triangle : Triangle3F, color : Vector4F, render_group : *RenderGroup, order : int = 0) {
	PushTriangleWireQuadMesh(triangle.a, triangle.b, triangle.c, color, render_group, order);
}

PushTriangleWireQuadMesh :: inline (v0 : Vector3F, v1 : Vector3F, v2 : Vector3F, color : Vector4F, render_group : *RenderGroup, order : int = 0) {
	//TODO Need a version of this where we pass in z for depth testing. Although having it as an option
	//to see a mesh behind a cube might be worth it...
	PushQuadLine(v0.xy, v1.xy, color, 0.7*v0.z, render_group, order = order);
	PushQuadLine(v0.xy, v2.xy, color, 0.7*v0.z, render_group, order = order);
	PushQuadLine(v1.xy, v2.xy, color, 0.7*v1.z, render_group, order = order);
}

//TODO do this all with triangles and then maybe make quad just [2] Triangle2F
PushQuad :: inline (quad : Quad2F, color : Vector4F, render_group : *RenderGroup,
			 		shade : Vector3F = Vector3F.{1,1,1}, order : int = 0)
{
	PushQuad(quad.a, quad.b, quad.c, quad.d, color, render_group, shade, order);
}

PushQuadViewport :: inline (quad : Quad2F, color : Vector4F, render_group : *RenderGroup,
			 				shade : Vector3F = Vector3F.{1,1,1}, order : int = 0)
{
	quad_viewport : Quad2F = ViewportOffset(quad, render_group);
	PushQuad(quad_viewport.a, quad_viewport.b, quad_viewport.c, quad_viewport.d, color, render_group, shade, order);
}

PushQuad :: inline (bottom_left : Vector2F, top_left : Vector2F,
			 		top_right : Vector2F, bottom_right : Vector2F,
		 	 		color : Vector4F, render_group : *RenderGroup,
			 		shade : Vector3F = Vector3F.{1,1,1}, order : int = 0)
{
	bottom_left_v3 : Vector3F = MakeV3F(bottom_left, 0);
	top_left_v3 : Vector3F = MakeV3F(top_left, 0);
	bottom_right_v3 : Vector3F = MakeV3F(bottom_right, 0);
	top_right_v3 : Vector3F = MakeV3F(top_right, 0);
	PushQuad(bottom_left_v3, top_left_v3, top_right_v3, bottom_right_v3, color, render_group, shade, order);
}

PushQuad :: inline (bottom_left : Vector3F, top_left : Vector3F,
			 		top_right : Vector3F, bottom_right : Vector3F,
		 	 		color : Vector4F, render_group : *RenderGroup,
			 		shade : Vector3F = Vector3F.{1,1,1}, order : int = 0)
{
	tri_0 : Triangle3F = MakeTriangle3F(bottom_left, top_left, top_right);
	PushFilledTriangle(tri_0, color, render_group, shade, order);

	tri_1 : Triangle3F = MakeTriangle3F(bottom_left, top_right, bottom_right);
	PushFilledTriangle(tri_1, color, render_group, shade, order);
}

//TODO should this just return [2] Triangle2F?
//TODO should we use Matrix3x2F here instead of transform and offset?
TransformRectangleQuad :: inline (center : Vector2F, dim : Vector2F, render_group : RenderGroup,
		  	  	 				  transform : Matrix2F = Matrix2F_IDENTITY, cam_offset : Vector2F = Vector2F.{0,0}) -> Quad2F
{
	c_offset := center - cam_offset;
	rect : Rectangle2 = RectCenterDim(c_offset, dim);
	bottom_left : Vector2F = TransformAboutPoint(rect.min, transform, c_offset);
	top_left : Vector2F = TransformAboutPoint(MakeV2F(rect.min.x, rect.max.y), transform, c_offset);
	top_right : Vector2F = TransformAboutPoint(rect.max, transform, c_offset);
	bottom_right : Vector2F = TransformAboutPoint(MakeV2F(rect.max.x, rect.min.y), transform, c_offset);
	result : Quad2F = MakeQuad2F(bottom_left, top_left, top_right, bottom_right);
	return result;		
}

TransformAndPushQuad :: inline (center : Vector2F, dim : Vector2F, color : Vector4F,
						 		render_group : *RenderGroup, transform : Matrix2F = Matrix2F_IDENTITY,
						 		cam_offset : Vector2F = Vector2F.{0,0},
						 		shade : Vector3F = Vector3F.{1,1,1}, order : int = 0)
{
	quad : Quad2F = TransformRectangleQuad(center, dim, <<render_group, transform, cam_offset);
	ViewportOffset(*quad, render_group);
	PushQuad(quad, color, render_group, shade, order);
}

TransformAndPushQuadOutline :: inline (center : Vector2F, dim : Vector2F, color : Vector4F,
						 			   render_group : *RenderGroup, transform : Matrix2F = Matrix2F_IDENTITY,
						 			   offset : Vector2F = Vector2F.{0,0}, r : float = 2.0,
						 			   shade : Vector3F = Vector3F.{1,1,1}, order : int = 0)
{
	R : float = r / render_group.pixels_per_square;
    rect : Rectangle2 = RectCenterDim(offset, dim);

	center_1 : Vector2F = center + MakeV2F(0, 0.5*(dim.y - R));
	center_1 = TransformAboutPoint(center_1, transform, center);
	dim_1 : Vector2F = MakeV2F(dim.x, R);
    quad_1 : Quad2F = TransformRectangleQuad(center_1, dim_1, render_group, transform, offset);
    ViewportOffset(*quad_1, render_group);
    PushQuad(quad_1, color, render_group, shade, order);

	center_2 : Vector2F = center + MakeV2F(0, 0.5*(-dim.y + R));
	center_2 = TransformAboutPoint(center_2, transform, center);
	dim_2 : Vector2F = MakeV2F(dim.x, R);
    quad_2 : Quad2F = TransformRectangleQuad(center_2, dim_2, render_group, transform, offset);
    ViewportOffset(*quad_2, render_group);
    PushQuad(quad_2, color, render_group, shade, order);

	center_3 : Vector2F = center + MakeV2F(0.5*(-dim.x + R), 0);
	center_3 = TransformAboutPoint(center_3, transform, center);
	dim_3 : Vector2F = MakeV2F(R, dim.y);
    quad_3 : Quad2F = TransformRectangleQuad(center_3, dim_3, render_group, transform, offset);
    ViewportOffset(*quad_3, render_group);
    PushQuad(quad_3, color, render_group, shade, order);

	center_4 : Vector2F = center + MakeV2F(0.5*(dim.x - R), 0);
	center_4 = TransformAboutPoint(center_4, transform, center);
	dim_4 : Vector2F = MakeV2F(R, dim.y);
    quad_4 : Quad2F = TransformRectangleQuad(center_4, dim_4, render_group, transform, offset);
    ViewportOffset(*quad_4, render_group);
    PushQuad(quad_4, color, render_group, shade, order);
}

//TODO Could make a version of this that return 2 triangles instead.
MakeQuadLine :: (start : Vector2F, end : Vector2F, thickness : float) -> Quad2F
{
	v_diff : Vector2F = end - start;
	length : float = Length(v_diff);
	theta : float = atan2(v_diff.y, v_diff.x);
	rotation := MakeRotationMatrix2F(theta);
	scale := MakeScaleMatrix2F(length, 1.0);
	transform : Matrix2F = rotation * scale;

	//Note : doing in clockwise motion for now
	//TODO multiplying thickness by length here is a hack for now to consider perspective projection
	lower_left  := start + (transform * MakeV2F(0,-thickness));
	lower_right := start + (transform * MakeV2F(1,-thickness));
	upper_left  := start + (transform * MakeV2F(0, thickness));
	upper_right := start + (transform * MakeV2F(1, thickness));

	quad := MakeQuad2F(lower_left, upper_left, upper_right, lower_right);
	return quad;
}

PushQuadLine :: (start : Vector2F, end : Vector2F, color : Vector4F, thickness : float, 
				 render_group : *RenderGroup, shade : Vector3F = Vector3F.{1,1,1}, order : int = 0)
{
	quad : Quad2F = MakeQuadLine(start, end, thickness);
	PushQuad(quad, color, render_group, shade, order);
}

PushQuadLineViewport :: (start : Vector2F, end : Vector2F, color : Vector4F, thickness : float, 
				 render_group : *RenderGroup, shade : Vector3F = Vector3F.{1,1,1}, order : int = 0)
{
	quad : Quad2F = MakeQuadLine(start, end, thickness * render_group.zoom_factor);
	ViewportOffset(*quad, render_group);
	PushQuad(quad, color, render_group, shade, order);
}

//TODO remove color not needed
MakeQuadArrow :: (start : Vector2F, end : Vector2F, thickness : float) 
-> line : Quad2F, arrow : Triangle2F
{
	v_diff : Vector2F = end - start;
	length : float = Length(v_diff);
	arrow_size : float = thickness * 6.0;
	arrow_length : float = arrow_size - thickness * 2.5;
	//Old hard-coded version
	// arrow_size : float = 0.7;
	// arrow_length : float = arrow_size - 0.25;
	ratio : float = (length - arrow_size) / length;
	line : Quad2F = MakeQuadLine(start, start + ratio*v_diff, thickness);

	theta : float = atan2(v_diff.y, v_diff.x);
	rotation := MakeRotationMatrix2F(theta);

	arrow_start : Vector2F = start + ratio*v_diff;
	lower_left  := arrow_start + (rotation * MakeV2F(0,-(arrow_length)));
	upper_left  := arrow_start + (rotation * MakeV2F(0, (arrow_length)));
	right_side  := arrow_start + (rotation * MakeV2F((1-ratio) * length, 0));

	arrow := MakeTriangle2F(lower_left, right_side, upper_left);
	return line, arrow;
}

//TODO should we just have arrow here or do we need quad line as well
PushQuadArrowViewport :: (start : Vector2F, end : Vector2F, color : Vector4F,
				  		  thickness : float, render_group : *RenderGroup,
			  	  		  shade : Vector3F = Vector3F.{1,1,1}, order : int = 0)
{
	line, arrow := MakeQuadArrow(start, end, thickness * render_group.zoom_factor);
	ViewportOffset(*line, render_group);
	PushQuad(line, color, render_group, shade, order);

	ViewportOffset(*arrow, render_group);
	arrow_3F := MakeTriangle3F(arrow);
	PushFilledTriangle(arrow_3F, color, render_group, shade, order);
}

//TODO should we move this to thegame_math?
EdgeCubeTransform :: (v1 : Vector3F, v2 : Vector3F) -> Matrix4F {
    edge_homogeneous := EdgeCubeHomogeneous(v1, v2);
    edge_transform := MakeMatrix4F(edge_homogeneous);
    return edge_transform;
}

//TODO should we move this to thegame_math?
EdgeCubeHomogeneous :: (v1 : Vector3F, v2 : Vector3F) -> Matrix4x3F {
	delta : Vector3F = v2 - v1;
	length : float = Length(delta);
	rot_matrix := MakeRotationAssumeDirNormal(Vector3F.{1,0,0}, v1, v2);
	pos : Vector3F = Lerp(v1, 0.5, v2);
	scale : Matrix3F = MakeScaleMatrix(length, 0.1, 0.1);
    edge_transform := MakeMatrix4x3F(rot_matrix * scale, pos);
    return edge_transform;
}

Viewport :: struct {
	cam_offset : Vector2F;
	//Note : Adding full_dim here so we have conistency for rendering
	//TODO Can we remove one of these later?
	full_dim : Vector2F;
	half_dim : Vector2F;

	//Note: useful for storing viewport of particular 3D frustum when we don't need polyhedron
	g : float;
	s : float;
}

MakeViewportFullDim :: inline (full_dim : Vector2F, depth : float) -> Viewport {
	viewport : Viewport = MakeViewportHalfDim(0.5 * full_dim, depth);
	//Note : Adding full_dim here so we have conistency for rendering
	viewport.full_dim = full_dim;
	return viewport;
}

MakeViewportHalfDim :: (half_dim : Vector2F, depth : float) -> Viewport {
	viewport : Viewport = ---;
	viewport.half_dim = half_dim;

	x : float = half_dim.x;
	y : float = half_dim.y;
	// y_factor : float = render_group.half_monitor_squares.y / y;
	// g_angle : float = 1.0 / tan(PI/3.06563 * 0.5);
	// g_ratio_to_y : float = render_group.focal_squares / render_group.half_monitor_squares.y;
	// g : float = y_factor*g_ratio_to_y; //z of viewport when y = 1

	//Note : multiply g*y or s*y to get z and x in squares respectively
	viewport.g = depth / y; //z of viewport when y = 1 (z / y ratio)
	viewport.s = x / y; //corresponds to viewport transform width / height ratio

	return viewport;
}

DebugMesh :: struct {
	print_check : bool;
	inv_camera : Matrix4F;
}

/*TODO If needed we could pull this out into a function for projecting from 3D using mvp matrix
to a corresponding 2D point. Also though we are double adding the screen_half_dim since we add it
int the TransformTriangleToViewport because we need correct triangle position for in-game calculations
but maybe if we use a different method then we can remove it altogether and not double compute it.
*/
Position3DTo2D :: inline (
	mvp : Matrix4F,
	viewport : Viewport,
	//TODO This doesn't need to be a pointer once we make it not a pointer in TransformTriangleToViewport
	render_group : *RenderGroup)
-> Vector2F, in_view_frustum : bool
{
	viewport_triangles : [] Triangle3F = 
		TransformTriangleToViewport(Triangle3F.{}, mvp, render_group, null, viewport, 0, backface_culling = false);

	if viewport_triangles.count > 0 {
		formatted_pos : Vector2F = viewport_triangles[0].a.xy;
		formatted_pos.x -= render_group.screen_half_dim.x / render_group.pixels_per_square;
		formatted_pos.y -= render_group.screen_half_dim.y / render_group.pixels_per_square;
		return formatted_pos, true;
	} else {
		return Vector2F.{}, false;
	}
}


//Note : only tested for cubes
//TODO remove render_buffer since it is unused and we only draw to render_group now
//TODO should we separate wire mesh out into separate function?
//TODO should we pass in all extra variables separately or have separate function?
/*TODO Color should just be part of the mesh I think and then we can set the color for each mesh.
OR remove color from mesh and just pass it in, whichever is more efficient.
TODO NEED A VERSION of draw_wire_mesh where we pass in the z value for the depth buffer
Can still keep a version without so we can see the mesh from behind. Maybe this could be an option.
Not sure which one is better overall.
*/
TransformAndPushMesh :: (mesh : FaceVertexMesh, mvp : Matrix4F,
						 render_group : *RenderGroup, render_buffer : *RenderBuffer,
						 viewport : Viewport = Viewport.{}, order : int = 0, 
						 color : Vector4F = Vector4F.{-1,-1,-1,-1},
						 $draw_wire_mesh : bool = false,
						 debug : DebugMesh = DebugMesh.{})
{
	for face : mesh.faces {
    	triangle := MakeTriangle3F(
			mesh.vertices[face.face_verts[0]],
			mesh.vertices[face.face_verts[1]],
			mesh.vertices[face.face_verts[2]]);
    	tri_color : Vector4F = face.color;
    	if color.x >= 0 tri_color = color;
    	TransformAndPushTriangle(triangle, mvp, tri_color, render_group, 
	    		render_buffer, viewport, order, draw_wire_mesh, debug);
	}
}

//TODO should we separate wire mesh out into separate function?
TransformAndPushTriangle :: (triangle : Triangle3F, mvp : Matrix4F, color : Vector4F, render_group : *RenderGroup,
							 render_buffer : *RenderBuffer, viewport : Viewport = Viewport.{},
							 order : int = 0, $draw_wire_mesh : bool = false,
							 debug : DebugMesh = DebugMesh.{})
{
	viewport_triangles : [] Triangle3F = 
		TransformTriangleToViewport(triangle, mvp, render_group,
  					  render_buffer, viewport, order, debug);
	for viewport_triangles {
		#if draw_wire_mesh {
			PushTriangleWireMesh(it, color, render_group, order);
		} else {
			PushFilledTriangle(it, color, render_group, MakeV3F(1.0, 1.0, 1.0), order);
		}
	}
}

TransformMeshToViewport :: (mesh : FaceVertexMesh, mvp : Matrix4F,
	    	render_group : *RenderGroup, render_buffer : *RenderBuffer,
	    	viewport : Viewport = Viewport.{}, order : int = 0, 
	    	debug : DebugMesh = DebugMesh.{}) -> [] Triangle3F
{
	result_triangles : [..] Triangle3F;
	result_triangles.allocator = temp;
    for face : mesh.faces {
    	triangle := MakeTriangle3F(
			mesh.vertices[face.face_verts[0]],
			mesh.vertices[face.face_verts[1]],
			mesh.vertices[face.face_verts[2]]);
	    viewport_triangles : [] Triangle3F = 
	    	TransformTriangleToViewport(triangle, mvp, render_group, 
	    		render_buffer, viewport, order, debug);
    	for viewport_triangles array_add(*result_triangles, it);

    	//FOR DEBUGGING AND TESTING
		#if 0 { if debug.print_check { 
    		//TODO move this into separate function
			t_world : Triangle4F;
		    for v, v_index : triangle.vertex t_world.vertex[v_index] = TransformVertex(v, mvp);
			if debug.print_check print("t_world is %\n\n", t_world);

		    t_camera : Triangle4F;
		    for v, v_index : triangle.vertex t_camera.vertex[v_index] = TransformVertex(v, debug.inv_camera * mvp);
			if debug.print_check print("t_camera is %\n\n", t_camera);

			t_pre_perp : Triangle4F;
			fovy_squares : float = render_group.half_monitor_squares.y * (1/tan(0.5 * PI/3.06563));
			if debug.print_check print("fovy_squares is %\n", fovy_squares);
		    for v, v_index : t_camera.vertex {
				t_pre_perp.vertex[v_index] = v * fovy_squares * (1/v.z);
			}
			if debug.print_check print("t_pre_perp is %\n\n", t_pre_perp);

			t_pixel_og := MakeTriangle3F(
						MakeV3F(render_group.pixels_per_square * render_group.half_monitor_squares.x * (t_pre_perp.a.x + 1.0),
								render_group.pixels_per_square * render_group.half_monitor_squares.y * (t_pre_perp.a.y + 1.0),
								t_pre_perp.a.z),
						MakeV3F(render_group.pixels_per_square * render_group.half_monitor_squares.x * (t_pre_perp.b.x + 1.0),
								render_group.pixels_per_square * render_group.half_monitor_squares.y * (t_pre_perp.b.y + 1.0),
								t_pre_perp.b.z),
						MakeV3F(render_group.pixels_per_square * render_group.half_monitor_squares.x * (t_pre_perp.c.x + 1.0),
								render_group.pixels_per_square * render_group.half_monitor_squares.y * (t_pre_perp.c.y + 1.0),
								t_pre_perp.c.z));		
			if debug.print_check print("t_pixel_og is %\n\n", t_pixel_og);
		}}
		//END OF DEBUGGING AND TESTING
	}
	return result_triangles;
}

//TODO pass in allocator for result_triangles
//TODO test a verson with orthographic projection (no perspective divide)
/*TODO Can replace render_group with just half_monitor_squares and can remove order and render_buffer
*/
TransformTriangleToViewport :: (
	triangle : Triangle3F, mvp : Matrix4F, render_group : *RenderGroup, 
    render_buffer : *RenderBuffer, viewport : Viewport = Viewport.{}, 
    //TODO ORDER IS NOT EVEN USED HERE!! REMOVE
    order : int = 0, 
    //TODO Make debug compile-time and this will be faster obviously
    debug : DebugMesh = DebugMesh.{},
    // $is_debug_mode : bool,
    $backface_culling : bool = true)
-> [] Triangle3F
{
    t_clip : Triangle4F;
    for v, v_index : triangle.vertex {
	    t_clip.vertex[v_index] = TransformVertex(v, mvp);
	}
	if debug.print_check print("t_clip is %\n\n", t_clip);
	//TODO can we remove this once we use glScissor?
	//TODO We can but we still need to filter out triangles
	//that are out of the viewport otherwise there is a smear
	//that happens. Also, it is more efficient to not render them.
	clipped_triangles : [] Triangle4F = ClipTriangleClipSpace(t_clip);
	result_triangles : [..] Triangle3F;
	result_triangles.allocator = temp;
	for t_c : clipped_triangles {
		//TODO Can we pass to the gpu from here and do as many calculation on the gpu as possible?
		//Even the viewport transform has values that only change if the op_space is moved or resized
		//So it may be possible to set those in the gpu and reuse them globally for each op_space.
		t_perp : Triangle3F = PerspectiveDivideClipSpace(t_c);
		if debug.print_check print("t_perp is %\n\n", t_perp);

		t_viewport : Triangle3F = ViewportTransform(t_perp, render_group, viewport);
		if debug.print_check print("t_viewport is %\n\n", t_viewport);

		#if backface_culling {
		o_area : float = OrientedArea(MakeTriangle2F(t_viewport));
		if o_area > 0 array_add(*result_triangles, t_viewport);
		} else {
		array_add(*result_triangles, t_viewport);
		}
	}		
	return result_triangles;
}

//TODO kept here for viewport testing code. could delete later if viewport testing finished
PushTriangleClipSpace :: (t_clip : Triangle4F, color : Vector4F, render_group : *RenderGroup, 
						  render_buffer : *RenderBuffer, viewport : Viewport = Viewport.{}, 
						  order : int = 0, debug : DebugMesh = DebugMesh.{})
{
	clipped_triangles : [] Triangle4F = ClipTriangleClipSpace(t_clip);
	for t_c : clipped_triangles {
		t_perp : Triangle3F = PerspectiveDivideClipSpace(t_c);
		if debug.print_check print("t_perp is %\n\n", t_perp);

		t_viewport : Triangle3F = ViewportTransform(t_perp, render_group, viewport);
		if debug.print_check print("t_viewport is %\n\n", t_viewport);

		//Back-face culling
		o_area : float = OrientedArea(MakeTriangle2F(t_viewport));
		if o_area > 0 {
			// DrawFilledTriangle(t_viewport, color, render_buffer);
			#if 0 {
				//TODO should bake normals into mesh and then convert to object space and then compute lighting
				//TODO this requires the original triangle and does not work in clip space
				normal : Vector3F = CrossProduct(triangle.b - triangle.a, triangle.c - triangle.a);
				light_a : float = ComputeLighting(triangle.a, normal, Vector3F.{} - triangle.a, -1, lights);
				light_b : float = ComputeLighting(triangle.b, normal, Vector3F.{} - triangle.b, -1, lights);
				light_c : float = ComputeLighting(triangle.c, normal, Vector3F.{} - triangle.c, -1, lights);
				PushFilledTriangle(t_viewport, color, render_group, MakeV3F(light_a, light_b, light_c));
			} else {
				PushFilledTriangle(t_viewport, color, render_group, MakeV3F(1.0, 1.0, 1.0), order);
			}
		}
	}
}

//TODO should we bake screen center offset into viewport_offset?
//TODO should we just leave it all up to the caller
//Note : for now it makes sense to default to set the grid to screen center with render_group
//Note : Z is for depth buffer currently not inverted
ViewportTransform :: inline (tri : Triangle3F, render_group : RenderGroup,
							 viewport : Viewport = Viewport.{}) -> Triangle3F 
{
	viewport_half_dim : Vector2F = viewport.half_dim;
	if viewport_half_dim.x == 0 || viewport_half_dim.y == 0 {
		viewport_half_dim.x = render_group.half_monitor_squares.x;
		viewport_half_dim.y = render_group.half_monitor_squares.y;
	}
	t_viewport := MakeTriangle3F(
		MakeV3F(viewport_half_dim.x * tri.a.x + viewport.cam_offset.x + render_group.half_monitor_squares.x,
				viewport_half_dim.y * tri.a.y + viewport.cam_offset.y + render_group.half_monitor_squares.y,
				tri.a.z),
		MakeV3F(viewport_half_dim.x * tri.b.x + viewport.cam_offset.x + render_group.half_monitor_squares.x,
				viewport_half_dim.y * tri.b.y + viewport.cam_offset.y + render_group.half_monitor_squares.y,
				tri.b.z),
		MakeV3F(viewport_half_dim.x * tri.c.x + viewport.cam_offset.x + render_group.half_monitor_squares.x,
				viewport_half_dim.y * tri.c.y + viewport.cam_offset.y + render_group.half_monitor_squares.y,
				tri.c.z));
	return t_viewport;
}

//TODO with Triangle2F as well
ViewportOffset :: inline (quad : Quad2F, render_group : RenderGroup) -> Quad2F {
	viewport_quad : Quad2F = quad;
	// viewport_quad += render_group.half_monitor_squares;
	viewport_quad += render_group.screen_half_dim * (1 / render_group.pixels_per_square);
	return viewport_quad;
}

ViewportOffset :: inline (quad : *Quad2F, render_group : RenderGroup) {
	// <<quad += render_group.half_monitor_squares;
	<<quad += render_group.screen_half_dim * (1 / render_group.pixels_per_square);
}

ViewportOffset :: inline (triangle : Triangle2F, render_group : RenderGroup) -> Triangle2F {
	viewport : Triangle2F = ---;
	viewport.a = triangle.a + render_group.half_monitor_squares;
	viewport.b = triangle.b + render_group.half_monitor_squares;
	viewport.c = triangle.c + render_group.half_monitor_squares;
	return viewport;
}

ViewportOffset :: inline (triangle : *Triangle2F, render_group : RenderGroup) {
	triangle.a += render_group.half_monitor_squares;
	triangle.b += render_group.half_monitor_squares;
	triangle.c += render_group.half_monitor_squares;
}

//TODO optimize with only division
PerspectiveDivideClipSpace :: inline (tri : Triangle4F) -> Triangle3F {
	a_w : float = 1.0 / tri.a.w;
	a_perp : Vector3F = a_w * tri.a.xyz;
	b_w : float = 1.0 / tri.b.w;
	b_perp : Vector3F = b_w * tri.b.xyz;
	c_w : float = 1.0 / tri.c.w;
	c_perp : Vector3F = c_w * tri.c.xyz;
	t_perp := MakeTriangle3F(a_perp, b_perp, c_perp);
	return t_perp;
}

//Note : Clip the vertices in the canonical clipping volume
ClipTriangleClipSpace :: (t_clip : Triangle4F) -> [] Triangle4F 
{
	IntersectionPoint :: inline (in : Vector4F, out : Vector4F) -> Vector4F {
		t : float;
		for 0..2 {
			p_in := in.component[it];
			p_out := out.component[it];
			numerator : float;
			denominator : float;
			if it == 2 && p_out < 0 {
				//Out of z near plane
				numerator = p_in;
				denominator = numerator - p_out;
			} else if p_out > out.w {
				//Out of upper x or y plane or z far plane
				numerator = p_in - in.w;
				denominator = numerator - (p_out - out.w);
			} else if p_out < -out.w {
				//Out of lower x or y plane
				numerator = p_in + in.w;
				denominator = numerator - (p_out + out.w);
			} 
			t_check : float = numerator / denominator;
			if t_check >= 0 && t_check <= 1 && denominator != 0 {
				t = t_check;
				break;
			}
		}
		inter : Vector4F = in + t * (out - in);
		return inter;
	}
	PointInViewFrustum :: inline (p_clip : Vector4F) -> bool {
	    result : bool = p_clip.x <= p_clip.w && p_clip.x >= -p_clip.w && //x in
	    				p_clip.y <= p_clip.w && p_clip.y >= -p_clip.w && //y in
	    				p_clip.z >= 0 && p_clip.z <= p_clip.w;		   //z in
	    return result;
	}
	
	clipped_triangles : [..] Triangle4F;
	//TODO uses jai temporary storage for now, should consider using other allocators (transient, etc...)
	clipped_triangles.allocator = temp; 

	a_in : bool = PointInViewFrustum(t_clip.a);
	b_in : bool = PointInViewFrustum(t_clip.b);
	c_in : bool = PointInViewFrustum(t_clip.c);

    if a_in && b_in && c_in {
    	//In canonical view volume / view frustum
    	array_add(*clipped_triangles, t_clip);
    } else if !a_in && !b_in && !c_in {
    	//Out of canonical view volume / view frustum
    } else {
		//TODO a good solution is to choose triangles vertices clockwise in the plane of the polygon
		//even better can choose triangles since we already know abc is stored clockwise in mesh
    	in : Vector4F;
    	out_1 : Vector4F;
    	out_2 : Vector4F;
    	one_point_in : bool = false;
		if a_in && !b_in && !c_in {
			one_point_in = true;
			in = t_clip.a;
			out_1 = t_clip.b;
			out_2 = t_clip.c;
		} else if !a_in && b_in && !c_in {
			one_point_in = true;
			in = t_clip.b;
			out_1 = t_clip.c;
			out_2 = t_clip.a;
		} else if !a_in && !b_in && c_in {
			one_point_in = true;
			in = t_clip.c;
			out_1 = t_clip.a;
			out_2 = t_clip.b;
		}

		if one_point_in {
			inter_1 : Vector4F = IntersectionPoint(in, out_1);
			inter_2 : Vector4F = IntersectionPoint(in, out_2);

			t1 := MakeTriangle4F(in, inter_1, inter_2);
			array_add(*clipped_triangles, t1);
		} else {
			//Two points in	
	    	out : Vector4F;
	    	in_1 : Vector4F;
	    	in_2 : Vector4F;
			if a_in && b_in && !c_in {
	    		out = t_clip.c;
	    		in_1 = t_clip.a;
	    		in_2 = t_clip.b;
	    	} else if a_in && !b_in && c_in {
	    		//TODO wrong orientation check
	    		out = t_clip.b;
	    		in_1 = t_clip.c;
	    		in_2 = t_clip.a;
			} else if !a_in && b_in && c_in {
	    		out = t_clip.a;
	    		in_1 = t_clip.b;
	    		in_2 = t_clip.c;
			}

			inter_1 : Vector4F = IntersectionPoint(in_1, out);
			inter_2 : Vector4F = IntersectionPoint(in_2, out);
			t1 : Triangle4F = MakeTriangle4F(inter_1, in_1, in_2);
			t2 : Triangle4F = MakeTriangle4F(in_2, inter_2, inter_1);
    		// t1 := MakeTriangle4F(in_2, inter_1, inter_2);
    		// t2 := MakeTriangle4F(in_1, inter_1, in_2);
			array_add(*clipped_triangles, t1);
			array_add(*clipped_triangles, t2);
		}
    }
    // print("clipped_triangles %\n", clipped_triangles);
	return clipped_triangles;	
}

/*
	s : x / y ratio
	g : focal squares 
	depth : z - depth / plane where to find vertices
	cam : homogeneous coordinates camera
*/
//TODO could have a version that takes frustum polyhedron
ComputeFrustumVertices :: (cam : Matrix4x3F, depth : float, s : float, g : float) -> [4] Vector3F {
	//TODO should we store matrices as column vectors
	cam_col_0 : Vector3F = MakeV3F(cam.m11, cam.m21, cam.m31);
	cam_col_1 : Vector3F = MakeV3F(cam.m12, cam.m22, cam.m32);
	cam_col_2 : Vector3F = MakeV3F(cam.m13, cam.m24, cam.m33);
	cam_col_3 : Vector3F = MakeV3F(cam.m14, cam.m24, cam.m34);

	x_factor : Vector3F = cam_col_0 * (depth * s / g);
	y_factor : Vector3F = cam_col_1 * (depth / g);
	z_factor : Vector3F = cam_col_2 * depth;
	frustum_v : [4] Vector3F;
	frustum_v[0] = cam_col_3 + x_factor + y_factor + z_factor; //upper-right
	frustum_v[1] = cam_col_3 + x_factor - y_factor + z_factor; //lower-right
	frustum_v[2] = cam_col_3 - x_factor - y_factor + z_factor; //lower-left
	frustum_v[3] = cam_col_3 - x_factor + y_factor + z_factor; //upper-left
	return frustum_v;
}

//TODO could we optimize this by just computing the dim directly with x_factor * 2 and y_factor * 2
ComputeFrustumDimAtDepth :: (cam : Matrix4x3F, depth : float, s : float, g : float) -> Vector2F {
	q : [4] Vector3F = ComputeFrustumVertices(cam, depth, s, g);
	dim : Vector2F = ---;
	dim.x = q[0].x - q[2].x;
	dim.y = q[0].y - q[2].y;
	return dim;
}

ClipState :: enum {
	ORIGINAL;
	CLIPPED;
	NO_DRAW;
}

FrustumPolyhedron :: struct {
	using polyhedron : Polyhedron(8, 6);
	g, s : float;
}
//TODO add edges and faces for different polyhedron shapes
Polyhedron :: struct($vertex_count : int, $plane_count : int) {
	vertex : [vertex_count] Vector3F;
	plane : [plane_count] Plane3F;
}
EdgePolyhedron :: struct {
	vertex_index : [2] u8;
	face_index : [2] u8;
}
FacePolyhedron :: struct {
	edge_count : u8;
	edge_index : [4] u8;
}
BuildFrustumPolyhedron :: (m_cam : Matrix4x3F, g : float, s : float, n : float, f : float) -> FrustumPolyhedron {
	frustum : FrustumPolyhedron;
	frustum.g = g;
	frustum.s = s;

	//Vertices for near side
	y : float = n / g;
	x : float = y * s;
	frustum.vertex[0] = TransformPoint(m_cam, MakeV3F( x, y, n));
	frustum.vertex[1] = TransformPoint(m_cam, MakeV3F( x,-y, n));
	frustum.vertex[2] = TransformPoint(m_cam, MakeV3F(-x,-y, n));
	frustum.vertex[3] = TransformPoint(m_cam, MakeV3F(-x, y, n));

	//Vertices for far side
	y = f / g;
	frustum.vertex[4] = TransformPoint(m_cam, MakeV3F( x, y, f));
	frustum.vertex[5] = TransformPoint(m_cam, MakeV3F( x,-y, f));
	frustum.vertex[6] = TransformPoint(m_cam, MakeV3F(-x,-y, f));
	frustum.vertex[7] = TransformPoint(m_cam, MakeV3F(-x, y, f));

	//Lateral planes
	inverse : Matrix4x3F = InverseLengyel(m_cam);
	mx : float = 1.0 / sqrt(g * g + s * s);
	my : float = 1.0 / sqrt(g * g + 1.0);
	frustum.plane[0] = MakePlane(-g * mx, 0, s * mx, 0) * inverse;
	frustum.plane[1] = MakePlane(0, g * my, my, 0) * inverse;
	frustum.plane[2] = MakePlane(g * mx, 0, s * mx, 0) * inverse;
	frustum.plane[3] = MakePlane(0, -g * my, my, 0) * inverse;

	//Near and far planes
	m_col3 : Vector3F = MakeV3F(m_cam.m13, m_cam.m23, m_cam.m33);
	m_col4 : Vector3F = MakeV3F(m_cam.m14, m_cam.m24, m_cam.m34);
	d : float = DotProduct(m_col3, m_col4);
	frustum.plane[4] = MakePlane(m_col3, -(d + n));
	frustum.plane[5] = MakePlane(m_col3,   d + f);
	return frustum;
}

//TODO would add/check planes here if we wanted multiple 3D spaces
FrustumPolyhedronClipping :: (triangle : Triangle3F, polyhedron : FrustumPolyhedron) -> [] Triangle3F {
    current_clip_state : ClipState = ClipState.ORIGINAL;
    triangles_to_draw : [] Triangle3F;
    for plane : polyhedron.plane {
		clipped_triangles, clip_state := ClipTriangle(triangle, plane);
		if clip_state == ClipState.CLIPPED {
			//TODO for now we just return the triangles clipped by the last plane in frustum_planes
			// if current_clip_state == ClipState.CLIPPED {
    			//TODO for now we dont draw on 2 clipping planes but should do 
    			//TODO multiple passes for multiple boundary clipping, n-clips = n-boundaries
    			// triangles_to_draw = .[];
    			// break;
			// } else {
				current_clip_state = ClipState.CLIPPED;
				triangles_to_draw = clipped_triangles;
				// print("plane clipped %\n", plane);
			// }
		} else if clip_state == ClipState.NO_DRAW {
			current_clip_state = ClipState.NO_DRAW;
			triangles_to_draw = .[];
			break;
		} else if clip_state == ClipState.ORIGINAL && 
			  current_clip_state != ClipState.CLIPPED 
	    {
			current_clip_state = ClipState.ORIGINAL;
			triangles_to_draw = clipped_triangles;
		}
	}
	return triangles_to_draw;
}

ClipTriangle :: inline (triangle : Triangle3F, plane : Plane3F) -> [] Triangle3F, ClipState {
	//TODO set allocator to transient when we make transient allocator_proc
	clipped_triangles : [..] Triangle3F;
	clipped_triangles.allocator = temp;

    ta_dist : float = DotPlane(plane, triangle.a);
    tb_dist : float = DotPlane(plane, triangle.b);
    tc_dist : float = DotPlane(plane, triangle.c);
    if ta_dist > 0 && tb_dist > 0 && tc_dist > 0 {
    	//In plane
    	array_add(*clipped_triangles, triangle);
		return clipped_triangles, ClipState.ORIGINAL;
    } else if ta_dist <= 0 && tb_dist <= 0 && tc_dist <= 0 {
    	//Out plane
    	return clipped_triangles, ClipState.NO_DRAW;
    } else { //triangle intersects with plane
		//One point in plane, first point in plane
		in : Vector3F;
		out_1 : Vector3F;
		out_2 : Vector3F;
		one_point_in : bool = false;
    	if ta_dist > 0 && tb_dist <= 0 && tc_dist <= 0 {
    		in = triangle.a;
    		out_1 = triangle.b;
    		out_2 = triangle.c;
    		one_point_in = true;
    	} else if tb_dist > 0 && ta_dist <= 0 && tc_dist <= 0 {
    		in = triangle.b;
    		out_1 = triangle.c;
    		out_2 = triangle.a;
    		one_point_in = true;
		} else if tc_dist > 0 && ta_dist <= 0 && tb_dist <= 0 {
    		in = triangle.c;
    		out_1 = triangle.a;
    		out_2 = triangle.b;
    		one_point_in = true;
    	}

    	if one_point_in {
			inter_1 : Vector3F = PlaneLineSegmentIntersectNoCheck(plane, in, out_1);
			inter_2 : Vector3F = PlaneLineSegmentIntersectNoCheck(plane, in, out_2);
			t1 := MakeTriangle3F(in, inter_1, inter_2);
			array_add(*clipped_triangles, t1);
		} else {
    		//Two points in plane, first 2 points in plane
    		out : Vector3F;
    		in_1 : Vector3F;
    		in_2 : Vector3F;
	    	if ta_dist > 0 && tb_dist > 0 && tc_dist <= 0 {
	    		out = triangle.c;
	    		in_1 = triangle.a;
	    		in_2 = triangle.b;
	    	} else if ta_dist > 0 && tc_dist > 0 && tb_dist <= 0 {
	    		out = triangle.b;
	    		in_1 = triangle.c;
	    		in_2 = triangle.a;
			} else if tb_dist > 0 && tc_dist > 0 && ta_dist <= 0 {
	    		out = triangle.a;
	    		in_1 = triangle.b;
	    		in_2 = triangle.c;
			}
    		inter_1 : Vector3F = PlaneLineSegmentIntersectNoCheck(plane, in_1, out);
    		inter_2 : Vector3F = PlaneLineSegmentIntersectNoCheck(plane, in_2, out);
    		// t1 := MakeTriangle3F(in_2, inter_1, inter_2);
    		// t2 := MakeTriangle3F(in_1, inter_1, in_2);
    		t1 := MakeTriangle3F(inter_1, in_1, in_2);
    		t2 := MakeTriangle3F(in_2, inter_2, inter_1);
    		array_add(*clipped_triangles, t1);
    		array_add(*clipped_triangles, t2);
		}
		return clipped_triangles, ClipState.CLIPPED;
    }
}

lights : [3] Light = .[
	Light.{LightType.AmbientLight, 0.2, Vector3F.{}},
	Light.{LightType.PointLight, 0.6, Vector3F.{1, 0, -2}},
	Light.{LightType.DirectionalLight, 0.5, Vector3F.{1, 4, 4}}
];

Light :: struct {
	type : LightType;
	intensity : float;
	vector : Vector3F;
}

LightType :: enum {
	AmbientLight;
	PointLight;
	DirectionalLight;
}

ComputeLighting :: (P : Vector3F, N : Vector3F, V : Vector3F, s : int, lights : [] Light) -> float {
	i : float = 0;
	for light : lights {
		if light.type == LightType.AmbientLight {
			i += light.intensity;
		} else {
			L : Vector3F;
			if light.type == LightType.PointLight {
				L = light.vector - P;
			} else if light.type == LightType.DirectionalLight {
				L = light.vector;
			}
			n_dot_l : float = DotProduct(N, L);
			if n_dot_l > 0 {
				i += light.intensity * n_dot_l / (Length(N) * Length(L));
			}

			if s != -1 {
				R : Vector3F = 2 * N * DotProduct(N, L) - L;
				r_dot_v : float = DotProduct(R, V);
				if r_dot_v > 0 {
					i += light.intensity * pow(r_dot_v / (Length(R) * Length(V)), cast(float) s);
				}
			}
		}
	}
	i = Clamp(i, 0, 1);
	return i;
}

