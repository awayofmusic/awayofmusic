/**From My_Windows.jai
**/

HEAP_GENERATE_EXCEPTIONS :: 0x00000004;
HEAP_NO_SERIALIZE ::        0x00000001;
HEAP_ZERO_MEMORY ::         0x00000008;
HEAP_CREATE_ENABLE_EXECUTE ::   0x00040000;
GetProcessHeap :: () -> *void #foreign kernel32;
HeapAlloc :: (hHeap : HANDLE, dwFlags : DWORD, dwBytes : SIZE_T) -> *void #foreign kernel32;
HeapReAlloc :: (hHeap : HANDLE, dwFlags : DWORD, lpMem : *void, dwBytes : SIZE_T) -> *void #foreign kernel32;
HeapFree :: (hHeap : HANDLE, dwFlags : DWORD, lpMem : *void) -> BOOL #foreign kernel32;
HeapCreate :: (flOptions : u32, dwInitialSize : u64, dwMaximumSize : u64) -> *void #foreign kernel32;
PAINTSTRUCT :: struct {
  hdc : HDC;
  fErase : u32;
  rcPaint : RECT;
  fRestore : u32;
  fIncUpdate : u32;
  rgbReserved : [32] u8;
}
BYTE :: u8;
DIB_PAL_COLORS :: 0x01;
DIB_PAL_INDICES :: 0x02;
SRCCOPY :: 13369376;
StretchDIBits :: (hdc : HDC, xDest : s32, yDest : s32, DestWidth : s32, DestHeight : s32, xSrc : s32, ySrc : s32, SrcWidth : s32, SrcHeight : s32, lpBits : *void, lpbmi : *BITMAPINFO, iUsage : u32, rop : u32) -> s32 #foreign gdi;

CompareFileTime :: (lpFileTime1 : *FILETIME, lpFileTime2 : *FILETIME) -> s32 #foreign kernel32;

PatBlt :: (
  hdc : HDC,
  x : s32,
  y : s32,
  w : s32,
  h : s32,
  rop : DWORD //use MSDC ternary raster operations for this
) -> BOOL #foreign gdi;

DWM_TIMING_INFO_SIZE :: 73*4; //apparently this is the size?
ULONGLONG :: u64;
QPC_TIME :: ULONGLONG;
DWM_FRAME_COUNT :: ULONGLONG;
UINT32 :: u32;
UINT :: u32;
UNSIGNED_RATIO :: struct {
	uiNumerator : UINT32;
	uiDenominator : UINT32;
}
DWM_TIMING_INFO :: struct {
	cbSize : UINT32;
	rateRefresh : UNSIGNED_RATIO;
	qpcRefreshPeriod : QPC_TIME;
	rateCompose : UNSIGNED_RATIO;
	qpcVBlank : QPC_TIME;
	cRefresh : DWM_FRAME_COUNT;
	cDXRefresh : UINT;
	qpcCompose : QPC_TIME;
	cFrame : DWM_FRAME_COUNT;
	cDXPresent : UINT;
	cRefreshFrame : DWM_FRAME_COUNT;
	cFrameSubmitted : DWM_FRAME_COUNT;
	cDXPresentSubmitted : UINT;
	cFrameConfirmed : DWM_FRAME_COUNT;
	cDXPresentConfirmed : UINT;
	cRefreshConfirmed : DWM_FRAME_COUNT;
	cDXRefreshConfirmed : UINT;
	cFramesLate : DWM_FRAME_COUNT;
	cFramesOutstanding : UINT;
	cFrameDisplayed : DWM_FRAME_COUNT;
	qpcFrameDisplayed : QPC_TIME;
	cRefreshFrameDisplayed : DWM_FRAME_COUNT;
	cFrameComplete : DWM_FRAME_COUNT;
	qpcFrameComplete : QPC_TIME;
	cFramePending : DWM_FRAME_COUNT;
	qpcFramePending : QPC_TIME;
	cFramesDisplayed : DWM_FRAME_COUNT;
	cFramesComplete : DWM_FRAME_COUNT;
	cFramesPending : DWM_FRAME_COUNT;
	cFramesAvailable : DWM_FRAME_COUNT;
	cFramesDropped : DWM_FRAME_COUNT;
	cFramesMissed : DWM_FRAME_COUNT;
	cRefreshNextDisplayed : DWM_FRAME_COUNT;
	cRefreshNextPresented : DWM_FRAME_COUNT;
	cRefreshesDisplayed : DWM_FRAME_COUNT;
	cRefreshesPresented : DWM_FRAME_COUNT;
	cRefreshStarted : DWM_FRAME_COUNT;
	cPixelsReceived : ULONGLONG;
	cPixelsDrawn : ULONGLONG;
	cBuffersEmpty : DWM_FRAME_COUNT;
};
DwmGetCompositionTimingInfo :: (hwnd : HWND, pTimingInfo : *DWM_TIMING_INFO) -> HRESULT #foreign Dwmapi;

SetCursorPos :: (X : s32, Y : s32) -> BOOL #foreign user32;
/** END OF My_Window.jai
**/

