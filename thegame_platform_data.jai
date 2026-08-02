//Colors
BLUE    : u32 : 0xFF0000FF;
LIGHT_BLUE : u32 : 0x00B0FF;
RED     : u32 : 0xFFFF0000;
GREEN   : u32 : 0xFF00FF00;
DARK_GREEN : u32 : 0xFF004B00;
YELLOW  : u32 : GREEN | RED;
MAGENTA : u32 : 0xFFFF00FF;
BLACK   : u32 : 0xFF000000;
WHITE   : u32 : 0xFFFFFFFF;

//TODO try to use these in function creation in macros or something
Type_GameUpdateAndRender :: #type (memory : *GameMemory, audio_data : *AudioData, input : *GameInput) -> ();
Stub_GameUpdateAndRender :: (memory : *GameMemory, audio_data : *AudioData, input : *GameInput) {
    log("We are running Stub_GameUpdateAndRender\n");    
}
Type_DrawLine :: #type (x0 : int, y0 : int, x1 : int, y1 : int, color : u32);
Stub_DrawLine :: (x0 : int, y0 : int, x1 : int, y1 : int, color : u32) {
    log("We are running Stube_DrawLine\n");    
}

// #import "Simp";
// #import "Math";

WriteFileType :: #type (*void);
ReadFileType :: #type (Filename : string) -> DebugReadFileResult;
//TODO Maybe we can just move this to platform and use from there directly since we need the midi
GameMemory :: struct {
	IsInitialized : bool;

	//TODO can replace these with jai allocators
	PermanentStorageSize : s64;
	PermanentStorage : *void;

	//TODO Can likely remove this if we just use jai temp storage and other allocators instead now
	TransientStorageSize : s64;
	TransientStorage : *void;

	SetCursorPosition : (x : s32, y : s32);

	//TODO Should likely put this in data because we can have multiple
	//and their pointers so it does not matter if their platform dependent.
	//TODO Should we put this in-game? It is platform dependent...
	midi_output : *MIDI_Output;
	//TODO To be used for midi clock sync
	midi_input  : *MIDI_Input;

	//TODO put this in RendererState/RendererData
	//TODO leaving name for now since Dynamic_Font and Font_Effects are SIMP specific
	// SIMPPrepareText : (font: *Dynamic_Font, text: string, effect_flags: Font_Effects = 0) -> (width: s64);
	// Font : *Dynamic_Font;
}

DebugReadFileResult :: struct {
    ContentsSize : u32; //assume <= 4gb file...
    Contents : *void;
}