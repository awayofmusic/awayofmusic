//Do we need this here? Not like we are importing this anywhere. If we make an external library for players to use,
//then we will be able to set the specific scope there.
#scope_module

memory_debug :: false;
#if memory_debug #import "Basic"()(MEMORY_DEBUGGER=true);
else #import "Basic";

#import "Unicode";
// #import "Gamepad"; //only using Xinput from this so could just copy that file to this project
// #load "../../jai-beta-1-015/jai/modules/Gamepad/Xinput.jai";
DSOUND_AUDIO :: false;
#if DSOUND_AUDIO {
//wasapi buffer implementation : https://hero.handmade.network/forums/code-discussion/t/8621-wasapi_sound_1_sec_delay
//core audio mac os x in c99 : https://gist.github.com/framkant/6daed7f6145af958f0bc
//It seems like core audio uses a callback anyways sooo... maybes it's best to just keep miniaudio
#import "Sound_Player"; //using the defined variables in win32.jai for DirectSound8
#import "Wav_File"; //only using for Waveformatex atm, so could just move in the struct if thats all we need
} else {
//TODO Could just import this or the other depending on some compile-time to allow switching back to DirectSound
//but maybe we remove the entirely once this is working since it will be very different.
#import,dir "../miniaudio-jai";
}
#import "Thread";
// #import "Atomics";
// #import "Machine_X64";
#import "File";
#import "File_Utilities";

/*Note : some multi-platform jai modules which we built ourselves and now we are using for simplicity

	Input : we have our own MyWindowProc and we will use the Input/module MyWindowProc as the default windows procedure
	and use our own beforehand process things that are not processed in Input there
		- can also DispatchMessageW(*Message) for double processing in ours and the default windows procedure
*/
Input :: #import "Input";
#import "Window_Creation"; //dont need this for just windows but testing out the jai create_window procedure for multi-platform
//TODO just use Gamepad.jai
// #load "copiedover/Xinput.jai"; //copied from Gamepad module and to avoid version updates above

//TODO Should this be here or in thgame_mode? The ports are created per platform
//TODO Can remove the ,dir here because we import the current directory anyways.
#import,dir "jai-midi";
#import,dir "jaison";

//TODO these should be moved into thegame_renderer?
//TODO Should we call thegame_mode.jai directly?
// #load "thegame.jai";
#load "thegame_mode.jai";
#load "thegame_renderer.jai";
// #load "thegame_renderer_data.jai";
// #load "thegame_platform_data.jai";

WINDOW_NAME :: "thegame";

// WINDOW_WIDTH :: 960;
// WINDOW_HEIGHT :: 540;
// WINDOW_WIDTH :: 960*3/2;
// WINDOW_HEIGHT :: 540*3/2;
// WINDOW_WIDTH :: 1920;
// WINDOW_HEIGHT :: 1080;
// WINDOW_WIDTH :: 2*1920;
// WINDOW_HEIGHT :: 2*1080;
// WINDOW_WIDTH :: #run round_to_s32(1.25*1920);
// WINDOW_HEIGHT :: #run round_to_s32(1.25*1080);
WINDOW_WIDTH :: #run round_to_s32(1.65*1920);
WINDOW_HEIGHT :: #run round_to_s32(1.65*1080);
//TODO this does not seem to align pixels properly...
// WINDOW_WIDTH :: 2560;
// WINDOW_HEIGHT :: 1440;

Running := true;
//Note : need this for SetCursorPosition
//TODO can we somehow keep in only in the platform layer function?
//TODO Use window type here so it works on other oses as well.
my_window : Window_Type;
main :: () {

ssr : StartupSettingsReturn = ParseStartupSettingsFile(STARTUP_SETTINGS_REL_PATH);
if ssr.success {
	GLOBAL_STARTUP_SETTINGS = ssr.new_settings;
} else {
	log_error(ssr.error_msg);
}

//TODO can make these ints now just need to update MakeRendererData
screen_width : s32;
screen_height : s32;
#if OS == .WINDOWS {
	//TODO Can we put windows imports in here or leave them in the global scope?
	//Note : Can turn this off by commenting it if we want to test direct resolutions like 1920x1080
	SetProcessDPIAware();
	// Windows is very bad at thread-switching by default unless you do this. Sad.
	timeBeginPeriod(1);
	// window_width = WINDOW_WIDTH;
	// window_height = WINDOW_HEIGHT;
	screen_width = GetSystemMetrics(SM_CXSCREEN);
	screen_height = GetSystemMetrics(SM_CYSCREEN);
} else #if OS == .MACOS {
	//MAKE sure we only use DSOUND_AUDIO if we are on windows
	#assert(!DSOUND_AUDIO);
	//TODO We could allow this to be adjustable on input through a settings file that we read in before this.
	init_mac_app();
	main_screen := NSScreen.mainScreen().frame(NSScreen.mainScreen());
	fb := NSView.convertRectToBacking(NSScreen.mainScreen(), main_screen); // :MacHighResDisplays
	//TODO Could allow screen width and screen height to be adjusted in settings as well if that
	//helps people to have more customization over resolution.
	screen_width  = cast(s32) round_to_int(fb.size.width);
	screen_height = cast(s32) round_to_int(fb.size.height);
}
if GLOBAL_STARTUP_SETTINGS.use_startup_screen_dim {
	screen_width = cast(s32) GLOBAL_STARTUP_SETTINGS.startup_screen_width;
	screen_height = cast(s32) GLOBAL_STARTUP_SETTINGS.startup_screen_height;
}
	//TODO Can reduce the size here for default or allow this to be in the startup settings or saved too.
	//TODO Can allow startup settings to be set from in-game as well in the editor and then saved directly.
	// window_width = cast(s32) (0.8*fb.size.width);
	// window_height = cast(s32) (0.8*fb.size.height);
	//TODO can make these ints now just need to update MakeRendererData
window_width : s32;
window_height : s32;
if GLOBAL_STARTUP_SETTINGS.use_startup_window_dim {
	window_width = cast(s32) GLOBAL_STARTUP_SETTINGS.startup_window_width;
	window_height = cast(s32) GLOBAL_STARTUP_SETTINGS.startup_window_height;
} else {
	window_width = cast(s32) (0.825*screen_width);
	window_height = cast(s32) (0.825*screen_height);
}

// window_width := cast(s32) (screen_width);
// window_height := cast(s32) (screen_height);
// window_pos_x := cast(int) (0.15*screen_width);
// window_pos_y := cast(int) (0.075*screen_height);
window_pos_x := cast(int) (GLOBAL_STARTUP_SETTINGS.startup_window_pos_x_screen_fraction*screen_width);
window_pos_y := cast(int) (GLOBAL_STARTUP_SETTINGS.startup_window_pos_y_screen_fraction*screen_height);

// print("screen_width=%\n", screen_width);
// print("screen_height=%\n", screen_height);
// print("window_width=%\n", window_width);
// print("window_height=%\n", window_height);

