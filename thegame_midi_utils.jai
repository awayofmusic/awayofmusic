#import "Basic";
#import "thegame_input";
#import "thegame_shared_library";
#import "thegame_math";
#import "jai-midi";

GetMidiOut :: inline (
	port_number : int, 
	all_midi_outs : [] *MIDI_Output) 
-> *MIDI_Output, found : bool 
{
	for all_midi_outs if it.index == port_number {
		return it, true;
	}
	return null, false;
}
PressMidiNote :: inline (
	audio_float_poses : [] float64,
	midi_data : RowMidiData,
	all_midi_outs : [] *MIDI_Output,
	game_input : GameInput)
{
	midi_out, found_midi_out := GetMidiOut(midi_data.midi_port, all_midi_outs);
	if !found_midi_out {
		print("Midi out port number % not found.\n", midi_data.midi_port);
		return;
	}

	m_channel : u8 = midi_data.midi_channel;
	if IsInputMapPress(.MIDI_PRESS_NOTE_ON, .DOWN_THIS_FRAME, game_input) {
		velocity : u8 = midi_data.midi_velocity;
		for audio_float_poses {
			note := (cast(u8) round_to_int(it)) + midi_data.midi_zero_note;
			note_on : MIDI_Message = create_midi_message(.Note_On, note, velocity, m_channel);
     		send_midi_message(midi_out, note_on);
		}
  	} else if IsInputMapPress(.MIDI_PRESS_NOTE_OFF, .DOWN_THIS_FRAME, game_input) {
		for audio_float_poses {
			note := (cast(u8) round_to_int(it)) + midi_data.midi_zero_note;
			note_off : MIDI_Message = create_midi_message(.Note_Off, note, channel = m_channel);
     		send_midi_message(midi_out, note_off);
		}
	}
}