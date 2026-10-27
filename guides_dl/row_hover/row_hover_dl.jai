#import "Remap_Context"(VERBOSE=false);
#import "Basic";
#import "Math";
#import "Sort";
#import "thegame_shared_library";
#import "thegame_math";
#import "thegame_audio";
#import "thegame_input";
#import "shared_names";
#import "thegame_renderer_out_data";
#import "thegame_array_poly";
#import "thegame_midi_utils";

#import "jai-midi";

//Run this once to setup MyData and get the midi output data.
#program_export
ExternalRunOnce :: (sld : *SharedLibraryData) {
	Remap_Context();

	if sld.my_per_dl_data == null {
		sld.my_per_dl_data = New(MyData);
	}
}

MyData :: struct {
	all_midi_outs : [] *MIDI_Output;
}

#program_export
ExternalPerFrame :: (sld : *SharedLibraryData) {
	my_data := cast(*MyData) sld.my_per_dl_data;
	//Update this every frame in case we added new midi ports
	if sld.all_midi_outs != null {
		//Could also set this in my_shared_data for reuse in other dls 
		my_data.all_midi_outs = (cast(*[] *MIDI_Output) sld.all_midi_outs).*;
	}
	//Can open a separate midi port here if needed
	// my_data.all_midi_outs = open_output(midi_port_number);

	Remap_Context();
	// my_data := cast(*MyData) sld.my_per_dl_data;
	for sld.frame_hover_entities if it.entity_type == {
	case EntityType.LANE_ROW_WITH_SECTIONS; 
		HoverBaseRow(it, sld);
	case EntityType.OP_LINEAR_ROW;
		HoverOpRow(it, sld);
	}
}