//TODO We could set this just to my_window so we only have 1 window in global scope that we use everywhere.
// Window := create_window(WINDOW_WIDTH, WINDOW_HEIGHT, WINDOW_NAME, 500, 150);
// Window := create_window(window_width, window_height, WINDOW_NAME, 500, 150);
Window := create_window(window_width, window_height, WINDOW_NAME, window_pos_x, window_pos_y);
if(Window) {
	my_window = Window;
	//TODO Should replace these either with a Pool or Flat_Pool and actually use them for data storage now.
	//This would also make them immediately usable on mac.
	game_memory : GameMemory;
	game_memory.PermanentStorageSize = Megabyte(10);
	//TODO I think we can just remove transient storage in favor of jai temp allocator and other allocators used throughout.
	game_memory.TransientStorageSize = Megabyte(5);
	GameMemoryBlockSize := game_memory.PermanentStorageSize + game_memory.TransientStorageSize;
	game_memory.PermanentStorage = alloc(cast(s64) GameMemoryBlockSize);
	game_memory.TransientStorage = (cast(*u8) game_memory.PermanentStorage) + game_memory.PermanentStorageSize;
	assert(game_memory.PermanentStorage != null && game_memory.TransientStorage != null);
	game_memory.IsInitialized = true;
	// win32_state : Win32GameState;
	// win32_state.GameMemoryBlockSize = cast(u64) (game_memory.PermanentStorageSize + game_memory.TransientStorageSize);
	// win32_state.GameMemoryBlock = VirtualAlloc(cast(*void) 0, win32_state.GameMemoryBlockSize, MEM_RESERVE|MEM_COMMIT, PAGE_READWRITE);
	//TODO This should be OS independent now but we can likely remove all of this stuff and just set 
	//a *GameState pointer in GameMemory or grab that directly here since it is fixed.
	//I guess we can think a bit more about it when I actually do memory for music spaces and op spaces
	// win32_state.GameMemoryBlock = alloc(cast(s64) win32_state.GameMemoryBlockSize);

	/*TODO
	initialize back buffer for software rendering but we can remove that
	once we only use gpu rendering or with the compile time if

	or move the renderer out so we can more easily swap it

	TODO THIS SHOULD ALSO BE A POOL OR FLAT_POOL SO IT WILL ALSO WORK ON MAC SEAMLESSLY and if we use normal poo
	it can also grow if we need for renderer_data at some point
	*/
	renderer_memory_size : s64 = Megabyte(40);
	// renderer_memory := cast(*u8) VirtualAlloc(cast(*void) 0, cast(u64) renderer_memory_size, MEM_RESERVE|MEM_COMMIT, PAGE_READWRITE);
	//TODO Indeed we can make this a Pool and then just increase the size if ever we need to render more than what we have.
	//Maybe this won't happen if we do op space optimizations although maybe it's best to be safe anyways and avoid having
	//to do any kind of extra optimizations and just get more memory instead.
	renderer_memory := cast(*u8) alloc(renderer_memory_size);
	assert(renderer_memory != null);
	SetupRenderer(Window);
	// renderer_data : RendererData = MakeRendererData(renderer_memory, renderer_memory_size, WINDOW_WIDTH, WINDOW_HEIGHT);
	renderer_data : RendererData = MakeRendererData(renderer_memory, renderer_memory_size, window_width, window_height,
		screen_width, screen_height);

	//TODO Set a pointer to ma_device or ma_device_config in AudioData so we use the same values as miniaudio
	audio_data : AudioData;
	audio_data.seconds_per_sample = 1.0 / audio_data.SampleRate;
	audio_data.seconds_per_sample_f64 = cast(float64) 1.0 / audio_data.SampleRate;
	//TODO test if this works for 44100 sample rate eventually (or higher 96000)
	audio_data.BufferSize = audio_data.SampleRate * audio_data.BytesPerSample;
	audio_data.Volume = 5000;
	// audio_data.Frequency = 220;
	// audio_buffer := cast(*s16) VirtualAlloc(cast(*void) 0, cast(u64) audio_data.BufferSize, MEM_RESERVE|MEM_COMMIT, PAGE_READWRITE);
	//TODO Can make this buffer 2-3 seconds
	audio_buffer := cast(*s16) alloc(audio_data.BufferSize);
	assert(audio_buffer != null);
   audio_data.audio_buffer = audio_buffer;

   //TODO Eventually we can JUST use this buffer when we remove direct sound and can pass this directly
   //to miniaudio as a float buffer once we know everything works.
   audio_data.number_of_channels = 2;
   audio_data.bytes_per_float_sample = size_of(float) * audio_data.number_of_channels;
   audio_data.float_buffer_size = audio_data.SampleRate * audio_data.bytes_per_float_sample;
   audio_data.float_buffer = cast(*float) alloc(audio_data.float_buffer_size);

	atd : AudioThreadData;
	//Possibly store a pointer to ma_device in audio data instead and use that so we remain consistent with audio data.
	atd.audio_data = *audio_data;
	atd.buffer_size_in_bytes = audio_data.BufferSize;
	/*DOC : Currently a sample in the code is the data for all channels whereas a sample in mini audio is the data for 1 single channel.
	So a frame is equivalent to a PCM frame which is the data for all channels.
	Maybe I like that wording better and we can update our use of the word sample to frame. The confusing thing is with 
	sample rate since that is sample/sec and refers to a sample as data for all channels but maybe it's ok... not sure...
	*/
	atd.bytes_per_frame = audio_data.BytesPerSample;
	/*DOC : Currently this buffer (same as fill buffer) is 1 sec long. Can make it 2-3 seconds to reduce potential
	stuttering later. THIS SHOULD BE TESTED by manually delaying both the audio thread and main thread and
	making sure that sounds ok or maybe even writing some sort of test for it (especially the video thread).
	TODO Maybe we can write test manually for this
	*/
	atd.audio_ring_buffer = alloc(audio_data.BufferSize);
	//TODO Maybe we should put the audio mutex in global scope to not make a mistake of where it is.
	init(*AUDIO_MUTEX);

	#if DSOUND_AUDIO {
	Win32InitDirectSound(Window, cast(s32) audio_data.SampleRate, cast(s32) audio_data.BufferSize);
	Win32ClearAudioBuffer(audio_data);
	} else {
	//TODO for device enumeration, we need a context. an example can be found in the docs in low level api section.
	//Can try changing device while the game is playing if possible. will need to add a miniaudio context and
	//may need to init and uninit OR start and stop a device with context
	// if (ma_context_get_devices(&context, &pPlaybackInfos, &playbackCount, &pCaptureInfos, &captureCount) != MA_SUCCESS) {
    // Error.
	// }
	// audio_buffer := cast(*float) alloc(audio_data.BufferSize);
	// assert(audio_buffer != null);
	//TODO We could set this in AudioData or keep it separate in case we use something different later.
	config : ma_device_config = ma_device_config_init(ma_device_type.playback);
	config.playback.format   = ma_format._s16;   // Set to ma_format_unknown to use the device's native format.
	//TODO Should likely use this when setting synth samples in the buffer and maybe we should use the default as 0 here.
	//Also might be different if/when we allow changing devices.
	config.playback.channels = 2;               // Set to 0 to use the device's native channel count.
	config.sampleRate        = cast(u32) audio_data.SampleRate;           // Set to 0 to use the device's native sample rate.
	config.dataCallback      = miniaudio_callback;   // This function will be called when miniaudio needs more data.
	config.pUserData      	 = *atd;   // This function will be called when miniaudio needs more data.

	device : ma_device;
	if ma_device_init(null, *config, *device) != ma_result.SUCCESS {
		log_error("Failed to initialize audio device.\n");
		return;  // Failed to initialize the device.
	}
	ma_device_start(*device);     // The device is sleeping by default so you'll need to start it manually.
	//TODO Can likely use this to pause the audio if we pause game.
	// ma_device_stop(*device);
	}

	//Timing code
	/*TODO 
	https://chromium.googlesource.com/chromium/src/+/refs/heads/main/ui/gl/vsync_provider_win.cc
	https://exchangetuts.com/how-to-find-out-real-screen-refresh-rate-not-the-rounded-number-1640674144780393
	https://gafferongames.com/post/fix_your_timestep/
	Should timing info be in float or float64?
	*/
	// sleep_is_granular : bool = timeBeginPeriod(1) == TIMERR_NOERROR;
	//TODO This could be adjusted at runtime to anything for convenience and efficiency.
	target_fps : float64 = GetDeviceFPS(Window);
	target_sec_per_frame : float64 = cast(float64) 1 / target_fps;
	target_apollo : Apollo_Time = to_apollo(target_sec_per_frame);

	//TODO Probably only need 1 of these once we only use jai input.
	//Maybe we can even remove old_input now since it does not seem like we use it other than in old windows input code.
	old_input : GameInput;
	//TODO rename this to game_input I think now
	new_input : GameInput;
	new_input.dtPerFrame = cast(float) target_sec_per_frame;
	//TODO old_keyboard, new_keyboard?
	keyboard := *new_input.Controllers[0];

	//TODO Can remove this once we change file
	//TODO Remove this once we know it's working on windows since this is windows specific and did not compile on mac.
	#if 0 {
	dt : float64;
	start_count : s64; 
	end_count : s64;
	ok := QueryPerformanceCounter(*start_count);

	count_per_sec : s64;
	ok = QueryPerformanceFrequency(*count_per_sec);
	count_per_sec_float := cast(float64) count_per_sec; 

	start_cycle := rdtsc();
	}

	//TODO Can leave this here or just remove it since we use seconds now but can leave apollo time version.
	//In general, seconds works better because we want to print and think about dt in seconds and also
	//for debugging purposes seeing it in seconds is better. Apollo_Time would be useful if ever the program
	//needed to run for much much longer (128-bit vs 64-bit).
	// #if 0 {
	//TODO Change the names of these once it works and then can remove above once we create the new file.
	dt_apollo : Apollo_Time;
	// start_apollo : Apollo_Time = current_time_monotonic();
	start_apollo : Apollo_Time;
	// end_apollo : Apollo_Time;
		// } else {
	// start_time : float64 = seconds_since_init();
	start_time : float64;
	delta_time : float64;
		// }


	//TODO Grab output port by name in case the index changes
	/*TODO This is 0 on mac and 1 on windows BUT this should be adjustable by the user so they
	can set it however they want.
	ALSO on mac we can create a virtual port from here easily so likely also best to do that maybe by default
	so that we don't even have to think about it and it just works.
	*/
	#if OS == .WINDOWS {
	midi_port_number : int = 1;
	} else {
	midi_port_number : int = 0;
	}
	game_memory.midi_output = open_output(midi_port_number);
	// assert(game_memory.midi_output != null, "No midi output found with port %.\n", midi_port_number);

	while(Running) {
		#if memory_debug memory_visualizer_per_frame_update();
		// start_apollo = current_time_monotonic();
		start_time = seconds_since_init();
		new_input.last_frame_delta_time = cast(float) delta_time;

		//TODO should this be reset in platform layer or game layer?
		ResetGameInput(*new_input);

		//We put this here to reset all input states when out of focus but not during tests.
		//We do it after ResetGameInput to make sure everything is reset when we don't have application focus
		//TODO We could put this below application has focus code if needed.
		if !Input.input_application_has_focus && !new_input.out_of_focus_reset_input {
	   	new_input.out_of_focus_reset_input = true;
			memset(new_input.my_input_states.data, 0, 
				size_of(MyInputState) * new_input.my_input_states.count);
	   }
		/*DOC : When opening file explorer, when we come back ,we don't get the up this frame event
		but the input_button_states does, so we update here just in case. Having it here avoids using
		the input during tests and ensures current button releases that are in line with jai input.
		We do this before updating window events in case we get an async button press this frame to remain consistent.
		The reason we don't JUST do this is because for testing we want the same functionality with UpdateInputStatesFromEvents
		so this is really just for inputs needed within the last frame which hopefully jai input has figured out on all platforms.
		We reset with either END (up_this_frame) or if it's just not down.
		WE COULD ALSO check Input.events_this_frame and if any event is up this frame then we reset the input state. 
		We just use input events for now and if we have an issue, then we can check each input button state directly later.
		events_this_frame seems to get the extra inputs from last frame if we got them async during the frame
		worth testing this on mac as well eventually.
		*/
		// for Input.input_button_states if (it & .END) || !(it & .DOWN) {
		// 	new_input.my_input_states[it_index] = .{};
		// }
		for Input.events_this_frame {
			my_event := FrameInputEvent.{it, .KEYBOARD, .{}};
			if IsKeyPressByType(.UP_THIS_FRAME, my_event) {
				new_input.my_input_states[my_event.key_code] = .{};
			}
		}

		Input.update_window_events();
		if Input.input_application_has_focus {
   		new_input.out_of_focus_reset_input = false;
			//TODO I am pretty sure we can remove this function now once we replace everything with the new input now.
		   JaiProcessWindowInput(*new_input);
		   //TODO We might be able to replace the entire input system with this array.
		   //Can also possibly just events_this_frame if we never add anything to FrameInputEvent.
		   //ACTUALLY This is better so we can have different types if input (like midi)
		   //and also this allows for more control for testing and resetting inputs in general when needed.
		   for Input.events_this_frame {
		   	array_add(*new_input.frame_input_events, .{it, .KEYBOARD, .{}});
		   }

		   //TODO Set mouse x and y to be cam positions so we can pass in cam or world convert positions directly
		   //to the game from tests and not have to use the actual mouse in tests.
			// x, y, success := get_mouse_pointer_position(Window, true);
			x, y, success := get_mouse_pointer_position(true);
			if success {
				// print("x,y=%,%\n",x,y);
				new_input.MouseX = x;
				new_input.MouseY = y;
				//TODO We could just pass in screen half dim and pixels per square if that removes the need for a RenderGroup
				//then in the platform data layer
				new_input.last_frame_mouse_cam = new_input.mouse_cam;
				new_input.mouse_cam = MouseScreenToCam(x, y, renderer_data.base_render_group);
			} else {
				//If we fail to get the mouse this frame, then the mouse stays in the same place as last frame and we log an error
				log_error("Cannot get mouse pointer position.\n");
			}

		   //TODO I think we can move the JaiProcessWindowInput in here now and just use our internal event and input state system
		   UpdateInputStatesFromEvents(*new_input);
			// print("x,y=%,%\n", x,y);
			// print("MouseX,MouseY=%,%\n", new_input.MouseX, new_input.MouseY);
			// raw := cast(*RAWINPUT) Input.raw_input_buffer.data;
			// print("raw_mouse=%\n", raw.data.mouse);
	   	// print("Input.mouse_delta_x=%\n", Input.mouse_delta_x);
	   	// print("Input.mouse_delta_y=%\n", Input.mouse_delta_y);

        	for Input.get_window_resizes() {
        		//TODO Call this in renderer so we only call Simp calls there so it's easier to move out
	         // Simp.update_window(it.window);
	         ResizeRenderWindow(it.window);
	         if it.window == Window {
					should_reinit := (it.width != window_width) || (it.height != window_height);
					window_width  = it.width;
					window_height = it.height;
					if should_reinit {
						#if 0 {
		         	//TODO Maybe we can just use the viewport width here now.
						terminal_width : s32 = round_to_s32(0.25*window_width);
						ResizeRenderGroup(terminal_width, window_height, renderer_data.terminal_render_group, *renderer_data);
						} else {
						ResizeRendererData(window_width, window_height, *renderer_data);
						// resize_playfield();
						// my_init_fonts();
						}
	       		}
	      	}
			}
		}

		//TODO Send to sublime text since this can in fact be done on macos
		// if keyboard.four.down_this_frame {
		// 	NSWindow.setStyleMask(Window, NSWindowStyleMaskBorderless);
		// } else if keyboard.three.down_this_frame {
		// 	NSWindow.setStyleMask(Window, NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskResizable);
		// }

		//TODO We can pull this out but it's a bit weird with the direct sound so maybe I can wait to pull it out
		//once we know it works on mac and we can remove direct sound.
		//Then this could just be UpdateAudioData function or another better name
		//TODO Could just pass in empty input here if we want the game to keep running.
		#if OS == .WINDOWS && DSOUND_AUDIO {
		if keyboard.PauseGame == 1 {
			SecondaryBuffer.Stop(SecondaryBuffer);
			continue;
		} else {
			SecondaryBuffer.Play(SecondaryBuffer, 0, 0, DSBPLAY_LOOPING);
		}
		//Create Sounds
		/*
		TODO try this with SDL which uses WASAPI backend and should have better latency
		or not since SDL does not seem to have a play cursor... wtf
		*/
		hr := SecondaryBuffer.GetCurrentPosition(SecondaryBuffer, cast(*s32) *PlayCursor, cast(*s32) *FixedWriteCursor);
		succeeded := SUCCEEDED(hr);
		} else {
		//TODO Maybe I should make my own atomic get function for this.
		//PlayCursor is kept global for now, but we could make it local once we remove old direct sound
		//TODO should the audio mutex be in global scope so we make sure it's always the same one?
		lock(*AUDIO_MUTEX);
		PlayCursor = atd.audio_play_cursor;
		// succeeded, PlayCursor = compare_and_swap(*atd.audio_play_cursor,0,0);
		unlock(*AUDIO_MUTEX);
		succeeded : bool = true;
		//1440 samples = 0.03 sec * (48000 samples/sec) = (0.016666 * 1.8) * 48000
		//TODO Can maybe reduce this once we test on wasapi and core audio for less latency
		//Currently 0.03 sec / 0.01666 (sec/frame) = 1.8 frames. Maybe it's fine.
		//At 30 fps then 0.06 sec = 1.8 * 0.033333(sec/frame)
		//At 120 fps then 0.015 sec = 1.8 * 0.008888(sec/frame) - Is 15 milliseconds enough? maybe we want to keep 30 ms
		//TODO The audio thread runs every 10ms on wasapi, let's see what it is in core audio and then adjust from there.
		//Maybe making this 2.0 would be better
		play_to_write_gap_in_samples : int = round_to_int(target_sec_per_frame * 1.8 * audio_data.SampleRate);
		//NOTE : This might be slightly more or less depending on the fractional value of the framerate.
		// assert(play_to_write_gap_in_samples == 1440);
		// print("play_to_write_gap_in_samples=%, target_sec_per_frame=%\n", play_to_write_gap_in_samples, target_sec_per_frame);
		// print("target_sec_per_frame=%, target_fps=%\n", target_sec_per_frame, target_fps);
		// play_to_write_gap_in_samples := 1440;
		play_to_write_gap_in_bytes : int = audio_data.BytesPerSample * play_to_write_gap_in_samples;
		FixedWriteCursor = PlayCursor + play_to_write_gap_in_bytes;
		}
		if succeeded {
			//NOTE : We are only using this for old direct sound anymore so I will leave here as an assertion
			//just to make sure that the write cursor is also within the buffer size
			//ALSO we don't have to grab audio_write_cursor with a lock because we only update it in the main thread.
			//Only the read cursor / play cursor is updated in the audio thread.
			ByteToLock = atd.audio_write_cursor % audio_data.BufferSize;
			assert(ByteToLock == atd.audio_write_cursor);
			// ByteToLock = (audio_data.SampleCounter * audio_data.BytesPerSample) % audio_data.BufferSize;
			/*The constant audio_data.samplerate / 33 is the gap between play and write cursor in directsound8
			which is also the write cursor latency. On the next frame, our write cursor will be exactly
			where we wrote this frame. If the write cursor == play cursor then we would be hearing exactly
			what we pressed on the previous frame. So our latency == write_cursor - play_cursor

			Also we need to stay up by 30 ms because the next write cursor could be up to 30 ms ahead
			of the current one since our frame time could be >20ms but unlikely to be more than say 23ms

			Note this can be divided by 33 or maybe even a bit quicker if we adjust framerate properly
			25 works well for 30 fps (40ms delay) and 35-45 seems to work OK for 60fps (20-30ms delay)
			Although for 60 fps have to be careful in case 30ms would happen if we have delay in video frame itself

			Apparently we need to reduce this more when we rendering larger 3D scenes. Would the 3D optimizations help
			eventually? We could allow this to be adjusted in settings to reduce th stuttering... If we process
			the audio on a separate thread would that also fix the issue? 5-15 seems to work even in large scenes.
			But we can definitely feel the latency at anything under 10-15 but doesnt really matter for chord spaces.
			DOES THIS EVEN HAPPEN ON MAC?

			DOC NEW
			We add a value to the FixedWriteCursor which depends on the audio_play_cursor. Therefore,
			if the audio thread ran more times that frame, then this value will be higher because FixedWriteCursor
			will be larger and if the audio thread ran fewer times that frame, then it will be less.
			SampleRate / 25 = 48000 / 25 = 1920 and 1920 sample / 48000(sample/sec) = 0.04 seconds.
			SampleRate / 30 = 48000 / 30 = 1600 and 1600 sample / 48000(sample/sec) = 0.0333 seconds.
			We can likely reduce this now since we know the audio thread runs every 10 ms on wasapy.
			That means we have 0.03 + 0.04 = 0.07 seconds of written data on this frame
			which could be 0.07 - 0.01666 = 0.053333 seconds at 60fps since we could write at the end of the frame.
			So its around 0.05333 / 0.01666 = 3.2 frames which seems reasonable, 
			but we can likely reduce it 2.5 - 3.0 frames in general for less latency.

			If we write at the end of the frame and the audio thread runs RIGHT after this then
			(2.0 + 1.8) * 0.016666 = 0.063333 - (0.016666 end of frame) - (0.01 audio thread) = 0.036666 seconds
			which is still > 2 frames buffer which seems pretty good for latency
			0.01 / 0.016666 = 0.6 so it would be 3.8 - 1.6 frames total = 2.2 frames in between.
			This seems good for latency. Can likely reduce it even more bring that down to 2 frames or even 1.8.
			Let's see what the audio thread latency is on core audio and then maybe we bring it down a bit
			to decrease the latency as much as possible. We could also let this be an input variable or something
			if people want to try super low latency if they are using an audio card or something like that
			but we would need to implement minaudio devices to have that working.
			ALSO having 2 frames extra, deals with a skipped frame or 2 not resulting in a click.
			Not sure if it's better to just reduce latency or remove random clicks from 1-2 frame latency.
			MAYBE best to let this be an input so that people could reduce it a lot if they want to just
			use it as an instrument where there would less potential lag, so let's see how that goes later with usage.
			*/
			// TargetCursor = (FixedWriteCursor + ((audio_data.SampleRate / 25) * audio_data.BytesPerSample))
			//                 % audio_data.BufferSize;
			//2.4 is approximately to SampleRate (1sec) / 25
			// target_offset_samples : int = round_to_int(target_sec_per_frame * 2.4 * audio_data.SampleRate);
			// target_offset_samples : int = (audio_data.SampleRate / 25);
			//This gives us around 1600 samples for 60fps like the /30 case above, but then adjusts based on framerate.
			//So there would be more filled up for 30fps and less for 120 fps for example.
			//WE CAN INCREASE THIS if there is some audio stuttering OR also increase the FixedWriteCursor above.
			//As per calculations above, 2.0 + 1.8 gives us 2.2 frames in between worst case, so 2.4
			//would give us 2.6 frames which is over an extra half frame from 2 frames which could be better buffer
			//but then worse latency.
			//WE could do 2.2 to be somewhere in between if this makes any kind of stuttering.
			//2.0 is approximately to SampleRate (1sec) / 30
			// target_offset_samples : int = (audio_data.SampleRate / 30);
			/*I noticed with chord space that there is a very short tail of sound with miniaudio that we do not hear
			with custom directsound. This is removed when we reduce this to 0.1-1.0 target offset here.
			Can likely reduce this then when we remove dsound audio and leave it max at 1.0.
			BEST TO ALLOW THIS as input as well because maybe it can be adjusted for devices for lower latency.
			//NOTE : With DSOUND_AUDIO < 2.0 begins to distort (so I will leave 2.0 for now)
			//but with miniaudio we do not have distortion at 1.0 and not even at 0.1
			//TODO So we can likely reduce this to 1.0 when we remove dsound and then possibly allow it even
			//lower later in case people decide to set a device that has even lower latency (like an audio interface or audio card)
			*/
			target_offset_samples : int = round_to_int(target_sec_per_frame * 2.0 * audio_data.SampleRate);
			// target_offset_samples : int = round_to_int(target_sec_per_frame * 1.0 * audio_data.SampleRate);
			// print("test=%,target=%\n", test_target_offset_samples, target_offset_samples);
			target_offset_bytes : int = target_offset_samples * audio_data.BytesPerSample;
			TargetCursor = (FixedWriteCursor + target_offset_bytes) % audio_data.BufferSize;
			if atd.audio_write_cursor > TargetCursor {
		  		BytesToWrite = audio_data.BufferSize - atd.audio_write_cursor + TargetCursor;
			}
			else {
			  /*
			  if PlayCursor doesn't move, then PlayCursor == atd.audio_write_cursor 
			  (on next frame TargetCursor == atd.audio_write_cursor since we wrote till TargetCursor)
			  and so BytesToWrite == 0 and so the buffer lock will all be 0 and nothing
			  will happen, maybe i need to make this more explicit codewise
			  */
  				BytesToWrite = TargetCursor - atd.audio_write_cursor;
			}
			// print("PC = %, WC = %, atd.audio_write_cursor = %, TC = %\n", PlayCursor, FixedWriteCursor, atd.audio_write_cursor, TargetCursor);
			// print("WC-PC = % sec\n", ((FixedWriteCursor-PlayCursor)/audio_data.BytesPerSample)/cast(float64)audio_data.SampleRate);
			//TODO CHECK THIS when we try updating to Sound_Player
			// SamplesToWrite := BytesToWrite / audio_data.BytesPerSample;
			// SecondsToWrite := cast(float64) SamplesToWrite / cast(float64) audio_data.SampleRate;
			// print("BytesToWrite=%, Samples=%, Seconds=%\n", BytesToWrite, SamplesToWrite, formatFloat(SecondsToWrite, 7, zero_removal=.NO));
			//TODO Check backend_count_buffered_bytes to see if that gives us how big the audio buffer should be.
			//Also seconds_to_fill_ahead might adjust the buffer size as well so can test both of those out
			//Also fill_sample_buffer seems to be what adds new samples
		} 
		else {
    		// log_error("Error getting direct sound current position : %\n", hr);
    		log_error("Error getting direct sound current position\n");
		}

		audio_data.SamplesToFill = BytesToWrite / audio_data.BytesPerSample;

		bytes_to_add : int = 0;
		if LastPlayCursor < PlayCursor {
			bytes_to_add = PlayCursor - LastPlayCursor;
		} else if LastPlayCursor > PlayCursor {
			bytes_to_add = audio_data.BufferSize - LastPlayCursor + PlayCursor;
		} else {
			//EQUAL so we do nothing and add 0
			//This could happen if the audio thread stalls
		}
		audio_data.play_cursor += bytes_to_add / audio_data.BytesPerSample;
		audio_data.play_time = audio_data.play_cursor * audio_data.seconds_per_sample_f64;
		LastPlayCursor = PlayCursor;
		// print("play_cursor=%, play_time=%\n", audio_data.play_cursor, audio_data.play_time);

		//TODO where do we put this
		//TODO remove if we don't use GetRect later
		#if 0 {
		PerFrameUpdateRenderer(Window, WINDOW_WIDTH, WINDOW_HEIGHT);
		}



		// GameUpdateAndRender(*game_memory, *renderer_data, *audio_data, *new_input);
		UpdateAndRender(*game_memory, *renderer_data, *audio_data, *new_input);



		//TODO set mouse input here if changed by game in UpdateAndRender loop
		// SetCursorPos(new_input.MouseX, new_input.MouseY);

		//TODO Can do this only if application has focus
		/*Inefficient way to not play audio on/off focus but we can also set
		this from the terminal since we don't have to update DirectSound settings
		*/
		// if !Input.input_application_has_focus {
		// 	Win32ClearAudioBuffer(audio_data);
		// }
		#if DSOUND_AUDIO {
		Win32FillBufferRegions(audio_buffer, *atd, *audio_data);
		} else {
		AudioFillBuffer(audio_buffer, *atd, *audio_data);
		}

	   //TODO remove this once we implement into renderer and game directly
	   // TESTGetRectSubwindow(*renderer_data);
		/*TODO Could put rendering in a layer in between platform and game. This way
		it's also separated from the platform layer and can be run directly from tests.
		*/
		//TODO can combine this into the renderer
		//TODO can put this back in GameUpdateRender temporarily if we don't use GetRect
		//and we want to have code hot-reload
		RenderDataToOutput(*renderer_data, RendererType.SIMP_OPENGL);
		ResetAllRenderGroups(*renderer_data);
		SwapRenderBuffer(Window, RendererType.SIMP_OPENGL);

		//SPIN LOCK - Here we attempt to hit the target framerate
		#if 0 {
		dt_apollo = current_time_monotonic() - start_apollo;
		while dt_apollo < target_apollo {
			dt_apollo = current_time_monotonic() - start_apollo;
		}
		} 
		#if 1 {
		//NOTE : We can remove this sleeping and just use spin lock if we have any framerate issues.
		//But I am testing for now to see if it works in most basic cases which should help with cpu load in general.
		//We give 2 milliseconds grace so the process can come back which seems to be enough on both mac and windows. 
		//We can try increasing this value if we have framerate issues.
		buffer_seconds :: 0.002;
		delta_time = seconds_since_init() - start_time;
		// print("frame dt = %\n", delta_time);
		target_sleep : float64 = target_sec_per_frame - buffer_seconds;
		if delta_time < target_sleep {
			//This significantly reduces overall cpu time for most scenes (3-4x). Full 4d runs around 25-30ms per frame.
			seconds_to_milli :: 1000.0;
			sleep_time := cast(s32) (seconds_to_milli * (target_sleep - delta_time));
			sleep_milliseconds(sleep_time);
			// Posix.usleep(sleep_time);
		}
		}
		//NOTE : Can use this only this spin lock if have issues with the process sleeping above.
		delta_time = seconds_since_init() - start_time;
		while delta_time < target_sec_per_frame {
			delta_time = seconds_since_init() - start_time;
		}
		// print("delta time = %\n", delta_time);
		// print("delta time = %, target_sec_per_frame=%, target_fps=%\n", delta_time, target_sec_per_frame, target_fps);
		if delta_time > 3 * target_sec_per_frame {
		    log_error("Did not hit 3x frame target % and dt is %\n", target_sec_per_frame, delta_time);
		}
	}

	if game_memory.midi_output != null {
		close_output(game_memory.midi_output);
	}

	#if !DSOUND_AUDIO {
		ma_device_uninit(*device);
	}
} else {
	log_error("Error creating window %.\n", Window);
}
}

