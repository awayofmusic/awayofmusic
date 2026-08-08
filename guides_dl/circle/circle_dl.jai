#import "Remap_Context"(VERBOSE=false);
#import "Basic";
#import "shared_names";
#import "thegame_shared_library";
#import "thegame_math";

#program_export
ExternalRunOnce :: (sld : *SharedLibraryData) {
	Remap_Context();

	/*To open this op space from the internal terminal run :
	open_op s2d
	*/
	op_space_name : string = "s2d";
	op_space, found_op_space := FindOpSpacePointerOpenOrClosed(op_space_name, 
		sld.all_open_op_spaces, sld.all_closed_op_spaces.*);
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
	c_data.is_sound_float = false;
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
		// rect.dspace_shape_group = 2;
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