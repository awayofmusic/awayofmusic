#import "Remap_Context"(VERBOSE=false);
#import "Basic";
#import "shared_names";
#import "thegame_shared_library";
#import "thegame_math";
#import "thegame_audio";
#import "thegame_array_poly";
#import "thegame_renderer_out_data";

#program_export
ExternalRunOnce :: (sld : *SharedLibraryData) {
	Remap_Context();

	/*To open this op space from the internal terminal run :
	open_op s2d
	*/
	op_space_name : string = "s2d";
	op_space, found_op_space := FindOpSpacePointerOpenOrClosed(op_space_name, 
		sld.all_open_op_spaces, sld.all_closed_op_spaces.*);
	/*IMPORTANT : When a dl is loaded, the operating system allocates addresses in memory
	specifically for that dl. When it is unloaded, that memory is unallocated.
	Reloading a dl is an unload and a load. Any new allocations made in this dl will be lost on unload.
	Op spaces have an allocator for convenience and efficiency. 
	Data like arrays and strings can use the allocator so that that allocated data is reset whenever we clear the op space.
	Therefore op spaces (or anything that allocates new memory) needs to persists. 
	This can be done by creating the data/allocator somewhere that will not be reloaded.
	Generally in the main program or in another dl that will not be reloaded like the startup_dl.
	This can be done in several ways :
	- use the internal programming language to create the op space (or other data) before this dl runs
	- use an internal terminal command like "create_op" to create the op space (or other data) before this dl runs
	A command can be run from a dl as well using all_terminal_events.
	- create the data in a separate dl which will not be unloaded or reloaded like the startup_dl

	Resizable arrays in SharedLibraryData are not affected by this as their allocators
	are set to the main context allocator in InitAllData.
	*/
	if !found_op_space {
		cosd : CreateOpSpaceData;
		cosd.op_space_name = op_space_name;
		cosd.op_space_external_type = OpSpaceExternalType.space_2d;
		op_space = CreateClosedOpSpace(cosd, 
			sld.all_closed_op_spaces, 
			sld.all_op_space_spec_data, 
			sld.all_op_spec_data_3D);
	}

	clear_data : ClearOpSpaceData;
	clear_data.op_space_id = op_space.id;
	ClearOpSpace(clear_data,
		sld.all_open_op_spaces,
		sld.all_closed_op_spaces.*,
		sld.all_op_space_spec_data.*,
		sld.all_op_spec_data_3D.*);

	//Can check for missing spec data here if needed.
	op_spec_data : *OpSpaceSpecData;
	for * sld.all_op_space_spec_data.* if it.op_space_id == op_space.id {
		op_spec_data = it;
		break;
	}

	c_data : CreateCircleSpaceData;
	c_data.radius = 9.0;
	c_data.world_center = Vector2F.{0,0};
	c_data.rotate_theta = 1.570796;
	c_data.point_dim = Vector2F.{0.6,0.6};
	c_data.is_clockwise = true;
	c_data.repeating_interval_ratio = 2.0;
	c_data.tuning_system_id = 0; //0 defaults to et12
	c_data.circle_audio = CircleAudioType.DISCRETE;
	// c_data.circle_audio = CircleAudioType.CONTINUOUS;
	// c_data.circle_audio = CircleAudioType.MIDI;
	// c_data.midi_data = .{
	// 	midi_channel = 0,
	// 	midi_velocity = 100,
	// 	midi_zero_note = 12*4,
	// };
	//setting this to true with ExternalPerFrame below will hover circle chord instead of individual values
	c_data.external_hover = false;
	c_data.show_text = false;
	c_data.inner_circle_mute = 0.;
	circle : *CircleSpace = CreateCircleInOpSpace(c_data, 
		op_spec_data, sld.all_tuning_systems.*, sld.all_tuning_pitches.*);


	map_points := float64.[0,4.5,7];
	last_pt : float64 = peek(map_points);
	previous_op_pos : Vector2F = MusicPtToCirclePos(last_pt, circle);
	for map_points {
		op_pos : Vector2F = MusicPtToCirclePos(it, circle);

		rect : *SpaceRect = array_add(*op_spec_data.ass.all_space_rects);
		rect.shape_id = context.ALL_NEXT_IDS.NEXT_SHAPE_ID;
		context.ALL_NEXT_IDS.NEXT_SHAPE_ID += 1;
		rect.op_space_id = op_space.id;
		rect.dspace_id = circle.dspace_id;
		rect.dspace_shape_group = 2;
		rect.render_order = circle.base_render_order+2;
		rect.color = FGREEN_V;
		rect.rect = RectCenterDim(op_pos, circle.point_dim);
		rect.pitch_set = NewArray(1, float64,,op_spec_data.spec_2D_alloc);
		rect.pitch_set[0] = it;
		rect.shape_text = sprint("%", it,,op_spec_data.spec_2D_alloc);
		
		line : Quad2F = MakeQuadLine(previous_op_pos, op_pos, 0.05);
		quad : *SpaceQuad = array_add(*op_spec_data.ass.all_space_quads);
		quad.op_space_id = op_space.id;
		quad.dspace_id = circle.dspace_id;
		// quad.dspace_shape_group = 2;
		quad.render_order = circle.base_render_order+1;
		quad.color = GREY_DARKER_V;
		quad.quad = line;


		previous_op_pos = op_pos;
	}
}