FileExplorerInput :: struct {
	initial_dir : string = "./";
}
FileExplorerResult :: struct {
	file_name : string;
	file_success : bool = false;
	error_msg : string;	
}
#if OS == .WINDOWS {
#import "Windows";
#import "Windows_Utf8";
//Note : use this if we don't want to hold program in the console
#if 0 {
#run {
	WR :: #import "Windows_Resources";
	WR.disable_runtime_console();
}
}
jai_cmd : string : "jai";
/*COMMON OS FUNCTIONS
These functions should be redone on every system.
*/
GetDeviceFPS :: (window : Window_Type) -> float64 {
	target_fps : float64 = 60.0;
	DeviceContext := GetDC(window);
	//This seems to return 59 fps for some reason so we add 1
	//TODO Maybe we should just use win32_fps here since dwm timing info seems sometimes unreliable.
	//I think eventually we will allow the player to set this and we can just use win32_fps as default.
	win32_fps := GetDeviceCaps(DeviceContext, VREFRESH);
	dwm_timing_info : DWM_TIMING_INFO = GetDwmTimingInfo();
	if win32_fps == 60 {
		target_fps = cast(float64) win32_fps;
	} else if dwm_timing_info.rateRefresh.uiDenominator != 0 && dwm_timing_info.rateRefresh.uiDenominator != 0 {
	   target_fps = dwm_timing_info.rateRefresh.uiNumerator / cast(float64) dwm_timing_info.rateRefresh.uiDenominator;
	} else if win32_fps == 59 {
	   target_fps = cast(float64)(win32_fps + 0.95);
	} else if win32_fps > 1 {
	   target_fps = cast(float64)(win32_fps);
	   // target_fps = (win32_fps + 1) / 2.0;
	}
	// target_fps = 59.0;
	return target_fps;
}
SetMouseWorldPos :: inline (world_pos : Vector2F, cam : Camera2D, render_group : RenderGroup) {
	mouse_pixel_pos : Vector2F = WorldSpaceToPixelSpace(world_pos, cam, render_group.screen_half_dim, render_group.pixels_per_square);
	//TODO Need to update this per OS
	Win32SetCursorPosition(cast(s32) mouse_pixel_pos.x, cast(s32) mouse_pixel_pos.y);
}
/*DOC Need to separate this for windows and unix with a common function so we can use it in SetMouseWorldPos
*/
Win32SetCursorPosition :: (x : s32, y : s32) {
	mouse_p : POINT;
	mouse_p.x = x;
	// mouse_p.y = BitmapInfo.bmiHeader.biHeight - y;
	mouse_p.y = WINDOW_HEIGHT - y;
	//Need to get rect if we resize I think unless we update WINDOW_HEIGHT which is probably best
	#if 0 {
	rect: RECT;
	win_success = GetClientRect(hwnd, *rect);
	// if !win_success return p.x, p.y, false;
	h := (rect.bottom - rect.top);
	mouse_p.y = h = mouse_p.y;
	}
 	ClientToScreen(my_window, *mouse_p);
	success : BOOL = SetCursorPos(mouse_p.x, mouse_p.y);
	if !success log_error("Win32SetCursorPosition error is %\n", GetLastError());
}

