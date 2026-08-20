#import "Remap_Context"(VERBOSE=false);
#import "Basic";
#import "thegame_shared_library";
#import "thegame_math";
#import "thegame_audio";
#import "shared_names";
#import "thegame_renderer_out_data";
#import "thegame_array_poly";

/*Generalized code in a 2d op space.
Rendering, audio and input code are included here as examples.
*/
op_space_name : string = "render_op";
#program_export
ExternalRunOnce :: (sld : *SharedLibraryData) {
	Remap_Context();

	/*To open this op space from the internal terminal run :
	open_op render_op
	*/
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

	if sld.my_per_dl_data == null {
		sld.my_per_dl_data = New(MyData);
	}
	my_data := cast(*MyData) sld.my_per_dl_data;
	my_data.synth.wave_type = OscWaveType.SINE;
	my_data.synth.envelope = MakeVolumeEnvelope();
	AddSimpleWaveFromFrequency(0, *my_data.synth, sld.audio_data);
}

MyData :: struct {
	synth : SimpleSynth;
}

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

	
	/*
	This is per frame rendering so we need to think about it that way. In other words, this data is not persistent across frames.
	They are created and rendered on each frame and so they do not exist on the next frame unless specified here.
	Therefore, we only render to op spaces that are open since otherwise there is no render group associated to it. 
	This means we do not render altogether when the op space is closed which is more efficient than if we did. 
	*/
	for * op_space : sld.all_open_op_spaces if op_space.op_space_name == op_space_name {
	//This does not render the op_space if it cannot be seen in the current mspace.
	if IsFixedViewableOpSpace(op_space, sld.render_mspace_id) {
		rect : Rectangle2 = RectCenterDim(.{0,0},.{1.5,1.5});
		rect_color : Vector4F = FGREEN_V;
		//Anything rendered in an op space neds to be converted to camera space which can generally be done with OpSpaceToCameraSpace.
		//Some convenience functions for various shapes are also available.
		cam_rect : Rectangle2 = OpRectToCamRect(rect, op_space, op_space.op_2D_cam.world_pos, default_base_cam);
		//Removing these is possible and may conflict with other op space inputs.
		//IsHoveringOpSpace and IsTopOpSpace are other ways of checking.
		if IsChosenOpSpace(op_space.id, sld.all_chosen_entities) {
			if IsInRectangle(sld.game_input.mouse_cam, cam_rect) {
				rect_color = LBLUE_V;
				UpdateWaveFrequency(444, *my_data.synth.simple_waves[0], sld.audio_data);
				GenerateSimpleSynthSamples(*my_data.synth, sld.audio_data.float_buffer, sld.audio_data);
		 	}
		}
		//scissor group gets scissored on the op space for 2d. It is not recommended to use the other render groups for 2d op spaces. 
		//rendering order should be considered in general. Currently DEFAULT_TEXT_ORDER = 10003 should be used for text.
		//Anything < 10000 should be fine for color. New shader orders can be set using functions in thegame_render_group.
		//If rendering here happens on top of internal rendering, then order can be checked there as well.
		PushRectangle(cam_rect, rect_color, op_space.render_groups.scissor_group, order=10);
	}
	}
}