/*Hovering a circle with external_hover set to false and this function running per frame
will hover the circle as a chord instead of individual note values.
Other 2d space would use similar logic and can be found in 
thegame_base at the frame_hover_entities loop.

For row hovering code :
guides_dl/row_hover/row_hover_dl.jai
*/
#program_export
ExternalPerFrame :: (sld : *SharedLibraryData) {
	Remap_Context();
	// my_data := cast(*MyData) sld.my_per_dl_data;
	for hover_entity : sld.frame_hover_entities if hover_entity.entity_type == {
	case EntityType.OP_CIRCLE_DSPACE; {
		found_hover_op_space : bool = false;
		hover_op_space : HoverEntity;
		for sld.frame_hover_entities if it.entity_type == .OP_SPACE {
			found_hover_op_space = true;
			hover_op_space = it;
			break;
		}
		if !found_hover_op_space {
			print("hover op space not found\n");
			return;
		}

		op_space, found_op_space :=
			ArrayFindFirstByNameId(sld.all_open_op_spaces, hover_op_space.id, "id");
		assert(found_op_space);

		op_spec_data, found_op_spec_data := ArrayFindFirstByNameId(sld.all_op_space_spec_data.*,
			hover_op_space.id, "op_space_id");
		assert(found_op_spec_data);		

		circle : *CircleSpace = ArrayFindFirstByNameId(op_spec_data.all_op_circle_spaces, 
			hover_entity.id, "dspace_id");

		mspace_for_input, found_mspace_for_input := ArrayFindFirstByNameId(sld.all_mspace_data.*,
			sld.render_mspace_id, "mspace_id");
		if !found_mspace_for_input {
			print("mspace id % not found.\n", sld.render_mspace_id);
			return;
		}

		audio_float_poses : [..] float64;
		audio_float_poses.allocator = temp;
		for op_spec_data.ass.all_space_rects if it.dspace_id == circle.dspace_id && it.dspace_shape_group == 2 {
			if it.pitch_set.count > 0 {
				cam_rect := OpRectToCamRect(it.rect, op_space, op_space.op_2D_cam.world_pos, mspace_for_input.mspace_cam);
				PushRectangle(cam_rect, LBLUE_V, op_space.render_groups.scissor_group, order = it.render_order+2);

				text_pos : Vector2F = GetCenter(cam_rect);
				text_pos.x -= 0.5 * it.shape_text.count * sld.text_editor_data.code_font_1_char_width_world; 
				text_pos.y += sld.text_editor_data.char_height / sld.renderer_data.current_pixels_per_square; 
				PushText(text_pos, it.shape_text, WHITE_V, op_space.render_groups.scissor_group, 10003);

				array_add(*audio_float_poses, it.pitch_set[0]);
			}
		}

		if audio_float_poses.count > 0 {
			if audio_float_poses.count != circle.synth.simple_waves.count {
				array_reset_keeping_memory(*circle.synth.simple_waves);
				for 0..audio_float_poses.count-1 {
					AddSimpleWaveFromFrequency(0, *circle.synth, sld.audio_data);
				}
			}

			if circle.circle_audio == {
			case CircleAudioType.DISCRETE; {
				ref_freq : float64 = sld.runtime_settings.default_zero_pitch_frequency;
				if circle.use_set_zero_freq ref_freq = circle.pitch_zero_freq;
				tuning_system := ArrayFindFirstByNameId(sld.all_tuning_systems.*, circle.tuning_system_id, "id");
				tuning_pitches := ArrayFindAllVarName(sld.all_tuning_pitches.*, tuning_system.id, "tuning_system_id", temp);
				for audio_float_poses {
					frequency : float = MusicPtToFrequency(it, tuning_system, tuning_pitches, ref_freq);
					UpdateWaveFrequency(frequency, *circle.synth.simple_waves[it_index], sld.audio_data.*);
				}
				GenerateSimpleSynthSamples(*circle.synth, sld.audio_data.float_buffer, sld.audio_data);
			}
			}
		}
	}
	}
}