/*DOC REMINDER : To remove a dynamic library from the dynamic library, we can set something that
tells it to remove itself now if we no longer need to use it and then we can allow other dynamic libraries
to load other dynamic libraries later.
This way anyone has control over how the libraries are loaded and run so we don't run extra libraries for now reason.
*/
//Note : Putting DynamicLibrary in windows layer in case the MacOS version is different later
//TODO FROM HERE check this in windows with everthing else, then cleanup if needed before updating jai
//ALSO check the copy is successful here.
LoadDynamicLibrary :: (dl : *DynamicLibrary) -> success : bool, msg : string {
	//TODO I think we can remove this copy if the tests are failing and then remove the use_input_path_name
	//as well. I think we were just using that for some kind of visual studio debugging thing.
	library_name_wide := utf8_to_wide(dl.input_path_name,, temp);
	use_dll_wide := utf8_to_wide(dl.use_input_path_name,, temp);
	copy_success := CopyFileW(library_name_wide, use_dll_wide, .FALSE);
	if copy_success == .FALSE {
		return false, tprint("Could not copy file % to %.\n", dl.input_path_name, dl.use_input_path_name);
	}
	//TODO We could do this more generalized way checking the absolute paths, but this way allows use more
	//control over how we copy (false if fail exists in last param) and also we dont have to do utf8 to wide conversion again
	// library_name_wide := get_absolute_path(dl.input_path_name,, temp);
	// use_dll_wide := get_absolute_path(dl.use_input_path_name,, temp);
	// copy_file(library_name_wide, use_dll_wide);

	dl.module_handle = LoadLibraryW(use_dll_wide);
	if dl.module_handle == null {		
		return false, tprint("DLL % was not found.\n", dl.use_input_path_name);
	}

	new_write_time, file_size, load_time_success := file_modtime_and_size(dl.input_path_name);
	if !load_time_success {
		return false, tprint("Could not load write time for dll : %.\n", dl.input_path_name);
	}
	dl.last_write_time = new_write_time;

	//TODO Can separate this out if we want to get multiple proc addresses for different functions eventually.
	//TODO Should we change the name of first one to ExternalRunOnce?
	dl.ExternalUpdate_proc_address = GetProcAddress(dl.module_handle, "ExternalUpdate");
	dl.ExternalUpdatePerFrame_proc_address = GetProcAddress(dl.module_handle, "ExternalUpdatePerFrame");
	if dl.ExternalUpdate_proc_address == null && dl.ExternalUpdatePerFrame_proc_address == null {
		return false, tprint("No ExternalUpdate or ExternalUpdatePerFrame function found in : %.\n", dl.abs_path_name);
	}

	return true, tprint("Library loaded : %.\n", dl.input_path_name);
}
CloseDynamicLibrary :: inline (dl : *DynamicLibrary) -> success : bool, msg : string {
	result := FreeLibrary(dl.module_handle);
	if result == .FALSE {
		return false, tprint("Close dl : % failed with error : %.\n", dl.abs_path_name, GetLastError());
	} else {
		return true, tprint("Successfuly closed : %.\n", dl.input_path_name);
	}
}
//END OF COMMON OS FUNCTIONS

//WINDOWS SPECIFIC FUNCTIONS
GetDwmTimingInfo :: inline () -> DWM_TIMING_INFO {
	dwm_timing_info : DWM_TIMING_INFO;
	dwm_timing_info.cbSize = DWM_TIMING_INFO_SIZE;
	dwm_hresult := DwmGetCompositionTimingInfo(null, *dwm_timing_info);
	if SUCCEEDED(dwm_hresult) {
		return dwm_timing_info;
	} else {
		//TODO logging
		print("DWM_TIMING_INFO error code %\n", dwm_hresult);
		return DWM_TIMING_INFO.{};
	}				            	
}
Win32QueryPerfCount :: () -> s64 {
    count : s64;
    QueryPerformanceCounter(*count);
    return count;
}
Win32SecondsThisFrame :: inline (start : s64, end : s64, count_per_sec_float : float64) -> float64 {
    return (end - start) / count_per_sec_float;
}

#if DSOUND_AUDIO {
DSound : *IDirectSound8;
PrimaryBuffer : *IDirectSoundBuffer8;
SecondaryBuffer : *IDirectSoundBuffer8;

//TODO Could clear the buffers with a memset here insteadc
Win32ClearAudioBuffer :: (audio_data : AudioData) {
    region1, region2 : *void;
    bytes1, bytes2 : s32;
    hr := SecondaryBuffer.Lock(SecondaryBuffer, 0, cast(s32) audio_data.BufferSize,
        *region1, *bytes1, *region2, *bytes2, 0);
    if SUCCEEDED(hr) {
        region1_byte := cast(*u8) region1;
        for 1..bytes1 {
            <<region1_byte = 0;
            region1_byte += 1;
        }
            
        if bytes2 > 0 {
            region2_byte := cast(*u8) region2;
            for 1..bytes2 {
                <<region1_byte = 0;
                region1_byte += 1;
            }
        }
        SecondaryBuffer.Unlock(SecondaryBuffer, region1, bytes1, region2, bytes2);
    }
    else {
        // log_error("secondary buffer lock not succeded : %\n", hr);
    }
}

/*
    TODO should probably factor this out into its own audio/synthesize module maybe...
    and also make a version with u32 instead of s32 to get that extra bit!

    TODO SHOULD MAKE audio_buffer *float and then cast and Clamp/clip in here so then
    we can keep it float throughout the whole process and then switch miniaudio to use float directly.
*/
Win32FillBufferRegions :: (audio_buffer : *s16, atd : *AudioThreadData, audio_data : *AudioData) {
    region1, region2 : *void;
    bytes1, bytes2 : s32;
    hr := SecondaryBuffer.Lock(SecondaryBuffer, cast(s32) ByteToLock, cast(s32) BytesToWrite,
        *region1, *bytes1, *region2, *bytes2, 0);
    if SUCCEEDED(hr) {
        region1_byte := cast(*s16) region1;
        for 1..bytes1/audio_data.BytesPerSample {
            <<region1_byte = <<audio_buffer;
            region1_byte += 1;
            audio_buffer += 1;
            <<region1_byte = <<audio_buffer;
            region1_byte += 1;  
            audio_buffer += 1;

            audio_data.SampleCounter += 1;
        }
            
        if bytes2 > 0 {
            region2_byte := cast(*s16) region2;
            for 1..bytes2/audio_data.BytesPerSample {
                <<region2_byte = <<audio_buffer;
                region2_byte += 1;
                audio_buffer += 1;
                <<region2_byte = <<audio_buffer;
                region2_byte += 1;  
                audio_buffer += 1;
                
                audio_data.SampleCounter += 1;
            }
        }
        atd.audio_write_cursor = (audio_data.SampleCounter * audio_data.BytesPerSample) % audio_data.BufferSize;
        SecondaryBuffer.Unlock(SecondaryBuffer, region1, bytes1, region2, bytes2);

        if !audio_data.Playing {
            SecondaryBuffer.Play(SecondaryBuffer, 0, 0, DSBPLAY_LOOPING);
            audio_data.Playing = true;
        }
    }
    else {
        // log_error("secondary buffer lock not succeded : %\n", hr);
    }
}

Win32InitDirectSound :: (Window : HWND, SamplingRate : s32, BufferSize : s32) {
	//TODO Since we only use this in this function I think best to just import here and let jai deal with the scope.
	//We were using before #scope_file before but this seems cleaner
	//#scope_file
	dsound_lib :: #system_library "dsound";
	DirectSoundCreate8 :: (device: *void, ppds8: **IDirectSound8, outer: *void) -> s32 #foreign dsound_lib;

	hr := DirectSoundCreate8(null, *DSound, null);
	if SUCCEEDED(hr) {
		DSSCL_NORMAL        :: 0x1;
		DSSCL_PRIORITY      :: 0x2;

		wfx: Waveformatex;
		wfx.wFormatTag      = WAVE_FORMAT_PCM; 
		wfx.nChannels       = 2;
		wfx.nSamplesPerSec  = SamplingRate; //TODO test this with 96000
		wfx.wBitsPerSample  = 16;
		wfx.nBlockAlign     = (wfx.wBitsPerSample / 8) * wfx.nChannels;
		wfx.nAvgBytesPerSec = wfx.nSamplesPerSec * wfx.nBlockAlign;

		hr = DSound.SetCooperativeLevel(DSound, Window, DSSCL_PRIORITY);
		if !SUCCEEDED(hr) log_error("SetCooperativeLevel Failed! HWND %.\n", Window);

		dsbd: DSBUFFERDESC;
		dsbd.dwSize        = size_of(DSBUFFERDESC);
		dsbd.dwFlags       = DSBCAPS_PRIMARYBUFFER;
		dsbd.dwBufferBytes = 0;
		hr = DSound.CreateSoundBuffer(DSound, *dsbd, *PrimaryBuffer, null);
		if !SUCCEEDED(hr) log_error("Primary buffer not created\n");

		hr = PrimaryBuffer.SetFormat(PrimaryBuffer, *wfx); 
		if SUCCEEDED(hr) {
		   log("Primary buffer format set\n");
		}
		else {
		   log("Primary buffer format failed with %\n", hr);
		}

		dsbd_2: DSBUFFERDESC;
		dsbd_2.dwSize        = size_of(DSBUFFERDESC);
		//Added DSBCAPS_GLOBALFOCUS so we can hear sound while dynamic loading, can remove normally
		//Could maybe have 2 separate flags here depending on the build
		#if DYNAMIC {
		dsbd_2.dwFlags       = DSBCAPS_CTRLVOLUME | DSBCAPS_GETCURRENTPOSITION2 | DSBCAPS_GLOBALFOCUS;
		} else {
		//TODO Can make it a terminal option if we want sound to execute on focus or not
		//and then just not pass in audio_data
		// dsbd_2.dwFlags       = DSBCAPS_CTRLVOLUME | DSBCAPS_GETCURRENTPOSITION2;
		dsbd_2.dwFlags       = DSBCAPS_CTRLVOLUME | DSBCAPS_GETCURRENTPOSITION2 | DSBCAPS_GLOBALFOCUS;
		}
		dsbd_2.lpwfxFormat   = *wfx;
		dsbd_2.dwBufferBytes = BufferSize;
		hr = DSound.CreateSoundBuffer(DSound, *dsbd_2, *SecondaryBuffer, null);
		if SUCCEEDED(hr) {
		   print("Secondary buffer format set\n");
		}
	}
	}
}
//TODO Could pass a struct in here to reuse with macos
//if we need more data.
OpenFileWithExplorer :: inline (
	fei := FileExplorerInput.{})
