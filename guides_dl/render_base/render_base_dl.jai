#import "Remap_Context"(VERBOSE=false);
#import "Basic";
#import "thegame_shared_library";
#import "thegame_math";
#import "thegame_audio";
#import "shared_names";
#import "thegame_renderer_out_data";
#import "thegame_array_poly";

/*Generally it is recommended to render geometries in an op_space for easier general access.
The base can be used to render things around the music rows or
if you want to create your own base geometries.
*/
op_space_name : string = "render_op";
#program_export
ExternalRunOnce :: (sld : *SharedLibraryData) {
	Remap_Context();

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

#import "Math";
//Can increment this more if we want to render on top of the rows
base_order : int = S64_MIN+100;
//Weird because higher values don't seem to work on the base renderer.

//TODO FROM HERE We could just set the shader everytime we draw something and that might fix the issues
//with these shaders in general. I think that might be fine

#program_export
ExternalPerFrame :: (sld : *SharedLibraryData) {
	Remap_Context();

	my_data := cast(*MyData) sld.my_per_dl_data;

	//This only renders on the first mspace but we can set it to any mspace.
	//The mspace with id == 0 always exists by default.
	//Custom data per mspace can be stored based on id.
	if sld.render_mspace_id == 0 {
		default_base_cam : Camera2D = sld.all_mspace_data.*[0].mspace_cam;
		/*This is per frame rendering so we need to think about it that way. 
		In other words, this data is not persistent across frames.
		They are created and rendered on each frame and so they do not exist on the next frame unless specified here.
		*/
		rect : Rectangle2 = RectCenterDim(.{0,0},.{1.5,1.5});
		rect_color : Vector4F = FGREEN_V;
		//Anything rendered in the base world needs to be converted to camera space which can generally be done with WorldSpaceToCameraSpace.
		cam_rect : Rectangle2 = WorldRectToCamRect(rect, default_base_cam);
		//INTERNAL NOTE : Another way to do this would be to add to all_base_collision_entities and have a custom type in there
		//and then have a separate external dynamic library function for user input. 
		//But that seems complicated for only the case of overlapping with internal things.
		//Specific hovering or chosen entity checks can still be done here if needed by checking hovering and collisions internal code.
		// is_choosing_entity : bool = sld.all_chosen_entities.count > 0;
		hovering_other_entity : bool = sld.frame_hover_entities.count > 0;
		if !hovering_other_entity && IsInRectangle(sld.game_input.mouse_cam, cam_rect) {
			UpdateWaveFrequency(888, *my_data.synth.simple_waves[0], sld.audio_data);
			GenerateSimpleSynthSamples(*my_data.synth, sld.audio_data.float_buffer, sld.audio_data);

			rect_color = LBLUE_V;
			PushRectangle(cam_rect, rect_color, sld.renderer_data.base_render_group, order=base_order+1);
			//Should likely push a text shader for this but seems fine for simple examples here.
			// PushText(GetCenter(cam_rect), "888", WHITE_V, sld.renderer_data.base_render_group, order=base_order+10);
	 	}
		//rendering order should be considered in general. Currently DEFAULT_TEXT_ORDER = 10003 should be used for text.
		//Anything < 10000 should be fine for color. New shader orders can be set using functions in thegame_render_group.
		//If rendering here happens on top of internal rendering, then order can be checked there as well.
		PushRectangleOutline(cam_rect, rect_color, sld.renderer_data.base_render_group, order=base_order);
	}
}
