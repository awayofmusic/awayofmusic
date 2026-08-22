#import "Remap_Context"(VERBOSE=false);
#import "Basic";
#import "Math";
#import "thegame_shared_library";
#import "thegame_math";
#import "thegame_audio";

/*More info on spirals can be found in guides/spiral.
*/
#program_export
ExternalRunOnce :: (sld : *SharedLibraryData) {
	Remap_Context();

	/*To open this op space from the internal terminal run :
	open_op sp_dl
	*/
	op_space_name : string = "sp_dl";
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
	for sld.all_tuning_systems.* if it.short_name == "et12" {
		tuning = it;
		break;
	}

	base_chord := float64.[0,4,7];

	spiral : SpiralSpace;
	spiral.spiral_type = SpiralType.PROPER;
	spiral.world_center_pos = Vector2F.{0,0};
	spiral.tuning_system_id = tuning.id;
	spiral.pitch_zero_freq = C3;
	spiral.tuning_count = 12;
	// spiral.tuning_count = 120;
	// spiral.tuning_count = 53;
	spiral.chord_count = base_chord.count;
	// spiral.rotate = 3*PI/2.0;
	spiral.rotate = PI/2.0;
	spiral.is_clockwise = true;
	spiral.radius_size = 3.6; // Use to adjust spiral_delta size going out
	spiral.sr_factor = 1.5; // Use to adjust inner radius size (although it does effect overall spiral size as well)
	spiral.is_in_out = true;
	spiral.sound_float = false;
	spiral.point_dim = Vector2F.{0.5,0.5};
	spiral.synth.wave_type = OscWaveType.SAW;
	sp : *SpiralSpace = CreateSpiralInSpace(spiral, op_spec_data);
	//Not calling SetSpiralBase will only draw the spiral without the points.
	//This allows us to put our own points on Spiral if needed.
	//Then we can still associate those to the tuning_system of the spiral for example.
	//sound_float should be off if we don't set this since we only have arbitrary points then
	SetSpiralBase(base_chord, 0, sp, op_spec_data);

	/*Points can easily be added to the spiral using functions like ChordToSpiralPoint and FloatIndexToSpiralPos.
	To customize the spiral even further, it is recommended to look at all the spiral code in thegame_shared_library.
	*/

	//NOTE : The major/minor double spiral
	#if 1 {
	minor_chord := float64.[0,3,7];

	create_s2 : SpiralSpace;
	create_s2.spiral_type = SpiralType.PROPER;
	create_s2.world_center_pos = Vector2F.{0,0};
	create_s2.tuning_system_id = tuning.id;
	create_s2.pitch_zero_freq = C3;
	create_s2.tuning_count = 12;
	// create_s2.tuning_count = 120;
	// create_s2.tuning_count = 53;
	create_s2.chord_count = minor_chord.count;
	// create_s2.rotate = 3*PI/2.0;
	create_s2.rotate = PI/2.0;
	create_s2.is_clockwise = true;
	create_s2.radius_size = 3.8; // Use to adjust spiral_delta size going out
	create_s2.sr_factor = 1.5; // Use to adjust inner radius size (although it does effect overall create_s2 size as well)
	create_s2.is_in_out = true;
	create_s2.sound_float = false;
	create_s2.point_dim = Vector2F.{0.5,0.5};
	create_s2.synth.wave_type = OscWaveType.SAW;
	s2 : *SpiralSpace = CreateSpiralInSpace(create_s2, op_spec_data);
	SetSpiralBase(minor_chord, 1, s2, op_spec_data);
	}
}