-> FileExplorerResult
{
   buffer: [512] u16;
   ofn: OPENFILENAMEW;
   ofn.lStructSize = size_of(OPENFILENAMEW);
   // wfilter := utf8_to_wide("Codex files\0*.codex",, temp);
   // ofn.lpstrFilter = wfilter;
   ofn.lpstrFile   = buffer.data;
   ofn.nMaxFile    = buffer.count;
   ofn.Flags       = OFN_NOCHANGEDIR;
   ofn.lpstrInitialDir = utf8_to_wide(fei.initial_dir,, temp);
   // ofn.lpstrInitialDir = utf8_to_wide(".",, temp);

   ofe_result : FileExplorerResult;
   open_success := GetOpenFileNameW(*ofn);
   if open_success {
		file_name, success := wide_to_utf8(buffer.data,, temp);
		if success {
			ofe_result.file_name = file_name;
			ofe_result.file_success = true;
	  		//TODO This is called twice in the jai codex library where i found this.
	  		// file_name = wide_to_utf8(buffer.data,, temp);
			// print_to_builder(*sb, "file_name : %\n", result);
		} else {
			ofe_result.file_success = false;
			ofe_result.error_msg = tprint("cannot convert wide % to utf8\n",buffer);
			log_error(ofe_result.error_msg);
		}
   } else {
   	//TODO Could print this to console as well
		ofe_result.file_success = false;
		ofe_result.error_msg = "No file opened.\n";
		//Techincally this is not necessarily an error since we could have just closed or cancelled the explorere
		log(ofe_result.error_msg);
   }
   return ofe_result;
}
//TODO This should be in windows.jai but we leave here for now so I don't have to keep adding it when i update the compiler.
OFN_OVERWRITEPROMPT :: 0x00000002;
SaveFileWithExplorer :: inline (
	fe_input := FileExplorerInput.{})
-> FileExplorerResult
{
	buffer: [512] u16;
   ofn: OPENFILENAMEW;
   ofn.lStructSize = size_of(OPENFILENAMEW);
   // wfilter := utf8_to_wide("Codex files\0*.codex",, temp);
   // ofn.lpstrFilter = wfilter;
   ofn.lpstrFile   = buffer.data;
   ofn.nMaxFile    = buffer.count;
   // ofn.Flags       = OFN_NOCHANGEDIR | OFN_OVERWRITEPROMPT;
   ofn.Flags       = OFN_OVERWRITEPROMPT;
   ofn.lpstrInitialDir = utf8_to_wide(fe_input.initial_dir,, temp);
   // ofn.lpstrInitialDir = utf8_to_wide(".",, temp);

   fe_result : FileExplorerResult;
   open_success := GetSaveFileNameW(*ofn);
   if open_success {
		file_name, success := wide_to_utf8(buffer.data,, temp);
		if success {
			fe_result.file_name = file_name;
			fe_result.file_success = true;
	  		//TODO This is called twice in the jai codex library where i found this.
	  		// file_name = wide_to_utf8(buffer.data,, temp);
			// print_to_builder(*sb, "file_name : %\n", result);
		} else {
			fe_result.error_msg = sprint("cannot convert wide % to utf8\n",buffer);
			log_error(fe_result.error_msg);
		}
   } else {
   	//TODO Could print this to console as well
		fe_result.error_msg = "No file saved.\n";
		log_error(fe_result.error_msg);
   }
   return fe_result;
}
} 
else #if OS == .MACOS {
Posix :: #import "POSIX";
#import "Objective_C";
#import "Objective_C/AppKit";
//Technically I can rename this to jai but Ill leave it like
//this since that's the default although will likely need this to be input
//if the user decides to change the name of their compiler executable.
jai_cmd : string : "jai-macos";
GetDeviceFPS :: (window : Window_Type) -> float64 {
	//TODO Implement this on mac once we have it, just assume 60fps for now since that is my current screen framerate.
	//OR we could just have this be user set with a default to 60 since I can't seem to programatically get the refresh rate on macos.
	target_fps : float64 = 60.0;
	return target_fps;
}
//TODO Should we have a function for each here or put the OS inside since the WorldSpaceToPixelSpace is the same for both of them...
SetMouseWorldPos :: inline (world_pos : Vector2F, cam : Camera2D, render_group : RenderGroup) {
	mouse_pixel_pos : Vector2F = WorldSpaceToPixelSpace(world_pos, cam, render_group.screen_half_dim, render_group.pixels_per_square);
	print("SetMouseWorldPos NOT implement for mac yet.\n");
	//TODO Need to update this per OS
	// Win32SetCursorPosition(cast(s32) mouse_pixel_pos.x, cast(s32) mouse_pixel_pos.y);
}

//Note : Putting DynamicLibrary in windows layer in case the MacOS version is different later
LoadDynamicLibrary :: (dl : *DynamicLibrary) -> success : bool, msg : string {
	//TODO Try to copy file directly with syscall if we don't have it in new jai yet anyways.
	// syscall :: (unknown0: s32, __args: ..Any) -> s32 #foreign libc;
	// syscall(SYS_copyfile, dl.input_path_name.data, dl.use_input_path_name.data)
	// SYS_copyfile
	//TODO It seems like this copy is failing in tests sometimes so let's see if not using it is ok anyways.
	//IF IT IS then we can remove it on windows as well and then check here for removing the use paths anyways.
	//TODO WHY AM I COPYING THIS? I guess to prevent issues with the original file...
	//or maybe also in case it changes again mid function. This is a good safety measure in general.
	//Generally, copying prevents any incorrect values from being fetched if we grab symbols
	//intermitently or something. It is unlikely since I will grab everything at once but this generally
	//prevents issues if the original dll is updated since we just use our copy of it.
	copy_success := copy_file(dl.input_path_name, dl.use_input_path_name);
	if !copy_success {
		return false, tprint("Could not copy file % to %.\n", dl.input_path_name, dl.use_input_path_name);
	}

	// rpath := Posix.realpath(dl.use_input_path_name.data, null);
	// if rpath == null {
	// 	return false, tprint("% not a real path.\n", dl.use_input_path_name);
	// }

	dl.module_handle = Posix.dlopen(dl.use_input_path_name.data, Posix.RTLD_LAZY | Posix.RTLD_LOCAL);
	// dl.module_handle = Posix.dlopen(dl.input_path_name.data, Posix.RTLD_LAZY | Posix.RTLD_LOCAL);
	if dl.module_handle == null {
		error := Posix.dlerror();
		return false, tprint("Could not open \"%\": %", dl.input_path_name, to_string(error));
	}

	//TODO FROM HERE Maybe we should load file time first and then copy and open to prevent writes before reading time
	//and then we have a time after.
	//ALSO use an allocator for dynamic libraries and make a free list eventually.
	//We need to grab this after dlopen since only now do we actually have the handle
	new_write_time, file_size, load_time_success := file_modtime_and_size(dl.input_path_name);
	if !load_time_success {
		return false, tprint("Could not load write time for : %.\n", dl.input_path_name);
	}
	dl.last_write_time = new_write_time;


	//TODO Can separate this out if we want to get multiple proc addresses for different functions eventually.
	dl.ExternalUpdate_proc_address = Posix.dlsym(dl.module_handle, "ExternalUpdate");
	dl.ExternalUpdatePerFrame_proc_address = Posix.dlsym(dl.module_handle, "ExternalUpdatePerFrame");
	if dl.ExternalUpdate_proc_address == null && dl.ExternalUpdatePerFrame_proc_address == null {
		return false, tprint("No ExternalUpdate or ExternalUpdatePerFrame function found in : %.\n", dl.abs_path_name);
	}

	return true, tprint("Library loaded : %.\n", dl.input_path_name);
}
CloseDynamicLibrary :: inline (dl : *DynamicLibrary) -> bool, string {
	result := Posix.dlclose(dl.module_handle);
	//NOTE : Apparently this returns 0 when it is successful
	if result == 0 {
		return true, tprint("Successfuly closed : %.\n", dl.input_path_name);
	} else {
		error := Posix.dlerror();
		return false, tprint("Could not close \"%\": %", dl.input_path_name, to_string(error));
	}
}
/*TODO Ask on jai discord how to set color to theme when opening an NSSavePanel on macos.
Also when returning back to program the input_application_has_focus is true and we read input
but the app is not actually in focus and cannot get mouse readings until we click it with the mouse.
*/
OpenFileWithExplorer :: inline (
	fei := FileExplorerInput.{}) 
-> FileExplorerResult
{
	open_panel : *NSOpenPanel = NSOpenPanel.openPanel();
	save_panel : *NSSavePanel = *open_panel.super_NSSavePanel;

	#if 0 {
	//TODO How do we actually set the background color to be the theme color or something darker?
	NSOpenPanel.setBackgroundColor(*save_panel.super_NSPanel.super_NSWindow, NSColor.blueColor());

	//TODO I don't think this actually does anything
  	nsstring : *NSString = NSString.initWithString(objc_alloc(NSString), fei.initial_dir);
  	nsurl : *NSURL = NSURL.URLWithString(nsstring);
	NSOpenPanel.setDirectoryURL(save_panel, nsurl);
	}

	ns_modal_response : NSModalResponse = NSOpenPanel.runModal(save_panel);
   ofe_result : FileExplorerResult;
	if ns_modal_response == NSModalResponseOK {
	   return_url : *NSURL = NSSavePanel.URL(save_panel);
	   file_path : string = to_string(NSURL.path(return_url),,temp);
	   ofe_result.file_name = file_path;
	   ofe_result.file_success = true;
	} else {
	   ofe_result.file_success = false;
		ofe_result.error_msg = "No file opened.\n";
		//Techincally this is not necessarily an error since we could have just closed or cancelled the explorer
		//TODO We could check the other NSModalResponse for more specific checking like if we cancelled or closed the pane
		//I think this is not available in windows since windows just returns a bool
		log(ofe_result.error_msg);
	}

	return ofe_result;
}
SaveFileWithExplorer :: inline (
	fei := FileExplorerInput.{}) 
-> FileExplorerResult 
{
	save_panel : *NSSavePanel = NSSavePanel.savePanel();

	#if 0 {
	//TODO How do we actually set the background color to be the theme color or something darker?
	NSSavePanel.setBackgroundColor(*save_panel.super_NSPanel.super_NSWindow, NSColor.blueColor());

	//TODO I don't think this actually does anything
  	nsstring : *NSString = NSString.initWithString(objc_alloc(NSString), fei.initial_dir);
  	nsurl : *NSURL = NSURL.URLWithString(nsstring);
	NSSavePanel.setDirectoryURL(save_panel, nsurl);
	}

	ns_modal_response : NSModalResponse = NSSavePanel.runModal(save_panel);
   ofe_result : FileExplorerResult;
	if ns_modal_response == NSModalResponseOK {
	   return_url : *NSURL = NSSavePanel.URL(save_panel);
	   file_path : string = to_string(NSURL.path(return_url),,temp);
	   ofe_result.file_name = file_path;
	   ofe_result.file_success = true;
	} else {
	   ofe_result.file_success = false;
		ofe_result.error_msg = "No file saved.\n";
		log_error(ofe_result.error_msg);
	}

	return ofe_result;
}
}

UnloadDLL :: (dl : *DynamicLibrary) -> success : bool, msg : string {
	if dl.module_handle != null {
		success, msg := CloseDynamicLibrary(dl);
		if !success {
			//TODO Should we set the handles to null or is it ok. I think we did not close the library
			//then it means we still have a valid handle but if ever we have an issue with this,
			//then we can try setting the handles to null here or before in this function.
			log_error("Unsuccessful close dynamic library : %\n", msg);
			return false, msg;
		}
		// log(msg, flags=.VERBOSE_ONLY);
		dl.module_handle = null;
	}
	dl.ExternalUpdate_proc_address = null;
	return true, tprint("Successfully unloaded %.\n", dl.input_path_name);
}
RemoveDynamicLibrary :: (dl : *DynamicLibrary) -> success : bool, msg : string {
	success, msg := UnloadDLL(dl);
	if !success return success, msg;
	for * global_dynamic_libraries if it.abs_path_name == dl.abs_path_name {
		//TODO We can remove these if we reuse dynamic libraries then store it in an allocator
		//in the dynamic library and just reuse that and have a free_dynamic_libraries list.
		//NOTE : no_ext_path_name is a string view on input_path_name so no need to free
		free(it.input_path_name);
		free(it.use_input_path_name);
		free(it.lock_file_name);
		free(it.abs_path_name);

		//TODO Should we remove this but ordered now that we can add more dynamic libraries
		remove it;
		break;
	}
	return success, msg;
}

LoadDLSuccess :: inline (dl : DynamicLibrary) -> bool {
	success : bool = dl.module_handle != null && dl.ExternalUpdate_proc_address != null;
	return success;
}

