#import "Remap_Context"(VERBOSE=false);
#import "Basic";
#import "Math";
#import "thegame_shared_library";
#import "thegame_math";
#import "thegame_audio";
#import "shared_names";
#import "thegame_renderer_out_data";
#import "thegame_array_poly";

/*Generalized code in a 3d op space.
Rendering, audio and input code are included here as examples.
*/
op_space_name : string = "render3d";
#program_export
ExternalRunOnce :: (sld : *SharedLibraryData) {
	Remap_Context();

	/*To open this op space from the internal terminal run :
	open_op render3d
	*/
	op_space, found_op_space := FindOpSpacePointerOpenOrClosed(op_space_name, 
		sld.all_open_op_spaces, sld.all_closed_op_spaces.*);
	if !found_op_space {
		cosd : CreateOpSpaceData;
		cosd.op_space_name = op_space_name;
		cosd.op_space_external_type = OpSpaceExternalType.space_3d;
		op_space = CreateClosedOpSpace(cosd, 
			sld.all_closed_op_spaces, 
			sld.all_op_space_spec_data, 
			sld.all_op_spec_data_3D);
	}

	op_3D, found_op_3D := ArrayFindFirstByNameId(sld.all_op_spec_data_3D.*,
		op_space.id, "op_space_id");
	assert(found_op_3D);

	create_cs3 : CreateChordS3Data;
	create_cs3.op_space_id = op_space.id;
	create_cs3.higher_dim = 3;
	create_cs3.lp_count = 12;
	create_cs3.tuning_system_id = 0; //index 0 is "et12" by default
	create_cs3.s3_cam_start_type = S3CamStartType.USER_SET;
	UpdateTranslation(*create_cs3.cam_trans, Vector3F.{0,0,0});
	// create_cs3.new_cs_filters = .[.{0,0,.{},.SUM}];
	// create_cs3.mouse_rotate = DEFAULT_CHORD_S3_ROTATION;
	//These values can be adjusted to change the 3d perspective
	// create_cs3.depth = DEFAULT_3D_DEPTH;
	// create_cs3.n = DEFAULT_3D_N;
	// create_cs3.f = DEFAULT_3D_F;
	CreateSpace3D(op_space.world_size, create_cs3, op_3D);

	//Can add the 3d generated points along with our own 3d rendering below
	// chord_space_points := GetOrCreateChordSpacePoints3D(op_3D.op_space_3D.higher_dim, op_3D.op_space_3D.lp_count, sld.all_chord_space_points);
	// FilterCS3D(chord_space_points, *op_3D.all_op_space_points_3D, op_3D.op_space_3D.new_cs_filters, create_cs3.cs_filter_aggregate);
	//This needs to be set after in case we set the camera based on filtered points
	op_3D.op_space_3D.cam_trans = Space3DStartCamTrans(create_cs3.s3_cam_start_type, create_cs3.cam_focus_fun_region_pos, create_cs3.cam_trans, op_3D);

	if sld.my_per_dl_data == null {
		sld.my_per_dl_data = New(MyData);
	}
	my_data := cast(*MyData) sld.my_per_dl_data;
	my_data.synth.wave_type = OscWaveType.SINE;
	my_data.synth.envelope = MakeVolumeEnvelope();
	for 0..2 AddSimpleWaveFromFrequency(0, *my_data.synth, sld.audio_data);

	my_data.my_space_points.allocator = op_3D.spec_3D_alloc;
	sp0 : *SpacePoint3D = array_add(*my_data.my_space_points);
	sp0.rel_pos = Vector3F.{0,0,5};
	sp0.pitch_set = array_copy(float64.[0,4,7],, op_3D.spec_3D_alloc);

	sp1 : *SpacePoint3D = array_add(*my_data.my_space_points);
	sp1.rel_pos = Vector3F.{0,0,10};
	sp1.pitch_set = array_copy(float64.[0,3,7],, op_3D.spec_3D_alloc);
}

MyData :: struct {
	synth : SimpleSynth;
	my_space_points : [..] SpacePoint3D;
}