/**
	MY INPUT WINDOWS

	modules/input/Windows

NOTE : currently this is compiled out so maybe we don't need to copy it over anymore
This is no longer being used anywhere, so we are not copying ti anymore but I will leave it here
in case we need it later to proccess our own window messages. Can check old code to see how we did that.
**/
my_update_window_events :: () {
    if !initted {
        init_input_system();
        initted = true;
    }
    
    input_per_frame_event_and_flag_update();

    // @Robustness: Maybe do this for all keystrokes that are down? Sigh...
    if alt_state || (input_button_states[Key_Code.ALT] & .DOWN) { // Checking both just to be paranoid about desync between them.
        state := GetAsyncKeyState(VK_MENU);  // GetAsyncKeyState actually checks the key, not to be confused with GetKeyState, which does nothing.
        if !(state & 0x8000) {
            alt_state = false;
            input_button_states[Key_Code.ALT] |= .END;
        }
    }

    if ctrl_state || (input_button_states[Key_Code.CTRL] & .DOWN) { // Checking both just to be paranoid about desync between them.
        state := GetAsyncKeyState(VK_CONTROL);  // GetAsyncKeyState actually checks the key, not to be confused with GetKeyState, which does nothing.
        if !(state & 0x8000) {
            ctrl_state = false;
            input_button_states[Key_Code.CTRL] |= .END;
        }
    }

    if shift_state || (input_button_states[Key_Code.SHIFT] & .DOWN) { // Checking both just to be paranoid about desync between them.
        state := GetAsyncKeyState(VK_SHIFT);  // GetAsyncKeyState actually checks the key, not to be confused with GetKeyState, which does nothing.
        if !(state & 0x8000) {
            shift_state = false;
            input_button_states[Key_Code.SHIFT] |= .END;
        }
    }
}

/**
	END OF MY INPUT WINDOWS
**/

/* My renderer updates
Simp/gl.jai
*/
/*MY GL STUFF
TODO FROM HERE Can put this in a separate file so we only need to #load it into the module.jai.
That would be best I think and then we can use that file to also store the separate
2D and 3D color shaders and vertex buffers and other shader info needed to optimize
the 2D and 3D color rendering later.
ALSO NEED TO DISABLE THIS LINE in immediate_flush in immediate.jai
glDisable(GL_DEPTH_TEST);
AND ALSO add .xyz line in shader. I think it's best to put this in a separate file with all the notes
about 3D in there and then we just need to copy that file with new jai versions and then load it
and just comment out above line and add .xyz line in shader.
GL_STREAM_DRAW->GL_STATIC_DRAW seems to make a difference

ULTIMATELY This can be heavily optimized especially for 3D so we put it in a separate file and then test it out later
also likely that metal will be different so then that can be in its own file too.

NOTE that only the small vl cubes are depth tested. The wire mesh is not since it is still using the old order.
*/

//add to top of Simp/gl.jai 
clear_depth_buffer :: () {
	glClear(GL_DEPTH_BUFFER_BIT);
}

enable_depth_test :: () {
	glEnable(GL_DEPTH_TEST);
}

disable_depth_test :: () {
	glDisable(GL_DEPTH_TEST);
}

//In Simp/gl.jai in backend_draw_immediate_vertices() (used to be in immediate.jai immediate_flush())
//comment out
glDisable(GL_DEPTH_TEST);
//AND replace GL_STATIC_DRAW -> GL_STREAM_DRAW (GL_STREAM_DRAW seems to be default in new jai)
// glBufferData(GL_ARRAY_BUFFER, size_of(Immediate_Vertex) * count, state.vertices.data, GL_STATIC_DRAW);
// glBufferData(GL_ARRAY_BUFFER, size_of(Immediate_Vertex) * count, state.vertices.data, GL_STREAM_DRAW);


//Specifically replace SHADER_COLOR main() in Simp/gl.jai with
SHADER_COLOR :: #string END
void main() {
    // gl_Position = projection * vec4(vert_position.xy, 0.0, 1.0);
    gl_Position = projection * vec4(vert_position.xyz, 1.0);
    iterated_color    = vert_color;
}
END



/*Mac window code
TODO Add the code for mac input not working because jon did not respond or do anything about that bug
*/
//Window_Creation/macos.jai
NSWindow.setTitle(window, window_name);
// NSWindow.setStyleMask(window, NSWindowStyleMaskBorderless);
// NSWindow.setStyleMask(window, NSWindowStyleMaskTitled | NSWindowStyleMaskClosable);

// NSWindow.setCollectionBehavior(window, NSWindowCollectionBehaviorFullScreenPrimary | NSWindowCollectionBehaviorManaged);
NSWindow.setCollectionBehavior(window, NSWindowCollectionBehaviorFullScreenNone | NSWindowCollectionBehaviorManaged);
// NSWindow.setCollectionBehavior(window, NSWindowCollectionBehaviorFullScreenAuxiliary | NSWindowCollectionBehaviorManaged);
// NSWindow.setLevel(window, 0);
// NSWindow.orderFront(window, null);
NSWindow.makeKeyAndOrderFront(window, null);

//For the weird tab input issues on macos. Add this under 
case NSEventTypeFlagsChanged;
   keycode := NSEvent.keyCode(nsevent);
	if keycode >= 54 && keycode <= 62 {