//TODO Should we leave this here since we only use it here right now or put it with the other cross-platform code?
#if OS == .WINDOWS {
dl_suffix : string : "dll";
} else #if OS == .MACOS {
dl_suffix : string : "dylib";
}
//TODO Should this return the actual dynamic library?
/*DOC : Generally only this function should be called to fetch a dynamic library. This will either create the library
or reload it and so ReloadDynamicLibrary and CreateDynamicLibrary should be only called directly from here.
We split them out only for coding simplicity and convenience. 
*/
FetchDynamicLibrary :: (file_name_with_type : string) -> success : bool, msg : string {
	//TODO Be careful if we add extension to the file_name because the dll cant have the extension on it 
	//otherwise well have file_name.jai.dll and it won't work like that one time, at band camp...
	file_name_split : [] string = String.split(file_name_with_type, cast(u8) #char ".",, temp);
	if file_name_split.count == 2 {
		file_extension : string = file_name_split[1];
		if file_extension != dl_suffix {
			return false, tprint("Invalid dynamic library suffix \"%\". Should be \"%\".\n", file_extension, dl_suffix);
		}
		abs_path_name := get_absolute_path(file_name_with_type);
		old_dl, dl_exists := ArrayFindFirstByNameId(global_dynamic_libraries,
			abs_path_name, "abs_path_name");
		if dl_exists {
			//NOTE : We have 3 reload states in case we don't reload but it does not fail for automatic dynamic lib reloading.
			reload_state, msg := ReloadDynamicLibrary(old_dl);
			if reload_state == .ERROR {
				log_error(msg);
				return false, msg;
			} else {
				return true, msg;
			}
		} else {
			//TODO Could load a list of these if we want to allow user to name functions whatever they want.
			file_name_no_ext := file_name_split[0];
			success, msg := CreateDynamicLibrary(file_name_no_ext);
			if !success log_error(msg);
			return success, msg;
		} 
	} else {
		return false, tprint("Invalid dynamic library : %.\n", file_name_with_type);
	}
}

/*NOTE : We don't pass in the extension here so we can set the extension for the use and lock files.
*/
CreateDynamicLibrary :: (rel_file_name_no_ext : string) -> success : bool, msg : string {
	//TODO We could pull this out as CreateDynamicLibrary if that helps eventually
	dl : DynamicLibrary;
	//NOTE : We temp string first in case we fail and then we copy them after if load is successful.
	dl.input_path_name = tprint("%.%", rel_file_name_no_ext, dl_suffix);
	dl.use_input_path_name = tprint("%_use.%", rel_file_name_no_ext, dl_suffix);
	load_success, msg := LoadDynamicLibrary(*dl);
	if !load_success {
		log_error(msg);
		return false, msg;
	}

	/*NOTE : Because these names will be stored indefinitely, we use the default allocator.
	TODO We could use a separate dl allocator just for dl names and then clear it whenever we reset all dynamic libraries.
	If we do user unloading dlls eventually then we can either just free the strings or even set a tiny allocator
	for each dynamic library and reuse that.
	YES have a free_dynamic_libraries list if we ever close them and then just store it there and keep
	a tiny allocator for each dynamically library for names and then reuse it.
	This will likely be necessary later when we have different types of functions for example.
	*/
	dl.input_path_name = copy_string(dl.input_path_name,,context.default_allocator);
	dl.no_ext_path_name = String.slice(dl.input_path_name, 0, rel_file_name_no_ext.count);
	dl.use_input_path_name = copy_string(dl.use_input_path_name,,context.default_allocator);
	//NOTE : We already checked this exists with LoadDynamicLibaray so we can just get it.
	//We copy because the string is return on the temp allocator by default and we set it as well to make sure.
	dl.abs_path_name = copy_string(get_absolute_path(dl.input_path_name,,temp),,context.default_allocator);
	// print("abs_path_name=%\n", dl.abs_path_name);
	dl.lock_file_name = sprint("%_lock.tmp", rel_file_name_no_ext,,context.default_allocator);
	//REMINDER : This needs to be stored in a global allocator otherwise tests fail if we initalize this
	//on a test because it will use the test allocator and then lose the datat at the end of the test.
	array_add(*global_dynamic_libraries, dl,,context.default_allocator);

	return true, tprint("Loaded dynamic library : %.\n", dl.input_path_name);
}

//TODO Should we rename this function? Maybe ReloadExternalUpdate?
//NOTE : We have 3 reload states in case we don't reload but it does not fail for automatic dynamic lib reloading.
ReloadState :: enum u8 {
	RELOADED;
	NO_CHANGE;
	ERROR;
}
ReloadDynamicLibrary :: (dl : *DynamicLibrary) -> ReloadState, msg : string {
	//Note : We put absolute path for errors and input path for success for clarity and maybe to help user debugging.
	lock_file_exists := file_exists(dl.lock_file_name);
	if !lock_file_exists {
		new_write_time, file_size, load_time_success := file_modtime_and_size(dl.input_path_name);
		if load_time_success && dl.last_write_time != new_write_time {
			// print("last write time %, new write time %", dl.last_write_time, new_write_time);
			unload_success, unload_msg := UnloadDLL(dl);
			if !unload_success {
				return .ERROR, unload_msg;
			}

			load_success, load_msg := LoadDynamicLibrary(dl);
			if !load_success {
				return .ERROR, load_msg;
			}
			//Note : This is the address to the function which is itself an address because a function
			//pointer is an address. So this is already an addres to an address so we can check it for null.
			// euf.ExternalUpdate = cast(Type_ExternalUpdate) dl.ExternalUpdate_proc_address;
			return .RELOADED, tprint("Reloaded : %.\n", dl.input_path_name);
		}
		return .NO_CHANGE, tprint("No changes : %.\n", dl.input_path_name);
	}
	return .NO_CHANGE, tprint("Lock file preventing reload : %.\n", dl.lock_file_name);
}

MyKeyInfo :: struct {
	wasDown : bool;
	isDown : bool;
	altDown : bool;
	ctrlDown : bool;
	repeat : bool;
}
// JaiProcessWindowInput :: (keyboard : *ControllerInput) 
JaiProcessWindowInput :: (new_input : *GameInput) {
	// if !Input.input_application_has_focus return;
	keyboard : *ControllerInput = *new_input.Controllers[0];

	key_info : MyKeyInfo;
	for event : Input.events_this_frame {
		//TODO Just use booleans here
    	key_info.wasDown = event.repeat;
		key_info.isDown = cast(bool) event.key_pressed;
		key_info.repeat = cast(bool) event.repeat;
		//TODO Storing these in bits would make it more efficient overall for storing and checking.
		key_info.altDown = cast(bool) event.alt_pressed;
		key_info.ctrlDown = cast(bool) event.ctrl_pressed;

		if key_info.altDown && key_info.ctrlDown {
			keyboard.only_ctrl_alt_down = true;
		} else {
			keyboard.only_alt_down = key_info.altDown;
			keyboard.only_ctrl_down = key_info.ctrlDown;
		}


		if event.type == {
			/*NOTE : This is a good way to do it because later we can generalize this to midi/alt inputs
			and then map keys to chars and then can just load this buffer up and use it in the same way.
			*/
			case .TEXT_INPUT; {
				// print("letter value %\n", cast(u8) event.utf32);
				// key_info.isDown = event.utf32 > 0;
				//TODO need to check if this is an actual fix on mac.
				//So check what TEXT_INPUT gives for thing like alt for example
				if event.utf32 >= 0 && event.utf32 <= 255 {
					JaiProcessTextInput(keyboard, cast(u8) event.utf32);
				}
				// JaiProcessTextInput(keyboard, cast,no_check(u8) event.utf32);
			}
			case .KEYBOARD; {
					//TODO could update this back to key_info if we want more control over keypress
			  	if event.key_code == Input.Key_Code.ARROW_UP {
					JaiProcessSingleInput(*keyboard.arrow_up, key_info);
			  	}
			  	else if event.key_code == Input.Key_Code.ARROW_DOWN {
					JaiProcessSingleInput(*keyboard.arrow_down, key_info);
			  	}
			  	else if event.key_code == Input.Key_Code.ARROW_LEFT {
					// print("left is_down : %, was_down : %\n", key_info.isDown, key_info.wasDown);
					JaiProcessSingleInput(*keyboard.arrow_left, key_info);
			  	}
			  	else if event.key_code == Input.Key_Code.ARROW_RIGHT {
					JaiProcessSingleInput(*keyboard.arrow_right, key_info);
			  	}
			  	else if event.key_code == Input.Key_Code.ENTER {
			  		//TODO Should this be here or processed separately by return_enter input key?
			  		//What if we have a very fast typer, we would still get both if we have if statements,
			  		//although it may not be in the right order if we process it ourselves.
			  		//NOTE : This isDown check is to not add "\n" when we are up_this_frame
			  		if key_info.isDown {
			  			/*Note : This works here because we pass in '\n' when we hit return_enter.
						So we will always get text_input when we do so. This keeps all the text_input
						button presses in order, in case someone writes very quickly, ie multiple chars
						in < 1 frame. It does however make the code a bit odd since we may want
						enter to be hit without text_input. As long as we don't check both then it's fine,
						but maybe we want to not pass in enter key as '\n' and therefore only process it 
						when we need it, which would be cleaner and less prone to programming error but also
						could lead to incorrect text_input character sequence.
						*/
						JaiProcessTextInput(keyboard, cast(u8) #char "\n");
					}
					JaiProcessSingleInput(*keyboard.return_enter, key_info);
			  	}
			  	else if event.key_code == Input.Key_Code.BACKSPACE {
					JaiProcessSingleInput(*keyboard.back_space, key_info);
			  	}
			  	else if event.key_code == Input.Key_Code.DELETE {
					JaiProcessSingleInput(*keyboard.delete, key_info);
			  	}
			  	else if event.key_code == Input.Key_Code.F9 {
					JaiProcessSingleInput(*keyboard.f9, key_info);
			  	}
				else if event.key_code == xx #char "C" {
			   	JaiProcessSingleInput(*keyboard.c_button, key_info);
			   }                
			  	else if event.key_code == xx #char "T" {
					JaiProcessSingleInput(*keyboard.t_button, key_info);
			  	}
				else if event.key_code == xx #char "U" {
			  		JaiProcessSingleInput(*keyboard.u_button, key_info);
				}
				else if event.key_code == xx #char "O" {
					JaiProcessSingleInput(*keyboard.o_button, key_info);
				}                
				else if event.key_code == xx #char "G" {
					JaiProcessSingleInput(*keyboard.g_button, key_info);
				}                
				else if event.key_code == xx #char "V" {
				  	JaiProcessSingleInput(*keyboard.v_button, key_info);
				}                
				else if event.key_code == xx #char "N" {
				  	JaiProcessSingleInput(*keyboard.n_button, key_info);
				}                
				else if event.key_code == xx #char "M" {
				  JaiProcessSingleInput(*keyboard.m_button, key_info);
				} 
				else if event.key_code == xx #char "R" {
				  JaiProcessSingleInput(*keyboard.r_button, key_info);
				}  
				else if event.key_code == xx #char "X" {
				  JaiProcessSingleInput(*keyboard.x_button, key_info);
				}  
				else if event.key_code == xx #char "Y" {
				  JaiProcessSingleInput(*keyboard.y_button, key_info);
				}  
				else if event.key_code == xx #char "E" {
				  JaiProcessSingleInput(*keyboard.e_button, key_info);
				}  
				else if event.key_code == xx #char "P" {
				  JaiProcessSingleInput(*keyboard.p_button, key_info);
				}
				else if event.key_code == xx #char "W" {
				  JaiProcessSingleInput(*keyboard.Up, key_info);
				}
				else if event.key_code == xx #char "A" {
				  JaiProcessSingleInput(*keyboard.Left, key_info);
				}
				else if event.key_code == xx #char "S" {
					//TODO Change name to s_button
				  JaiProcessSingleInput(*keyboard.Down, key_info);
				}
				else if event.key_code == xx #char "D" {
				  JaiProcessSingleInput(*keyboard.Right, key_info);
				}
				else if event.key_code == xx #char "I" {
				  JaiProcessSingleInput(*keyboard.ActionUp, key_info);
				}
				else if event.key_code == xx #char "J" {
				  JaiProcessSingleInput(*keyboard.ActionLeft, key_info);
				}
				else if event.key_code == xx #char "L" {
					//TODO Change name to l_button
				  JaiProcessSingleInput(*keyboard.ActionRight, key_info);
				}
				else if event.key_code == xx #char "K" {
				  JaiProcessSingleInput(*keyboard.ActionDown, key_info);
				}
				else if event.key_code == xx #char "1" {
				  JaiProcessSingleInput(*keyboard.one, key_info);
				}
				else if event.key_code == xx #char "2" {
				  JaiProcessSingleInput(*keyboard.two, key_info);
				}
				else if event.key_code == xx #char "3" {
					JaiProcessSingleInput(*keyboard.three, key_info);
				}
				else if event.key_code == xx #char "4" {
					JaiProcessSingleInput(*keyboard.four, key_info);
				}
				else if event.key_code == xx #char "5" {
					JaiProcessSingleInput(*keyboard.five, key_info);
				}
				else if event.key_code == xx #char "6" {
				  JaiProcessSingleInput(*keyboard.six, key_info);
				}
				else if event.key_code == xx #char "7" {
					JaiProcessSingleInput(*keyboard.seven, key_info);
				}
				else if event.key_code == xx #char "8" {
				  	JaiProcessSingleInput(*keyboard.eight, key_info);
				}
				else if event.key_code == xx #char "9" {
				  	JaiProcessSingleInput(*keyboard.nine, key_info);
				}
				else if event.key_code == xx #char "0" {
				  	JaiProcessSingleInput(*keyboard.zero, key_info);
				}
				else if keyboard.only_ctrl_alt_down && event.key_code == xx #char "Q" && 
						key_info.isDown && !key_info.repeat
				{
					keyboard.PauseGame ^= 1;
					if IsOdd(keyboard.PauseGame) print("Game Paused\n");
					else print("Game Unpaused\n");
					// print("keyboard.PauseGame = %\n", keyboard.PauseGame);
				}
				else if keyboard.only_alt_down && event.key_code == .F4
				{
					print("pressed Alt+F4\n");
					Running = false;
				}
				else if event.key_code == .MOUSE_BUTTON_LEFT {
					//TODO This is temporary. We will use this directly from events once we refactor the mouse input completely.
    				// Win32ProcessKeyboardInput(key_info, *new_input.MouseButtons[0]);
    				JaiProcessSingleInput(*new_input.MouseButtons[0], key_info);
				}
				else if event.key_code == .MOUSE_BUTTON_RIGHT {
    				// Win32ProcessKeyboardInput(key_info, *new_input.MouseButtons[1]);
    				JaiProcessSingleInput(*new_input.MouseButtons[1], key_info);
				}
				else if event.key_code == .MOUSE_BUTTON_MIDDLE {
    				// Win32ProcessKeyboardInput(key_info, *new_input.MouseButtons[2]);
    				JaiProcessSingleInput(*new_input.MouseButtons[2], key_info);
				}
			}
			case .MOUSE_WHEEL; {
				//TODO Could round to account for non-typical wheel deltas
				// new_input.mouse_wheel = round_to_s32(event.wheel_delta / cast(float) event.typical_wheel_delta);
				#if OS == .WINDOWS {
				new_input.mouse_wheel = event.wheel_delta / event.typical_wheel_delta;
				} else #if OS == .MACOS {
				//TODO Test to see if we can make this smoother on mac. It's wierd though because if people
				//adjusting the scroll wheel themselves, then we would have to change it as well.
				//Could just set it to be +/- 1 or 2 (test out later) depending on if wheel delta is 1 or > 1 or something.
				//Can do it logarithmically (so 1 == 1 and 1-10 == 2 and 10+ == 3)
				//The acceleration makes it tricky to judge but at least we can dampen it and maybe allow people to adjust it.
				new_input.mouse_wheel = event.wheel_delta;
				print("mouse_wheel=%\n", new_input.mouse_wheel);
				}
			}
			case .QUIT; {
				print("closed window\n");
				Running = false;
			}
		}
	}
}