/*
This is per frame rendering so we need to think about it that way. In other words, this data is not persistent across frames.
They are created and rendered on each frame and so they do not exist on the next frame unless specified here.
Therefore, we only render to op spaces that are open since otherwise there is no render group associated to it. 
This means we do not render altogether when the op space is closed which is more efficient than if we did. 
*/
#program_export
ExternalPerFrame :: (sld : *SharedLibraryData) {
	Remap_Context();

	my_data := cast(*MyData) sld.my_per_dl_data;
	
	mspace_for_input, found_mspace_for_input := ArrayFindFirstByNameId(sld.all_mspace_data.*,
		sld.render_mspace_id, "mspace_id");
	if !found_mspace_for_input {
		print("mspace id % not found.\n", sld.render_mspace_id);
		return;
	}
	default_base_cam : Camera2D = mspace_for_input.mspace_cam;

	for * op_space : sld.all_open_op_spaces if op_space.op_space_name == op_space_name {
	//This does not render the op_space if it cannot be seen in the current mspace.
	if IsFixedViewableOpSpace(op_space, sld.render_mspace_id) {
		op_3D, found_op_3D := ArrayFindFirstByNameId(sld.all_op_spec_data_3D.*,
			op_space.id, "op_space_id");
		assert(found_op_3D);

		op_3D.op_space_3D.viewport.cam_offset = WorldSpaceToCameraSpace(op_space.world_offset, default_base_cam);

		/*The following keys update the 3d camera in thegame_base on the input space_3d code.
		- "WASD" and "IJKL" can be used to move around the 3d space.
		- "ctrl+mouse_button_left" will rotate each cube about a central point.
		- holding "alt+c" allows free camera movement with the mouse.

		If needed, a flag can be added to the internal code to block internal 3d movement.
		Other keys can also be used here as input for anything.
		*/
		rotate_with_temp : Matrix3F = op_3D.op_space_3D.temp_cam_rotate * GetTransform(op_3D.op_space_3D.cam_trans);
		rotate_camera := MakeMatrix4x3F(rotate_with_temp, GetTranslation(op_3D.op_space_3D.cam_trans));
		inv_camera : Matrix4x3F = InverseLengyel(rotate_camera);
		frustum_inv_camera : Matrix4F = op_3D.op_space_3D.p_frustum * inv_camera;

		//3D mouse selection code
		is_mouse_choosing : bool = false; 
		chosen_sp : SpacePoint3D;
		chosen_sp_index : int = -1;
		chosen_order : int = S64_MIN;
		if IsChosenOpSpace(op_space.id, sld.all_chosen_entities) {
			mouse_viewport : Vector2F = sld.game_input.mouse_cam + sld.renderer_data.base_render_group.half_monitor_squares;
			for sp, sp_index : my_data.my_space_points {
				rotate_pos : Vector3F = RotatedGrid3DPosition(sp.rel_pos, op_3D.op_space_3D);
				//Can set other transformation matrices in the first 3x3 matrix parameter
		    	rotate_transform : Matrix4x3F = MakeMatrix4x3F(MakeScaleMatrix(1.0), rotate_pos);
			   mvp_cube := frustum_inv_camera * rotate_transform;
		    	order_by_length : int = -round_to_int(100 * Length(rotate_pos - GetTranslation(op_3D.op_space_3D.cam_trans)));
				mesh_to_view_triangles : [] Triangle3F = 
			 		TransformMeshToViewport(CUBE_TRI_FACE, mvp_cube, sld.renderer_data.base_render_group, null, op_3D.op_space_3D.viewport, order_by_length);
				for mesh_to_view_triangles if PointInTriangle(mouse_viewport, MakeTriangle2F(it)) {
					if order_by_length >= chosen_order {
						chosen_order = order_by_length;
						is_mouse_choosing = true;
						chosen_sp = sp;
						chosen_sp_index = sp_index;
					}
				}
			}
			if is_mouse_choosing {
				tuning_system := ArrayFindFirstByNameId(sld.all_tuning_systems.*, op_3D.op_space_3D.tuning_system_id, "id");
				tuning_pitches := ArrayFindAllVarName(sld.all_tuning_pitches.*, tuning_system.id, "tuning_system_id", temp);
				for * wave : my_data.synth.simple_waves {
					frequency : float = MusicPtToFrequency(chosen_sp.pitch_set[it_index], tuning_system, tuning_pitches);
					UpdateWaveFrequency(frequency, wave, sld.audio_data);
				}
				GenerateSimpleSynthSamples(*my_data.synth, sld.audio_data.float_buffer, sld.audio_data);
			}
		}

		//3D shape rendering
		for my_data.my_space_points { 
			rotate_pos : Vector3F = RotatedGrid3DPosition(it.rel_pos, op_3D.op_space_3D);
			//Can set other transformation matrices in the first 3x3 matrix parameter
	    	rotate_transform : Matrix4x3F = MakeMatrix4x3F(MakeScaleMatrix(it.scale_value), rotate_pos);
		   mvp_cube := frustum_inv_camera * rotate_transform;
	    	order_by_length : int = -round_to_int(100 * Length(rotate_pos - GetTranslation(op_3D.op_space_3D.cam_trans)));

	    	/*Custom face-vertex meshes can be made and passed in here.
	    	Examples of a cube and tesseract face-vertex meshes can be found in thegame_render_group.jai.
	    	To change the color of each triangle, copy CUBE_TRI_FACE and then set each triangle color individually.
	    	*/
		   TransformAndPushMesh(CUBE_TRI_FACE, mvp_cube, op_space.render_groups.scissor_group_3D, null, op_3D.op_space_3D.viewport, 
		   	order_by_length);

		   if it_index == chosen_sp_index && is_mouse_choosing {
	    		TransformAndPushMesh(CUBE_TRI_FACE, mvp_cube, op_space.render_groups.scissor_group, null, op_3D.op_space_3D.viewport, 
	    			order_by_length+2, ORANGE_V, draw_wire_mesh=true);
		   }
		}

		//3D text rendering
		text_pos : Vector3F = RotatedGrid3DPosition(Vector3F.{-0.7,1,5}, op_3D.op_space_3D);
    	text_transform : Matrix4x3F = MakeMatrix4x3F(Matrix3F_Identity, text_pos);
	   mvp_text := frustum_inv_camera * text_transform;
		text_formatted_pos, in_view_frustum := Position3DTo2D(mvp_text, op_3D.op_space_3D.viewport, op_space.render_groups.scissor_group);
		//TODO This cuts out a bit early. It will get scissored out anyways if we want to remove it I think.
		if in_view_frustum {
			my_text := "[0,4,7]";
			PushText(text_formatted_pos, my_text, WHITE_V, op_space.render_groups.scissor_group, 10003);
			rect_formatted : Rectangle2 = Text3DBackgroundRect(my_text, text_formatted_pos, 
				op_space.render_groups.scissor_group.pixels_per_square, sld.text_editor_data);
			PushRectangle(rect_formatted, BLACK_V, op_space.render_groups.scissor_group, order = 10001);
		}
	}
	}
}