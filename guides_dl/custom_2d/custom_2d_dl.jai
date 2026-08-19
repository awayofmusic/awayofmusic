#import "Remap_Context"(VERBOSE=false);
#import "Basic";
#import "thegame_shared_library";
#import "thegame_math";
#import "thegame_audio";

#program_export
ExternalRunOnce :: (sld : *SharedLibraryData) {
	Remap_Context();

	/*To open this op space from the internal terminal run :
	open_op cu2
	*/
	op_space_name : string = "cu2";
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

	tuning : TuningSystem;
	for sld.all_tuning_systems.* if it.short_name == "et24" {
		tuning = it;
		break;
	}

	custom_g : *CustomGeometry = array_add(*op_spec_data.ass.all_custom_geometries);
	custom_g.dspace_id = context.ALL_NEXT_IDS.DSPACE_ID;
	context.ALL_NEXT_IDS.DSPACE_ID += 1;
	custom_g.tuning_system_id = tuning.id;
	custom_g.custom_audio_type = CustomAudioType.TUNING_SYSTEM;
	custom_g.synth.wave_type = OscWaveType.SAW;
	custom_g.synth.envelope = MakeVolumeEnvelope();
	custom_g.collision_rect = RectCenterDim(Vector2F.{10,0}, Vector2F.{3,3});
	custom_g.show_collision = true;

	coll : *CollisionEntity = array_add(*op_spec_data.all_op_collision_entities);
	coll.entity_id = custom_g.dspace_id;
	coll.entity_type = EntityType.CUSTOM_GEOMETRY;
	coll.shape = CollisionShape.RECTANGLE;
	coll.rect = custom_g.collision_rect;

	rect : *SpaceRect = array_add(*op_spec_data.ass.all_space_rects);
	rect.shape_id = context.ALL_NEXT_IDS.NEXT_SHAPE_ID;
	context.ALL_NEXT_IDS.NEXT_SHAPE_ID += 1;
	rect.dspace_id = custom_g.dspace_id;
	//Optional parameters for general sub_geometry grouping or for relative render ordering.
	// rect.dspace_shape_group = asm_data.dspace_shape_group;
	// rect.render_order = asm_data.render_order;
	rect.color = Vector4F.{0,1,0,1};
	rect.rect = RectCenterDim(GetCenter(custom_g.collision_rect), Vector2F.{0.5,0.5});
	//pitch_set will be played on mouse hover based on the geometry tuning system
	rect.pitch_set = array_copy(float64.[0,8,14],, op_spec_data.spec_2D_alloc);
	//shape_text will appear on mouse hover based on the geometry tuning system
	rect.shape_text = copy_string("24-[0,8,14]",, op_spec_data.spec_2D_alloc);
	//fun_region is optional and can be generally used to store extra data if needed
	rect.fun_region = OrderedPitchSetToFundamentalRegion(rect.pitch_set, cast(float64) tuning.music_pt_count,, op_spec_data.spec_2D_alloc);

	space_text : *SpaceText = array_add(*op_spec_data.ass.all_space_text);
	space_text.op_pos = Vector2F.{10,1};
	space_text.color = Vector4F.{0.95,0.95,0.95,1};
	SetSpaceText("24eq", space_text);
}