JaiProcessSingleInput :: inline (button_state : *ButtonState, key_info : MyKeyInfo) {
	button_state.EndedDown = key_info.isDown; //This does not get reset every frame in ResetControllerInput
	button_state.is_down_with_pause = key_info.isDown;
	button_state.down_this_frame = key_info.isDown && !key_info.repeat;
	button_state.up_this_frame = !key_info.isDown;
}

JaiProcessTextInput :: inline (keyboard : *ControllerInput, char_utf32 : u8) {
	keyboard.text_input_buffer[keyboard.text_buffer_count] = char_utf32;
	keyboard.text_buffer_count += 1;

	is_down : bool = char_utf32 > 0;
	keyboard.text_input.is_down_with_pause = is_down;
	keyboard.text_input.up_this_frame = !is_down;
}


PlayCursor : int;
LastPlayCursor : int;
FixedWriteCursor : int; //garbage not used anywhere. apparently this is fixed offset after play cursor...wtf!
BytesToWrite : int; //if ByteToLock == PlayCursor we do nothing since BytesToWrite would remain 0
ByteToLock : int;
TargetCursor : int;
//TODO Should we use this instead of having the mutex being passed around and possibly having the wrong mutex...
/*DOC I think it is better to have this mutex in the global scope like Sound_Player so that we remove the chance of
taking invalid pointer to it ever. It seems like if we were using the wrong mutex 
(like copying on the stack or or copying through a function a call)
it could lead to a total crash which we want to avoid as much as possible and so this seems more full proof
to use the same mutex every from global scope so we always get the same data and same pointer everywhere.
ALSO this is only used in this file and since we use a ring buffer only in the audio thread I think we will
only ever use it in this file so maybe it is also generally cleaner to leave it here anyways.
*/
AUDIO_MUTEX : Mutex;
#if !DSOUND_AUDIO {
//TODO Can likely either swap between direct sound or just use this instead since it is likely better overall.
miniaudio_callback :: (pDevice : *ma_device, pOutput : *void, pInput : *void , frameCount : ma_uint32) -> void #c_call {
//TODO We can push a specific context if needed here.
// new_context : #Context;	
// new_context.allocator = 
// new_context.temporary_storage = 
push_context { // This pushes a default #Context.
	// print("frame=%\n", frameCount);
	atd := cast(*AudioThreadData) pDevice.pUserData;
	assert(atd != null);
	assert(atd.audio_data != null);

	lock(*AUDIO_MUTEX);

	output_array : [] u8;
	output_array.data = cast(*u8) pOutput;
	//Note that here BytesPerSample, the sample from before is the same as the frame from mini audio.
	output_array.count = cast(int) frameCount * atd.audio_data.BytesPerSample;
	circle_array : [] u8;
	circle_array.data = cast(*u8) atd.audio_ring_buffer;
	circle_array.count = atd.audio_data.BufferSize;
	ReadBytesFromCircleBuffer(output_array, circle_array, *atd.audio_play_cursor);

	unlock(*AUDIO_MUTEX);
}
}
}
//Better to keep 16-bit depth since that will work on all machines and then maybe we can allow adjustment later.
//This way we can also clip in-game and then people can decide if they want to allow it or do it themselves.
//mini-audio docs - In the data callback, if your data is already clipped prior to copying it into the output buffer, 
//set the noClip config option in the device config to true. This will disable miniaudio's built in clipping function.
AudioFillBuffer :: inline (audio_buffer : *s16, atd : *AudioThreadData, ad : *AudioData) {
	lock(*AUDIO_MUTEX);

	audio_array : [] u8;
	audio_array.data = cast(*u8) audio_buffer;
	audio_array.count = ad.SamplesToFill * ad.BytesPerSample;
	circle_array : [] u8;
	circle_array.data = cast(*u8) atd.audio_ring_buffer;
	circle_array.count = ad.BufferSize;
	WriteBytesToCircleBuffer(audio_array, circle_array, *atd.audio_write_cursor);

	//TODO I think we can just use audio_write_cursor instead of this if we update the setup
	//I am keeping it for now since this keeps track of total samples, but do we really need it for anything?
	ad.SampleCounter += ad.SamplesToFill;
	unlock(*AUDIO_MUTEX);
}
/*TODO REMINDER TESTS
1) Test audio thread latency (100ms and also a few seconds) and see if it makes sense while everything is running.
Basically we would write some code in the audio thread which would force latency given some input or a timer.
Check both cases with neumes playing and with hover audio. In this case, the audio and the cursor should pause
but everything else should run and then the audio should pick up from where it left off.
2) Test video thread latency (100ms and also a few seconds) and force it with input or timer like above.
Check both neume playing and hover audio cases to make sure everything is correct on restart.
We would likely hear some kind of 1 sec loop since the audio rendering depends on the main thread and so
the play cursor would just loop on whatever is in the ring buffer until the video comes back up.
*/
AudioThreadData :: struct {
	//We can likely remove this from here eventually but maybe we wait until we move the miniaudio device
	//into it so we only have it in 1 place and then see how we want to move it around.
	audio_data : *AudioData;
	//TODO Remove this and put it in here below
	// locked_sound_data : *LockedSoundData;

	//TODO Maybe this should be in global scope like in Sound_Player
	//so we don't accidentally have alternate ones.
	// audio_mutex : Mutex;

	//TODO Eventually if we set these and use this in the audio thread, then we can remove the
	//pointer to AudioData but I don't want the same data in 2 places so let's change it once we
	//collapse it into one place and know where/if that place will be.
	buffer_size_in_bytes : int;
	//NOTE : This is bytes per frame since mini audio considers a frame the samples for all channels.
	//Maybe that is a better word in any case for it since it correspond to PCM frames and I should change
	//to that word everywhere for my sanity.
	//Right not sample refers to sample for all channels but in miniaudio a frame is sample for all channels
	//and a sample is data for 1 single channel.
	bytes_per_frame : int;
	// bytes_per_sample : int;

	/*DOC
	This is a ring/circle buffer where the audio thread reads from the buffer at byte audio_play_cursor and
	the main system thread writes to the buffer at byte audio_write_cursor. These are both done in circular fashion
	with byte arrays for clarity and memcpy for efficiency.
	*/
	//TODO We could make this an array if that is more convenient but things are a bit confusing when converting
	//between samples and bytes so maybe better to do this.
	//Can likely change to *float later, just leaving like this so it matches with direct sound but if we remove
	//that later we can change this OR just change the direct sound to cast from float when filling the buffer
	//and we can clip in there too manually.
	//If we change this to float, we can clip manually by clamping and see if then we can allow clipping or no clipping
	//so the user can decide to do it themselves if they want to do something other than clipping.
	audio_ring_buffer : *s16;
	/*DOC 
	audio_play_cursor is the current byte that the audio thread will play. (The next byte that will be read when the audio thread is called)
	audio_write_cursor is the current byte that we are writing to in the ring buffer. (The next byte that will be written to when the audio thread is called)
	The audio_write_cursor is generally between the audio_play_cursor and the FixedWriteCursor. We then write
	up until TargetCursor which will be less times if the play cursor ran more times and less times if the play cursor ran less.
	Since the FixedWriteCursor is dependent on the audio_play_cursor, then the audio_write_cursor will write more or less depending on that.
	If there is video (main thread) or audio (audio thread) latency then we have 2 cases :
	1) Video (main thread) latency 
		- The play cursor will keep moving up but the write cursor will not. In this case, we continue writing
		only after we come back. Since the ring buffer is 1 second (48000 samples), then as long as the latency
		is < 1s we just write in all the audio on the next frame.
		- IF THE hiccup is > 1 second, it is still ok because there are 2 cases here.
			- 1) Playing neumes and so we will just end all neumes that cursor is greater than
				  since the play cursor keeps going, wherever it is, it will start to play those neumes
			     this means we have to ensure we pickup neumes where neume.x_start <= audio_cursor <= neume.x_end
     		- 2) Playing hover waves (like a chord space or instrument) 
     			  and so we will just continue to the synth wave from wherever we are. So a small clip might be heard
     			  due to the fact that the synth wave amplitude point won't be in sync with the next point.
     			  One way to mitigate this is to write in all the waves and make SamplesToFill be the total amount
     			  of samples that we have passed, but then there would still be a clip since there would be no audio
     			  for a while and then the play_cursor would land back on an amplitude which is likely != 0.
     			  The clip would not be audible if we were close to 0 so probably around 85% chance of clip in this case
     			  given that there is no clip heard from silence to witing 15% of the amplitude of the wave up or down.
	2) Audio (audio thread) latency
		- The play cursor would pause and so we would not write anything. Therefore the video would keep going
		but we would not hear anything AND the play cursor would not move visually. This is fine because if the 
		audio thread pauses, no audio is playing anyways and so no new samples would be added and then we would
		come back wherever we are once the audio thread starts running again.
	*/
	audio_play_cursor : int;
	audio_write_cursor : int;
}

//TODO Where should we put these? Probably best to move out of this global scope
//We could put them in AllData with other resources or also in Persist.
//These are a bit different because we do not use them in-game BUT we still might want to
//clear them with everything later...
//ALSO use an allocator for dynamic libraries and make a free list eventually.
global_dynamic_libraries : [..] DynamicLibrary;
// free_list_dynamic_libraries : [..] DynamicLibrary;
// ResetDynamicLibraries :: () {
// 	array_reset_keeping_memory(*global_dynamic_libraries);
// }
/*We have currently separated this from ExternalUpdateFile where we use this as the platform layer dynamic library
which remains in-game agnostic so we only store void pointer and path names. Then we associate with
*/
DynamicLibrary :: struct {
	//NOTE : These are all based on the input path without extension.
	//input path without extension which we split in LoadExternalUpdateFile and then pass in to CreateExternalUpdateFile
	no_ext_path_name : string; 
	input_path_name : string; //input path with extension
	use_input_path_name : string; //input path with _use and extension for dynamic lib copying
	lock_file_name : string; //input path with _lock.tmp to make sure were done compiling the dynamic lib

	//This is the complete absolute path with the extensions
	abs_path_name : string;

	//TODO Maybe we can JUST store this here and everything else in ExternalUpdateFile
	//so that this is just platform specific later for dynamic libraries
	#if OS == .WINDOWS {
	module_handle : HMODULE; //HMODULE == *void
	} else #if OS == .MACOS {
	//TODO I think this would be the same with linux since that is what is done in bindings generator.
	module_handle : *void;
	}

	last_write_time : Apollo_Time;

	//TODO Can separate these out if we want to allow multiple GetProcAddress eventually to allow 
	//different functions in different places or that have different purposes.
	//NOTE : These are referenced as function types in ExternalUpdateFile which is what we use in game.
	ExternalUpdate_proc_address : *void;
	ExternalUpdatePerFrame_proc_address : *void;
	// ExternalUpdate : Type_ExternalUpdate;

	//My external data specific to this dl. my_shared_data is the same across all dls but this is specific to each dl.
	my_per_dl_data : *void;
}