/*This uses the start x for the music points to play the audio and show the text on hovering.
The internal version uses the mouse hovering tuning system.
*/
HoverBaseRow :: inline (row_hover : HoverEntity, sld : *SharedLibraryData) {
	my_data := cast(*MyData) sld.my_per_dl_data;

	//This can be also set in my data and reused
	row_section_rects_array : [..] RowSectionRectsReturn;
	row_section_rects_array.allocator = temp;

	mspace_for_input, found_mspace_for_input := ArrayFindFirstByNameId(sld.all_mspace_data.*,
		sld.render_mspace_id, "mspace_id");
	if !found_mspace_for_input {
		print("mspace id % not found.\n", sld.render_mspace_id);
		return;
	}

	row, found_row := ArrayFindFirstByNameId(mspace_for_input.all_music_lane_rows,
		row_hover.id, "id");
	assert(found_row);

	if !row.external_hover_row {
		//Can also do this with muted or hover text if we just want to update those
		return;
	}
	
	world_mouse : Vector2F = CameraSpaceToWorldSpace(sld.game_input.mouse_cam, mspace_for_input.mspace_cam);
	mouse_x_float : float = WorldXToRowXFloat(world_mouse.x, row, sld.global_rules.memory_unit_width);

	hover_text : string;
	show_hover_text : bool = false;
	section, found_section := GetRowSectionByXRange(mouse_x_float, row.id, mspace_for_input.all_section_to_row);
	if !found_section {
		print("section not found %\n", section);
		return;
	}
	mouse_rsrl : RowSectionRectsData = BuildRSRData(section, row, sld.all_tuning_systems.*, sld.all_space_points.*, sld.global_rules.memory_unit_width);
	ComputeRowSectionRects(mouse_rsrl, row, *row_section_rects_array);
	for rs_ret : row_section_rects_array {
		cam_rect : Rectangle2 = WorldRectToCamRect(rs_ret.world_rect, mspace_for_input.mspace_cam);
   	if IsInRectangle(sld.game_input.mouse_cam, cam_rect) {
			pos_mod : int = rs_ret.point.int_pos.x;
			hover_text = tprint("%,%,%", pos_mod, rs_ret.octave, mouse_rsrl.tuning_system.short_name);
			show_hover_text = true;
			break;
		}
	}

	audio_float_poses : [..] float64;
	audio_float_poses.allocator = temp;
	mp_tuning_systems : [..] TuningSystem;
	mp_tuning_systems.allocator = temp;
	play_row_audio : bool = false;
	hover_chord : [] MusicPoint = GetAllRenderMusicPtPosByPosition(row.total_row_index, mouse_x_float, 
		mspace_for_input, type=MusicPoint,,temp);
	for mp : hover_chord {
		mp_start_rsrl : RowSectionRectsData = mouse_rsrl;
		if !InEpsilonRangeLeft(mp.x_start_float, cast(float64) mouse_rsrl.section.start_x, cast(float64) mouse_rsrl.section.end_x) {
			row_section : SectionToRow = GetRowSectionByXEpsLeft(mp.x_start_float, row.id, mspace_for_input.all_section_to_row);
			mp_start_rsrl = BuildRSRData(row_section, row, sld.all_tuning_systems.*, 
				sld.all_space_points.*, sld.global_rules.memory_unit_width);
		}

		world_rect := MusicPtRowSectionRect(mp, mp_start_rsrl.octave_mult, cast(float) mp.x_start_float, 
			sld.global_rules.memory_unit_width, row, mp_start_rsrl.section_points);
		cam_rect : Rectangle2 = WorldRectToCamRect(world_rect, mspace_for_input.mspace_cam);
		//If in rectangle then we break out when rendering below and only add pts for this rectangle
		//if play row chords is true then we would add each one
		if sld.runtime_settings.play_row_hover_chords || IsInRectangle(sld.game_input.mouse_cam, cam_rect) {
			array_add(*audio_float_poses, mp.music_pt_float);
			array_add(*mp_tuning_systems, mp_start_rsrl.tuning_system);
			play_row_audio = true;
		}

		if sld.runtime_settings.play_row_hover_chords {
			array_add(*row.row_hover_rects, world_rect);
			row.render_row_hovering = true;
			show_hover_text = true;
		} else if IsInRectangle(sld.game_input.mouse_cam, cam_rect) {
			array_add(*row.row_hover_rects, world_rect);
			row.render_row_hovering = true;
			show_hover_text = true;
			break;
		}
	}

	//Sort so that they are consistently used for output
	quick_sort(audio_float_poses, (f1,f2) => f1 - f2);

	//If we don't play row audio then there are no tuning systems to check
	all_same_tunings : bool = true;
	if play_row_audio {
		first_ts_id := mp_tuning_systems[0].id;
		for mp_tuning_systems if it.id != first_ts_id {
			all_same_tunings = false;
			break;
		}
		if row.row_system_type == {
		case .internal_pitch; {
			synth, found_synth := ArrayFindFirstByNameId(sld.all_simple_synths.*, 
				row.system_id, "synth_id");
			if found_synth {
				//TODO Add a pitch_zero_freq for each row
				ref_freq : float64 = sld.runtime_settings.default_zero_pitch_frequency;
				// if circle.use_set_zero_freq ref_freq = circle.pitch_zero_freq;
				if row.extra_hover_synth.simple_waves.count != audio_float_poses.count {
					row.extra_hover_synth = synth.*;
					array_reset_keeping_memory(*row.extra_hover_synth.simple_waves);
					for 0..audio_float_poses.count-1 {
						AddSimpleWaveFromFrequency(0, *row.extra_hover_synth, sld.audio_data);
					}
				}
				if all_same_tunings {
					ts : TuningSystem = mp_tuning_systems[0];
					tuning_pitches := ArrayFindAllVarName(sld.all_tuning_pitches.*, ts.id, "tuning_system_id", temp);
					for audio_float_poses {
						frequency := MusicPtToFrequency(it, ts, tuning_pitches, ref_freq);
						UpdateWaveFrequency(frequency, *row.extra_hover_synth.simple_waves[it_index], sld.audio_data.*);
					}									
				} else {
					for audio_float_poses {
						ts : TuningSystem = mp_tuning_systems[it_index];
						tuning_pitches := ArrayFindAllVarName(sld.all_tuning_pitches.*, mp_tuning_systems[it_index].id, "tuning_system_id", temp);
						frequency := MusicPtToFrequency(it, ts, tuning_pitches, ref_freq);
						UpdateWaveFrequency(frequency, *row.extra_hover_synth.simple_waves[it_index], sld.audio_data.*);
					}
				}
				GenerateSimpleSynthSamples(*row.extra_hover_synth, sld.audio_data.float_buffer, sld.audio_data);
			} 
			else {
				//Maybe this is a helpful log message, maybe not and we remove it.
				print("No synth found for row id % with synth id %.\n", row.id, row.system_id);
			}
		}
		case .midi_pitch; {
			midi_out, found_midi_out := GetMidiOut(row.row_midi_data.midi_port, my_data.all_midi_outs);
			if found_midi_out {
	     		m_channel : u8 = row.row_midi_data.midi_channel;
				if IsInputMapPress(.MIDI_PRESS_NOTE_ON, .DOWN_THIS_FRAME, sld.game_input) {
					velocity : u8 = row.row_midi_data.midi_velocity;
					for audio_float_poses {
						note := (cast(u8) round_to_int(it)) + row.row_midi_data.midi_zero_note;
						note_on : MIDI_Message = create_midi_message(.Note_On, note, velocity, m_channel);
		        		send_midi_message(midi_out, note_on);
					}
	        	} else if IsInputMapPress(.MIDI_PRESS_NOTE_OFF, .DOWN_THIS_FRAME, sld.game_input) {
					for audio_float_poses {
						note := (cast(u8) round_to_int(it)) + row.row_midi_data.midi_zero_note;
						note_off : MIDI_Message = create_midi_message(.Note_Off, note, channel = m_channel);
		        		send_midi_message(midi_out, note_off);
					}
				}
			} else {
				print("Midi output port number % not found for row %.", row.row_midi_data.midi_port, row);
			}
		}
		}
	}
	if show_hover_text {
		if play_row_audio {
			if audio_float_poses.count == 1 || !all_same_tunings {
				for audio_float_poses {
					hover_text = tprint("%-%", it, mp_tuning_systems[it_index].short_name);
					text_y : float = it_index*sld.text_editor_data.char_height/sld.renderer_data.current_pixels_per_square;
					hover_cam := sld.game_input.mouse_cam + Vector2F.{1,text_y};
					hover_rect : Rectangle2 = TextBackgroundRect2D(hover_text, hover_cam, sld.text_editor_data, sld.renderer_data.current_pixels_per_square);
					PushRectangle(hover_rect, GREY_BLACKER_V, sld.renderer_data.base_render_group, order = MAX_ROW_RENDER_ORDER+2);
					PushText(hover_cam, hover_text, GREY_DARK_V, sld.renderer_data.base_render_group, order = MAX_ROW_RENDER_ORDER+3);
				}
			} else if all_same_tunings {
				sb : String_Builder;
				sb.allocator = temp;
				append(*sb, "[");
				for audio_float_poses {
					print_to_builder(*sb, "%", it);
					if it_index < audio_float_poses.count-1 append(*sb, ",");
				}
				append(*sb, "]");
				append(*sb, mp_tuning_systems[0].short_name);
				hover_text = builder_to_string(*sb,,temp);
				hover_cam := sld.game_input.mouse_cam + Vector2F.{1,0};
				hover_rect : Rectangle2 = TextBackgroundRect2D(hover_text, hover_cam, sld.text_editor_data, sld.renderer_data.current_pixels_per_square);
				PushRectangle(hover_rect, GREY_BLACKER_V, sld.renderer_data.base_render_group, order = MAX_ROW_RENDER_ORDER+2);
				PushText(hover_cam, hover_text, GREY_DARK_V, sld.renderer_data.base_render_group, order = MAX_ROW_RENDER_ORDER+3);
			}
		}
		else {
			hover_cam := sld.game_input.mouse_cam + Vector2F.{1,0};
			hover_rect : Rectangle2 = TextBackgroundRect2D(hover_text, hover_cam, sld.text_editor_data, sld.renderer_data.current_pixels_per_square);
			PushRectangle(hover_rect, GREY_BLACKER_V, sld.renderer_data.base_render_group, order = MAX_ROW_RENDER_ORDER+2);
			PushText(hover_cam, hover_text, GREY_DARK_V, sld.renderer_data.base_render_group, order = MAX_ROW_RENDER_ORDER+3);						
		}
	}		
}

