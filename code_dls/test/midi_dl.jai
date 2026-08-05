#import "Basic";
#import "thegame_shared_library";
#import "thegame_audio";
#import "thegame_input";
#import "thegame_array_poly";

#import "jai-midi";

m_out : *MIDI_Output;
m_in : *MIDI_Input;

sld : SharedLibraryData;

#program_export
ExternalUpdate :: (shared_lib : *SharedLibraryData) {
	#if OS == .WINDOWS {
	midi_port_number : int = 1;
	} else {
	midi_port_number : int = 0;
	}
	//NOTE : If we are using a midi instrument, then we just need to hook up the midi in below to the midi out from the midi instrument.
	m_out = open_output(midi_port_number);
	//NOTE : We cannot set shared_lib directly since it is rebuilt everytime we call this so the pointer will change on the stack.
	//We could fix that by setting shared lib in all data and then separting out audio data and render data.
	//So we set it globally in here and pass it in. The pointers should not change in general.
	//If we have an issue then we will move the data values together in all data to match it up and keep it consistent.
	sld = shared_lib.*;
	m_in = open_input(0, midi_input_callback, *sld);

	gocss : GetOrCreateSimpleSynthData;
	gocss.synth_name = "s0";
	synth : *SimpleSynth = GetOrCreateSimpleSynth(gocss, shared_lib.all_simple_synths, shared_lib.free_simple_synth_pool);
	update_synth : UpdateSimpleSynthData;
	update_synth.synth_id = synth.synth_id;
	update_synth.update_wave_type = true;
	update_synth.wave_type = OscWaveType.SINE;
	//Volume is between 0-1 and is set for each neume
	//so 0.1 for 3 values will be 0.3 overall
	//anything above 1 will be clipped and likely cause audible distortion
	update_synth.update_volume = true;
	update_synth.volume = 0.1;
	UpdateSimpleSynth(synth, update_synth);

	crd : CreateRowData;
	crd.octave_height = 12;
	crd.row_height = 12;
	crd.row_system_type = RowSystemType.internal_pitch;
	//TODO Add a synth at set it here like this
	crd.row_system_id = synth.synth_id;
	row_sections : [1] RowSectionData;
	row_sections[0].tuning_system_id = shared_lib.all_tuning_systems.*[0].id;
	row_sections[0].x_length = 12;
	crd.row_section_data = row_sections;
	// crd.row_system_type = RowSystemType.midi_pitch;
	// crd.row_midi_data.midi_channel = cast(u8) asm_data.row_midi_data.midi_channel;
	// crd.row_midi_data.midi_velocity = cast(u8) asm_data.row_midi_data.midi_velocity;
	// crd.row_midi_data.midi_control_change = cast(u8) asm_data.row_midi_data.midi_control_change;
	CreateMusicRow(crd,
		shared_lib.all_mspace_data.*,
		shared_lib.global_rules,
		shared_lib.all_tuning_systems.*,
		shared_lib.all_tuning_pitches.*,
		shared_lib.all_linear_to_tuning_system,
		shared_lib.all_linear_pitch_spaces,
		shared_lib.all_space_points);

	// CreateMusicPtInMemory(0, 0, 0, 1, *shared_lib.all_mspace_data.*[0].all_music_pts);

	//This is an example of how you would create your own synth and put audio data directly into the audio buffer.
	//The simple synth is a synth that has several different oscillator waves and a ASR volume envelope.
	my_synth.wave_type = OscWaveType.SINE;
	my_synth.envelope = MakeVolumeEnvelope();
	AddSimpleWaveFromFrequency(0, *my_synth, shared_lib.audio_data);
	// for 0..1 AddSimpleWaveFromFrequency(0, *my_synth, shared_lib.audio_data);
}