/*TODO Should this function be in here in the platform layer or somewhere else since it uses 
 many structs from in the game.

 TODO Maybe we should move all this resource loading into its own file/module eventually.
 TODO Can update this now since text_editor seems to handle more lines. Maybe 2-5Mb 
 Also can unbound it since we can load text_files without editing. For example just to compile.
 TODO REMINDER Should we add it to all_text_files in here or is it better not to if we need to add it elsewhere?

 TODO There should be a delete text file function as well. However we have to check that op_spaces also are ok
 with proper reloading or just leaving the file as is if we delete a file.
*/
//TODO Could make a start file size and then double the size if we hit max size when updating the file
//I think we could easily make this 80 or 100 kb to start by default though.
//And then max size could be 500kb but then we could also just have it be 500kb
max_allowable_file_size : int : #run Kilobytes(40);
LoadTextFile :: inline (
	file_name : string,
	all_text_files : *[..] TextFile,
	// all_next_ids : *AllNextIds,
	short_name : string = "",
	for_writing : bool = false,
	//TODO SETTINGS this should be settable in the settings file.
	//size_of(TextAction) == 224 bytes and size_of(TextCursor) == 88 bytes
	//so if we used u32/s32 in TextCursor then 224-88 = 136 bytes
	//100 * 224 bytes = 22400bytes = 22.4kb -> * 2 = 44.8kb (for 200 undos)
	//Seems ok to default to < 50kb but could increase default if we compress TextCursor to 136 bytes
	//100 * 136 = 13.6kb -> * 3 = 40.8. So 300 undos for less memory. Could even have 350-400 default at that point.
	undo_action_count : int = 200)
//TODO Should we return a pointer here so we can set things externally if needed?
-> *TextFile, load_success : bool
{
	//TODO FROM HERE We should double check here that the text_file does not already exist to avoid making duplicates.
	//We should check that the file exists and then check if it's already a text file and then return error
	//in that case and then that is more consistent and we can deal with that error depending on return.
	//We could return an load file success enum instead.

	//TODO Should we just read_entire_file for now and copy it over since we only
	//copy it if its < 50kb for now? copy would be simpler for now and we would
	//have to free the resource_file_string after copying it over.
	resource_file, resource_is_open := file_open(file_name, for_writing);
	if !resource_is_open {
		log_error("Resource file : % could not be opened.\n", file_name);
		return null, false;
	}
	// Make sure we close the resource file after using it
	defer file_close(*resource_file);

	modtime, resource_file_size, read_time_success := file_modtime_and_size(file_name);
	if !read_time_success || resource_file_size >= max_allowable_file_size
	{
		log_error("Could not read modtime or resource file size : % was not read or file is greater than max size % bytes.\n", file_name, max_allowable_file_size);
		file_close(*resource_file);
		return null, false;
	}

	//NOTE : Leaving this here in case we have another issue i forgot about like setting the resource_file_size below.
	// file_string.total_allocated_bytes = max_allowable_file_size;
	// file_string.text_string = alloc_string(file_string.total_allocated_bytes);
	// file_string.text_string.count = resource_file_size;
	// file_string.text_undo_split = "\n";
	cfsd : CreateFileStringData;
	cfsd.total_allocated_bytes = max_allowable_file_size;
	cfsd.undo_action_count = 200;
	cfsd.text_undo_split = "\n";
	file_string : FileString;
	InitFileString(*file_string, cfsd);
	file_string.text_string.count = resource_file_size;
	/*DOC : file_read returns false here if the file size is 0 so we don't read if it's 0 since we already checked the size.
	This way for empty files (ie in tests) we can still read it in if the file exists but it's just empty.
	*/
	if resource_file_size > 0 {
		read_file_success := file_read(resource_file, file_string.text_string.data, resource_file_size);
		if !read_file_success {
			log_error("Resource file : % could not be read.\n", file_name);
			file_close(*resource_file);
			// free(file_string.text_string);
			// free(file_string.text_action_history.data);
			return null, false;
		}
	}

	//TODO How many actions should we add here based on how much memory we actually want to store
	//We don't delete files now but we can also reuse them even if we do and so this is persisted either way.
	// text_file.file_string.text_action_history = NewArray(undo_action_count, TextAction);

	//TODO Maybe we should return this and not add it here so it can be adjusted before adding
	//or not added at all if needed.
	//TODO WE COULD HAVE A compile-time option to not add the text file if needed but then we have to
	//remove the pointer so need to check if that's ok where it's used and ALSO could just have a separate function
	//that returns the pointer and adds it and this one just returns the TextFile without pointer
	text_file : *TextFile = array_add(all_text_files);
	// text_file.id = all_next_ids.NEXT_TEXT_FILE_ID;
	// all_next_ids.NEXT_TEXT_FILE_ID += 1;
	text_file.id = context.ALL_NEXT_IDS.NEXT_TEXT_FILE_ID;
	context.ALL_NEXT_IDS.NEXT_TEXT_FILE_ID += 1;
	text_file.file_type = TextFileType.DEFAULT;
	UpdateTextFileName(file_name, text_file);
	// text_file.absolute_path_name = copy_string(get_absolute_path(file_name));
	// text_file.file_name = copy_string(file_name);
	text_file.file_write_time = modtime;
	//TODO How do we set this if we are pulling in a library? Do we need metadata
	//or can we store it in the game. Probably need some metadata for asm files.
	//Or have a separate file with data for each file. This could be a general resource
	//file that is pulled in at the beginning with a bunch of info that then we don't need
	//to pull in from disk all the time.
	#if 1 {
	if short_name.count == 0 {
		//TODO Need to make this OS dependent probably "/" for unix
		found, left, right := String.split_from_right(text_file.file_name, #char "\\");
		text_file.file_short_name = right;
		found_f, left_f, right_f := String.split_from_right(text_file.file_name, #char "/");
		if right_f.count < right.count text_file.file_short_name = right_f;
	} else {
		text_file.file_short_name = copy_string(short_name);
	}
	}

	text_file.file_string = file_string;
	text_file.is_external_file = true;

	//TODO Why do we copy this, should do it directly but I guess that might change if have a split with an allocator
	//or if we don't store the file_loc in here anyways.
	lines := String.split(text_file.text_string, cast(u8) #char "\n");
	for lines array_add(*text_file.file_loc, it);

	return text_file, true;
}
//TODO Optimize this. I Think we can just get by id as array access
//since we never delete 
GetTextFileById :: inline (
	text_file_id : int,
	all_text_files : [] TextFile) 
-> *TextFile, found_text_file : bool
{
	/*
	found_text_file : bool = text_file_id >= 0 && text_file_id < all_text_files.count;
	text_file : *TextFile;
	if found_text_file {
		text_file = *all_text_files[text_file_id];
	}
	*/
 	text_file, found_text_file := ArrayFindFirstByNameId(all_text_files,
		text_file_id, "id");
 	if !found_text_file {
		log_error("Text file not found id %.\n", text_file_id);
	}
	return text_file, found_text_file;
}
/*DOC : So we can have the checking if file exist done outside
but I like it this way because its more consistent wherever we use it
we know we are always checking the absolute path name and we are getting it
in the same way.
*/
GetOrLoadTextFileByAbsolutePath :: inline (
	file_name : string,
	all_text_files : *[..] TextFile,
	$check_absolute_path : bool = false)
-> *TextFile, found_text_file : bool, loaded_file : bool
{
	#if check_absolute_path {
	/*DOC : We currently only pass in the absolute path so maybe this check is unecessary especially since it
	prints a bunch of messages when it does not have one
	ALSO this is check in LoadTextFile below anyways so maybe this is too much
	ACTUALLY we can just make this optional here since we have GetOrLoadTextFileByFileName below
	so this assumes the absolute file name anyways now.
	TODO We can remove this case if we never use it in any case since we should just check it on the outside now
	*/
	absolute_file_name, absolute_path_success := get_absolute_path(file_name);
	if !absolute_path_success return null, false, false;
	} else {
	absolute_file_name : string = file_name;
	}
	text_file, found_text_file := ArrayFindFirstByNameId(all_text_files.*,
		absolute_file_name, "absolute_path_name");
	loaded_file : bool = false;
	if !found_text_file {
		//NOTE : We already checked that the file existed when we checked the absolute path, so we just load here directly.
		//NOT ANYMORE but I will leave it so if we don't find the file, then the error will be clearer in this function I think.
		text_file, found_text_file = LoadTextFile(absolute_file_name, all_text_files);
		if found_text_file loaded_file = true;
	}
	return text_file, found_text_file, loaded_file;
}
/*DOC : This is used in case we have some file input and the file still exists internally but we deleted the file externally
then we can still load it. It is a convenience for the user in case we accidentally deleted the file externally but still have it
here. Then we can still load the file and not lose the data.

TODO MAYBE we should remove file_name altogether and just keep absolute path and short name for convenience
*/
GetOrLoadTextFileByFileName :: inline (
	file_name : string,
	all_text_files : *[..] TextFile)
-> TextFile, found_text_file : bool, loaded_file : bool
{
	text_file, found_text_file := ArrayFindFirstConstByNameId(all_text_files.*,
		file_name, "file_name");
	loaded_file : bool = false;
	if !found_text_file {
		//Technically this is checked in LoadTextFile but I think it's good to double check here to issues i did not think of
		file_does_exist : bool = file_exists(file_name);
		if file_does_exist {
			text_file, found_text_file = LoadTextFile(file_name, all_text_files);
			if found_text_file loaded_file = true;
		}
	}
	return text_file, found_text_file, loaded_file;
}
UpdateTextFileName :: inline (new_name : string, text_file : *TextFile) {
	//TODO We can remove these if we set some memory for text file strings for each file
	//maybe a Flat_Pool would be fine for that here.
	if text_file.file_name.data != null {
		free(text_file.file_name);
	}
	if text_file.absolute_path_name.data != null {
		free(text_file.absolute_path_name);
	}

	text_file.absolute_path_name = copy_string(get_absolute_path(new_name));
	text_file.file_name = copy_string(new_name);
}

//TODO Could also pass back error message if easier to specify error from caller.
ReloadTextFile :: inline (text_file : *TextFile, log_output : bool = false) -> reload_success : bool
{
	if text_file == null return false;

	modtime, resource_file_size, read_time_success := file_modtime_and_size(text_file.file_name);
	if !(read_time_success && resource_file_size < max_allowable_file_size) 
	{
		if log_output log("Could not read modtime or resource file size for text file : % was not read or file is greater than max size (20kb).\n", text_file.file_name);
		return false;		
	}

	if modtime == text_file.file_write_time {
		if log_output log("No reload needed for file : %.\n", text_file.file_name);
		return false;
	}

	//TODO Should we just read_entire_file for now and copy it over since we only
	//copy it if its < 50kb for now? copy would be simpler for now and we would
	//have to free the resource_file_string after copying it over.
	resource_file, resource_is_open := file_open(text_file.file_name);
	if !resource_is_open {
		if log_output print("Resource file : % could not be opened.\n", text_file.file_name);
		return false;
	}

	// Make sure we close the resource file after using it
	defer file_close(*resource_file);

	read_file_success := file_read(resource_file, text_file.text_string.data, resource_file_size);
	if !read_file_success {
		if log_output print("Resource file : % could not be read.\n", text_file.file_name);
		return false;
	}

	text_file.file_write_time = modtime;
	text_file.text_string.count = resource_file_size;

	array_reset_keeping_memory(*text_file.file_loc);
	lines := String.split(text_file.text_string, cast(u8) #char "\n");
	for lines array_add(*text_file.file_loc, it);

	return true;
}

SaveTextFile :: (text_file : *TextFile) -> success : bool, msg : string {
	update_file_name : bool = false;
	new_file_name : string = text_file.file_name;
	/*DOC: In case the file was deleted externally, we check if it still exists and if it doesn't
	then we ask where the file would like to be saved with the file explorer.
	*/
	if !file_exists(text_file.file_name) {
		fe_input : FileExplorerInput;
		fe_input.initial_dir = ".";
		fe_result := SaveFileWithExplorer(fe_input);
		if fe_result.file_success {
			update_file_name = true;
			new_file_name = fe_result.file_name;
		} else {
			return false, tprint("Cannot save %.\n", fe_result.file_name);
		}
	}

 	save_success : bool = write_entire_file(new_file_name, text_file.file_string.text_string);
 	if save_success {
 		//DOC : We only want to update the file name if the write was successful to keep file system consistent with our text files.
 		//TODO We could check here again that the file exists to avoid any issues but I think it's ok since the save was successful.
		if update_file_name {
			UpdateTextFileName(new_file_name, text_file);
		}
		modtime, resource_file_size, read_time_success := file_modtime_and_size(text_file.file_name);		text_file.file_write_time = modtime;
		text_file.file_string.not_saved_text_edit = false;
		return true, tprint("% saved.\n", text_file.file_name);
 	}

	return false, tprint("% NOT saved.\n", text_file.file_name);
}

FileNameProc :: (info : *File_Visit_Info, user_data : *[..] string)
{
	if !info.is_directory {
		array_add(user_data, copy_temporary_string(info.full_name));
	}
}

GetAllFileNamesInDir :: inline (
	dir_name : string) 
-> [] string, success : bool
{
	file_names : [..] string;
	file_names.allocator = temp;
	success : bool = visit_files(dir_name, false, *file_names, FileNameProc);
	return file_names, success;
}