/*This uses the start x for the music points to play the audio and show the text on hovering.
The internal version uses the mouse hovering tuning system.
*/
HoverOpRow :: inline (op_row_hover : HoverEntity, sld : *SharedLibraryData) {
	my_data := cast(*MyData) sld.my_per_dl_data;

	//This can be also set in my data and reused
	row_section_rects_array : [..] RowSectionRectsReturn;
	row_section_rects_array.allocator = temp;

	mspace_for_input, found_mspace_for_input := ArrayFindFirstByNameId(sld.all_mspace_data.*,
		sld.render_mspace_id, "mspace_id");
	if !found_mspace_for_input {
		print("mspace id % not found.\n", sld.render_mspace_id);
		return;
	}

	found_hover_op_space : bool = false;
	hover_op_space : HoverEntity;
	for sld.frame_hover_entities if it.entity_type == .OP_SPACE {
		found_hover_op_space = true;
		hover_op_space = it;
		break;
	}
	if !found_hover_op_space return;

	op_spec_data, found_op_spec_data := ArrayFindFirstByNameId(sld.all_op_space_spec_data.*,
		hover_op_space.id, "op_space_id");
	assert(found_op_spec_data);

	op_row, found_op_row := ArrayFindFirstByNameId(op_spec_data.all_op_linear_rows,
		op_row_hover.id, "id");
	assert(found_op_row);

	if !op_row.external_hover_row {
		//Can also do this with muted or hover text if we just want to update those
		return;
	}

	//We can't get hover but maybe we put an mspace we did not create yet...
	mspace_data, found_mspace := ArrayFindFirstByNameId(sld.all_mspace_data.*, 
		op_row.op_ref_mspace_id, "mspace_id");
	if !found_mspace {
		print("Op linear op_row % has op_ref_mspace_id=% which does not exist.\n", op_row.id, op_row.op_ref_mspace_id);
		return;
	}

	op_space, found_op_space :=
		ArrayFindFirstByNameId(sld.all_open_op_spaces, op_spec_data.op_space_id, "id");
	assert(found_op_space);

	world_mouse : Vector2F = CameraSpaceToWorldSpace(sld.game_input.mouse_cam, mspace_for_input.mspace_cam);
	op_mouse : Vector2F = WorldSpaceToOpSpace(world_mouse, op_space, op_space.op_2D_cam.world_pos);
	mouse_x_float : float = WorldXToRowXFloat(op_mouse.x, op_row, op_row.x_point_width);
	// if perm.all_data.runtime_settings.show_row_hover {
	row_section_check_id : int;
	current_section_to_row : [] SectionToRow;
	if op_row.op_row_type == {
	case OpRowType.MULTI_SECTION; {
		row_section_check_id = op_row.id;
		current_section_to_row = op_spec_data.all_op_section_to_row;
	}
	case OpRowType.COPY_MUSIC_ROW; {
		//TODO Could also allow a specific sections to be copied between a given x_start and x_end
		row_section_check_id = op_row.op_ref_row_id;
		current_section_to_row = mspace_data.all_section_to_row;
	} 
	}
	
	hover_text : string;
	show_hover_text : bool = false;
	section, found_section := GetRowSectionByXRange(mouse_x_float, row_section_check_id, current_section_to_row);
	if !found_section {
		print("section not found %\n", section);
		return;
	}
	mouse_rsrl : RowSectionRectsData = BuildRSRData(section, op_row, sld.all_tuning_systems.*, sld.all_space_points.*, op_row.x_point_width);
	ComputeRowSectionRects(mouse_rsrl, op_row, *row_section_rects_array);
	for rs_ret : row_section_rects_array {
		cam_rect : Rectangle2 = OpRectToCamRect(rs_ret.world_rect, op_space, op_space.op_2D_cam.world_pos, mspace_for_input.mspace_cam);
   	if IsInRectangle(sld.game_input.mouse_cam, cam_rect) {
			pos_mod : int = rs_ret.point.int_pos.x;
			hover_text = tprint("%,%,%", pos_mod, rs_ret.octave, mouse_rsrl.tuning_system.short_name);
			show_hover_text = true;
			break;
		}
	}

	audio_float_poses : [..] float64;
	audio_float_poses.allocator = temp;
	mp_tuning_systems : [..] TuningSystem;
	mp_tuning_systems.allocator = temp;
	play_row_audio : bool = false;

	base_row, found_base_row := ArrayFindFirstByNameId(mspace_data.all_music_lane_rows,
		op_row.op_ref_row_id, "id");
	if found_base_row {
		total_x_float : float = mouse_x_float + op_row.op_ref_start_x;
		hover_chord : [] MusicPoint = GetAllRenderMusicPtPosByPosition(base_row.total_row_index, total_x_float, 
			mspace_data, type=MusicPoint,,temp);

		for mp : hover_chord {
			mp_start_rsrl : RowSectionRectsData = mouse_rsrl;
			x_offset := cast(float) (mp.x_start_float - op_row.op_ref_start_x);
			if !InEpsilonRangeLeft(x_offset, cast(float64) mouse_rsrl.section.start_x, cast(float64) mouse_rsrl.section.end_x) {
				row_section : SectionToRow = GetRowSectionByXEpsLeft(x_offset, row_section_check_id, current_section_to_row);
				mp_start_rsrl = BuildRSRData(row_section, op_row, sld.all_tuning_systems.*, 
					sld.all_space_points.*, op_row.x_point_width);
			}

			op_rect := MusicPtRowSectionRect(mp, mp_start_rsrl.octave_mult, x_offset, 
				op_row.x_point_width, op_row, mp_start_rsrl.section_points);
			cam_rect : Rectangle2 = OpRectToCamRect(op_rect, op_space, op_space.op_2D_cam.world_pos, mspace_for_input.mspace_cam);
			//If in rectangle then we break out when rendering below and only add pts for this rectangle
			//if play row chords is true then we would add each one
			if sld.runtime_settings.play_row_hover_chords || IsInRectangle(sld.game_input.mouse_cam, cam_rect) {
				array_add(*audio_float_poses, mp.music_pt_float);
				array_add(*mp_tuning_systems, mp_start_rsrl.tuning_system);
				play_row_audio = true;
			}

			if sld.runtime_settings.play_row_hover_chords {
				array_add(*op_row.row_hover_rects, op_rect);
				op_row.render_row_hovering = true;
				show_hover_text = true;
			} else if IsInRectangle(sld.game_input.mouse_cam, cam_rect) {
				array_add(*op_row.row_hover_rects, op_rect);
				op_row.render_row_hovering = true;
				show_hover_text = true;
				break;
			}
		}
	}

	//Sort so that they are consistently used for output
	quick_sort(audio_float_poses, (f1,f2) => f1 - f2);

	//If we don't play row audio then there are no tuning systems to check
	all_same_tunings : bool = true;
	if play_row_audio {
		first_ts_id := mp_tuning_systems[0].id;
		for mp_tuning_systems if it.id != first_ts_id {
			all_same_tunings = false;
			break;
		}
		if base_row.row_system_type == {
		case .internal_pitch; {
			synth, found_synth := ArrayFindFirstByNameId(sld.all_simple_synths.*, 
				base_row.system_id, "synth_id");
			if found_synth {
				//TODO Add a pitch_zero_freq for each row
				ref_freq : float64 = sld.runtime_settings.default_zero_pitch_frequency;
				// if circle.use_set_zero_freq ref_freq = circle.pitch_zero_freq;
				if op_row.extra_hover_synth.simple_waves.count != audio_float_poses.count {
					op_row.extra_hover_synth = synth.*;
					array_reset_keeping_memory(*op_row.extra_hover_synth.simple_waves);
					for 0..audio_float_poses.count-1 {
						AddSimpleWaveFromFrequency(0, *op_row.extra_hover_synth, sld.audio_data);
					}
				}
				if all_same_tunings {
					ts : TuningSystem = mp_tuning_systems[0];
					tuning_pitches := ArrayFindAllVarName(sld.all_tuning_pitches.*, ts.id, "tuning_system_id", temp);
					for audio_float_poses {
						frequency := MusicPtToFrequency(it, ts, tuning_pitches, ref_freq);
						UpdateWaveFrequency(frequency, *op_row.extra_hover_synth.simple_waves[it_index], sld.audio_data.*);
					}									
				} else {
					for audio_float_poses {
						ts : TuningSystem = mp_tuning_systems[it_index];
						tuning_pitches := ArrayFindAllVarName(sld.all_tuning_pitches.*, mp_tuning_systems[it_index].id, "tuning_system_id", temp);
						frequency := MusicPtToFrequency(it, ts, tuning_pitches, ref_freq);
						UpdateWaveFrequency(frequency, *op_row.extra_hover_synth.simple_waves[it_index], sld.audio_data.*);
					}
				}
				GenerateSimpleSynthSamples(*op_row.extra_hover_synth, sld.audio_data.float_buffer, sld.audio_data);
			} 
			else {
				//Maybe this is a helpful log message, maybe not and we remove it.
				print("No synth found for row id % with synth id %.\n", base_row.id, base_row.system_id);
			}
		}
		case .midi_pitch; {
			midi_out, found_midi_out := GetMidiOut(base_row.row_midi_data.midi_port, my_data.all_midi_outs);
			if found_midi_out {
		  		m_channel : u8 = base_row.row_midi_data.midi_channel;
				if IsInputMapPress(.MIDI_PRESS_NOTE_ON, .DOWN_THIS_FRAME, sld.game_input) {
					velocity : u8 = base_row.row_midi_data.midi_velocity;
					for audio_float_poses {
						note := (cast(u8) round_to_int(it)) + base_row.row_midi_data.midi_zero_note;
						note_on : MIDI_Message = create_midi_message(.Note_On, note, velocity, m_channel);
		        		send_midi_message(midi_out, note_on);
					}
		     	} else if IsInputMapPress(.MIDI_PRESS_NOTE_OFF, .DOWN_THIS_FRAME, sld.game_input) {
					for audio_float_poses {
						note := (cast(u8) round_to_int(it)) + base_row.row_midi_data.midi_zero_note;
						note_off : MIDI_Message = create_midi_message(.Note_Off, note, channel = m_channel);
		        		send_midi_message(midi_out, note_off);
					}
				}
			} else {
				print("Midi output port number % not found for row %.", base_row.row_midi_data.midi_port, row);
			}
		}
		}
	}
	if show_hover_text {
		if play_row_audio {
			if audio_float_poses.count == 1 || !all_same_tunings {
				for audio_float_poses {
					hover_text = tprint("%-%", it, mp_tuning_systems[it_index].short_name);
					text_y : float = it_index*sld.text_editor_data.char_height/sld.renderer_data.current_pixels_per_square;
					hover_cam := sld.game_input.mouse_cam + Vector2F.{1,text_y};
					hover_rect : Rectangle2 = TextBackgroundRect2D(hover_text, hover_cam, sld.text_editor_data, sld.renderer_data.current_pixels_per_square);
					PushRectangle(hover_rect, GREY_BLACKER_V, op_space.render_groups.post_render_group, order = 100);
					PushText(hover_cam, hover_text, GREY_DARK_V, op_space.render_groups.post_render_group, order = 101);
				}
			} else if all_same_tunings {
				sb : String_Builder;
				sb.allocator = temp;
				append(*sb, "[");
				for audio_float_poses {
					print_to_builder(*sb, "%", it);
					if it_index < audio_float_poses.count-1 append(*sb, ",");
				}
				append(*sb, "]");
				append(*sb, mp_tuning_systems[0].short_name);
				hover_text = builder_to_string(*sb,,temp);
				hover_cam := sld.game_input.mouse_cam + Vector2F.{1,0};
				hover_rect : Rectangle2 = TextBackgroundRect2D(hover_text, hover_cam, sld.text_editor_data, sld.renderer_data.current_pixels_per_square);
				PushRectangle(hover_rect, GREY_BLACKER_V, op_space.render_groups.post_render_group, order = 100);
				PushText(hover_cam, hover_text, GREY_DARK_V, op_space.render_groups.post_render_group, order = 101);
			}
		}
		else {
			hover_cam := sld.game_input.mouse_cam + Vector2F.{1,0};
			hover_rect : Rectangle2 = TextBackgroundRect2D(hover_text, hover_cam, sld.text_editor_data, sld.renderer_data.current_pixels_per_square);
			PushRectangle(hover_rect, GREY_BLACKER_V, op_space.render_groups.post_render_group, order = 100);
			PushText(hover_cam, hover_text, GREY_DARK_V, op_space.render_groups.post_render_group, order = 101);						
		}
	}		
}