FIXED_OCTAVE : u8 : 12*5;
//TODO FROM HERE add guides for dl and then maybe an example with generalized audio/synth and also generalized rendering
#program_export
ExternalUpdatePerFrame :: (sld : *SharedLibraryData) {
	// if sld.my_per_dl_data == null {
	// 	sld.my_per_dl_data = New(MyExternData);
	// }
	// my_data := cast(*MyExternData) sld.my_per_dl_data;
	channel : u8 = 0;
	velocity : u8 = 100;
	note : u8;
	pressed_note : bool = false;
	lifted_note : bool = false;
 	if IsKeyboardPress(#char "Q", .{ctrl_pressed=true}, .DOWN_THIS_FRAME, sld.game_input) {
		pressed_note = true;
		note = cast(u8) 0 + FIXED_OCTAVE;
  	} else if IsKeyboardPress(#char "Q", .{ctrl_pressed=true}, .UP_THIS_FRAME, sld.game_input) {
		lifted_note = true;
		note = cast(u8) 0 + FIXED_OCTAVE;
  	} else if IsKeyboardPress(#char "W", .{ctrl_pressed=true}, .DOWN_THIS_FRAME, sld.game_input) { 
		pressed_note = true;
		note = cast(u8) 1 + FIXED_OCTAVE;
  	} else if IsKeyboardPress(#char "W", .{ctrl_pressed=true}, .UP_THIS_FRAME, sld.game_input) { 
		lifted_note = true;
		note = cast(u8) 1 + FIXED_OCTAVE;
  	}
  	if pressed_note {
		note_on : MIDI_Message = create_midi_message(.Note_On, note, velocity, channel);
		send_midi_message(m_out, note_on);
	}
  	if lifted_note {
		note_off : MIDI_Message = create_midi_message(.Note_Off, note, velocity, channel);
		send_midi_message(m_out, note_off);
	}

	//If we want a non-midi instrument, then we just put the synth samples with the key presses above
	//or any other input or function that we want the synth samples to be generated with.
	if note_is_on {
		//These functions are examples of how one would create their own synths and then generate samples per frame here.
		// UpdateWaveFrequency(frequency, *my_synth.simple_waves[0], sld.audio_data);
		GenerateSimpleSynthSamples(*my_synth, sld.audio_data.float_buffer, sld.audio_data);
	}
}

USE_INTERNAL_AUDIO : bool : false;

//These could be stored in my_per_dl_data or my_shared_data if needed.
my_synth : SimpleSynth;
pos : int = 0;
note_is_on : bool = false;
previous_timestamp : Apollo_Time;
midi_input_callback :: (input: *MIDI_Input, message: MIDI_Message, timestamp: Apollo_Time, user_data: *void) {
	print_message_info(message, timestamp);
	#if 0 {
	print("time_delta = %\n", timestamp - previous_timestamp);
	previous_timestamp = timestamp;
	}

	my_sld := cast(*SharedLibraryData) user_data;

	//If we allow multiple notes at once then we would have to check the specific midi note values with the note on and off messages.
	if message.status == MIDI_Status.Note_On {
		print("note=%\n", message.note_info.note);
		//This will add the note visually if needed. Can comment it out if we just want the synth sounds.
		CreateMusicPtInMemory(cast(int) message.note_info.note - FIXED_OCTAVE, 0, pos, pos+1, *my_sld.all_mspace_data.*[0].all_music_pts);

		//I am not a huge fan of these array polymorph functions but it simplifies things nicely. 
		//Better to use a loop when possible.
		// tuning_system, found_tuning_system := ArrayFindFirstConstByNameId(tuning_system_id, "et12", "short_name");
		// if !found_tuning_system return; //early out if we did not find the tuning system since the rest will not work
		tuning_system_id : int = my_sld.all_mspace_data.*[0].all_section_to_row[0].tuning_system_id;
		tuning_system, found_tuning_system := ArrayFindFirstConstByNameId(my_sld.all_tuning_systems.*, tuning_system_id, "id");
		if !found_tuning_system return; //early out if we did not find the tuning system since the rest will not work
		tuning_pitches : [] TuningPitch = ArrayFindAllVarName(my_sld.all_tuning_pitches.*, tuning_system.id, "tuning_system_id",, temp);
		music_pt := cast(float64) ((cast(int)message.note_info.note) - FIXED_OCTAVE);
		frequency : float = MusicPtToFrequency(music_pt, tuning_system, tuning_pitches);
		UpdateWaveFrequency(frequency, *my_synth.simple_waves[0], my_sld.audio_data.*);
		//Then we use this flag to generate the sample in ExternalUpdatePerFrame
		note_is_on = true;

		pos += 1;
	}
	if message.status == MIDI_Status.Note_Off {
		note_is_on = false;
	}
}
