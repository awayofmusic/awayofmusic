#import "Basic";
#import "Sort";
#import "Math";
#import "Flat_Pool";

#import "thegame_input";
#import "thegame_math";
#import "thegame_audio";
#import "thegame_array_poly";
#import "shared_names";
//TODO Currently this is only used for Viewport so if we move out 3d op space data, then we can remove this from here as well
#import "thegame_renderer_out_data";


//TODO Maybe eventually we can collapse this with AllData so we only have 1 struct both internally and externally
/*DOC : This is a combinary of Dynamic Library and Shared Object file which sounds good in general imo.
We pass this in to the dynamic lib / shared object so that the arrays can be used directly.

WE COULD put all shared data in a common struct here and all data and then just pass a pointer with just that.
That would likely be the best option.

TODO If we want to separate this file, first thing to pull out would be all the Op Space Spec Data
since that is self contained anyways. Maybe if this file gets too big or if the code separation makes sense in general.
*/
SharedLibraryData :: struct {
	//TODO add renderer data
	audio_data : *AudioData;
	game_input : *GameInput;

	//TODO Should we group everything in all_data together here?
	global_rules : GlobalRules;

	//Tuning system data
	all_tuning_systems : *[..] TuningSystem;
	all_tuning_pitches : *[..] TuningPitch;

	//Music space data
	all_mspace_data : *[..] MusicSpaceData;
	free_mspace_data_pool : *[..] MusicSpaceData;

	//Linear row data
	all_linear_to_tuning_system : *[..] LinearToTuningSystem;
	all_linear_pitch_spaces : *[..] LinearPitchSpace;
	all_space_points : *[..] SpacePoint;

	//Synth data
	all_simple_synths : *[..] SimpleSynth;
	free_simple_synth_pool : *[..] SimpleSynth;

	//Op Space Data
	//This is not a pointer since we can't open op spaces from shared library yet.
	//Maybe we just leave this opening in the terminal for now since opening requires renderer data and text data
	all_open_op_spaces : [] OperationSpace;
	all_closed_op_spaces : *[..] OperationSpace;
	all_op_space_spec_data : *[..] OpSpaceSpecData;
	all_op_spec_data_3D : *[..] OpSpecData3D;

	//TODO FROM HERE Pass in OperationSpace with finding them for now (can check create closed op space or do later when needed)
	//and then also pass RendererData and GameInput

	//TODO How should we pass this in? Or should we pass it in at all?
	//I guess we need to pass it for each function that creates things as we add them.
	//Is there a better way of generating ids?
	//Then we would have to put the struct in here.
	// all_next_ids : *AllNextIds;

	//TODO We could add a pointer for my_shared_data here if global data does not work.
	//Probably need to pass in an allocator for this to work properly
	my_shared_data : *void;
	my_per_dl_data : *void;
	// extern_alloc : Allocator;

	//This works! so we can use this method for custom synths for example and set function pointers back to call
	//We could have to check them. The other method is using more dll functions but that seems like something
	//more for if we want to call functions in different places within the main code base.
	test_foo : TestFooProc;
}
TestFooProc :: #type (t : int) -> int;

/*TODO Should we rename this to GlobalDefaults
since they are not really used as rules anymore?
*/
GlobalRules :: struct {
	check_max_voice_leading : bool;
	max_voice_leading_size : int;

	check_max_chord : bool;
	max_chord_size : int;

	tuning_system_id : int;
	//TODO Caching here for now until i think more about it
	tuning_system : TuningSystem; 

	//TODO Should likely change name of struct
	//or move these to a more appropriate place
	//for overall lane and row dimensions.
	row_size : int;
	memory_unit_width : float;

	//TODO should we have a global scale as well?
}
Kilobyte :: (bytes : s64) -> s64 #expand {
    return 1024 * bytes;
}
Megabyte :: (bytes : s64) -> s64 #expand {
    return 1024 * Kilobyte(bytes);
}
Gigabyte :: (bytes : s64) -> s64 #expand {
    return 1024 * Megabyte(bytes);
}

/*Synth Data creation start 
*/
AsmGetOrCreateSimpleSynthData :: struct {
	ret_synth_id : int;
	synth_name : AsmString;
} @LibraryAsmGen
GetOrCreateSimpleSynthData :: struct {
	synth_name : string;
}
/*TODO Should this be separate from synths we add later like subtractive synth?
Maybe we won't add it and we'll just do custom synths.
I think it's better this way and then if we add a subtractive synth later
we can separate it especially for update and custom synths will run completely separately anyways.

We could also pass in runtime settings here if we want to set some defaults from there eventually
*/
GetOrCreateSimpleSynth :: (
	gcsd : GetOrCreateSimpleSynthData,
	all_simple_synths : *[..] SimpleSynth,
	free_simple_synth_pool : *[..] SimpleSynth)
-> *SimpleSynth 
{
	synth_data, found_synth := ArrayFindFirstByNameId(all_simple_synths.*,
		gcsd.synth_name, "synth_name");
	if found_synth return synth_data;

	synth : *SimpleSynth;
	if free_simple_synth_pool.count > 0 {
		popped_synth : SimpleSynth = pop(free_simple_synth_pool);
		array_add(all_simple_synths, popped_synth);
		synth = peek_pointer(all_simple_synths.*);
	} else {
		synth = array_add(all_simple_synths);
	}
	//TODO We only need to set the id for a new synth but to avoid errors ill just always generate a new id there
	synth.synth_id = context.ALL_NEXT_IDS.NEXT_SYNTH_ID;
	context.ALL_NEXT_IDS.NEXT_SYNTH_ID += 1;
	synth.wave_type = OscWaveType.SINE;
	synth.envelope = MakeVolumeEnvelope();
	synth.volume = 0.1;
	array_reset_keeping_memory(*synth.simple_waves);

	update : UpdateSimpleSynthData;
	update.update_synth_name = true;
	update.synth_name = gcsd.synth_name;
	UpdateSimpleSynth(synth, update);
	return synth;
}
SimpleSynthMessageType :: enum {
	VOLUME;
	WAVE_TYPE;
	ATTACK_SECONDS;
	RELEASE_SECONDS;
	ATTACK_CURVE;
	RELEASE_CURVE;
} @LibraryAsmGen
AsmUpdateSimpleSynthData :: struct {
	synth_id : int;

	update_synth_name : AsmBool;
	synth_name : AsmString;

	update_volume : AsmBool;
	volume : float64;

	update_wave_type : AsmBool;
	wave_type : OscWaveType;

	update_attack_seconds : AsmBool;
	attack_seconds : float64;

	update_attack_curve : AsmBool;
	attack_curve : float64;

	update_release_seconds : AsmBool;
	release_seconds : float64;

	update_release_curve : AsmBool;
	release_curve : float64;
} @LibraryAsmGen
UpdateSimpleSynthData :: struct {
	synth_id : int;

	update_synth_name : bool;
	synth_name : string;

	update_volume : bool;
	volume : float;

	update_wave_type : bool;
	wave_type : OscWaveType;

	update_attack_seconds : bool;
	attack_seconds : float;

	update_attack_curve : bool;
	attack_curve : float;

	update_release_seconds : bool;
	release_seconds : float;

	update_release_curve : bool;
	release_curve : float;
}
UpdateSimpleSynth :: (
	update : UpdateSimpleSynthData,
	all_simple_synths : [] SimpleSynth) 
-> *SimpleSynth, success : bool, msg : string
{
	synth, found_synth := ArrayFindFirstByNameId(all_simple_synths,
		update.synth_id, "synth_id");
	if !found_synth {
		return null, false, tprint("synth_id % not found.\n", update.synth_id);
	}

	success, msg := UpdateSimpleSynth(synth, update);
	return synth, success, msg;
}
UpdateSimpleSynth :: (
	synth : *SimpleSynth,
	update : UpdateSimpleSynthData) 
-> success : bool, msg : string
{
	if update.update_synth_name {
		if synth.synth_name.data != null && synth.synth_name.count > 0 {
			free(synth.synth_name);
		}
		synth.synth_name = copy_string(update.synth_name);
	}
	if update.update_volume {
		synth.volume = update.volume;
	}
	if update.update_wave_type {
		synth.wave_type = update.wave_type;
	}
	if update.update_attack_seconds {
		synth.envelope.attack_seconds = update.attack_seconds;
	}
	if update.update_release_seconds {
		synth.envelope.release_seconds = update.release_seconds;
	}
	if update.update_attack_curve {
		synth.envelope.n_attack = update.attack_curve;
	}
	if update.update_release_curve {
		synth.envelope.n_release = update.release_curve;
	}
	return true, "";
}
AsmDeleteSimpleSynthData :: struct {
	synth_id : int;
} @LibraryAsmGen
DeleteSimpleSynthData :: struct {
	synth_id : int;
}
DeleteSimpleSynth :: (
	delete : DeleteSimpleSynthData,
	all_simple_synths : *[..] SimpleSynth,
	free_simple_synth_pool : *[..] SimpleSynth)
-> success : bool, msg : string
{
	synth_index, found_synth := ArrayFindFirstIndexByNameId(all_simple_synths.*,
		delete.synth_id, "synth_id");
	if !found_synth {
		return false, tprint("synth_id % not found.\n", delete.synth_id);
	}
	/*DOC : We reset the synth on creation if we take it back from the pool.*/
	deleted_synth : SimpleSynth = all_simple_synths.*[synth_index];
	array_add(free_simple_synth_pool, deleted_synth);
	array_ordered_remove_by_index(all_simple_synths, synth_index);
	return true, "";
}
//TODO We can also delete all subtractive synths here eventually if we add those
DeleteAllSynths :: (
	all_simple_synths : *[..] SimpleSynth,
	free_simple_synth_pool : *[..] SimpleSynth)
{
	//We don't want to delete the default simple synth
	// assert(all_simple_synths.count >= 1);
	if all_simple_synths.count <= 1 return;

	delete : DeleteSimpleSynthData;
	for 1..all_simple_synths.count-1 {
		delete.synth_id = all_simple_synths.*[it].synth_id;
		DeleteSimpleSynth(delete, all_simple_synths, free_simple_synth_pool);
	}
	//We reset the synth id to 1 since the default synth should always be in the array
	context.ALL_NEXT_IDS.NEXT_SYNTH_ID = 1;
}
/*Synth Data creation end
*/

//TODO rename all_base_collision_entities -> mspace_collision_entities
//TODO I think the ids for these arrays should be stored in here so we can reset them
//OR we keep ids unique all throughout, the problem is if we reset large things, then we 
//keep getting new ids which may not be great.
MusicSpaceData :: struct {
	//This could be the index so we can access the mspace directly
	mspace_id : int;
	//TODO We can store this in an allocator for each mspace
	//OR just free and grab a new one for now since it won't happen often
	mspace_name : string;
	mspace_cam : Camera2D;
	tano_x_unit_width : float64;

	/*DOC : Note that this is always used as the audio row size but if it's
	fixed then we don't update it based on adding rows. If it's not fixed
	then we set the largest row be be the mspace audio row size if add a new row
	and also when updating the mspace itself with the update mspace function.
	*/
	is_fixed_audio_row_size : bool;
	//TODO Should we rename this something clearer?
	//Maybe mspace_right_bound_x?
	mspace_audio_row_size : int;

	//TODO Could put ids here or set a pointer to global ids if we want different ids for all rows
	all_music_lane_rows : [..] MusicLaneRow;
	all_section_to_row : [..] SectionToRow;

	//Music Points
	//NOTE : all_music_pts is now assumed to be sorted by x_start_float.
	//We use this to play notes efficiently.
	//We also may want to fetch notes by row_index so let's see.
	//We could either double sort OR make 2 arrays one sorted by x and one by row.
	all_music_pts : [..] MusicPoint;

	//TODO Could have a different struct for this without the
	//op_space_id and maybe just rect if that's the only shape in the base.
	all_base_collision_entities : [..] CollisionEntity;	
}
AsmGetOrCreateMSpaceData :: struct {
	ret_mspace_id : int;

	gc_type : GetOrCreateMSpaceType;
	mspace_id : int;
	mspace_index : int;
	mspace_name : AsmString;
} @LibraryAsmGen
GetOrCreateMSpaceType :: enum {
	GET_BY_NAME;
	GET_BY_ID;
	GET_BY_INDEX;
	// CREATE;
} @LibraryAsmGen
GetOrCreateMSpaceData :: struct {
	gc_type : GetOrCreateMSpaceType;
	mspace_id : int;
	mspace_index : int;
	mspace_name : string;
}
GetOrCreateMusicSpace :: (
	gcmd : GetOrCreateMSpaceData,
	rs : RuntimeSettingsData,
	all_mspace_data : *[..] MusicSpaceData,
	free_mspace_data_pool : *[..] MusicSpaceData) 
-> *MusicSpaceData
{
	if gcmd.gc_type == {
	case GetOrCreateMSpaceType.GET_BY_INDEX; {
		if gcmd.mspace_index >= 0 && gcmd.mspace_index < all_mspace_data.count {
			return *(all_mspace_data.*[gcmd.mspace_index]);
		}
	}
	case GetOrCreateMSpaceType.GET_BY_ID; {
		mspace_data, found_mspace := ArrayFindFirstByNameId(all_mspace_data.*,
			gcmd.mspace_id, "mspace_id");
		if found_mspace return mspace_data;
	}
	case GetOrCreateMSpaceType.GET_BY_NAME; {
		mspace_data, found_mspace := ArrayFindFirstByNameId(all_mspace_data.*,
			gcmd.mspace_name, "mspace_name");
		if found_mspace return mspace_data;
	}
	}

	//We did not find the mspace so we create it
	//DOC : We will reuse mspaces eventually so having this as default allocator
	//is fine since we can just clear it and then reuse later when needed
	mspace_data : *MusicSpaceData;
	if free_mspace_data_pool.count > 0 {
		popped_mspace : MusicSpaceData = pop(free_mspace_data_pool);
		ClearMusicSpace(*popped_mspace);
		array_add(all_mspace_data, popped_mspace);
		mspace_data = peek_pointer(all_mspace_data.*);
	} else {
		mspace_data = array_add(all_mspace_data);
	}
	//TODO We only need to set the id for a new mspace but to avoid errors ill just always generate a new id there
	mspace_data.mspace_id = context.ALL_NEXT_IDS.NEXT_MSPACE_ID;
	context.ALL_NEXT_IDS.NEXT_MSPACE_ID += 1;
	#insert #run SetResizableArrays(MusicSpaceData, 
		"mspace_data.%.allocator = context.allocator;\n");

	//This will set all the default values from runtime settings to the new mspace by default
	//We could pass this in to create but I think it's ok to separate them right now.
	//Setting the name here ensures that we free the old string if neede.
	update : UpdateMSpaceData;
	update.update_mspace_name = true;
	update.mspace_name = gcmd.mspace_name;
	UpdateMusicSpace(mspace_data, update, rs, all_mspace_data);

	return mspace_data;
}
AsmUpdateMSpaceData :: struct {
	mspace_id : int;

	update_mspace_index : AsmBool;
	mspace_index : int;

	update_mspace_name : AsmBool;
	mspace_name : AsmString;

	update_tano_x_unit_width : AsmBool;
	tano_x_unit_width : float64;

	update_mspace_audio_row_size : AsmBool;
	set_fixed_audio_row_size : AsmBool;
	mspace_audio_row_size : int;
} @LibraryAsmGen
UpdateMSpaceData :: struct {
	mspace_id : int;

	update_mspace_index : bool;
	mspace_index : int;

	update_mspace_name : bool;
	mspace_name : string;

	update_tano_x_unit_width : bool;
	tano_x_unit_width : float64;

	update_mspace_audio_row_size : bool;
	set_fixed_audio_row_size : bool;
	mspace_audio_row_size : int;
}
UpdateMusicSpace :: (
	update : UpdateMSpaceData,
	rsd : RuntimeSettingsData,
	all_mspace_data : *[..] MusicSpaceData)
-> *MusicSpaceData, success : bool, msg : string
{
	mspace, found_mspace := ArrayFindFirstByNameId(all_mspace_data.*,
		update.mspace_id, "mspace_id");
	if !found_mspace {
		return null, false, tprint("mspace_id % not found.\n", update.mspace_id);
	}

	success, msg := UpdateMusicSpace(mspace, update, rsd, all_mspace_data);
	return mspace, success, msg;
}
UpdateMusicSpace :: (
	mspace : *MusicSpaceData,
	update : UpdateMSpaceData,
	rsd : RuntimeSettingsData,
	all_mspace_data : *[..] MusicSpaceData)
-> success : bool, msg : string
{
	if update.update_mspace_index {
		if update.mspace_index >= 0 && update.mspace_index < all_mspace_data.count {
			swap(mspace, *(all_mspace_data.*[update.mspace_index]));
		}
	}
	if update.update_mspace_name {
		//TODO If we ever have an mspace allocator, then we can also use that here instead
		//although we only clear it on clearing mspace so maybe this is better overall
		if mspace.mspace_name.data != null && mspace.mspace_name.count > 0 {
			free(mspace.mspace_name);
		}
		mspace.mspace_name = copy_string(update.mspace_name);
	}
	if update.update_tano_x_unit_width {
		mspace.tano_x_unit_width = update.tano_x_unit_width;
	} else {
		mspace.tano_x_unit_width = rsd.default_tano_x_unit_width;
	}
	if update.update_mspace_audio_row_size {
		mspace.is_fixed_audio_row_size = update.set_fixed_audio_row_size;
		if update.set_fixed_audio_row_size {
			mspace.mspace_audio_row_size = update.mspace_audio_row_size;
		} else {
			mspace.mspace_audio_row_size = ArrayFindMaxByNameId(mspace.all_music_lane_rows, "row_size", 0);
		}
	}

	return true, "";
}

AsmDeleteMSpaceData :: struct {
	mspace_id : int;
} @LibraryAsmGen
DeleteMSpaceData :: struct {
	mspace_id : int;
}
DeleteMusicSpace :: (
	delete : DeleteMSpaceData,
	all_mspace_data : *[..] MusicSpaceData,
	free_mspace_data_pool : *[..] MusicSpaceData)
-> success : bool, msg : string
{
	mspace_index, found_mspace := ArrayFindFirstIndexByNameId(all_mspace_data.*,
		delete.mspace_id, "mspace_id");
	if !found_mspace {
		return false, tprint("mspace_id % not found.\n", delete.mspace_id);
	}
	/*DOC : We don't reset or clear the mspace here because in case we accidentally
	deleted it, we still have the info, so we can make a terminal command or function
	to keep these back (or dynamic lib can just get it back directly from free_mspace_data_pool)
	*/
	deleted_mspace : MusicSpaceData = all_mspace_data.*[mspace_index];
	array_add(free_mspace_data_pool, deleted_mspace);
	array_ordered_remove_by_index(all_mspace_data, mspace_index);
	return true, "";
}
AsmClearMSpaceData :: struct {
	mspace_id : int;
} @LibraryAsmGen
ClearMSpaceData :: struct {
	mspace_id : int;
}
ClearMusicSpace :: (
	clear : ClearMSpaceData,
	all_mspace_data : *[..] MusicSpaceData) 
-> success : bool, msg : string
{
	//TODO We could do by index or id here and the do a GetMusicSpace and pull that out from get or create
	//and then fetch by that here
	// if !InRange(0, clear.mspace_index, all_mspace_data.count-1) {
	// 	return false, tprint("mspace_id % not found.\n", clear.mspace_id);
	// }
	mspace, found_mspace := ArrayFindFirstByNameId(all_mspace_data.*,
		clear.mspace_id, "mspace_id");
	if !found_mspace {
		return false, tprint("mspace_id % not found.\n", clear.mspace_id);
	}

	ClearMusicSpace(mspace);
	return true, "";
}
ClearMusicSpace :: (mspace_data : *MusicSpaceData) {
	#insert #run SetResizableArrays(MusicSpaceData, 
		"array_reset_keeping_memory(*mspace_data.%);\n");

	ResetCamera2D(*mspace_data.mspace_cam);
}

OP_SPACE_DEFAULT_SIZE :: Vector2F.{40,30};
DEFAULT_TEXT_OP_SIZE : Vector2F : #run 1.115*OP_SPACE_DEFAULT_SIZE;
RuntimeSettingsData :: struct {
	//TODO Add these to ParsedRuntimeSettings
	default_zero_pitch_frequency : float64 = C4;
	default_tano_x_units_per_second : float64 = 1.0;
	default_tano_x_unit_width : float64 = 1.75;

	//TODO What is a good default here? Should we test it somehow?
	//Will likely be different on different cpus
	asm_instructions_per_frame : int = 200;

	//I am removing this and setting it through the terminal instead for testing
	//eventually we have some file names here for dynamic libraries once we do that
	//but for now its easier to avoid string memory allocation and freeing
	// default_input_mappings_file : string = INPUT_MAPPINGS_REL_PATH;
	save_file_on_focus_lost : bool = false;

	//TODO Should this be in it's own file eventually so we can have custom shareable themes with just 1 file?
	//Maybe we wait till there are too many setting options or if we want to add colors/settings as variables as well.
	//TODO We could add that as part of the language and have a specific file for current theme which is just code...
	//and then have a specific asm instruction to do that. ALSO can do it with external dynamic libraries
	//ACTUALLY external dynamic library is even better I think. Gives an example of using external dynamic libraries as well
	//which could be fun to play around with how things look
	//Theme settings
	default_font_size : float = 18.0;
	default_font_color : Vector4F;
	default_text_op_background_color : Vector4F;
	default_text_op_border_color : Vector4F;

	terminal_size : Vector2F = OP_SPACE_DEFAULT_SIZE;
	text_op_size : Vector2F = DEFAULT_TEXT_OP_SIZE;
	default_op_space_size : Vector2F = OP_SPACE_DEFAULT_SIZE;
}

//TODO We don't use most of the things in here anymore so we
//can remove them like the transform and cam_dim especially.
Camera2D :: struct {
	//TODO Can likely remove this id since we don't use this from an array anymore
	// id : int;
	world_pos : Vector2F;

	//TODO Can likely remove this as well and just set it somewhere
	//int the frame if needed
	// move_this_frame : Vector2F;

	//TODO I THINK we can remove everything below here now
	// transform : Matrix2F;
	//TODO do we really need a cam_dim?
	// cam_dim : Rectangle2;
	//TODO should we combine world_pos and transform into Matrix3x2F?
	// is_fixed : bool = false;
}
ResetCamera2D :: inline (cam : *Camera2D) {
	cam.world_pos = Vector2F.{0,0};
	// cam.move_this_frame = Vector2F.{0,0};
}

/*TODO
We could change this to being an array with 
[Row,Point,Point,Row,Point...]
The Row would store how many points after it and then we just
skip over it if we are looking for the row. This would allow
easy memory manipulation since we can just set and get things
based on direct offset.
*/
/*TODO
	***can likely replace invariant_id (and maybe id) with music_pt_set_id since every
	music_pt will be in a music_pt_set and usually we only get music_pts relative
	to the music_pt_set that its in***

	for long notes we could have a separate duration (maybe just AudioMusicPt)
	and then check if a newly added note is within the beat of that
	NOTE_BEAT_START <= NEW_BEAT <= NOTE_BEAT_END && == invariant_id
*/
//TODO should this be called MusicPoint or SoundPoint? i think so
//TODO or just call it Tano or Tanote or Tzyno Mvzrbtmsdg
/*
Nume
Neme
Newme
Newm
newm
nume
*/
MusicPoint :: struct {
	/*TODO rename to tuning_pitch or tuning_abs_pitch?
		//TODO change name since we use compass interval now
		//music_pt_and_compass_degree?
		//tuning_abs_pos (tuning absolute pos which include the compass multiple)

		currently this is relative to the tuning system but we can
		also just store cents everywhere or both
		can store cents and cache the current overlayed tuning system
		position as well. or store cents in AudioMusicPt and
		cache current music_pt_pos relative to tuning_system here

		storing cents does not work since this is used in general
		for other mps like rhythm or volume or timbre
	*/
	/*One way to do this is that we use int as cents or higher
	and we use float for the displayed point. This way we can use
	the float but then have the benefits of the int in the background
	value.
	*/
	//TODO leaving this here so we don't break old code for now
	/*TODO I THINK WE CAN TRY REMOVING THIS NOW AND SEE HOW IT WORKS WITH JUST music_pt_float
	I will leave for now, but we can try that at some point and I don't think we use it anywhere
	*/
	music_pt_pos : int;

	/*This model would have the float be tuning_system dependent
	and the cent_pos would simply be a mapping from the float
	to the cent using the tuning_system.
	*/
	//TODO Could this be a union with music_pt_pos?
	//Keeping them separate now for safety but this will likely
	//be possible later to have a union with some testing for data packing.
	//TODO This should likely be a float64 to avoid rounding errors.
	//Need to update functions accordingly so that works.
	//I want this to remain valid for all frequencies including animals.
	//Apparently bats can hear up to 200Khz which would be
	//200000.0 so we would start losing decimal precision with bats.
	//IT WOULD BE MORE EFFICIENT TO HAVE THIS JUST BE FLOAT BUT we are likely going to remove the int
	//value and having float64 allows us to treat this value like an int without worrying about precision
	//if needed. So that is the reason i changed it. At the frequency level, we cast(float) for now
	//We could change that as well but generating samples gets a large speedup with float.
	/*BASICALLY we are keeping it float64 so we can treat it like an int without worrying about precision
	or some obscure float 32-bit error that could drive me crazy finding if there is a bug. Later, if we see that
	we don't need it, then we can just set it to float, although this would already lose decimal precision at the
	cent scale. One thing to note here is that a change of +/- 1 in the cent scale is imperceivable to humans
	but may not be to other animals like dogs and bats. I want this to work for animals as well as maybe animals
	could also partake in making music with easily-accessible software some day.
	*/
	// music_pt_float : float; //TODO This needs to be float64
	music_pt_float : float64;
	//TODO Do we want cent_pos or just compute frequency directly?
	//Maybe cents would be useful for chord_s2 and chord_s3 for example
	//to completely generalize.
	// cent_pos : u32;
	// union {
	// 	//TODO Need to refactor music_pt_pos -> music_pt_int
	// 	// music_pt_int : int;
	// 	music_pt_pos : int;
	// 	music_pt_float : float64;
	// }
	//TODO this can be a 32-bit and even a 16-bit for optimization
	//since 20*1200 < 2^16 which would be 20 octaves 
	//in cents starting from 2Hz
	// cent_pt_pos : int;

	//TODO Could have both float and int for now (or forever)
	//until we understand better how it would be used by using it.
	// music_pt_pos : float;
	/*An extra note to make here regarding
	FLOAT VS CENTS
	I need to test this but while floats seem useful
	for calculations it seems to make sense (cents!) that
	we could use cents or even 120-eq tuning_systems.
	This way we easily have access to numbers like 5 and 8
	and even coprime numbers like 7 and 9 are very close
	to something in the tuning system. This way we can still
	show 12-eq as a background and then have the other notes
	overlay it. It becomes difficult to see after around 30-50
	so 24 would work but 48 and 53 would be hard to manage mentally.

	IF WE STORE BOTH CAN STORE BOTH AS 32-bit and then
	we don't have storage issues. Could be good short-term solution.
	SoA is possibly a better long-term solution.

	IN WHICH CASE we could also store both the in values which
	would be directly placeable on the tuning_system and also
	a float value which would be more precise and could be
	used if necessary. Having both is ideal although may require
	some coding finesse to keep things efficient.
	Seems like a good candidate for SoA meta-programming where
	we can change which variable we get depending on the coding
	context at compile-time.
	*/
	/*
	Floating point is interesting because then we can 
	arbitrarily interpolate anything within the significant 
	digit bounds of 32 bit floating point. 
	So then we can interpolate along any tuning system and 
	therefore divide 12 tone by 5 and also 19-tone or 53-tone 
	by any rational that fits in 32-bit floating point. 
	AND we can also move between scales smoothly like 
	diatonic where the spacings between points is uneven 
	on the tuning system.
	*/
	// music_pt_pos : float;

	/*TODO We could replace this with memory_index
	  but this requires less computations overall both
	  for generation and for playing and won't 
	  require more space with SoA later.
	  TODO These can likely be SoA
	  and then we only use x_start for op_spaces.
	  Although we can easily compute by 
	  memory = x + row_index * row_size

	  TODO Could also store both x_positions and
	  memory_indices for convenience if we need them
	  and this makes sense since we are recomputing
	  all the music_pts every code execution and then
	  we cannot move them around except for in op_spaces
	  which could have a different model. Op spaces
	  could use the old model since we will have specific
	  sets most likely.

	  FL Studio has this down to 1 millisecond at 522 bpm and (24*4) ticks per beat
	  so we could adjust it so that the minimum change possible is 1 millisecond.
	  How does this fit into float64?
	  It would be worth playing around with this at some point because
	  if each memory_unit is 1 millisecond it would be pretty ridiculous
	  so maybe that could be a hard limit or also above. And then you
	  would only be able to fit a certain number of notes.
	  How does that fit into float32 for world_pos as well?
	  Could that just be float32 with a an extra 32 bit int if
	  we go passed it?
	  float64 with an extra 16 or 32 bit int would work if
	  we wanted to extend the x_index and reduce row_index eventually
	  OR just add an extra operand with a specific movc instruction

	  At 10ms per memory unit we still have 5-6 decimal places on rhs to have 9 decimal places (billions) on lhs.
	  So 10^9 * 0.01s = 10^7seconds. 10^7s / 60(s/min) / 60(min/h) / 24(h/day) = 115 days.
	  I think that is also extreme 10ms per memory unit with with 10^(-5) still on rhs decimal places.
	  Even if we just have 100ms per unit which is 120(bpm) = 0.5s so 480bpm = 0.125s
	  then we would have 10^8 seconds > 3 years. So even in these extreme cases we have days to years with 
	  5-6 decimal places rhs precision which is <= 15 float64 decimal precision and float64 is 15-17 which
	  should all reduce float error to almost 0.
	  THEN we can allow multiple spaces so that when one space is over we move to another space.
	  Assuming a simpler case like a film which is 2 hours then we have 7200s but thats < 10^5 so then
	  we would have 10 decimal places rhs which guarantees 5-6 decimal places no problem. Then we can
	  move the decimal place down if needed or not to really have low error.
	  Then each space can be 2 hours for example and then we can move (space_index,row_index)
	  using the same asm between spaces with only 2 values.
	  A general mov between spaces would look like : 
	  mov (space,row), (space,row), row_count
	  SO then we can move an entire space with 1 instruction

	  It seems like this code
	  	test_float : float64 = 1.000001;
		iter := 1000000000;
		acc := 0.000001;
		print("ground = %\n", test_float + iter*acc);
		for 1..iter test_float += acc;
		print("test_float = %\n", test_float);
	  Starts to produce some error of 0.000000011 around 1-2 billion operations.
	  So the 8th significant digit is off by 1 after 1 billion operations or so.
	  This can be mitigated by the user but also the use can just make sure to 
	  use new fresh values after 1 billion operations. Also can cast to int once
	  in a while and then back for example.
	  THIS WHOLE THINGS WOULD BE WORTH WRITING SOMEWHERE IN THE GAME SO THAT PEOPLE
	  CAN UNDERSTAND THE LIMITATIONS OF FLOAT64 AND ADJUST FOR IT.
	  ALSO to discuss alternatives and how we would implement them.
	  DISCUSS THIS WITH FRIENDS :)

	  GOOD IDEA!!! FOR EXAMPLE
	  We could have an instruction that adjusts all music_pt x and pos to a certain decimal place.
	  So lets say its to 5 then we do
		f : float = 10000.00001;
		x : int = round_to_int(f * 10000) = 1000000001;
		music_pt.x = cast(float64) x;
	  THIS way we completely remove the floating error.
	  So this can be seen as a lower level cycling. We can also do it
	  by default every 1-10 million operations or so by default or with a given setting.

	  Interesting to consider advantages between float, int and fixed-point
	  With float we have most flexibility and also built in computation with cpu
	  but the best way to think of it is to put the error handling on the use and
	  then allow them the most variability possible. This way they can choose how things
	  are dealt with if they are faced with edge cases.
	  Integers don't have errors as the errors are dealt with by the transistors themselves,
	  but they then don't allow immediate access to float. We could have float reduced to ticks
	  for example but this would still contain the same floating point error. And then
	  if we need midi with float, we can just adjust with systematic error at the end on conversion.
	  Fixed point solves the error issue but then we have limited precision AND
	  we would have to implement everything so it would not run natively on the cpu
	  and thus would be less efficient than integer or float.
	  So we leave both int and float here for now and can see later.
	  My hunch is that float64 is fine and we just assume less decimal maybe 14-15.

	  Other formats may become widely available on cpus eventually as well such as :
	  https://en.wikipedia.org/wiki/Unum_(number_format)
	*/
	/*TODO these can likely be floats in any case since i don't
	think we explicitly need the ints in any case as we usually
	compare within ranges and not with equality.
	MORE notes below but wrote here as there may be not real
	point in having the int version at all although both
	version could be used to test at first.
	NOTE : CAN LIKELY CHANGE THIS BEFORE CHANGING X_INDEX IN ROW to fetch with float
	*/
	x_start : int;
	x_end : int; //TODO Should this just be the x_length?
	x_start_float : float64;
	x_end_float : float64;
	
	//TODO Could make row_index->row_id and then store which index corresponds
	//to which id which would make adding rows and switching things around easier to update
	//but is the indirection worth it? Right now we store music_pts with row_index in them for example.
	//I still think keeping row_index is better because we just need to + 1 to everything after this index...
	//which is 1 pass through a few arrays whenever we add a row. The other way is constant indirection and table lookup everytime.
	//The 1 time seems more balanced considering how often we will do row_index checks for music_pts for example.
	//TODO Put row_index above x to remain consistent with asm and code input.
	//Might still be worth doing row_id since we can fetch rows by index
	//directly in asm and then just use the id after for any operation.
	//ONE ARGUMENT is we could just let the player do it since they can
	//mov all the points from one row to another with 1 asm instruction
	//and then just have higher level functions that do some convenient things.
	//Unless of course we realize that it is more efficient to have the id instead eventually.
	row_index : int;
	//TODO Could use negative rows as pure data points which are not played,
	//which could be beneficial for fetch and delete optimizations since we only
	//have to do it for part of the array and then playing pts are just >= 0;

	//TODO Could keep order here if we sort this array so that
	//we know the order of the array and can us the memory_units
	//as arrays here.
	// order : int;

	//TODO Should these be float as well. We seem to only check
	//these within bounds and therefore changing to float would not matter.
	//In many cases we convert to float anyways and the audio_position is
	//in float64 also so in that case we have to convert to float.
	// x_start : float;
	// x_end : float;

	//TODO We could have all of these for now to see which
	// is the most convenient long term or to just store all
	// of them but in an SoA instead and use what we need
	// when we need
	// memory_index = x_start + row_index * row_size
	// memory_index : int;


	//TODO ***Can likely remove id and invariant_id now***
	/*TODO If we remove MusicPtToMusicPtSet, a MusicPoint could
	be defined by its music_pt_pos and music_pt_set_id alone.
	And that could be all we have in MusicPoint. Invariant id
	would only be needed in the operation op_spaces.

	Then we could have music_pt_set_id : int and
	music_pt_pos : u32 probably don't need more.
	And we could have an SoA for efficiency and then
	easily do SIMD for some operations ADD, MOVE, SUB...
	*/
	id : int;
	//TODO could use this instead of a direct music_pt_id
	// single_music_pt_set_id : int;

	/*TODO this could just be a invariant_set_id instead so
		the music_pts in a voice would just be special set
		in a separate MusicPtSet array
	*/
	/*TODO should we pull this out as well?
		if we do pull out then we can have invariants associated
		to op_spaces and invariants associated to base_space/music_lane
	*/
	/*TODO this may only make sense making it related
		to a specific music_lane section or a specific op_space
		ie only 1 color per music_lane and only 1 set of invariant_ids
		per op_space
		OR 1 invariant_id per music_pt between ops which lets us keep track 
		of the music_pts during ops so we can do things like inverse union.
		So then maybe invariant_id should be internal and not visible to the player.
	*/
	//TODO Can likely remove this since we MAY only need for op_space but also maybe not at all
	invariant_id : int;
}
//TODO Could make an equals operator overload here if that's better
EqMusicPt :: inline (m1 : MusicPoint, m2 : MusicPoint) -> bool {
	is_eq : bool = 
		m1.row_index == m2.row_index &&
		Float64Equal(m1.music_pt_float, m2.music_pt_float) &&
		Float64Equal(m1.x_start_float, m2.x_start_float) &&
		Float64Equal(m1.x_end_float, m2.x_end_float);
	return is_eq;
}

Length :: inline (m : MusicPoint) -> float64 {
	length : float64 = abs(m.x_end_float - m.x_start_float);
	return length;
}

//TODO Can rename this to MakeMusicPoint later.
//Using this name for now to be explicit that we
//are creating it with the memory data model.
MakeMemoryMusicPoint :: inline (
	music_pt_pos : $T,
	x_start : int,
	x_end : $R,
	row_index : R)
-> MusicPoint
{
	mp : MusicPoint = ---;
	SetMemoryMusicPoint(*mp, music_pt_pos, row_index, x_start, x_end);
	return mp;
}

MakeNeume :: MakeMusicPoint;
MakeMusicPoint :: inline (
	music_pt_pos : float64, row_index : int,
	x_start : float64, x_end : float64)
-> MusicPoint
{
	//TODO Could assert x_start <= x_end to avoid issues.
	mp : MusicPoint = ---;
	//TODO Can move the code from SetMemoryMusicPoint in here now that
	//we only use float and only make the MusicPoint here
	SetMemoryMusicPoint(*mp, music_pt_pos, row_index, x_start, x_end);
	return mp;
}

//TODO Could have options in here to sort by row or x_start_float or both
//but we need default to set things back to normal wherever we need it.
//Although eventually having separate audio neume array might be best.
DefaultSortNeumes :: inline (all_music_pts : [] MusicPoint) {
	quick_sort(all_music_pts, (m1,m2) => m1.x_start_float - m2.x_start_float);
}

SetMemoryMusicPoint :: inline (
	mp : *MusicPoint,
	music_pt_pos : $T,
	row_index : int,
	//TODO Should we force these to be float64 once it works everywhere?
	x_start : $R,
	x_end : R)
{
#assert(AllOrEquals(T, .[float,float64,int]));
#assert(AllOrEquals(R, .[float,float64,int]));

	//TODO Can remove the int versions now once we refactor everything
	//since the int version will not be used eventually.
	#if T == int {
	mp.music_pt_pos = music_pt_pos;
	mp.music_pt_float = cast(float64) music_pt_pos;
	} else #if T == float || T == float64 {
	mp.music_pt_float = cast(float64) music_pt_pos;
	mp.music_pt_pos = round_to_int(music_pt_pos);
	}
	//TODO Can also remove int version here one everything works with float
	//since we will only use x_start_float and x_end_float from now on.
	#if R == int {
	mp.x_start = cast(int) x_start;
	mp.x_end =   cast(int) x_end;
	mp.x_start_float = cast(float64) x_start;
	mp.x_end_float =   cast(float64) x_end;
	} else #if R == float || R == float64 {
	mp.x_start = round_to_int(x_start);
	mp.x_end = round_to_int(x_end);
	mp.x_start_float = x_start;
	mp.x_end_float = x_end;		
	}
	mp.row_index = row_index;
}

//HOWEVER .and <x,y> [r] where r is empty array would clear the music_memory
//If the first value in memory is always zero, so [0] is zero then that would be
//a clear instruction without adding a new instruction, which seems ideal.
RemoveAllMusicPtsInMemory :: inline (
	row_index : int,
	x_pos : $T,
	all_music_pts : *[..] MusicPoint)
-> [] MusicPoint
{
	music_pts : [..] MusicPoint;
	music_pts.allocator = context.allocator;

	//TODO BETTER WAY TO DO THIS IS JUST MEMCPY BACKWARDS AND THEN RESIZE ARRAY
	//SHOULD TRY THAT AND TEST WITH NEW 2 OPERAND SET OPERATORS
	mpi : int;
	while mpi < all_music_pts.count {
		mp := all_music_pts.*[mpi];
		if ValueInMusicPt(x_pos, row_index, mp) {
    		array_add(*music_pts, mp);
    		//TODO I think its better to just remove it unordered and then sort once afterwards
			array_ordered_remove_by_index(all_music_pts, mpi);
			mpi -= 1;
	   }
	   mpi += 1;
	}

	return music_pts;
}

//TODO Rename to CreateMemoryMusicPt or just CreateMusicPt if we don't do it anywhere else.
CreateMusicPtInMemory :: inline (
	music_pt_pos : $T,
	row_index : int,
	//R is checked in SetMemoryMusicPoint. (float, float64 and int for convenience)
	x_start : $R, x_end : R,
	all_music_pts : *[..] MusicPoint)
-> *MusicPoint
{
	//TODO This would be faster if we just create the point directly in memory
	mp : *MusicPoint = array_add(all_music_pts);
	SetMemoryMusicPoint(mp, music_pt_pos, row_index, x_start, x_end);
	return mp;
}
CreateManyMusicPtsInMemory :: inline (
	input_music_pt_poses : [] $T,
	row_index : int,
	//R is checked in SetMemoryMusicPoint. (float, float64 and int for convenience)
	x_start : $R, x_end : R,
	all_music_pts : *[..] MusicPoint)
-> [] MusicPoint
{
	//TODO Could just return an array view although it would be incorrect if we change values in the all_music_pts later.
	result_music_pts : [] MusicPoint = NewArray(input_music_pt_poses.count, MusicPoint, false,, temp);
	for input_music_pt_poses {
		mp : *MusicPoint = CreateMusicPtInMemory(it, row_index, x_start, x_end, all_music_pts);
		result_music_pts[it_index] = mp.*;
	}
	return result_music_pts;
}

//TODO Should swap value and row_index i think for consistency since we do that everywhere else.
ValueInMusicPt :: inline (value : $T, row_index : int, mp : MusicPoint) -> bool {
	if ValueInMusicPt(value, mp) && row_index == mp.row_index {
		return true;
	}
	return false;
}
//This is adjustable so that people can think about floating point in any case with 5 decimal points
//being a good default. I think I should look at FloatEquals website also.
//TODO Maybe 6 decimal points is better by default since that would still leave 9 lhs values, which is billions.
//That assumes only 15 values whereas float64 is from 15-17 values which should reduce most of float accumulation error.
DEFAULT_MP_EPSILON : float64 : 0.00001;

//TODO Do we really need this version or are we always checking row_index.
//Leaving here for now but currently not using directly.
ValueInMusicPt :: inline (value : $T, mp : MusicPoint, EPSILON : float64 = DEFAULT_MP_EPSILON) -> bool {
#assert(T == int || T == float64 || T == float);
	//NOTE : Because we can choose our bounds with float, I am trying to adjust the bounds by a bit here.
	//so if mp.x_start_float = 1.999999 and mp.x_end_float = 2.000001 and value = 1.999999
	//then 1.999999 + 0.00001 = 2.000009 >= 1.999999 && 1.999999 + 0.00001 = 2.000009 > 1.999999
	//NOTE : These are equivalent, can use whichever is more efficient. I doubt making a variable on the stack
	//will be more efficient than just having the 2 subtractions. So I keep the one thats clearer.
	//Essentially we are shifting over the music_pt range down to accomodate more start values and remove more end values.
	//Therefore if x_start == 1.0 and x_end == 2.0, if value of 1.999999 is passed in, it should fail because
	//that is being considered as a 2.0
	// if value + EPSILON >= mp.x_start_float && value + EPSILON < mp.x_end_float {
	#if 1 {
	return InEpsilonRangeLeft(cast(float64) value, mp.x_start_float, mp.x_end_float, EPSILON);
	} else {
	// if value >= mp.x_start_float - EPSILON && value <= mp.x_end_float - EPSILON {
	if value >= mp.x_start && value < mp.x_end {
    	return true;
   }	
   return false;
	}
}

//TODO Maybe we should make everything in TuningSystem and TuningPitch
//be float64 to reduce any kind of float errors down the road. Although
//we have to reduce to float32 for frequency anyways since the audio buffer
//takes an s16 anyways but still having more precision in calculation could
//be beneficial. Maybe eventually we also have float64 frequencies!
MusicPtToFrequency :: (
	music_pt_float : float64,
	//TODO We should index pitches in TuningSystem and then
	//we can do a direct array access for all_tuning_pitches
	//without having to do any search
	tuning_system : TuningSystem,
	all_tuning_pitches : [] TuningPitch,
	//TODO I think this needs to be separate and not in TuningSystem
	//so that we can easily change the base or octave of any TuningSystem
	//without having to create a new one. For example we could get this from
	//SectionToRow for the world linear structure.
	base_freq : float = C4) 
-> float
{
	//TODO MAYBE WE RETURN frequency = 0 if music_pt_float < 0
	//Technically it works if base_freq is C4 for example since we can go below it...
	//OR we just ClampMin frequency to 0 so we can still go music_pt_float < 0 for convenience but never frequency < 0
	frequency : float64;
	if tuning_system.type == TuningSystemType.EQUAL_TEMPERAMENT {
		//TODO Need to pass in ref_freq either from TuningSystem OR from SectionToRow so we can change the
		//base note and keep the same tuning system.
		frequency = PitchWithOctaveToFrequency(music_pt_float, 
			tuning_system.music_pt_count, tuning_system.compass_interval, ref_freq = base_freq);
	} else {
		//TODO We add VF_EPSILON_64 to be consistent so we avoid issues with something like 1.999999 being cast down to 1.
		//Maybe we should increase the value precision. Right now it's to 5 decimal places.
		//TODO Could make a floor_to_int function where we do this automatically and consistently.
		//can also use the jai floor function to make sure the float64 fits into the int
		//TODO FROM HERE make a more consistent floor_to_int function and then use this for circles
		//and also do a circle float for fun. Can use floor_to_int in create circle space too
		//also and indices for getting tuning_pitches eventually
		// music_pt_int := cast(int) (music_pt_float + VF_EPSILON_64);
		music_pt_int : int = floor_to_int(music_pt_float);
		compass_multiple : int = music_pt_int / tuning_system.music_pt_count;
		music_pt_mod : int = music_pt_int % tuning_system.music_pt_count;
		//TODO all_tuning_pitches should be indexed and sorted by tuning_system_id
		//and then also by music_pt_pos for immediate fetching since they wont change order.
		tuning_pitch, found_tuning_pitch := 
			ArrayFindFirstConstByAndOp(all_tuning_pitches,
				tuning_system.id, "tuning_system_id",
				music_pt_mod, "music_pt_pos");
		assert(found_tuning_pitch);

		//TODO Need to pass in ref_freq either from TuningSystem OR from SectionToRow so we can change the
		//base note and keep the same tuning system.
		frequency = RatioToFrequency(tuning_pitch.ratio_from_start, compass_multiple, tuning_system.compass_interval, ref_freq = base_freq);

		//TODO We could remove this check and just always do the interpolation if that is more efficient
		music_pt_remainder : float64 = music_pt_float - music_pt_int;
		//TODO What should the remainder be here? 64-bit has 15 decimal digits of precision i think.
		if music_pt_remainder > VF_EPSILON_64 {
			next_music_pt : int = music_pt_int + 1;
			next_compass_multiple : int = next_music_pt / tuning_system.music_pt_count;
			next_music_pt_mod : int = next_music_pt % tuning_system.music_pt_count;
			next_tuning_pitch, found_next_tuning_pitch := 
				ArrayFindFirstConstByAndOp(all_tuning_pitches,
					tuning_system.id, "tuning_system_id",
					next_music_pt_mod, "music_pt_pos");
			assert(found_next_tuning_pitch);

			next_frequency : float64 = RatioToFrequency(next_tuning_pitch.ratio_from_start, next_compass_multiple, tuning_system.compass_interval, ref_freq = base_freq);
			interp_frequncy : float64 = (next_frequency - frequency) * music_pt_remainder;
			frequency += interp_frequncy;
		}
	}
	return cast(float) frequency;
}

/*Basic tano code
TODO Could add operator overloads for tano and music pts OR just have that be customizable
*/

/*DOC : Tano can be thought of as a k-cell (hyperbox/hyperrectangle/orthotope) made up of rows of tuning systems.
It is defined by pairs of values (int or reals) which represent the start and end of each of the edges of the k-cell 
so therefore, the number of elements in a tano is always even.
Due to the current use of computers where rectangles are the natural way (ie memory is linear, screens are rectangular...), 
we use a k-cell here BUT if there are currently unknown advances in human mind experiential systems,
a tano can also be generalized to a parallelohedron/polyhedron/parallelotope/zonotope/polytope
if rectangles are not the only natural way in these new systems.

Operations defined on a tano are well defined for "~=", "+", "-", "/", "*", "<<", "<<<" and we can do more later like 
"~+" and "~-" and "||" and "&", and "~&" etc... Which should all be mathematically sound defaults which I think
are best determined later from experience and communication in awareness.

Each edge range can be ordered low->high or high->low which determines the order in which they are traversed
when the mov operation is performed. So eg [x_start, x_end] where x_start <= x_end || x_start >= x_end
which differs from a k-cell definition where x_start < x_end is part of the definition.
So doing tano(0) ~= tano(3..2); would copy row 3 to row 0 and row 2 to row 1.
(The reason is to make reverse/retrograde a normal movement.)

The trivial default case of tano(0,0) is a piano. (default is 12-eq) (check math words for trivial/degenerate/simple)

A tano could also be represented as
struct {
	pairs : [] int;
	pairs : [] float64;
}
but it is interesting since then we dont know in what order they are in (int vs floats) or what they are related to.
The current case is 3-cell where we introduce 2-cell first with row and x and then the 3-cell case with mspace.
We can add more dimensions later if needed and possibly have an n-dimensional tano if this has some relationship in experience.
Since our current experience is 3-dimensional we can also leave it open ended so that if/when our experience becomes
4(or more)-dimensional then we can increase the tano dimension one at a time with a new pair of values
and decide if that pair is integer or reals later.

TODO Formal definition of k-cell is https://en.wikipedia.org/wiki/Hyperrectangle.
So we can make a formal definition of a tano once it is more functional and stable.
*/
//TODO Maybe we should put this in thegame_math since it is a math construct
//TODO We could use it as tano as well and then do #as using in TanoLoop for clarity
//TODO Is there a better name than whole CENTER_TANO? CENTER_TANO?
//NOTE : This should be from row_start=0 and x_start=0 because its relative to the center
CENTER_TANO :: tano.{0,0,0,0,0};
tano :: struct {
	row_start : int;
	row_end : int;

	x_start : float64;
	x_end : float64;

	//TODO Should we rename to mspace_index if we don't use mspace_end here?
	mspace_start : int = 0;

	//TODO I will leave this value here for now since intuitively it makes sense,
	//but will only implement it when we actually implement mspaces since it may not make sense in practice
	//and then we can just copy multiple mspaces with a for loop in the code.
	//Maybe internally is more efficient but we will see later and just leave this here for future convenience and reminder.
	//The main benefit is that having this would allow us to do
	//tano(0,0,1) ~= tano(0,0,0..3) + 1;
	//OR
	//tano(,,1) ~= tano(,,0..3) + 1;
	//OR
	//for 0..3 tano(,,1+it) ~= tano(,,it) + 1;
	//Mathematical intuition is saying to keep this and use it later.
	//BUT for tano(,,0..3) + 1 then we would have to store each musical space on the stack
	//so maybe this is overkill and we just allow mspace moving without the end
	//and then we can add functions for the end ones or can code it themselves.
	//DEFINITELY thinking of removing this now since it overcomplicates things and we can make functions
	//that do this anyways if needed or even operator overloads for ~+ or something like that,
	//instead of adding a lot of complexity at the assembly/runtime level for moving between neume arrays.
	//NOTE : This has been removed for now because we would need to copy each mspace and therefore
	//have a stack for each mspace which is possible but for now we won't do it and can add it later if
	//it is more practical than just making some functions or operator overloads for it.
	// mspace_end : int = 0;
}
MakeTano :: inline (rs : int, re : int, xs : float64, xe : float64) -> tano {
	t := tano.{rs,re,xs,xe,0};
	return t;
}
MakeTano :: inline (r : int, x : float64) -> tano {
	t : tano = tano.{r,r,x,x+1,0};
	return t;
}
TanoXLength :: inline (t : tano) -> float64 {
	x_length : float64 = abs(t.x_end - t.x_start);
	return x_length;
}
/*Definition : A normalized tano is when 
row_start <= row_end && x_start <= x_end
*/
NormalizeTano :: inline (t : tano) -> tano {
	t_norm := t;
	NormalizeTano(*t_norm);
	return t_norm;
}
NormalizeTano :: inline (t : *tano) {
	if t.row_start > t.row_end {
		swap(*t.row_start, *t.row_end);
	}
	if t.x_start > t.x_end {
		swap(*t.x_start, *t.x_end);
	}
}

/*TODO We could include this function in code so that people can use it and create their own 
operations and math structures to be used with tano and music points.

TODO Need to pass in musical spaces to move that or we just do that externally unless we store mspace_index
in MusicPoint which depends if we have separate neume arrays for each mspace.
*/
TMovMusicPt :: inline (mp : MusicPoint, from_tano : tano, to_tano : tano) -> MusicPoint {
	//Default : from_tano.row_start <= from_tano.row_end
	row_diff : int = mp.row_index - from_tano.row_start;
	if from_tano.row_start > from_tano.row_end {
		row_diff = from_tano.row_start - mp.row_index;
	}
	//Default : to_tano.row_start <= to_tano.row_end
	to_row : int = to_tano.row_start + row_diff;
	if to_tano.row_start > to_tano.row_end {
		to_row = to_tano.row_start - row_diff;
	}
	//Default : from_tano.x_start >= mp.x_start (This way removes Float64Equal)
	x_diff : float64 = mp.x_start_float - from_tano.x_start;
	if from_tano.x_start > from_tano.x_end {
		x_diff = from_tano.x_start - mp.x_end_float;
	}
	//Default : to_tano.x_start <= to_tano.x_end (This way removes Float64Equal)
	to_x_start : float64 = to_tano.x_start + x_diff;
	to_x_end : float64 = to_x_start + Length(mp);
	if to_tano.x_start > to_tano.x_end {
		to_x_end = to_tano.x_start - x_diff;
		to_x_start = to_x_end - Length(mp);
	}

	//TODO Could set this at the top so it's clearer what we are setting and more efficient
	//TODO DO PUT ON TOP LATER once we remove ints from MusicPoint and stabilize tmov usage.
	//Keeping here for now because we have to call SetMemoryMusicPoint in MakeMusicPoint
	//to set the integer values but can remove it once we remove integer values from MusicPoint.
	//Also doing it this way allows us to have a generalized movement from tano although
	//the MusicPoint is already generalized once it is just (pos,row,x_start,x_end)
	new_mp : MusicPoint = MakeMusicPoint(mp.music_pt_float, to_row, to_x_start, to_x_end);
	return new_mp;
}

GetAllMusicPtFloat :: inline (row_index : int, x_pos : $T, all_music_pts : [] MusicPoint) -> [] float64 {
	return GetAllMusicPtPosByPosition(row_index, x_pos, all_music_pts, float64);
}

/*TODO Likely change the name of this to just GetAllMusicPts or something like that.
ALSO int is currently the default type because of old code but eventually we could make it
float64 or MusicPoint depending on whichever return type is used most.

TOOD Should pass in MemoryUnit here so we can change to float64 later
TODO We can make a for_expansion version of this so we don't need to accumulate memory here.
*/
GetAllMusicPtPosByPosition :: inline (
	row_index : int,
	x_pos : $T,
	all_music_pts : [] MusicPoint,
	//TODO Maybe this should only return float64 and MusicPoint if we only use that
	$type : Type = int)
-> [] type
{
#assert(AllOrEquals(type, .[int,float64,MusicPoint,*MusicPoint]));

	music_pt_poses : [..] type;
	music_pt_poses.allocator = context.allocator;
	//TODO If x_pos and row_index are > row_size then we should print out and error or pause on the debugger eventually.
	//For now we do nothing but we could print it out.
	for music_pt : all_music_pts {
		if ValueInMusicPt(x_pos, row_index, music_pt) {
   		#if type == int array_add(*music_pt_poses, music_pt.music_pt_pos);
	   	else #if type == float64 array_add(*music_pt_poses, music_pt.music_pt_float);
	   	else #if type == MusicPoint array_add(*music_pt_poses, music_pt);
	   	else #if type == *MusicPoint array_add(*music_pt_poses, *all_music_pts[it_index]);
	   }
	}

	return music_pt_poses;
}

MusicPtStartInRange :: inline (x_start : $T, mp : MusicPoint, x_end : T, EPSILON : float64 = DEFAULT_MP_EPSILON) -> bool {
#assert(T == float64 || T == int);
	//x_start = 1 and x_end = 2 then we want a point starting on 1 to be valid but a point starting on 2 not to be within epsilon
	// in_range : bool = (mp.x_start_float >= x_start - EPSILON && mp.x_start_float <= x_end - EPSILON);
	// return in_range;
	return InEpsilonRangeLeft(mp.x_start_float, cast(float64) x_start, cast(float64) x_end, EPSILON);
}
//MusicPoint either starts or ends in the given range.
MusicPtInRange :: inline (x_start : $T, mp : MusicPoint, x_end : T, EPSILON : float64 = DEFAULT_MP_EPSILON) -> bool {
#assert(T == float64 || T == int);
	//TODO Update to ones below once we can test everywhere
	// in_range : bool = (mp.x_start >= x_start && mp.x_start < x_end) ||
	//    (mp.x_end > x_start && mp.x_end <= x_end);	
	// in_range : bool = (mp.x_start_float >= x_start - EPSILON && mp.x_start_float < cast(float64) x_end) ||
	//    (mp.x_end_float > cast(float64) x_start && mp.x_end_float <= x_end + EPSILON);	

	//TODO I think I can use this now but I want to run the tests first before checking.
	//Using Left and then Right epsilon seems to work since we want to include the RHS end range.
	//IS this actually what we want? I think so but worth thinking about as well.
	//This feels more intuitive and is the way we had it for ints above.
	//x_start [0-2.0[ and x_end ]0-2.0]
	in_range : bool = InEpsilonRangeLeft(mp.x_start_float, cast(float64) x_start, cast(float64) x_end, EPSILON) ||
	   InEpsilonRangeRight(mp.x_end_float, cast(float64) x_start, cast(float64) x_end, EPSILON);
	//x_start [0-2.0] and x_end ]0-2.0]
	// in_range : bool = InEpsilonRangeOpen(mp.x_start_float, cast(float64) x_start, cast(float64) x_end, EPSILON) ||
	//    InEpsilonRangeRight(mp.x_end_float, cast(float64) x_start, cast(float64) x_end, EPSILON);
	//x_start [0-2.0[ and x_end [0-2.0[
	// in_range : bool = InEpsilonRangeLeft(mp.x_start_float, cast(float64) x_start, cast(float64) x_end, EPSILON) ||
	//    InEpsilonRangeLeft(mp.x_end_float, cast(float64) x_start, cast(float64) x_end, EPSILON);

	return in_range;
}
MusicPtInRowRange :: inline (start_row : int, mp : MusicPoint, end_row : int) -> bool {
	in_row : bool = mp.row_index >= start_row && mp.row_index <= end_row;
	return in_row;
}

//TODO Where should we put this?
//TODO Should call this TanoLoop for clarity or just keep it as is to replicate the language?
//Maybe call it TanoMusicPts
TanoLoop :: struct {
	t : tano;
	all_music_pts : [] MusicPoint;
	//TODO should we grab this in the for_expansion or grab the music point array beforehand?
	// mspace_index : int;
	//TODO Do a version where we only check row
}
for_expansion :: (tl: TanoLoop, body: Code, flags: For_Flags) #expand {
	t_norm : tano = NormalizeTano(tl.t);
	found_index : int = 0;
	//TODO If we wanted reverse and the music_pts are sorted, then we could just reverse here.
	//TODO If we have a all_row setting, then we can just check row 
	for * mp : tl.all_music_pts {
		in_tano : bool = InTanoAssumeNorm(mp, t_norm);
		if in_tano {
			`it := mp;
			#if flags & .POINTER {
			`it_index := mp;
			} else {
			`it_index := mp.*;
			}

			#insert body;

			found_index += 1;
	   }
	}
}

//NOTE : This assumes that the tano is normalized for efficiency
//TODO could make another function that adjusts the tano every time.
InTanoAssumeNorm :: inline (mp : MusicPoint, t : tano) -> bool {
	in_row_range : bool = MusicPtInRowRange(t.row_start, mp, t.row_end);
	in_x_range : bool = MusicPtInRange(t.x_start, mp, t.x_end);
	in_tano : bool =  in_row_range && in_x_range;
	return in_tano;
}
InTanoNorm :: inline (mp : MusicPoint, t : tano) -> bool {
	t_adj : tano = NormalizeTano(t);
	return InTanoAssumeNorm(mp, t_adj);
}

//TODO We could to replace MusicPoint with this eventually, for now we could rename it NeumeData.
//They could be the same struct or keep it separate depending on how we decide to name them.
Neume :: struct {
	//TODO Should we call this something else or is svara ok? suram?
	svara : float64;
	row : int;
	x_start : float64;
	x_end : float64;
}
//TODO Could add a flag to sort values in here by x or row or in reverse
TanoSortType :: enum {
	DEFAULT; //x and row forward
	X_REVERSE;
	ROW_REVERSE;
	// X_ROW_REVERSE;
}
GetTanoMusicPts :: inline (
	t : tano,
	all_music_pts : [] MusicPoint,
	sort_type : TanoSortType = .DEFAULT,
	$type : Type = MusicPoint)
-> [] type
{
#assert(AllOrEquals(type,.[int,float64,MusicPoint,*MusicPoint,Neume]));

	music_pts : [..] type;
	music_pts.allocator = context.allocator;

	t_norm : tano = NormalizeTano(t);
	for mp : all_music_pts {
		in_tano : bool = InTanoAssumeNorm(mp, t_norm);
		if in_tano {
			#if type == *MusicPoint array_add(*music_pts, *all_music_pts[it_index]);
			else #if type == int array_add(*music_pts, round_to_int(mp.music_pt_float));
			else #if type == float64 array_add(*music_pts, mp.music_pt_float);
	    	else #if type == MusicPoint array_add(*music_pts, mp);
	    	//TODO We can remove this case eventually once MusicPoint and Neume are the same struct
			else #if type == Neume array_add(*music_pts, Neume.{mp.music_pt_float, mp.row_index, mp.x_start_float, mp.x_end_float});
	   }
	}

	#if type == MusicPoint || type == *MusicPoint {
	if sort_type == {
	case .X_REVERSE;
		quick_sort(music_pts, (m1,m2) => m2.x_start_float - m1.x_start_float);
	case .ROW_REVERSE;
		quick_sort(music_pts, (m1,m2) => m2.row_index - m1.row_index);
	}
	}

	return music_pts;
}
GetTanoNumOfPoints :: inline (t : tano, all_music_pts : [] MusicPoint) -> int {
	dim : int = 0;
	t_norm : tano = NormalizeTano(t);
	for mp : all_music_pts {
		in_tano : bool = InTanoAssumeNorm(mp, t_norm);
		if in_tano dim += 1;
	}
	return dim;
}

//TODO Update this function and use it in mov for music, then test
//and also check rendering and audio
//Copy all notes in range and then have them all start
//relative to the min_x_start in the set.
//TODO We can make a for_expansion version of this so we don't need to accumulate memory here.
GetAllMemoryMusicPtsInRange :: inline (
	x_start : $T, x_end : T,
	row_index : int,
	all_music_pts : [] MusicPoint,
	$type : Type = MusicPoint)
-> [] type
{
#assert(AllOrEquals(type,.[MusicPoint,*MusicPoint]));

	music_pts : [..] type;
	music_pts.allocator = context.allocator;

	for mp : all_music_pts {
		in_range : bool = MusicPtInRange(x_start, mp, x_end);
		if in_range && row_index == mp.row_index {
			#if type == *MusicPoint array_add(*music_pts, *all_music_pts[it_index]);
	    	else array_add(*music_pts, mp);
	   }
	}

	return music_pts;
}

//TODO REMOVE ALL THE INT CODE FROM HERE ONCE float64 x works since that should be the only way.
//We can just cast(float64) if we are passing in an int then.
UpdateMusicPtsFromMinStart :: inline (
	music_pts : [] MusicPoint, 
	to_start_x : $T, to_row : int,
	row_size : int) 
{
//TODO Remove this and just use float64 only once we 
#assert(AllOrEquals(T, .[int, float64]));
	//TODO This should be float eventually since the x values should be float.
	#if T == int {
	min_x : int = ArrayFindMinByNameId(music_pts, "x_start", S64_MAX);
	} else {
	min_x : float64 = ArrayFindMinByNameId(music_pts, "x_start_float", FLOAT64_MAX);		
	}
	for * music_pts {
		it.row_index = to_row;
		#if T == int {
		from_min_x : int = it.x_start - min_x;
		x_length : int = it.x_end - it.x_start;
		it.x_start = to_start_x + from_min_x;
		it.x_start_float = cast(float64) it.x_start;
		it.x_end = ClampMax(it.x_start + x_length, row_size);
		it.x_end_float = cast(float64) it.x_end;
		} else {
		from_min_x : float64 = it.x_start_float - min_x;
		x_length : float64 = it.x_end_float - it.x_start_float;
		it.x_start_float = to_start_x + from_min_x;
		it.x_start = round_to_int(it.x_start);
		it.x_end_float = ClampMax(it.x_start_float + x_length, cast(float64) row_size);
		it.x_end = round_to_int(it.x_end);
		}
		//We remove right now, we could increase row_size. We could also not have a row_size
		//and just render based on max note or a user defined value.
		//Leaving it off for now until we decide if we want row_size at all.
		// if it.x_start > perm.all_data.global_rules.row_size {
		// 	remove it;
		// 	continue;
		// }
		//TODO Need to just use these floats eventually
		//Left this commented so the tests keep failing so we can update everything
		//when I update the asm to allow x float everywhere.
		// it.x_start_float = cast(float64) it.x_start;
		// it.x_end_float = cast(float64) it.x_end;
	}
}

//TODO eventually may want to have this be an octave range
//or a different total visible range of music_pts
//ie min_music_pt_pos to max_music_pt_pos
FilterMusicPtsInOctave :: inline (
	input_music_pts : [] MusicPoint,
	current_octave : int,
	system_size : int,
	allocator : Allocator = temp)
-> [] MusicPoint
{
	filtered_music_pts : [..] MusicPoint;
	filtered_music_pts.allocator = allocator;

	for music_pt : input_music_pts
	{
		music_pt_octave : int = music_pt.music_pt_pos / system_size;
		if music_pt_octave == current_octave {
			array_add(*filtered_music_pts, music_pt);
		}
	}

	return filtered_music_pts;
}

FilterMusicPtsInView :: inline (
	input_music_pts : [] MusicPoint,
	base_note : int,
	system_size : int,
	allocator : Allocator = temp)
-> [] MusicPoint
{
	filtered_music_pts : [..] MusicPoint;
	filtered_music_pts.allocator = allocator;

	top_note : int = base_note + system_size;
	for music_pt : input_music_pts
	{
		if music_pt.music_pt_float >= cast(float64) base_note &&
		   music_pt.music_pt_float <  cast(float64) top_note
		{
			array_add(*filtered_music_pts, music_pt);
		}
	}

	return filtered_music_pts;
}

MusicPtsByPitch :: struct {
	music_pts : [..] MusicPoint;
	music_pts.allocator = temp;
}

/*MusicPt
	by default we return the first MusicPoint of each pitch found
*/
RemoveMusicPtsDuplicatePitch :: inline (
	input_music_pts : [] MusicPoint,
	allocator : Allocator = temp)
-> [] MusicPoint
{
	all_music_pts_by_pitch : [..] MusicPtsByPitch;
	all_music_pts_by_pitch.allocator = temp;
	for music_pt : input_music_pts
	{
		music_pts_by_pitch, found_pitch :=
			ArrayFindFirstByNameId(all_music_pts_by_pitch, music_pt.music_pt_pos, "music_pts[0].music_pt_pos");

		if found_pitch {
			array_add(*music_pts_by_pitch.music_pts, music_pt);
		}
		else {
			new_music_pts_by_pitch : MusicPtsByPitch;
			array_add(*new_music_pts_by_pitch.music_pts, music_pt);
			array_add(*all_music_pts_by_pitch, new_music_pts_by_pitch);
		}
	}

	no_duplicates : [..] MusicPoint;
	no_duplicates.allocator = allocator;
	for music_pts_by_pitch : all_music_pts_by_pitch
	{
		array_add(*no_duplicates, music_pts_by_pitch.music_pts[0]);
	}

	return no_duplicates;
}

/*End of tano code
*/

ArrayData :: struct {
	count : int;
	data_address : int;
}
AsmArray :: struct($array_type : Type) {
	count : int;
	data_address : int;
}
AsmPointer :: struct($p_type : Type) {
	data_address : int;
}

//DOC bool in language is 64-bits so we just use an int
//and then use functions to convert here to bool type
AsmBool :: struct {
	value : int;
}
ToAsmBool :: inline (b : bool) -> AsmBool {
	if b return .{1};
	else return .{0};
}
AsmBoolToBool :: inline (ab: AsmBool) -> bool {
	//This is the same as cast(bool) int but more explicit for clarity and remembering.
	if ab.value == 0 return false;
	else return true;
}
AsmString :: struct {
	count : int;
	data_address : int;
}



/*Start of row data
TODO Put all row data here so we have it in 1 place and then maybe we can make it's own module eventually.
Maybe put tuning and geometries all in 1 module or just here
*/

//TODO should we separate music_pts/OscWave out for multi-beat music_pts and more efficient use of space
//TODO then we would also only have to loop through music_pts instead of all values
Space2D :: struct {
	#as using space : DimensionalSpace;
	transform : Matrix2F;
	//TODO move this back into LinearPitchSpace and CircularPitchClassSpace
	hover_point_index : int;
	//TODO could put start_index and end_index to know exact positions in all_space_points array
}

/*TODO
	these should be spatially partitioned in a separate table that is acessed through an optimized spatial hash
	stack overflow hash - hashing 2D, 3D and...

	should we have entities or elements in general?
	seems like DimensionalSpace may just be an Entity struct
	with basic dimensions and positions and other variables
	that are needed by all entities (eg mesh_id...)
*/
//TODO how should we generate ids?
DimensionalSpace :: struct {
	//TODO could maybe use a dspace id to type table
	//TODO update dspace data to work with indexed by id model
	dspace_id : int;
	// dpsace_type : Type;
	//TODO should we eventually do Matrix3x2F for efficiency?
	//TODO do we really need both of these world vectors?
	dspace_world_center : Vector2F;
	dspace_world_pos : Vector2F;
	dspace_dim : Vector2F; //TODO should this be an int vector?
	dspace_dim_int : Vector2I;
	dspace_point_dim : Vector2F;
	//TODO keep index in here for point locations of this dspace

	//TODO dspace might also have a invariant_id
	//TODO dspace might be related to one scale
}

/*TODO
	for clarity and efficiency, we can likely separate linear_space_points
	from higher_space_points

TODO We could store op_space_id in here and then index and sort by op_space_id
and then we could also remove by op_space_id more easily.
*/
//TODO CAN CHANGE NAME TO SpacePoint2D
//TODO CHANGE NAME TO COORDINATE
//TODO do we make points dspace specific (different dimensions)
//TODO currently this is for chord_s2 and works for linear and circular
//TODO 1D version would have only int for int_pos and no text and maybe no color
SpacePoint :: struct {
	//MusicPt : dspace_id and rel_pos are enough for a unique space_point_id
	id : int;
	dspace_id : int;
	//TODO We could have OpDSpaceType in here now or EntityType.

	//MusicPt : These are the original positions of the music_pt (maybe we can remove later)
	//Leaving here now for convenience
	/*TODO should probably remove this and only have rel_pos and dspace_pos
		this unnecessarily complicates updating

		also may be worth keeping since we may not move dspaces very often
		space vs speed argument

		TODO Should this be float64 for world_pos?
	*/
	world_pos : Vector2F;
	//TODO could store a mesh_id in here at some point to have different meshes
	//TODO this is only being used for linear spaces now for alternative views
	//such as log and linear and overlay and for pitch class profiles
	rect_mesh : Rectangle2;
	//TODO Can likely re
	rect_dim : Vector2F;
	//TODO eventually need to have a separate collider rect instead 

	//TODO Can likely remove 1 or both of these and just use world_pos (which should probably be float64)
	//TODO can probably remove one of these, or rename to
	//original_rel_pos and transformed_rel_pos
	rel_pos : Vector2F; //MusicPt : can derive octave, tritave, etc... from static rel_pos and scale data
	//MusicPt : These are both the dimensional space and cam space we actually use for rendering and checks
	dspace_pos : Vector2F;


	//MusicPt : int_pos used for chord space 2 fundamental region points values
	//and also used for linear pitch space to cache music_pt values with octave
	//TODO should we move it out if not used by anything else?
	//TODO this is probably just a cached version of the tuning_pitch music_pt_pos
	//TODO should we remove it then?
	int_pos : Vector2I;
	fun_region_float : [2] float64;

	//Can use this on a filter if needed to not draw
	//It looked weird on 2D as an outline though...
	//Maybe I can draw something else to show points off access
	//TODO Not really using this anymore so we can remove if we don't need
	//but am leaving here for now in case we want to separate
	not_base_point : bool;

	color : Vector4F;
	text : string;
	//TODO should we cache beat in here? or beat in separate table to dspace
	//TODO if point data is completely separated by dimension, then we can cache tuning music_pts in here
}

/*TODO We can differentiate here between linear and non-linear with the same
tuning_system but technically these are different points so maybe the dspace should
be different. For now we only have 1 anyways. The rationale here is that each tuning
system should have 1 representation. Otherwise we cant really tell which is which.
We can add 2 separate point sets later if needed or just force equal rendering
at the rendering loop. I am not sure if it is needed right now so let's see until later if we do.
Making 2 sets of points keep everything the same and we just add that.

TODO Should we put this in LinearPitchSpace like we did for CircleSpace?
Right now we don't have a LinearPitchSpace since we just create the SpacePoint
but maybe it would make sense since we sort of need it for op_spaces as well.
Let's see how we do op_space and then we can homogenize.

IF WE WANT DIFFERENT COLORS for the same tuning_system then we could create that
in separate data so that it does not need to overlap.
*/
LinearToTuningSystem :: struct {
	// view : LinearPitchSpaceView;
	dspace_id : int;
	tuning_system_id : int;
}
//NOTE : This is 64-bit because we use it in asm which requires all 64-bit values right now.
LinearPitchSpaceView :: enum {
	RATIO_PROPORTIONAL; //default
	FORCE_EQUAL;

	//TODO I think we can remove the other options here now since we only use the 2 above. Keeping just in case for now.
	// EQUAL;
	// LOG_RATIO;

	// //TODO could be interesting for experimentation later
	// OVERLAY;
	// SIDE_BY_SIDE;

	// //TODO could have this as a view so we render out and select
	// //grouped music_pts and points properly
	// DSPACE_GROUP;
} @LibraryAsmGen
LinearPitchSpaceOrientation :: enum {
	VERTICAL;
	HORIZONTAL;
}
DEFAULT_LINEAR_SPACE_SIZE :: Vector2F.{2,12};
DEFAULT_LINEAR_POINT_SIZE :: Vector2F.{2,1};
/*TODO
	should we store music_pt_set_id directly in here?
	yes if we continue to only have 1 music_pt_set per dspace

	TODO should we have a separate LinearSpace for music_lanes and for op_spaces?
	this way we can optimize for each case. eg music_lanes are systematically
	associated to rhythm by their op_grid_pos so we would not need PitchDSpaceToRhythmSection
	for music_lanes and could use them only for op_space

	***TODO Yes should have separate structs for each since
	they will likely be very different. Likely for rows we will
	have dspaces just to cache values and dimensions but
	otherwise things will be stored in the rows or x_index.***
*/
LinearPitchSpace :: struct {
	#as using linear_space : Space2D;
	//music_pt_set_id : int;
	base_world_pos : Vector2F;
	octave_dim : Vector2F;
	orientation : LinearPitchSpaceOrientation;
	/*TODO not sure how we should go about doing the different views
		for example what if we want it to be overlayed 
		could set view to both since we'd have to manage rendering differences
		such as color and opacity
	*/
	view : LinearPitchSpaceView;
	//TODO make a separate LinearPitchSpace struct and move this in?
	//TODO octave can be less bits of course, probably an s8 is fine
	current_octave : int;
	//TODO maybe we can just draw which octave we're at somehow
	octave_text : string;

	/*Note : can potentially split out LinearPitchSpace
	in music_lane from the ones in op_space so will separate
	the data internally for now until we actually do it
	*/
	//TODO can use this for music_lane offset
	// grid_rel_pos : Vector2F;
	// grid_pos : Vector2I;
}
//Asm specific create row data
AsmCreateRowData :: struct {
	octave_height : float64;
	row_height : float64;
	muted_row : AsmBool;
	//TODO Should we make this it's own struct?
	row_system_type : RowSystemType;
	row_system_id : int;
	row_sub_system_id : int;
	row_sections : AsmArray(RowSectionData);
	row_midi_data : AsmRowMidiData;
} @LibraryAsmGen
RowSectionData :: struct {
	linear_view : LinearPitchSpaceView;
	tuning_system_id : int;
	//TODO Should this be length or x_start and x_end for convenience?
	//This way eliminates the possibility of overlapping errors.
	x_length : int;
} @LibraryAsmGen

MakeRowSectionData :: inline (tuning_system_id : int, x_length : int, linear_view : LinearPitchSpaceView = .RATIO_PROPORTIONAL) -> RowSectionData {
	section_data : RowSectionData = ---;
	section_data.linear_view = linear_view;
	section_data.tuning_system_id = tuning_system_id;
	section_data.x_length = x_length;
	return section_data;
}

MUSIC_ROW_GAP : float = 1;
CreateMusicRow :: inline (
	create_row_data : CreateRowData,
	all_mspace_data : [] MusicSpaceData,
	global_rules : GlobalRules,
	all_tuning_systems : [] TuningSystem,
	all_tuning_pitches : [] TuningPitch,
	//TODO Need to pass these through shared library and then test in dynamic library and check mac
	all_linear_to_tuning_system : *[..] LinearToTuningSystem,
	all_linear_pitch_spaces : *[..] LinearPitchSpace,
	all_space_points : *[..] SpacePoint) 
-> MusicLaneRow {
	mspace_data, found_mspace := ArrayFindFirstByNameId(all_mspace_data,
		create_row_data.mspace_id, "mspace_id");
	//TODO We should either check this externally or return this as an error.
	//Probably an error is best for dynamic libraries eventually.
	assert(found_mspace);

	//TODO Should we push this halfway down row_height here or leave it to the player to decide and just 
	//have the lowest point be what the player inputs be default?
	//TODO Maybe we don't need this and we just compute it directly if/else.
	//ALSO if we don't allow adding a row by index directly here and the player has to do it, then we can just have this 1 way.
	// next_lane_world_base_pos : Vector2F = ComputeNextMusicLaneWorldPos(all_mspace_data[0].all_music_lane_rows);
	//Center the first dspace to the middle of screen. Can remove this if unnecessary
	next_row_world_base_pos : Vector2F = Vector2F.{0,-0.25 * create_row_data.row_height};
	//TODO This has to be allowed to grow up or down depending on a global setting so people can adjust either way.
	// If we don't have any rows, then we use the default world_pos for the row.
	if mspace_data.all_music_lane_rows.count > 0 {
		//TODO This should be += if we have the opposite directions and add rows upwards if we want to allow that.
		last_row_y : float = peek(mspace_data.all_music_lane_rows).row_world_base_start.y;
		//TODO We can just allow adjusting the gap here instead
		next_row_world_base_pos.y = last_row_y - create_row_data.row_height - MUSIC_ROW_GAP;
	}

	//TODO How should we compute this?
	next_row_index : int = mspace_data.all_music_lane_rows.count;

	DEFAULT_MUSIC_LANE_ID : int = 0;
	//TODO Leaving here for now just in case but we can remove it if everything is fine.
	#if 0 {
	row : MusicLaneRow = MakeMusicLaneRow(DEFAULT_MUSIC_LANE_ID, RowSystemType.internal_pitch, MusicLaneType.MEMORY, 
		next_row_world_base_pos, next_row_index, create_row_data.row_height, use_create_row_data = true, create_row_data);
	array_add(*mspace_data.all_music_lane_rows, row);
	} else {
	row : *MusicLaneRow = array_add(*mspace_data.all_music_lane_rows);
	//We are using negative row_ids/row_indices now for hidden rows
	assert(context.ALL_NEXT_IDS.NEXT_MUSIC_LANE_ROW_ID >= 0);
	row.id = context.ALL_NEXT_IDS.NEXT_MUSIC_LANE_ROW_ID;
	context.ALL_NEXT_IDS.NEXT_MUSIC_LANE_ROW_ID += 1;
	// row.music_lane_id = DEFAULT_MUSIC_LANE_ID;
	row.row_world_base_start = next_row_world_base_pos;
	row.total_row_index = next_row_index;
	row.octave_height = create_row_data.octave_height;
	row.row_height = create_row_data.row_height;
	row.row_midi_data = create_row_data.row_midi_data;
	row.row_system_type = create_row_data.row_system_type;
	row.system_id = create_row_data.row_system_id;
	// row.sound_on = create_row_data.sound_on;
	row.is_muted_row = create_row_data.muted_row;
	// row.num_of_points = GetRowNumOfPoints(create_row_data.tuning_system_count, create_row_data);
	}

	last_section_x : int = 0;
	for row_section : create_row_data.row_section_data {
		// linear_tuning : LinearToTuningSystem = 
		// 	GetOrCreateLinearTuning(row_section.tuning_system_id, row_section.linear_view, all_data);
		linear_tuning : LinearToTuningSystem = GetOrCreateLinearTuning(
			row_section.tuning_system_id, 
			row_section.linear_view, 
			all_tuning_systems, 
			all_tuning_pitches,
			all_linear_to_tuning_system,
			all_linear_pitch_spaces,
			all_space_points);

		section : *SectionToRow = array_add(*mspace_data.all_section_to_row);
		//TODO Should this be index or id? Id would allow row movement without having to update this section.
		section.row_id = row.id;
		section.dspace_id = linear_tuning.dspace_id;
		section.start_x = last_section_x;
		section.end_x = last_section_x + row_section.x_length;
		section.tuning_system_id = linear_tuning.tuning_system_id;

		//TODO Should check that last_section_x == global row_size after this loop i think.
		//So we would have to set the row_size beforehand OR take the first row or something like that.
		//We could force all rows to be row_size OR we just take max row here and set that to global row size.
		//Maybe force is better first for consistency and later we can see if it makes sense to allow shorter rows.
		//Different row sizes can be allowed across different musical spaces eventually.
		last_section_x = section.end_x;
	}

	row.row_size = last_section_x;
	if !mspace_data.is_fixed_audio_row_size {
		mspace_data.mspace_audio_row_size = max(row.row_size, mspace_data.mspace_audio_row_size);
	}


	linear_grid_dim : Vector2F = ---;
	linear_grid_dim.x = global_rules.memory_unit_width * last_section_x;
	linear_grid_dim.y = create_row_data.row_height;
	//TODO We could store this rectangle in a separate linear space for op space struct with grid_size etc...
	// world_min_pos : Vector2F = points_in_space[0].rect_mesh.min + row.row_world_base_start;
	//row.row_world_base_start is the min_center so we subtract half the width the get the bottom left
	//without having to use the space_points so we can compute this anywhere instead.
	world_min_pos : Vector2F = row.row_world_base_start - Vector2F.{0.5*global_rules.memory_unit_width,0};
	linear_grid_rect : Rectangle2 = RectMinDim(world_min_pos, linear_grid_dim);
	linear_world_center : Vector2F = GetCenter(linear_grid_rect);

	coll : *CollisionEntity = array_add(*mspace_data.all_base_collision_entities);
	coll.entity_id = row.id;
	coll.entity_type = EntityType.LANE_ROW_WITH_SECTIONS;
	coll.shape = CollisionShape.RECTANGLE;
	coll.rect = RectCenterDim(linear_world_center, linear_grid_dim);

	return row;
}
GetOrCreateLinearTuning :: inline (
	tuning_system_id : int, 
	linear_view : LinearPitchSpaceView, 
	all_tuning_systems : [] TuningSystem,
	all_tuning_pitches : [] TuningPitch,
	all_linear_to_tuning_system : *[..] LinearToTuningSystem,
	all_linear_pitch_spaces : *[..] LinearPitchSpace,
	all_space_points : *[..] SpacePoint) 
-> LinearToTuningSystem
{
	tuning_system, found_tuning_system := 
		ArrayFindFirstConstByNameId(all_tuning_systems, tuning_system_id, "id");
	//We just return default tuning_system for now to avoid error checking everywhere.
	if !found_tuning_system {
		//TODO Could generalize this to print to inner console.
		print("Invalid tuning_system_id : %\n", tuning_system_id);
		tuning_system = all_tuning_systems[0];
	}
	// if !found_tuning_system {
	// 	//TODO Can likely log this error or send back to player. Maybe better to check input before running it instead of everywhere.
	// 	//Unless of course we allow an api and then we would have to consider other things.
	// 	print("Invalid tuning_system_id : %\n", tuning_system_id);
	// 	return linear_to_tuning_system, false;
	// }

	linear_to_tuning_system, found_linear_to_tuning_system := 
		ArrayFindFirstConstByNameId(all_linear_to_tuning_system.*, 
			tuning_system.id, "tuning_system_id");

	/*TODO We could NOT create SpacePoints for equal sized and just draw them at rendering. That seems beneficial
	actually so maybe do that and only get points if we have proportional. But the proportional, we could
	also just compute it directly from the tuning_pitches.
	COULD Not create SpacePoint at all and store the log length ratio in TuningPitch but then we have no visual
	abstraction and so SpacePoint allows us to make these linear spaces without a TuningSystem.

	TODO Should we be creating here or create when we create the TuningSystem?
	*/
	if !found_linear_to_tuning_system {
		//NOTE : We no longer store it but use to to create the points for now since we still have the old
		//precise linear rendering method.
		//TODO Can we remove this altogether and just use the row for MakeLinearSpacePoints?
		//TODO Maybe we can create LinearPitchSpace from row for convenience and then remove it later if it's unnecessary.
		//NOTE : It is good to keep this for now so that the SpacePoints remain consistent
		//with differen dspace_ids
		linear : *LinearPitchSpace = array_add(all_linear_pitch_spaces);
		linear.dspace_id = context.ALL_NEXT_IDS.DSPACE_ID;
		defer context.ALL_NEXT_IDS.DSPACE_ID += 1;
		//TODO We have this here in case we want to force an unequal temperament to be equal.
		//We can remove later if we do the forcing in the rendering directly for efficiency.
		linear.view = linear_view;

		//TODO Should we call this here or check the FORCE_EQUAL type here and separate here directly.
		//Let's see once generalize and use the same SpacePoints everywhere
		//TODO CAN WE JUST CREATE FROM ROW DIRECTLY? Does the linear allow more generalized?
		space_points : [] SpacePoint = MakeRatioProportionalPoints(tuning_system.music_pt_count, linear,
			tuning_system, all_tuning_pitches);
		ArrayAddAll(space_points, all_space_points);

		linear_to_tuning_system.dspace_id = linear.dspace_id;
		linear_to_tuning_system.tuning_system_id = tuning_system.id;
		array_add(all_linear_to_tuning_system, linear_to_tuning_system);
	}

	return linear_to_tuning_system;
}
MakeRatioProportionalPoints :: inline (
	num_of_points : int,
	linear : LinearPitchSpace,
	//TODO Can have a generalized version of this with just linear_diff data between points
	//and then call that function with a tuning_system.
	tuning_system : TuningSystem,
	all_tuning_pitches : [] TuningPitch,
	color_data : PointColorData = .{})
-> [] SpacePoint
{
	array_tuning_pitches : [] TuningPitch;
	if linear.view != LinearPitchSpaceView.FORCE_EQUAL {
		array_tuning_pitches = 
			ArrayFindAllVarName(all_tuning_pitches, tuning_system.id, "tuning_system_id", temp);
		assert(tuning_system.music_pt_count == array_tuning_pitches.count);
	}

	total_height : float;
	equal_point_height : float = linear.octave_dim.y / tuning_system.music_pt_count;
	points_in_space : [] SpacePoint = NewArray(num_of_points, SpacePoint, false,, temp);
	for p_index : 0..num_of_points-1 {
		point : *SpacePoint = *points_in_space[p_index];
		point.id = context.ALL_NEXT_IDS.POINT_ID;
		context.ALL_NEXT_IDS.POINT_ID += 1;
		point.dspace_id = linear.dspace_id;
		point.color = GetPointColor(p_index, tuning_system, color_data);
		point.int_pos.x = p_index;

		/*TODO We only use dspace_pos anymore for relative rendering so maybe that's the only thing we should set now
		for linear scissor and have separate points for that.
		Will leave it for now but we can definitely do that and separate from the old function here.
		Will keep the same for consistency for now.
		*/
		//Forcing equal is needed for unequal temperaments where we want them to look equal.
		//TODO We may not need this at all if we force in rendering instead.
		//Although I guess this allows it to work here without any changes in rendering code.
		if linear.view == LinearPitchSpaceView.FORCE_EQUAL {
			//NOTE : ONLY THE dspace_pos is actually being used here
			//Everything else is left for convenience but does not do anything
			//We need to make it proportional here so we can multiple by octave_height at runtime.
			//This makes it consistent with ratio points and also allows octave adjustments more easily.
			//TODO This is all we use now so we could use TuningPitch directly for the base world linear scissor space.
			//Would just need to separate out color and then we could us it instead.
			//Just use TuningPitch and color then.
			point.dspace_pos = Vector2F.{
				p_index/cast(float)tuning_system.music_pt_count,
				1.0/tuning_system.music_pt_count};
			//NOTE : This does not do anything. Maybe I should comment out for clarity.
			point.world_pos = linear.base_world_pos;
			point.world_pos.y += p_index * equal_point_height;
			point.rect_dim = MakeV2F(linear.octave_dim.x, equal_point_height);
			point.rect_mesh = RectMinCenterDim(point.world_pos, point.rect_dim);
			point.rel_pos.y = point.world_pos.y - linear.base_world_pos.y;
		} else {
			octave_index, mod_index := ComputeQuotientAndRemainder2(p_index, tuning_system.music_pt_count);
			tuning_pitch : TuningPitch = array_tuning_pitches[mod_index];

			//TODO This is all we use now so we could use TuningPitch directly for the base world linear scissor space.
			//Would just need to separate out color and then we could us it instead.
			//Just use TuningPitch and color then.
			point.dspace_pos = Vector2F.{tuning_pitch.linear_from_start, tuning_pitch.linear_to_next};
			// point.dspace_pos = Vector2F.{total_height, length_ratio};
			// print("total_height = %\n, linear = %\n", total_height, tuning_pitch.linear_from_start);

			//TODO NONE OF THIS IS USED ANYMORE We can remove eventually or maybe we will reuse for op_space linear spaces
			//NOTE : We can do everything from length_ratio with accumulation. Leaving here for reference.
			// ratio_with_octave : float = RatioWithOctaveBase(tuning_pitch.ratio_from_start, octave_index, tuning_system.compass_interval);
			// start_ratio : float = LogRatioToLinear(ratio_with_octave, tuning_system.compass_interval);
			// length_ratio : float = LogRatioToLinear(tuning_pitch.ratio_to_next_music_pt, tuning_system.compass_interval);
			length_ratio : float = tuning_pitch.linear_to_next;

			//TODO We don't use any of these for linear scissor, only dspace_pos and color. So maybe that is worth optimizing
			//for to no longer use SpacePoint since we only need 6 floats now for each point.
			point.world_pos = linear.base_world_pos;
			// point.world_pos.y += start_ratio * linear.octave_dim.y;
			point.world_pos.y += total_height * linear.octave_dim.y;
			point.rect_dim = MakeV2F(linear.octave_dim.x, linear.octave_dim.y * length_ratio);
			//NOTE : From min_center so we only have to adjust the height on the top
			point.rect_mesh = RectMinCenterDim(point.world_pos, point.rect_dim);

			// if p_index == 0 {
			// 	linear.dspace_world_pos.y = linear.base_world_pos.y + 0.5*point.rect_dim.y;
			// }
			// point.rel_pos.y = point.world_pos.y + (0.5*point.rect_dim.y) - linear.dspace_world_pos.y;
			point.rel_pos.y = point.world_pos.y - linear.base_world_pos.y;
			// point.dspace_pos = Vector2F.{tuning_pitch.linear_from_start, length_ratio};
			// point.fun_region_float[0] = total_height;
			// point.fun_region_float[1] = length_ratio;

			total_height += length_ratio;
		}
	}

	return points_in_space;
}
//TODO Where should we put these color compile-time arrays?
//TODO Can make default for other default implemented tuning systems as well like PYTHAGORUS and other eq temps.
//Maybe one for 19 and 24 and 48 and 53 or anything thats used more.
EQ_12_POINT_COLORS :: Vector4F.[
	GREY_DARKER_V, 
	GREY_BLACK_V, 
	GREY_DARKER_V,
	GREY_BLACK_V,
	GREY_DARKER_V,
	GREY_DARKER_V,
	GREY_BLACK_V,
	GREY_DARKER_V, 
	GREY_BLACK_V, 
	GREY_DARKER_V,
	GREY_BLACK_V,
	GREY_DARKER_V
];
//TODO How do we use this and the above for 12 system? Could pass in a default shape type for example
//or an extra int value as a type to differentiate between default.
EQ_12_POINT_COLORS_CIRCLE :: Vector4F.[
	LIGHT_BROWN, 
	GREY_DARKER_V, 
	LIGHT_BROWN,
	GREY_DARKER_V,
	LIGHT_BROWN,
	LIGHT_BROWN,
	GREY_DARKER_V,
	LIGHT_BROWN, 
	GREY_DARKER_V, 
	LIGHT_BROWN,
	GREY_DARKER_V,
	LIGHT_BROWN
];
PointColorType :: enum u8 {
	DEFAULT;
	CUSTOM;
}
PointColorShape :: enum u8 {
	LINEAR;
	CIRCLE;
}
PointColorData :: struct {
	type : PointColorType;
	shape : PointColorShape;
	white_color : Vector4F = GREY_DARKER_V;
	black_color : Vector4F = GREY_BLACK_V;
	point_colors : [] Vector4F;
}

CIRCLE_COLOR_DEFAULT :: PointColorData.{shape=.CIRCLE,white_color=LIGHT_BROWN,black_color=GREY_BLACK_V};

GetPointColor :: inline (
	p_index : int, 
	tuning_system : TuningSystem,
	color_data : PointColorData)
-> Vector4F 
{
	color : Vector4F;
	if color_data.type == {
	case PointColorType.DEFAULT;
		//TODO CAn we make default PointColorData so we can just
		//have it all be the same below by default and only 
		//alternate in cases which we don't have specific colors for.
		if tuning_system.music_pt_count == 12 {
			if color_data.shape == {
			case .LINEAR; color = EQ_12_POINT_COLORS[p_index];
			case .CIRCLE; color = EQ_12_POINT_COLORS_CIRCLE[p_index];
			}
		} else {
			if p_index % 2 == 1 color = color_data.black_color;
			else color = color_data.white_color;
		}
	case PointColorType.CUSTOM;
		assert(p_index < color_data.point_colors.count);
		color = color_data.point_colors[p_index];
	}
	return color;
}

CreateRowData :: struct {
	mspace_id : int;
	// lane_start_row_index : int;
	// relative_row_index : int;
	// row_name : string;
	//TODO Could replace this with tuning_system_id
	//TODO Can remove this if we remove old precise linear way
	//since we have info in row_section_data.
	tuning_system_type : TuningSystemType;
	tuning_system_count : int;

	base_note : int;

	//TODO Can we remove this if we are using tuning system only now? I think so yes but maybe
	//need to remove some old code before it'll compile out.
	use_num_of_points : bool = false;
	num_of_points : int;

	//TODO Pass this in from the code
	//TODO Should these be float64 so we dont lose info from asm?
	octave_height : float = 12;
	row_height : float = 12;

	sound_on : bool = true;
	muted_row : bool;

	row_system_type : RowSystemType;
	row_system_id : int;
	row_sub_system_id : int;

	music_lane_row_point_type : MusicLaneRowPointType;
	row_midi_data : RowMidiData;

	//TODO This can be used for modulo spaces
	//So maybe we can replace with row_type
	// is_octave_view : int;
	// num_of_octaves : int;
	// row_view_type : RowViewType;

	// compass_interval : int;

	row_section_data : [] RowSectionData;


	//op_row specific data
	//TODO We can separate this if needed but keeping in here for convenience for now.
	op_world_pos : Vector2F;
	x_point_width : float;
	op_row_type : OpRowType;
	copy_music_row_id : int;
}

/*TODO if we implement MusicLaneRow based on type, then we
can split each type into separate struct and store info there
since something like pitch (with octaves) may need that info
but not other types. or we could store type info separately
and grab it when needed
*/
MusicLaneRow :: struct {
	id : int;
	//TODO Should this just be a group id for convenience instead of 
	//being meaningful for some innate reason?
	music_lane_id : int;

	//TODO can pull these properties out as MusicLaneRowRenderingData
	//TODO row_world_size should be a collision_rect
	// row_world_size : Vector2F;
	//TODO Should we remove row_world_base_start in favor of
	//total_row_index altogether or have both for convenience?
	//Can likely recompute row_world_base_start whenever it moves
	//and so theres no need to store it here.
	//THAT IS INTERESTING AND POSSIBLE.
	//NOTE THAT row_world_base_start as the center_min. Maybe should change the name
	row_world_base_start : Vector2F;
	//TODO Do we need this in here or just use array index?
	total_row_index : int;

	//TODO Should this just be y? Can we allow moving along x for all rows at once?
	row_cam : Vector2F;

	//TODO Can remove current_octave in favor of base_note
	//Can still have an instruction that sets the base_note
	//from an octave perspective
	base_note : int;
	num_of_points : int;

	/*Note : row_height is computed from octave_height for total_height
	in case we have > or < 1 octave of num_of_points*/
	octave_height : float;
	row_height : float;
	// row_view_type : RowViewType;

	//TODO Should we change the name?
	//This should be a general mute variable and not
	//just used for sound.
	// sound_on : bool = true;
	is_muted_row : bool;

	//TODO This should likely be pulled out into
	//a separate array like SoA.
	row_name : string;

	//TODO Can pull this out and associate by row_index
	//since not all rows will have midi. Also some rows
	//may have MPE or midi 2.0 or be internal
	row_midi_data : RowMidiData;

	//Note : this is used as an accessor for the correct
	//data array, eg RHYTHM from RhythmSectionToMusicLane
	//TODO Maybe rename to MusicRowControlType
	//RENAME To RowSystemType
	row_system_type : RowSystemType = .internal_pitch;
	//TODO Can remove this now since everything is float now
	music_lane_row_point_type : MusicLaneRowPointType;

	/*DOC : These ids are used to reference what system the row should be interpreted through.
	This can be internal or also custom/external and then they can use this
	to reference specific systems or subsystems within it.
	*/
	system_id : int;
	sub_system_id : int;

	//This specifies the synth type for internal rows for simple vs subtractive
	//and then we can add some if we add other internal synths or other things later.
	row_internal_synth_type : RowInternalSynthType;

	/*Note : Cached here for convience since we will
		usually get it from the music_lane_row

		TODO can we remove this?
	*/
	music_lane_type : MusicLaneType;

	//op-specific data
	//TODO We can separate this out if needed later. Leaving here for now for convenience.
	//TODO Might be worth having a completely separate OpLinearRow struct
	//since there will likely be more differences long term.
	//TODO Could update the CreateRowData also to CreateOpRowData for asm
	row_size : int; 
	x_point_width : float;
	op_row_type : OpRowType;
	copy_music_row_id : int;
}
OpRowType :: enum {
	MULTI_SECTION;
	SINGLE_SECTION;
	COPY_MUSIC_ROW;
}
/*New system for associating systems to rows so we can
tell when it changes and how many there are.
*/
//TODO Maybe just name SectionToRow?
SectionToRow :: struct {
	//TODO Should this be row_index or row_id? If it's id then we just have to change the id.
	//Probably rows should be fixed and then we just move things around.
	//This would make things more efficient overall. The only case where its slow
	//is adding new rows which is a relatively rare occurence but also just need
	//to update everything afterwards by 1 so that is also pretty efficient.
	row_id : int;
	//NOTE : This is used for points but there is no dspace stored anywhere
	//since all the info is in the row right now.
	//ACTUALLY we do store a linear space for convenience but it does not do anything other than keep the dspace_id
	dspace_id : int;
	start_x : int;
	end_x : int;

	/*NOTE : I am putting this in here for now BUT might be better to
	put in LinearToTuningSystem. This allows us to also have FORCE_EQUAL or PROPORTIONAL
	depending on what we want AND also can change the base_note of each section
	per tuning_system BUT maybe base_note is better to do per row for clarity.
	Can also just leave that up to the user.
	*/
	tuning_system_id : int;
}

/*TODO should we eventually split these up by type for efficiency
TODO Maybe RENAME RowChannelType
TODO Can we remove this since all rows are memory now?
TODO Rename to RowSystemType
*/
row_system_type_names : [] string : #run enum_names(RowSystemType);
row_system_type_enums : [] RowSystemType : #run enum_values_as_enum(RowSystemType);
RowSystemType :: enum {
	//For use to store values without any external output	
	//TODO Should this be the default or maybe internal_pitch?
	none; 

	//Internal Rows
	internal_message; //TODO Allow changing synth params for example
	internal_pitch;

	//Midi rows
	midi_control_change;
	midi_velocity;
	midi_pitch;
	//TODO Other midi types

	/*TODO This can be used to allow a row to have some code that
	can run whenever we arrive at music_pts.
	Can allow 3 function start, during and end so that we can react
	to each point on the MusicPoint(MusicNote?).
	This would probably only be jai custom and now internal code custom,
	although we could make something that facilitates it internally possibly...
	but it would not be generalized so... only for internal things
	maybe internal_custom?
	*/
	// CUSTOM;

	// //TODO Can remove all these other types
	// LINEAR;
	// BINARY;
	// FLOAT;

	// RHYTHM;
	// PITCH;
	// SYSTEM_SUBSET;
	// VOLUME;
	// TIMBRE;

	// MEMORY;

	// //TODO we don't really need this since we have
	// //music_lane_type but for now
	// CODE;
} @LibraryAsmGen

music_lane_row_point_type_enums : [] MusicLaneRowPointType : #run enum_values_as_enum(MusicLaneRowPointType);
MusicLaneRowPointType :: enum {
	float_based;
	int_based;
}
RowInternalSynthType :: enum {
	SIMPLE_SYNTH;
	//TODO Likely remove this until we actually add it
	SUBTRACTIVE_SYNTH;
}
//TODO REMOVE THIS when we remove it from MusicLaneRow
MusicLaneType :: enum {
	DEFAULT;
	//TODO should we call this GUIDE or something else?
	//RULES sounds very strict
	RULES;

	//TODO can likely remove LOOP now that we have SEQUENCE and TEMPLATE
	LOOP; //TODO should we rename LOOP to TEMPLATE?

	SEQUENCE;
	TEMPLATE;

	//TODO
	CODE;
	MEMORY;
}
/*TODO Overall this is mostly for asm since the player
  can do anything with code but this allows setting values
  more specifically in asm

  This should also be available per note, to send
  velocity per note. Maybe we can add that to music_pts
  that are in midi_rows...
*/
RowMidiData :: struct {
	//TODO This can be channel and port for now
	//since only 16 channels, we would have 2 bits per port
	//TODO Should this channel be per lane or per row?
	//TODO I think this should just be called midi_channel
	midi_channel : u8;
	midi_velocity : u8 = 100;
	midi_control_change : u8;
}
AsmRowMidiData :: struct {
	midi_channel : int;
	midi_velocity : int = 100;
	midi_control_change : int;	
} @LibraryAsmGen

/*End of row data
*/

CollisionShape :: enum u8 {
	RECTANGLE;
	QUAD;
	CIRCLE;
}
CollisionEntity :: struct {
	entity_id : int;
	//TODO Should this be EntityType instead?
	//Then we can just copy directly to HoverEntity.
	entity_type : EntityType;
	//TODO Eventually we can index on op_space index for all_op_collision_entities
	//and maybe remove for all_base_collision_entities
	//and then also maybe only use rectangles if we only need that in base
	//TODO Maybe we don't need an index of we only have the visible
	//collision entities which may be very small.
	op_space_id : int;

	//TODO We could separate these into multiple arrays for each shape
	//if that is more efficient later. Since quad is 2x size of rect.
	//If we separated arrays, we could also do simd later on multiple shapes at once in each array.
	//eg multiple rects at once with the same collision checking code. OR do 64-bit (possible still with less simd)
	//Currently we only use quad for unrotated chord_s2.
	//We could then store index to that array and keep track of a free list
	//and then add it and remove it when we add and remove CollisionEntities
	shape : CollisionShape;
	union {
		//TODO What if we just used triangle here and then can replace quad with 2 triangles? Problem with center not colliding possibly?
		//TODO Technically a quad can be 2 Vector2Fs and a thickness  or rotation which would then just be 5 floats
		//That is if the quad is just a rotated rectangle
		quad : Quad2F;
		rect : Rectangle2;
		circle : Circle2;
	}
}

//TODO should we separate these out as an array based FSM?
//TODO do i like the word entity here?
EntityType :: enum {
	NONE;

	/*Putting new spaces here and can gradually remove bottom ones once we remove the hover/chosen code for each of them.
	SHOULD CALL THIS HoverEntityType probabl
	*/
	OP_LINEAR_DSPACE;
	OP_CIRCLE_DSPACE; //TODO Should this just be CIRCLE or OP_CIRCLE?
	OP_LINEAR_ROW;

	SPIRAL;

	PITCH_S2;

	CUSTOM_GEOMETRY;

	LANE_ROW_WITH_SECTIONS;
	//TODO can we change the name of this if we don't
	//directly interact with the pitches unless were in op_space?
	MUSIC_LANE_ROW;
	LINEAR_SPACE_MUSIC_LANE;
	//TODO should we have input and output space as separate type?
	CIRCULAR_PITCH_CLASS_SPACE;
	CHORD_S2;
	CHORD_S3;
	
	CONTINUOUS_DSPACE_GROUP;
	OPERATION_ENTITY;
	OPERATION_AS_DSPACE;

	CIRCULAR_RHYTHM_SPACE;

	TERMINAL;
	OP_SPACE;
	OP_LINEAR_SPACE;
	OP_MUSIC_PT_SET;

	OP_SELECT_GRID_POS;

	//TODO ui_entities : should they be separate?
	//TODO rename to transforms or remove altogether if we change the whole pattern
	UI_INVARIANT_SELECTOR;
	UI_BINARY_ADD_OPERATION;
	UI_OPERATION_SELECT;
}

/*TODO 
	should these orders all be different for safety or
	can we keep some the same knowing that, for example,
	we won't overlap 2 dspaces together but we will overlap
	a transform with a a dspace

	***this should be replaced with specified order for each
	op_entity in the HoverEntity struct***
*/
//TODO should this be constant or variable?
hover_entity_type_order :: #run () -> [] int {
	info := cast(*Type_Info_Enum) type_info(EntityType);
	hover_order := NewArray(info.values.count, int);
	hover_order[EntityType.NONE] = 0;
	hover_order[EntityType.MUSIC_LANE_ROW] = 10;
	hover_order[EntityType.LINEAR_SPACE_MUSIC_LANE] = 10;
	hover_order[EntityType.CIRCULAR_PITCH_CLASS_SPACE] = 10;
	hover_order[EntityType.OPERATION_AS_DSPACE] = 20;
	hover_order[EntityType.UI_BINARY_ADD_OPERATION] = 30;
	hover_order[EntityType.UI_OPERATION_SELECT] = 31;
	hover_order[EntityType.UI_INVARIANT_SELECTOR] = 40;

	hover_order[EntityType.OP_SPACE] = 109;
	hover_order[EntityType.OPERATION_ENTITY] = 100;
	hover_order[EntityType.OP_LINEAR_SPACE] = 100;
	hover_order[EntityType.OP_MUSIC_PT_SET] = 100;
	hover_order[EntityType.OP_LINEAR_DSPACE] = 100;
	//TODO should CHORD_S2 be higher or the same?
	hover_order[EntityType.CHORD_S2] = 100;
	hover_order[EntityType.CHORD_S3] = 100;

	hover_order[EntityType.OP_SELECT_GRID_POS] = 200;
	return hover_order;
	// for info.values {
	// 	print("size_of(%) is %\n", cast(EntityType) it, chosen_entity_type_order[it]);
	// }
}();

/*Start of tuning system data
*/
/*TODO
	USE FIGURE 3.1 and draw in op_space or world to show how the first
	intervals are used to create a simple tuning_system.
	Need to use multiply/divide due to the wave representation of frequencies.
	Definition of frequency is how often wave repeats in given period.
	Then to go from multiplication to addition, we use exponents.
	Can put PitchToFrequency equation as the example and then use that
	to show how to code by example with direct frequency creation.
	Then also show how to use that to load up audio buffer.
	So we go directly from tuning_system -> audio buffer in 1 or a few levels.
	LOADING AUDIO BUFFER SHOULD BE A LEVEL-maybe first coding level.

	input and compare the other tuning systems with some examples
*/
// TONE_12_EQUAL_TEMPERAMENT :: TuningSystem.{0, 12, .EQUAL_TEMPERAMENT, true, A0};
// pyth :: TuningSystem.{1, 13, .pyth, false, A0};
// CENTS_EQUAL_TEMPERAMENT :: TuningSystem.{2, 1200, .EQUAL_TEMPERAMENT, false, A0};
// TEN_CENTS_EQUAL_TEMPERAMENT :: TuningSystem.{3, 120, .EQUAL_TEMPERAMENT, false, A0};

//NOTE : I think we can do perfect with multiple tuning systems now.
// PERFECT_12_TONE_TUNING :: TuningSystem.{4, 12, .PERFECT_TUNING, false, A0};

//TODO not implemented yet
// TONE_53_EQUAL_TEMPERAMENT :: TuningSystem.{5, 53, .EQUAL_TEMPERAMENT, false, A0};
// MEANTONE_12_TEMPERAMENT :: TuningSystem.{6, 12, .MEANTONE_TEMPERAMENT, false, A0};
// natural chromatic
// natural, pyth and meantone diatonic
// microtonal scales
// 12, 19, quarter and 53 (play around with color as well)
// can draw cents without vertical delineations maybe set it in row data to not draw

//TEST OUT APPROXIMATIONS OF GAMMA AND BETA SCALE
//eg beta scale is 4/3 split into 2 or 8 points
//so compass_interval = 4/3 and music_pt_count = 2 or 8
//do same for beta, gamma and delta scale
/*TODO should common code be pulled out with RhythmSection?

SHOULD WE CHANGE THE NAME OF THIS. I kind of like the name TuningSystem.
It implies music but also not. This is a generalized linear point system.
Could call it PointSystem or LinearSystem... hmmm...
*/
TuningSystem :: struct {
	id : int;
	//TODO this is cached here since we have all music_pts in the all_tuning_pitches array
	//TODO for equal_tempered systems we may not need those separate tuning_pitchs
	/*TODO both of these imply that the tuning system is repeating
		but we want to allow for non-repeating tuning_systems as well
	*/
	//TODO rename this to tuning_pt_count
	music_pt_count : int;
	// music_pt_cents_count : int;
	// is_compass_repeating : bool;
	//TODO Should this be float64 precision along with TuningPitches?
	compass_interval : float64;
	// log_compass_interval : float;
	/*TODO could this just be a string name?
		TODO could implement a fractional tuning system
		where we keep track of numerator and denominator
		to go forward and backwards
		then we would have different analyses for fractions
		or equal temperaments or other tuning systems
	*/
	//TODO do we really need this at all if we just use the
	//log_ratio_points to create the uneven spacing?
	//Yes I think the only difference shold be even and uneven here.
	//Maybe these can be used as names but then may as well just store a string
	//so that people can create their own.
	type : TuningSystemType;
	name : string;
	short_name : string;
	//TODO Could have a nickname here as well
	//TODO could put base frequency in here like C0 or A4
	//TODO Maybe best to put base_frequency in SectionToRow or Row itself for consistency.
	base_frequency : float = A0;
	//TODO could put another type which specifies if we need tuning music_pts or music_pt

	//TODO for custom tuning systems if needed
	// tuning_system_name : string;

	/*TODO tuning_system could have its own music_pt_set
		and so we could build tuning systems in this way
		using union and difference to add and subtract
		elements from the tuning_system and then we could
		set the ratios (or cents) directly
	*/
	// music_pt_set_id : int;
}

/*We assume eq_temp, A0 base frequency and 
octave as compass_interval unless otherwise specified.

TODO These should all be changeable from code
including the base_frequency maybe per row.
*/
//This ensures that we can do all_tuning_system[id] to get the tuning system directly
NextTuningSystemId :: inline (all_tuning_systems : [] TuningSystem) -> int {
	return all_tuning_systems.count;
}

//TODO FROM HERE implement asm for get and create and reset tuning systems
//and also add 22-sruti and harry partch and bohlen pierce just scale to default
//We can print the names out for refernece in an intro file so
//ppl can see the names 
//TODO Should pass in from CreateTuningData
CreateEqualTemperedTuningSystem :: inline (
	name : string,
	short_name : string,
	tuning_system_pt_count : int,
	compass_interval : float64,
	all_tuning_systems : *[..] TuningSystem,
	all_tuning_pitches : *[..] TuningPitch)
-> TuningSystem
{
	next_tuning_id : int = NextTuningSystemId(all_tuning_systems.*);

	tuning_system : *TuningSystem = array_add(all_tuning_systems);
	tuning_system.id = next_tuning_id;
	tuning_system.name = name;
	tuning_system.short_name = short_name;
	tuning_system.music_pt_count = tuning_system_pt_count;
	tuning_system.type = .EQUAL_TEMPERAMENT;
	tuning_system.compass_interval = compass_interval;

	//TODO We don't need to create these since they are systematic...
	ratio_to_next : float64 = pow(compass_interval, 1.0 / tuning_system_pt_count);
	for 0..tuning_system_pt_count-1 {
		tp : *TuningPitch = array_add(all_tuning_pitches);
		tp.tuning_system_id = tuning_system.id;
		tp.music_pt_pos = it;
		tp.ratio_from_start = pow(compass_interval, it / cast(float) tuning_system_pt_count);
		tp.ratio_to_next_music_pt = ratio_to_next;
		tp.linear_from_start = it / cast(float) tuning_system_pt_count;
		tp.linear_to_next = 1.0 / tuning_system_pt_count;
	}

	return tuning_system;
}

CreateTuningData :: struct {
	name : string;
	short_name : string;
	//TODO Can include a short name here
	compass_interval : float64 = 2;
	//I think float64 is better for higher accuracy with ratios
	//even though ultimately we reduce to float.
	values : [] float64;
}

//TODO Should add diatonic and partch and exact bohlen pierce here
//ALSO 22-sruti scale
//TODO Could make this non-constant if that is more convenient.
DEFAULT_RATIO_FROM_START_TUNINGS :: CreateTuningData.[
//Pythagorean Chromatic
.{"Pythagorean Chromatic", "pyth", 2.0,
	float64.[1, 256/243.0, 9/8.0, 32/27.0, 81/64.0, 4/3.0, 
	  1024/729.0, 729/512.0, 3/2.0, 128/81.0, 27/16.0, 16/9.0, 243/128.0],
},

//Natural Chromatic
.{"Natural Chromatic", "natural", 2.0,
	float64.[1, 16/15.0, 9/8.0, 6/5.0, 5/4.0, 4/3.0, 
	  64/45.0, 3/2.0, 8/5.0, 5/3.0, 16/9.0, 15/8.0],
},

//Hindustani 22-Sruti Scale
.{"Hindustani 22-Sruti", "22sruti", 2.0,
	float64.[1, 256/243.0, 16/15.0, 10/9.0, 9/8.0, 32/27.0, 
	  6/5.0, 5/4.0, 81/64.0, 4/3.0, 27/20.0, 45/32.0, 729/512.0,
	  3/2.0, 128/81.0, 8/5.0, 5/3.0, 27/16.0, 16/9.0, 9/5.0,
	  15/8.0, 243/128.0],
},

//Harry Partch's 43-tone scale
.{"Harry Partch's 43-tone", "hp43", 2.0,
	float64.[1, 81/80.0, 33/32.0, 21/20.0, 16/15.0, 12/11.0, 
	  11/10.0, 10/9.0, 9/8.0, 8/7.0, 7/6.0, 32/27.0, 6/5.0,
	  11/9.0, 5/4.0, 14/11.0, 9/7.0, 21/16.0, 4/3.0, 27/20.0,
	  11/8.0, 7/5.0, 10/7.0, 16/11.0, 40/27.0, 3/2.0, 32/21.0,
	  14/9.0, 11/7.0, 8/5.0, 18/11.0, 5/3.0, 27/16.0, 12/7.0,
	  7/4.0, 16/9.0, 9/5.0, 20/11.0, 11/6.0, 15/8.0, 40/21.0,
	  64/33.0, 160/81.0],
},

//Bohlen-Pierce Just Scale
.{"Bohlen-Pierce Just", "bpjust", 3.0,
	float64.[1, 27/25.0, 25/21.0, 9/7.0, 7/5.0, 75/49.0, 
	  5/3.0, 9/5.0, 49/25.0, 15/7.0, 7/3.0, 63/25.0, 25/9.0],
},

//TODO add all diatonic scales, natural, pythagorean and chromatic (p55)
//This will give an example of how you can add a subset of another tuning system to represent
//a fixed scale tuning system, instead of, for example, having a scale be overlaid on a tuning system
//so that you need to pick the notes by checking what notes are a subset of music pt set.

//TODO FROM HERE Need to add these and also write some tests for each tuning creation type.
//ALSO CLEANUP the old unused tuning system stuff now, can put in deadcode.
//Maybe start with circle tomorrow if needed.
//Then linear scissor base with tuning and move spac epoint to op_space
//can maybe do op_psace one first to make sure it works with op camera.
];

//NOTE : This is just for experiments although it is very cool indeed.
DEFAULT_LINEAR_FROM_START_TUNINGS :: CreateTuningData.[
.{"TestLinearFromStart", "tlfs", 2.0, float64.[0, 0.1, 0.33333, 0.5, 0.75, 0.9]}
];

/*TODO FROM HERE SHOULD WRITE TESTS FOR SOME OF THESE MAYBE 1 OF EACH CREATION TYPE TO MAKE SURE THEY ARE WORKING PROPERLY
Can also make global pointers to this possibly... or at least
an enum index which can fetch from the array by index and then
make a convenience function since we can optimize the tuning_ssytem array fetch easily.
*/
CreateDefaultTuningSystems :: (all_tuning_systems : *[..] TuningSystem, all_tuning_pitches : *[..] TuningPitch) {
	//TODO Should we put the first 53 here indexed and 12-ET as index 0 default?
	//We would double 12-ET in 12 and in 0 for convenience.
	//TODO Create a few other default eq temp. Could also make up to 120 or something like that and index them properly with TuningPitch.
	CreateEqualTemperedTuningSystem("12-ET", "et12", 12, 2,
		all_tuning_systems, all_tuning_pitches);
	CreateEqualTemperedTuningSystem("19-ET", "et19", 19, 2,
		all_tuning_systems, all_tuning_pitches);
	CreateEqualTemperedTuningSystem("24-ET", "et24", 24, 2,
		all_tuning_systems, all_tuning_pitches);
	CreateEqualTemperedTuningSystem("48-ET", "et48", 48, 2,
		all_tuning_systems, all_tuning_pitches);
	CreateEqualTemperedTuningSystem("53-ET", "et53", 53, 2,
		all_tuning_systems, all_tuning_pitches);

	//Bohlen-Pierce equal tempered approximation
	CreateEqualTemperedTuningSystem("Bohlen-Pierce ET 3^(1/13)", 
		"bpet", 13, 3, all_tuning_systems, all_tuning_pitches);
	// CreateEqualTemperedTuningSystem(8, all_tuning_systems, all_tuning_pitches, 4/3.0);
	//TODO FROM HERE keep adding other scales and put name
	//and compass interval here. Need to add to MakeTuningSystem
	//AND ALSO Add to DEFAULT_RATIO_FROM_START_TUNINGS as a struct with name and compass_interval
	//Should we change name of compass_interval?
	//ALSO Use tuning pitch instead of SpacePoint possibly and at least
	//store linear values in TuningPitch so we don't have to recompute.
	//Also do uneven circles before op_space linear scissor maybe
	//Also maybe split eq and proportional (see for circle as well)
	//Then one deep pass before starting asm. OR
	//doing asm will then cycle with these anyways

	//Tuning developped with ratio manipulation
	//TODO Could have some levels where we show the manipulation
	//and let them create their own tuning using multiplcation of specific ratios.
	for DEFAULT_RATIO_FROM_START_TUNINGS CreateTuningSystemFromStart(it, all_tuning_systems, all_tuning_pitches);
	for DEFAULT_LINEAR_FROM_START_TUNINGS CreateTuningSystemFromStart(it, all_tuning_systems, all_tuning_pitches, is_ratio=false);

	//Wendy Carlos scales
	//Repeating (approximation) but non-octave repeating scales
	//Alpha scale approximations - "wonderful triads"
	//Perfect fifth (3/2) into 9 equal steps - (3/2)^(1/9)
	CreateEqualTemperedTuningSystem("Alpha (3/2)^(1/9)", 
		"alpha", 9, 3/2.0, all_tuning_systems, all_tuning_pitches);
	//Minor third (6/5) into 4 equal steps - (6/5)^(1/4)
	CreateEqualTemperedTuningSystem("Alpha1 (6/5)^(1/4)", 
		"alpha1", 4, 6/5.0, all_tuning_systems, all_tuning_pitches);

	//Beta scale approximations - like alpha with more just sevenths
	//Perfect fifth (3/2) into 9 equal steps - (3/2)^(1/11)
	CreateEqualTemperedTuningSystem("Beta (3/2)^(1/11)", 
		"beta", 11, 3/2.0, all_tuning_systems, all_tuning_pitches);
	//Perfect fourth (4/3) into 8 equal steps - (4/3)^(1/8)
	CreateEqualTemperedTuningSystem("Beta1 (4/3)^(1/8)", 
		"beta1", 8, 4/3.0, all_tuning_systems, all_tuning_pitches);
	//Perfect fourth (4/3) into 2 equal steps - (4/3)^(1/2)
	CreateEqualTemperedTuningSystem("Beta2 (4/3)^(1/2)", 
		"beta2", 2, 4/3.0, all_tuning_systems, all_tuning_pitches);

	//Delta scale approximation - beta scale reciprocal
	//Minor second (16/15) into 8 equal steps - (16/15)^(1/8)
	CreateEqualTemperedTuningSystem("Delta (16/15)^(1/8)", 
		"delta", 8, 16/15.0, all_tuning_systems, all_tuning_pitches);

	//Gamma scale approximation - beta scale reciprocal
	//Perfect fifth (3/2) into 20 equal steps - (3/2)^(1/20)
	CreateEqualTemperedTuningSystem("Gamma (3/2)^(1/20)", 
		"gamma", 20, 3/2.0, all_tuning_systems, all_tuning_pitches);
	//Undecimal neutral third (11/9) into 2 equal steps - (11/9)^(1/2)
	CreateEqualTemperedTuningSystem("Gamma1 (11/9)^(1/2)", 
		"gamma1", 2, 11/9.0, all_tuning_systems, all_tuning_pitches);
	//Undecimal neutral third (11/9) into 10 equal steps - (11/9)^(1/10)
	CreateEqualTemperedTuningSystem("Gamma2 (11/9)^(1/10)", 
		"gamma2", 10, 11/9.0, all_tuning_systems, all_tuning_pitches);

}

CreateTuningSystemFromStart :: inline (
	tuning : CreateTuningData,
	all_tuning_systems : *[..] TuningSystem,
	all_tuning_pitches : *[..] TuningPitch,
	is_ratio : bool = true)
-> TuningSystem
{
	next_tuning_id : int = NextTuningSystemId(all_tuning_systems.*);

	tuning_system : *TuningSystem = array_add(all_tuning_systems);
	tuning_system.id = next_tuning_id;
	tuning_system.name = tuning.name;
	tuning_system.short_name = tuning.short_name;
	tuning_system.music_pt_count = tuning.values.count;
	tuning_system.type = .NOT_EQUAL_TEMPERAMENT;
	tuning_system.compass_interval = tuning.compass_interval;

	for 0..tuning.values.count-2 {
		tp : *TuningPitch = array_add(all_tuning_pitches);
		tp.tuning_system_id = tuning_system.id;
		tp.music_pt_pos = it;
		if is_ratio {
		tp.ratio_from_start = tuning.values[it];
		tp.ratio_to_next_music_pt = tuning.values[it+1] / tuning.values[it];
		tp.linear_from_start = LogRatioToLinear(tp.ratio_from_start, tuning_system.compass_interval);
		tp.linear_to_next = LogRatioToLinear(tp.ratio_to_next_music_pt, tuning_system.compass_interval);
		} else {
		tp.linear_from_start = cast(float) tuning.values[it];
		tp.linear_to_next = cast(float) (tuning.values[it+1] - tuning.values[it]);
		tp.ratio_from_start = LinearToLogRatio(tp.linear_from_start, tuning_system.compass_interval);
		tp.ratio_to_next_music_pt = LinearToLogRatio(tp.linear_to_next, tuning_system.compass_interval);;			
		}
	}

	last : int = tuning.values.count-1;
	tp : *TuningPitch = array_add(all_tuning_pitches);
	tp.tuning_system_id = tuning_system.id;
	tp.music_pt_pos = last;
	if is_ratio {
	tp.ratio_from_start = tuning.values[last];
	tp.ratio_to_next_music_pt = tuning_system.compass_interval / tuning.values[last];
	tp.linear_from_start = LogRatioToLinear(tp.ratio_from_start, tuning_system.compass_interval);
	tp.linear_to_next = LogRatioToLinear(tp.ratio_to_next_music_pt, tuning_system.compass_interval);
	} else {
	tp.linear_from_start = cast(float) tuning.values[last];
	tp.linear_to_next = cast(float) (1.0 - tuning.values[last]);
	tp.ratio_from_start = LinearToLogRatio(tp.linear_from_start, tuning_system.compass_interval);
	tp.ratio_to_next_music_pt = LinearToLogRatio(tp.linear_to_next, tuning_system.compass_interval);;
	}

	return tuning_system;
}

//NOTE : This is here for convenience but is not currently used.
CreateTuningSystemToNext :: inline (
	tuning : CreateTuningData,
	all_tuning_systems : *[..] TuningSystem,
	all_tuning_pitches : *[..] TuningPitch,
	is_ratio : bool = true)
-> TuningSystem
{
	next_tuning_id : int = NextTuningSystemId(all_tuning_systems.*);

	tuning_system : *TuningSystem = array_add(all_tuning_systems);
	tuning_system.id = next_tuning_id;
	tuning_system.name = tuning.name;
	tuning_system.short_name = tuning.short_name;
	tuning_system.music_pt_count = tuning.values.count;
	tuning_system.type = .NOT_EQUAL_TEMPERAMENT;
	tuning_system.compass_interval = tuning.compass_interval;

	last_tp : *TuningPitch = array_add(all_tuning_pitches);
	last_tp.tuning_system_id = tuning_system.id;
	last_tp.music_pt_pos = 0;
	if is_ratio {
	last_tp.ratio_from_start = 1;
	last_tp.ratio_to_next_music_pt = tuning.values[0];
	last_tp.linear_from_start = LogRatioToLinear(last_tp.ratio_from_start, tuning_system.compass_interval);
	last_tp.linear_to_next = LogRatioToLinear(last_tp.ratio_to_next_music_pt, tuning_system.compass_interval);
	} else {
	last_tp.linear_from_start = 0;
	last_tp.linear_to_next = cast(float) tuning.values[0];
	last_tp.ratio_from_start = 1;
	last_tp.ratio_to_next_music_pt = LinearToLogRatio(last_tp.linear_to_next, tuning_system.compass_interval);
	}

	for 1..tuning.values.count-1 {
		tp : *TuningPitch = array_add(all_tuning_pitches);
		tp.tuning_system_id = tuning_system.id;
		tp.music_pt_pos = it;
		if is_ratio {
		tp.ratio_from_start = last_tp.ratio_from_start * last_tp.ratio_to_next_music_pt;
		tp.ratio_to_next_music_pt = tuning.values[it];
		tp.linear_from_start = LogRatioToLinear(tp.ratio_from_start, tuning_system.compass_interval);
		tp.linear_to_next = LogRatioToLinear(tp.ratio_to_next_music_pt, tuning_system.compass_interval);
		} else {
		tp.linear_from_start = last_tp.linear_from_start + last_tp.linear_to_next;
		tp.linear_to_next = cast(float) tuning.values[it];
		tp.ratio_from_start = LinearToLogRatio(tp.linear_from_start, tuning_system.compass_interval);
		tp.ratio_to_next_music_pt = LinearToLogRatio(tp.linear_to_next, tuning_system.compass_interval);
		}

		last_tp = tp;
	}

	return tuning_system;
}

//TODO could replace this with string names so we can make new ones
tuning_system_type_names : [] string : #run enum_names(TuningSystemType);
tuning_system_type_enums : [] TuningSystemType : #run enum_values_as_enum(TuningSystemType);
tuning_system_type_s64 : [] s64 : #run enum_values_as_s64(TuningSystemType);
TuningSystemType :: enum {
	//TODO Should we call this something else now. Also maybe put names in strings instead and also maybe short names as well.
	EQUAL_TEMPERAMENT; // Equal temperament
	NOT_EQUAL_TEMPERAMENT;

	// pyth; // Pythagorean tuning
	// mean; // Meantone temperament
	// diatonic; // diatonic scale as a tuning system
	// cents;
	//TODO other tuning systems

	//TODO have one tuning system that allows frequencies
	//TODO This could simply be a separate row type
	//instead of a tuning_system
	// frequency;
	//TODO PERFECT_TUNING or RELATIVE_TUNING?
	// PERFECT_TUNING;
	// CUSTOM_TUNING;
	//TODO different tuning systems eg well-tempered, just intonation, ...
	//https://en.wikipedia.org/wiki/Well_temperament
	//https://en.wikipedia.org/wiki/Quarter-comma_meantone
	//TODO Compass Interval tuning p87 k^(1/x) so we need k and x as integer inputs
}

/*TODO 
	this is similar to RhythmPulse (removed RhythmPulse but maybe still something to think about)
	can we be bring these concepts together?
	SpaceCoord -> TuningCoord OR RhythmCoord OR OtherCoord
	Should we rename this TuningCoord or TuningPoint?
*/
TuningPitch :: struct {
	//TODO We don't need id AND music_pt_pos for tuning pitches.
	// id : int;
	tuning_system_id : int;
	//MusicPt : this is from 0 - tuning_system.music_pt_count
	//TODO this is also technically the pitch_class_label
	//we can call tuning_degree for now though to avoid 
	//associating these directly to pitch_class by name
	//TODO music_pt_pos -> pitch_coord
	//TODO FROM HERE rename to tuning_pitch
	//instead of confusing it for music_pt_pos for now
	music_pt_pos : int; //TODO music_pt_pos -> tuning_degree?
	// cent_pos : int;
	//TODO should maybe have tuning_degree and cent_pos
	//but cent_pos might be enough
	
	//TODO could implement a fractional tuning system
	//where we keep track of numerator and denominator
	//to go forward and backwards

	//TODO Or we could have a version that takes cents
	//as input and then does ratio or also store cents
	//and then we wouldnt have to do
	//TODO should we use cents instead of ratios?
	//TODO this can be used for un-equal interval tuning systems
	//TODO Technically we don't need this
	//TODO Should all these be float64 for precision?
	// I Think so yes for higher values when we still want fractional precision.
	ratio_from_start : float64;
	//TODO not sure if we should store these since we can compute directly
	//from the division of the ratio_from_start
	ratio_to_next_music_pt : float64;

	/*I am keeping these here as a reminder that we should convert to linear from ratio
	with LogRatioToLinear. This makes it much simpler when we are dealing with rendering for example.
	IN FACT, we can even render directly from tuning_pitch with this and without the
	SpacePoint for the base world linear scissor if that is more convenient.

	Left this as float for now because we use it in MakeRatioProportionalPoints
	to make the vector for the linear system and float is likely enough
	We can eventually set to float64 and then cast to float for that case
	*/
	linear_from_start : float;
	linear_to_next : float;
}
/* End of tuning system data
*/

//TODO how should we actually do ids? UUIDS or systematic?
//TODO should this be in a separate file?
//TODO Can likely pull some of these out per op_space or mspace
//TODO THIS WORKS LOCALLY when passed through the context with the correct ids.
//ASK SOMEONE TO MAKE SURE IT WORKS ON THEIR COMPUTER AS WELL. SINCE its a pointer, it should be 
//fine because its a pointer to a global variable so that should never change and this should work
//fine in a dynamic library, double check on mac as well. This is cleaner and simpler than passing
//The id everywhere. 
//WE COULD ALSO GENERATE IDS by type with a compile time function for each type we need an id for.
//Then we would have to keep each id globally anyways but then we would just call a function by type
//and we we would not need to pass this in to the context but maybe this way is even better anyways.
#add_context ALL_NEXT_IDS : *AllNextIds;
//TODO We can just always use the pointer from the context and store this in all data instead i think now
//ALSO can remove all the ids we are not using
ALL_NEXT_IDS : AllNextIds;
AllNextIds :: struct {
	DSPACE_ID : int = 0;
	POINT_ID : int = 0;
	TUNING_NOTE_ID : int = 0;
	//Note : starting at seven due to the constant 
	//tuning_systems for now which we should probably remove
	NEXT_TUNING_SYSTEM_ID : int = 0;

	//MusicPt Ids
	//TODO rename to NEXT_NOTE_ID
	NEXT_MUSIC_POINT_ID : int = 0;

	NEXT_MSPACE_ID : int = 0;

	NEXT_OP_SPACE_ID : int;

	NEXT_COLLISION_ID : int = 0;

	NEXT_CAM_ID : int = 0;

	NEXT_MUSIC_LANE_ID : int = 0;
	NEXT_MUSIC_LANE_ROW_ID : int = 0;

	NEXT_OP_LINEAR_ROW_ID : int = 0;

	NEXT_CS2_POINTS_ID : int = 0;

	NEXT_CHORD_SPACE_POINT_ID : int = 0;
	NEXT_SPACE_POINT_3D_ID : int = 0;
	NEXT_CHORD_S3_ID : int = 0;
	NEXT_RENDER_MUSIC_PT_3D : int = 0;

	NEXT_MUSIC_INSTRUCTION_ID : int = 0;

	NEXT_TEXT_FILE_ID : int = 0;

	NEXT_VL_ID : int = 0;

	NEXT_SYNTH_ID : int = 0;

	//Shape ids
	//Can likely pull these out once we have shapes per op space
	NEXT_SHAPE_ID : int = 0;	
	// NEXT_SHAPE_RECT_ID : int = 0;
	// NEXT_SHAPE_QUAD_ID : int = 0;
	// NEXT_SHAPE_TRIANGLE_ID : int = 0;
	// NEXT_SHAPE_TEXT_ID : int = 0;
}

/*Start op space data / op space shapes data

TODO Should we put all this in a separate file?
Could also pull out the chord space and filtering code specifically if needed
*/

/*TODO
	should this be changed to the general concept of a window?
	in other words just change the name and keep all other data separate
	with maybe a type to know which one if needed?

	will keep all info in here for now and then separate accordingly

	TODO should we store the *RenderGroup directly in here
	or should we store it separately? could also just store the id
	here by index and then fetch it by id/index

	can have a rhythm op space as well

	*** should we store dspace type in op_space, 
	ie linear, chord_s2, chord_s3...***

	***it seems to make sense that every op space should have
	input and output spaces or sets of spaces***
*/
//can we rename to OpSpace or OperationSpace?
//TODO check MIN_SIZE on resizing op_space
OP_SPACE_MIN_SIZE :: Vector2F.{8,5};
//This size is arbitrary and is only checked for settings now. We can increase or decreate if needed.
//We could remove it once we do settings through dynamic libraries.
OP_SPACE_MAX_SIZE :: Vector2F.{500,500};
// OP_SPACE_MIN_SIZE :: Vector2F.{5,5};
//TODO NEED TO PUT THESE IN TextOpSpaceData and compute them
//on creation and also on update if we change the window size
//or change proportions for example.
OP_SPACE_LINE_HEIGHT : float : 1.5;
OP_SPACE_VIEWABLE_LINE_COUNT : int : 
	#run round_to_int(OP_SPACE_DEFAULT_SIZE.y / OP_SPACE_LINE_HEIGHT) - 1;
OperationSpace :: struct {
	id : int;
	op_space_external_type : OpSpaceExternalType;
	op_space_name : string;

	//TODO should this just be a Rectangle2?
	//What is the best option for moving and resizing op_space as well?
	world_offset : Vector2F;
	world_size : Vector2F = OP_SPACE_DEFAULT_SIZE;


	is_moving_op_space : bool;
	//TODO could remove this if we remove the close window button
	op_close_selected : bool;
	//TODO Could make this 1 struct if that helps with using it
	//since we only use these 2 for some functions
	fixed_op_type : OpSpaceFixedType;
	fixed_mspace_id : int;

	// fixed_camera_offset : Vector2F;
	// per_frame_world_cam : Camera2D;
	// op_cam_pos : Vector2F;
	//TODO should we just store the camera in here?
	/*TODO due to 3D cameras being completely different, should we pull this out?
		If we do pull it out, then make sure that we do note
		create a camera for 3D space or that we have a separate
		array for 3D cameras or just keep it in ChordSpace3 for now
	*/
	//TODO CAN LIKELY REMOVE THIS AND active_cam_id as well
	//and camera array now that we store the camera directly
	// cam_2D_id : int;
	op_2D_cam : Camera2D;

	//TODO We could remove this from here and grab it from the 
	//open_op_space_render_groups array each time if needed.
	//This is more efficient for fetching though since we use it
	//all the time whenever rendering.
	render_groups : OpSpaceRenderGroups;

	//TODO Could have functions here for allowing external
	//to open or close OR 
	//could have an event system where we have event types
	//with ids and then the external dll can react to that
	//event with that id
	// on_close : OnCloseType;
	// on_open : OnOpenType;
}
//NOTE : This needs to be 64-bit if we want to use it as asm data.
OpSpaceExternalType :: enum {
	/*New general spaces, can likely remove other spaces later
	  in favor of just general spaces with more robust creation
	  functions. For example to add linear or circular spaces in a line.
	*/
	space_2d;
	space_3d;
	terminal;
	//TODO Maybe rename this to text instead
	txt;

	//TODO Remove these when we go over the 2d and 3d spaces
	chord_s3;
	circle;
}
OpSpaceFixedType :: enum {
	FIXED_TO_CAMERA;
	FIXED_TO_MSPACE;
}

CreateOpSpaceData :: struct {
	op_space_name : string;
	op_space_external_type : OpSpaceExternalType;
	world_offset : Vector2F;
	world_size : Vector2F = OP_SPACE_DEFAULT_SIZE;
}
CreateClosedOpSpace :: inline (
	cosd : CreateOpSpaceData,
	all_closed_op_spaces : *[..] OperationSpace,
	all_op_space_spec_data : *[..] OpSpaceSpecData,
	all_op_spec_data_3D : *[..] OpSpecData3D)
-> *OperationSpace 
{
	//TODO Should we store this in the OperationSpace instead of cosd.world_offset and cosd.world_size? 
	//We would need to just store it in 1 place. I guess it depends how we move or resize the op_space.
	op_space_rect : Rectangle2 = RectCenterDim(cosd.world_offset, cosd.world_size);
	op_ui_min : Vector2F = MakeV2F(op_space_rect.min.x, op_space_rect.max.y);
	// op_ui_size : Vector2F = MakeV2F(OP_SPACE_MIN_SIZE.x, 1.6);
	// op_ui_size : Vector2F = MakeV2F(OP_SPACE_MIN_SIZE.x, 1.4);
	op_ui_size : Vector2F = MakeV2F(cosd.world_size.x, 1.4);
	op_ui_rect : Rectangle2 = RectMinDim(op_ui_min, op_ui_size);

	op_space : *OperationSpace = array_add(all_closed_op_spaces);
	op_space.id = context.ALL_NEXT_IDS.NEXT_OP_SPACE_ID;
	context.ALL_NEXT_IDS.NEXT_OP_SPACE_ID += 1;
	op_space.world_offset = cosd.world_offset;
	op_space.world_size = cosd.world_size;
	// op_space.cam_2D_id = op_2D_cam.id;
	//TODO I think we should copy the name in here and then later if we store it with some op_space data storage we can update it all at once
	op_space.op_space_name = cosd.op_space_name;
	op_space.op_space_external_type = cosd.op_space_external_type;
	// SetDefaultOpSpaceFixedTypeState(op_space, all_data.runtime_settings);

	//TODO Should we just put this in op space directly or have it be separate?
	//Separate means we can reuse it if we delete an op space.
	//We could also just create this for everything if we want to allow people to draw shapes in the text editor and terminal...
	//TODO remove the space_3d from here once the new code is working
	if AllOrEquals(cosd.op_space_external_type, .[.space_2d, .chord_s3]) {
		//TODO Eventually we can allow reusing these if we allow the deletion of a 2d op space.
		op_space_data : *OpSpaceSpecData = array_add(all_op_space_spec_data);
		op_space_data.op_space_id = op_space.id;
		init(*op_space_data.spec_2D_pool, Megabyte(10));
		op_space_data.spec_2D_alloc = Allocator.{flat_pool_allocator_proc, *op_space_data.spec_2D_pool};
	}
	//Make this an else and remove above once new code is working
	if cosd.op_space_external_type == .space_3d {
		//TODO Eventually we can allow reusing these if we allow the deletion of a 3d op space.
		op_3D : *OpSpecData3D = array_add(all_op_spec_data_3D);
		op_3D.op_space_id = op_space.id;	
		init(*op_3D.spec_3D_pool, Megabyte(10));
		op_3D.spec_3D_alloc = Allocator.{flat_pool_allocator_proc, *op_3D.spec_3D_pool};
		//If we reuse this then we don't need this since we can just use the same array data
		// #insert #run SetResizableArrays(OpSpecData3D, "op_3D.%.allocator = op_3D.spec_3D_alloc;\n");
	}

	//TODO Likely can just return the pointer depending on how we use it
	return op_space;
}
//TODO I'm not sure I want to leave these find functions in shared library but I guess it's convenient for now
FindOpSpaceOpenOrClosed :: inline (
	op_space_id : int, 
	all_open_op_spaces : [] OperationSpace,
	all_closed_op_spaces : [] OperationSpace)
-> OperationSpace, found_op_space : bool
{
	op_space, found_op_space := ArrayFindFirstConstByNameId(all_open_op_spaces,
		op_space_id, "id");
	if !found_op_space {
		op_space, found_op_space = ArrayFindFirstConstByNameId(all_closed_op_spaces, 
			op_space_id, "id");
	}
	return op_space, found_op_space;
}
FindOpSpacePointerOpenOrClosed :: inline (
	op_space_name : string, 
	all_open_op_spaces : [] OperationSpace,
	all_closed_op_spaces : [] OperationSpace)
-> *OperationSpace, found_op_space : bool
{
	op_space, found_op_space := ArrayFindFirstByNameId(all_open_op_spaces,
		op_space_name, "op_space_name");
	if !found_op_space {
		op_space, found_op_space = ArrayFindFirstByNameId(all_closed_op_spaces, 
			op_space_name, "op_space_name");
	}
	return op_space, found_op_space;
}

//TODO Could make this into a compile-time list if needed.
AsmOpSpaceData :: struct {
	//return data
	ret_op_space_id : int;//returned

	op_space_type : AsmOpSpaceType;
	// op_space_name : ArrayData;
	op_space_name : AsmString;
	//TODO Add world size and world offset here
} @LibraryAsmGen
/*DOC : This is an ordered subset of OpSpaceExternalType.
Since we don't allow creating text and terminal op space
from asm yet but maybe we will eventually but just in case for now.
*/
AsmOpSpaceType :: enum {
	space_2d;
	space_3d;
} @LibraryAsmGen
AsmOpSpaceToExternalType :: inline (
	asm_type : AsmOpSpaceType)
->	ext_type : OpSpaceExternalType
{
	if #complete asm_type == {
	case .space_2d; return .space_2d;
	case .space_3d; return .space_3d;
	}
}
ClearOpSpaceData :: struct {
	op_space_id : int;
	clear_not_filter_3D : bool; 
}
AsmClearOpData :: struct {
	op_space_id : int;

	//TODO We could also add a value that removes only the filterable points
	//but this feels like soething that should just be in dynamic libraries since then
	//we can do whatever we want from there and asm should just be a total clear.
	//If so, then we can remove this flag later
	clear_not_filter_3D : AsmBool;
} @LibraryAsmGen
/*DOC TODO WE can have a DeleteOpSpace which would just close and then store the op space
somehwere else separately for each type so then we can just reuse the memory directly when a new one is opened.
That is the best way overall since then we don't need any extra allocators and we can just reuse the exact same memory
for all the resizable arrays and only need the op space specific allocator for the data we want to reset in play.
*/
ClearOpSpace :: inline (
	clear_data : ClearOpSpaceData,
	all_open_op_spaces : [] OperationSpace,
	all_closed_op_spaces : [] OperationSpace,
	all_op_space_spec_data : [] OpSpaceSpecData,
	all_op_spec_data_3D : [] OpSpecData3D) 
{
	op_space, found_op_space := FindOpSpaceOpenOrClosed(clear_data.op_space_id, 
		all_open_op_spaces, all_closed_op_spaces);
	if !found_op_space return;
	//TODO Should we return error if not found or just do nothing?
	// if !found_op_space return NO_CPU_ERROR;

	if op_space.op_space_external_type == {
	case .space_2d; {
		op_space_data, found_op_space_data := ArrayFindFirstByNameId(all_op_space_spec_data,
			clear_data.op_space_id, "op_space_id");
		assert(found_op_space_data);

		#insert #run SetResizableArrays(OpSpaceSpecData, "array_reset_keeping_memory(*op_space_data.%);\n");
		//TODO We can remove this if we pull out the shapes for op space spec data
		#insert #run SetResizableArrays(AllSpaceShapes, "array_reset_keeping_memory(*op_space_data.ass.%);\n");
		reset(*op_space_data.spec_2D_pool);
	}
	case .space_3d; {
		op_3D, found_op_3D := ArrayFindFirstByNameId(all_op_spec_data_3D,
			clear_data.op_space_id, "op_space_id");
		assert(found_op_3D);

		//I am adding this here in case we want to generate for higher dims
		//and then just remove vls but the other way is more general for now.
		//We could also allow removing by group_id eventually. HOWEVER that would not clear the allocator pool, so not sure...
		if clear_data.clear_not_filter_3D {
			ArrayRemoveAllByNameId(*op_3D.all_op_space_points_3D,
				true, "do_not_remove_with_filter");
			array_reset_keeping_memory(*op_3D.all_op_text_3D);
		} else {
			#insert #run SetResizableArrays(OpSpecData3D, "array_reset_keeping_memory(*op_3D.%);\n");
			#insert #run SetResizableArrays(ChordSpace3, "array_reset_keeping_memory(*op_3D.op_space_3D.%);\n");
		}
		reset(*op_3D.spec_3D_pool);
	}
	}
}

/*DOC : All the data specific to each op space.
These are separated out since we can reuse them if we ever
remove an op space and since we don't always need the data
when accessing op space info.
Also maybe this is better for resetting, I guess let's see
how we use it and then we can decide.

TODO We could possibly separate 2d and 3d data, but it
may not be worth it since 2d can overlap 3d anyways
*/
//TODO Maybe rename to OpSpecData for conciseness
OpSpaceSpecData :: struct {
	op_space_id : int;

	//TODO WE CAN PUT IDS IN HERE JUST FOR THIS OP SPACE

	//TODO We could maybe pull the arrays out from here eventually
	//if we only have it in the op space
	ass : AllSpaceShapes;
	all_op_circle_spaces : [..] CircleSpace;
	all_op_chord_s2 : [..] ChordSpace2;
	all_op_collision_entities : [..] CollisionEntity;
	all_op_spirals : [..] SpiralSpace;

	//TODO I Think we can generally replace this with using a
	//base shape group in ass so i guess we can gradually transfer over.
	//For example we can do this with circles first.
	//IF that is possible then we can eventually remove this altogether.
	all_op_space_points : [..] SpacePoint;

	spec_2D_pool : Flat_Pool;
	spec_2D_alloc : Allocator;

	//TODO Should we just store this here instead of a separate array since we can only have 1 per op_space?
	//I will leave it in the array for now while refactoring, but afterwards, storing in here makes more sense
	//so then we can just use the same allocator for the whole op_space_3d and then reuse it if ever we delete it
	//Also then we could
	// op_space_3d : ChordSpace3;
	//TODO Can likely change this struct or remove unecessary data
	//once it's working
	//TODO We could separate this out from 3d if this is all we need
	//or if the 2d arrays we allow are different than the above ones
	// all_op_space_points_3D : [..] SpacePoint3D;
	// all_op_text_3D : [..] SpaceText3D;
}

/*ACTUALLY this is more than convenience as it groups all objects by the op_Space their in.
So we would only have to cycle directly through these arrays for both rendering and input
and this would avoid any kind of filtering or moving around data we would need to do later.

ALSO This makes me think that maybe its best to have the dspace be separate by op_space_id as well.
Not entirely sure. Then we would just have an allocator for all shapes and dspaces here
and could then reuse it if we close an op_space for example.

We could also have ids specific to op_spaces eventually and that would mean dspaces
would be identified with op_space_id + dspace_id. Would have to think about that a bit
depending on how we are using it but I think now everything is being redone per op_space
whenever we interact except for linear rows.

PROBABLY Worth considering all of this once we have all the data setup and can use it
with most code so then we know rendering and input and can make a best decision based on that. 
*/
//TODO Use this for convenience so we can add any shape in any function
AllSpaceShapes :: struct {
	all_space_rects : [..] SpaceRect;
	all_space_quads : [..] SpaceQuad;
	all_space_triangles : [..] SpaceTriangle;
	all_space_circles : [..] SpaceCircle;
	all_space_text : [..] SpaceText;

	all_space_shape_values : [..] SpaceShapeValue;

	all_custom_geometries : [..] CustomGeometry;

	/*TODO Leaving this data below here as a reminder of some ideas
	of how to organize data once we separate data between op_spaces here.
	*/
	//TODO Maybe this is better as op_space_id
	//TODO Can remove this from SpaceShape if we use this method.
	// op_space_id : int;
	// all_next_ids : AllNextIds;
	//TODO Would use this to store everything per op_space so this would
	//be the same as op_space allocator. Can use the same allocator for all the
	//shapes and also the text strings.
	//op_alloc : Allocator;
}

/*TODO For custom shapes (and also some of ours maybe) we should allow the creation of point_values
which can be associated to a dspace_to_tuning_system_id struct and then those values can play if
that particular dspace is on. This way people can creates static dspaces using asm/code directly.
Maybe even pseudo-dynamic ones with input if we allow some code to run given input for example in asm/code.
We'll see if we allow that or just allow that in external code.
*/
//TODO Could make this compile-time and insert the code in here or something like that.
SpaceShape :: struct {
	//Maybe we don't need id since the other 3 values are an identifier.
	//This could be used as a return value for code.
	//TODO Still might need this if we want to associate audio for example.
	//Could have space_shape_group and another id for each shape anyways.
	//TODO We set this to -1 and start the next ids from 0 so we only use
	//the id if we need it and we can set it to whatever we want as reference.
	shape_id : int = -1; 
	//This array can be indexed/sorted by op_space_id
	//and then dspace_id and then dspace_shape_group
	//TODO Remove this from here if we use the AllSpaceShapes ordering and indexing method.
	op_space_id : int;
	dspace_id : int;
	//TODO Could add this if we need, maybe also useful for custom shapes
	//that can be added to the system.
	// op_dspace_type : OpDSpaceType;
	//TODO This can likely be 1 64-bit int and then just grab the color from somewhere.
	//Or just a Vector3F... I don't know if that's worth it though, what about alpha?
	color : Vector4F;

	//Probably can make each order 32-bit or 16-bit if needed for efficiency.
	//TODO Do we need render_order for our own rendering?
	render_order : int;
	//This is used to group shapes together.
	//We can then delete in bulk later using op, dspace and shape_group together.
	//TODO should we rename to dspace_shape_ref?
	dspace_shape_group : int;

	not_selectable : bool;

	//These are arrays and not just 2d because we can set more pitches or fun region poses depending on the
	//geometry. Like with spiral the size of the chord depends on the spiral's geometric properties.
	fun_region : [] float64;
	pitch_set : [] float64;
	shape_text : string;
}
SpaceRect :: struct {
	using shape : SpaceShape;
	//TODO Should we store pos and dim here instead?
	//Let's see how we use it overall if we're getting center and dim often.
	//Would also allow us to do SoA and then re-use the point_dim and color
	//from the particular space for the space_points for example.
	rect : Rectangle2;
}
//TODO We could instead of SpaceLine which would only need 5 floats
//But then we would have to compute the quad at runtime anyways...
//ALTHOUGH with this method, say we translated or rotated a dspace
//then we would just have to translate or rotate all space shapes
//in that dspace.
SpaceQuad :: struct {
	using shape : SpaceShape;
	quad : Quad2F;
}
SpaceCircle :: struct {
	using shape : SpaceShape;
	circle : Circle2;
	//TODO Could add a resolution which would allow us
	//to also make polygons.
}
SpaceTriangle :: struct {
	using shape : SpaceShape;
	triangle : Triangle2F;
}
/*TODO Text ideas
1) Current SpaceText which is just 1 short line of 32 chars. Can increase later if needed.u
2) Variable text where we store the string and it can be formatted (like a paragraph for example)
3) Text editing boxes which are formattable so people can write their own text
   which could then be used somehow to adjust some shapes for example or something like that.

We could eventually add font index to change font_size or font type. 
*/
SpaceText :: struct {
	using shape : SpaceShape;
	//REMINDER SET text.data = text_chars.data
	text : string;
	text_chars : [32] u8;
	op_pos : Vector2F;
}
//TODO Eventually we can just allocated the string with the op space allocator
//similarly to the space point fun region pos
SetSpaceText :: inline (s : string, space_text : *SpaceText) {
	count : int = min(s.count, space_text.text_chars.count);
	space_text.text.data = space_text.text_chars.data;
	space_text.text.count = count;
	memcpy(space_text.text.data, s.data, count);
}

AsmShapeType :: enum {
	RECTANGLE;
	// QUADRILATERAL;
	// TRIANGLE;
	// TEXT;
	//TODO Line can be a quad given 2 points
	// LINE;
	//TODO Arrow can just be quad and triangle the way we do it now between 2 points
	// ARROW; 

	// CUBE;
	// BOX;
} @LibraryAsmGen
AsmShapeData :: struct {
	ret_shape_id : int; //return value

	dspace_id : int;
	op_space_id : int;
	dspace_shape_group : int;
	render_order : int;
	color : Vector4F64;
	fun_region : AsmArray(float64); @float64
	pitch_set : AsmArray(float64); @float64
	shape_text : AsmString;
	not_selectable : AsmBool;

	//TODO Put other vars for other shape types later when we add them
	type : AsmShapeType;
	rect_pos : Vector2F64;
	rect_dim : Vector2F64;
} @LibraryAsmGen
AsmText2D :: struct {
	op_space_id : int;
	text : AsmString;
	op_pos : Vector2F64;
	color : Vector4F64;
	render_order : int;
} @LibraryAsmGen
DeleteShapeData :: struct {
	op_space_id : int;
	shape_id : int;
	type : AsmShapeType;
}
//TODO Could rename just SpaceValue
SpaceShapeValue :: struct {
	op_space_id : int;
	shape_id : int;
	//TODO could add this to differentiate for what to do with
	//each different value group
	// shape_value_group : int;
	using value : ShapeValueUnion;
}
//TODO Can use this if we use this union elsewhere to copy generally.
ShapeValueUnion :: union {
	float_value : float64;
	int_value : int;
}
CustomGeometry :: struct {
	dspace_id : int;
	custom_audio_type : CustomAudioType;
	tuning_system_id : int;
	//TODO We can remove this if we don't use it.
	//Using currently to help see where the dspace boundaries are.
	collision_rect : Rectangle2;
	show_collision : bool;
	/*DOC : We technically need this here if want this to work / allow for
	overlapping geometries or overlapping op spaces. So I think it's best to
	just leave this like this
	*/
	synth : SimpleSynth;

	//TODO We could then also put types in here and just fetch
	//that specific data if needed and 
	//custom_internal_type
	//TODO If we put this in here then we could just draw the rects
	//and if it's a sound float, then we do the special audio
	// is_sound_float : AsmBool;
}
CustomAudioType :: enum {
	TUNING_SYSTEM;
	PITCH_SET_AS_FREQUENCY;
} @LibraryAsmGen

CircleSpace :: struct {
	//Note : In case we have 2 sets of SpacePoints with same tuning_system_id
	//we put tuning_system_id in here. This way we allow flexibility.
	//TODO Rename to dspace_id I think. Maybe can leave like this...
	//to make it clear what this actually points to.
	dspace_id : int;
	//TODO Could pull this out or I think it's associated to point_dspace_id
	//and so we can just get it from there. This would let us generalize
	//playing points for different tuning_systems.
	tuning_system_id : int;
	
	//TODO Should this be float64 for accuracy?
	//I guess we can change it if/when we change TuningPitch to float64.
	//I think we use a ratio here instead of just linear because we can think of things
	//like gamma scale with is non-repeating over a non-integer interval.
	//Can likely allow either one to be passed in with an option though for convenience
	//but they could just do the conversion themselves from linear to log ratio
	repeating_interval_ratio : float;

	world_center : Vector2F;
	point_dim : Vector2F;
	//transform includes 3 matrix multiplications for convenience
	//rotation_matrix(theta) * scale_matrix(radius)
	//clockwise *= REFLECT_0(reflection about x_axis)
	transform : Matrix2F;
	radius : float;
	start_note : int;
	//TODO Should this be float64 accuracy for more precision with points?
	repeating_interval_linear : float;
	// repeating_interval_linear : float64;
	//Circle values each between 0-1, we can set them to the world pos
	//with CirclePointToWorldPos
	inter_points : [..] float64;
	//TODO REmove num_of_points once we use circle_points
	// num_of_points : int;
	show_pitch_text : bool;

	//Example of non-repeating circle is gamma scale over 2.0 compass interval
	//which was 34 points that are evenly spaced over a fifth(3/2) but do not repeat evenly.
	is_repeating : bool;

	// sort_music_pts : bool;

	base_shape_group : int = -1;
	base_render_order : int = 7;

	/*Not sure if we need this but just in case we want to allow
	other circles with the same tuning_system but maybe different colored points?
	If we don't allow that though, we can remove this.
	*/
	is_default : bool;

	is_sound_float : bool;
	inner_circle_mute : float;

	//TODO Can make this an array if needed
	osc_wave : OscWave;
	synth : SimpleSynth;
}


ChordSpace2 :: struct {
	#as using chord_space2 : Space2D;

	//TODO Should this really be here or somewhere else?
	//Will we need this when we create spaces with code?
	op_space_id : int;

	next_group_order : int;

	space_pt_render_order : int;
	music_pt_render_order : int;
	vl_pt_render_order : int;

	vl_order_text : bool;
	vl_order_color : bool;

	cs_filters : [..] CSFilter;
	cs_filter_aggregate : ChordSpaceFilterAggregate;

	//TODO maybe separate these out since invariant_ids will be related to dspaces
	invariant_ids : [2] int;
	random_color_0 : Vector4F;
	random_color_1 : Vector4F;
	scale_world_unit : float;
	//TODO this could be a cached *SpacePoint eventually
	//TODO could cache hover world_rect here as well
	//TODO I think we can remove this altogether since we only use
	//it in the OLDChordSpace2 and not in the new one.
	hover_space_point_id : int;

	chosen_point : bool;
	boundary_start_space_point_id : int;
	boundary_start_world_pos : Vector2F;
	start_space_point_id : int;

	accumulated_vl_size : Vector2I;

	//MusicPt : if true then use swapped matrix, otherwise false
	swapped_matrix_flag : bool;
	/*TODO
		i am leaving this here for now for mathematical clarity
		ultimately we only need 2 of these and can swap the
		second column vector coordinates x = y, y = x to have
		the same effect but only while storing 2 matrices

		we explicitly leave 4 matrices for now to show that
		we can change in basis relative to the original transformation
		or to the swapped transformation whenever we cross a boundary
	*/
	invariant_to_world_matrix : Matrix2F;
	world_to_invariant_matrix : Matrix2F;
	swapped_invariant_to_world : Matrix2F;
	swapped_world_to_voice : Matrix2F;
	//TODO could store reflected matrix here since we use regularly

	/*TODO
		placing the input and output spaces here seems more in line
		with the written logic at this point.
		they would be separate from the other spaces and could
		be more easily considered when dealing with chord_s2.
		we are leaving it out for now so we can be more flexible
		with our input/output spaces in case something changes
		logically or conceptually at some point.

		Eventually these may not even be normal linear spaces
		and just be completely different visually so then it
		would make even more sense since the code would also
		be separate.

		The music_pt voices in the input and output space are also
		not supposed to be played so we will separate those with
		a boolean for now but can also put them in a separate array 
		later if we full implement this version of the solution.
	*/
	//TODO should we store the input and output space directly here?
	//TODO or should we just leave it as a connection?
	// input_dspace_id : int;
	// output_dspace_id : int;

	/*MusicPt : position of chord with voice values (0,0)
	  Technically there are 2 of these but we take the 0-sum one as
	  a 2D reference point for converting from fundamental region to world position
	*/
	zero_pos : Vector2F;

	music_pt_count : int;
	tuning_system_id : int;

	//REMINDER : This is does not work with op space zooming.
	//I will leave it so we can play around with it but I don't think
	//I'll update that for now.
	is_sound_float : bool;

	//We only need 1 of these since presumably we will only listen to 1 point at a time with the mouse.
	/*TECHNICALLY This should not be part of the geometry but it is convenient for now.
	This should likely be fetched from a separate synth or maybe even op_space
	where we set a specific sound per op_space to listen to the things in that op_space as
	or per dspace to explore and listen each op_space/dspace.
	*/
	//TODO Can likely replace this later with a synthesizer per dspace or per op_space
	osc_waves : [2] OscWave;
	//TODO Could have an enum with simple synth and subtractive synth
	//AND also custom synth for external function pointer calls.
	//Then can make a dspace_simple_synths and dspace_sub_synths array
	//for separate processing from the neume synth arrays.
	synth : SimpleSynth;


	//MusicPt : temporary data for space edges
	crossed_edge : bool;
	edge_mouse : Vector2F;
	rotate180_edge_mouse : Vector2F;

	reflect_edge : bool;
	reflect_mouse : Vector2F;
}

//UPDATE if changed in Library
//TODO Remove all unused types from here once we cleanup 
//chord space filters for 2d and 3d spaces
ChordSpaceFilterType :: enum {
	//Default for chord_s3 is all points
	//Default for chord_s4 is 3D cross-sections by equal sum
	DEFAULT;
	ALL;
	DIMENSIONAL;
	SUM;

	//TODO Collapse these into 1 type
	EQUAL_AND_ONE_VL;
	VL_DISTANCE;
	LOCAL_VL_DISTANCE_TO_CHORD;
	INTER_CHORD_DELTA;

	SAME_VALUE_COUNT;

	NO_DUPLICATE_PITCHES;
	IN_VALUE_SET;
	//Currently only valid for chord_s3
	DIATONIC;
	CHROMATIC;

	//TODO Use multiple filters instead of this
	CHROMATIC_SUM; //For 3D
	EQUALS_AND_ONE_VL_SUM; //For 4D
} @LibraryAsmGen

ChordSpaceFilterAggregate :: enum {
	INTERSECTION;
	UNION;
	//TODO Implement if we want later
	// DIFFERENCE;
} @LibraryAsmGen

/*TODO I think we should just use 3 64-bit values here anyways so we can reuse
the same struct for asm. Just check when we do 3d spaces as well if it works
and then we can switch it to just having ChordSpaceFilter.
*/
//TODO We could add a negation to the filter so we can do everything that is not that filter
//and then we just have to swap the point_in_filter in FilterChordSpacePoints for each filter point
CSFilter :: struct {
	filter_index : int;
	filter_value : float64;	
	value_set : [] float64;
	filter_type : ChordSpaceFilterType;
}

//TODO I think id like to remove these types eventually.
//Maybe could have an extra array with extra spirals... but iunno
//I find proper ones the most intuitive and flexible and clearest to code for.
SpiralType :: enum {
	PROPER;
	CONCENTRIC_CIRCLE;
	BOOK;
} @LibraryAsmGen
SpiralSpace :: struct {
	dspace_id : int;
	op_space_id : int;
	//TODO I kind of want to remove these types and just have a PROPER spiral.
	//Concentric circle feels weird and has inconsistent float instrument
	//and the book one is downright confusing.
	spiral_type : SpiralType;

	world_center_pos : Vector2F;

	rotate : float = PI/2.0;
	is_clockwise : bool = true;

	start_radius : float; //Not-settable, computed in InitSpiralSpace
	//These sets the spiral_delta so how much we move out per radius index value
	radius_size : float = 3;
	//start_radius_factor to adjust the inner radius size start size
	sr_factor : float = 2;

	total_radius : float;

	pitch_zero_freq : float64;
	tuning_system_id : int;
	//TODO Rename these to point_count and loop_count maybe? Should be generalized just for Spiral
	//instead of for music since we want the spiral geometry to be independent of music.
	//Maybe tuning_count is ok though... circle_delineation_count? not sure...
	tuning_count : int;
	//TODO This could be a float64 so we could have not whole spirals
	//I don't know if that matters since we can just add + 1 here if needed more for example.
	//Why would we need a precise offset from whole is the question in this case?
	//TODO Could be turn_count...
	chord_count : int;

	//TODO We could have an additional value to increase the size of the points on the spiral which we could
	//store here and then also store total point count. This would allow for more instrument exploration for example.

	spiral_delta : float;
	//TODO The factor here can replace bool branch
	//in_out = 1.0 and out_in = -1.0
	in_out_factor : float = 1.0;
	is_in_out : bool = true;

	is_loop : bool = true;
	show_values : bool = true;

	sound_float : bool;

	point_dim : Vector2F = .{0.5,0.5};
	point_color : Vector4F = LIGHT_BROWN;

	base_shape_group : int;
	base_render_order : int = 7;

	/*After some consideration, for now, we will leave the spiral as having 1 base.
	And then we can add other points around the spiral separately if needed.
	Can make some convenience functions to add some in order like with base.
	These values also tell us what the float spiral instrument should be based on.
	*/
	// has_base_points : bool;
	// base_space_point_id : int;
	base_index : int;
	base_chord : [] float64;

	//TODO This will likely just be calling a synthesizer eventually
	//So it does not matter where we put the data for now.
	osc_waves : [] OscWave;
	synth : SimpleSynth;
}

//TODO FROM HERE Add an allocator here so we can set the fun_region_pos
//and also strings and then clear them when we do a clear_op instruction
//don't mind tests we will just have some lost data with tests with the allocator
OpSpecData3D :: struct {
	op_space_id : int;
	op_space_3D : ChordSpace3;
	all_op_space_points_3D : [..] SpacePoint3D;
	all_op_text_3D : [..] SpaceText3D;

	all_custom_geom_3D : [..] CustomGeom3D;

	//TODO We could have separate allocators for text and shapes if needed
	//if we add arbitrary text sizes so then we could reset the text allocator
	//DOC : These allocator are for text and fun regions for vls NOT For the arrays.
	//the arrays are stored on the default allocator since we can reuse this whole data
	//if we delete and create a new 3d space.
	//So they don't affect the regular points which are copied from chord space points
	spec_3D_pool : Flat_Pool;
	spec_3D_alloc : Allocator;
}
/*DOC : This groups some data for custom 3d geometries. Right now
we just use it for sound, but we could include some rendering things in here
although that would complicate rendering. If we add things for rendering
maybe only apply them to a different array a 3d shapes where we fetch
this data separately per group of 3d shapes.
*/
CustomGeom3D :: struct {
	group_id : int;
	//Tuning system is used by default here
	tuning_system_id : int;
	custom_audio_type : CustomAudioType;
	osc_wave_type : OscWaveType;
}

//TODO MAybe we should rename this just OpSpace3DData
DEFAULT_CENTER_OF_ROTATION :: Vector3F.{0,0,25}; 
DEFAULT_CAM_TRANS : Matrix4x3F : #run MakeMatrix4x3F(Matrix3F_Identity, Vector3F.{0,0,0});
MOUSE_DEFAULT :: Vector2F.{FLOAT32_MIN+7, FLOAT32_MIN+92};
//TODO between 25-30 might be better for larger op spaces / screens
DEFAULT_3D_DEPTH : float : 24.0;
// DEFAULT_3D_DEPTH : float : 25.0;
DEFAULT_3D_N : float : 1.0;
DEFAULT_3D_F : float : 240.0;
//TODO update the variable names in here, especially grid ones
//TODO Leaving 3D here for now since this models the mapping
//into 3D specifically
/*TODO If we reuse this as a general 3D space, then we could rename it
*/
//TODO Rename this to Space3D once we clear the old 3d code out
//and then remove all the unused data like osc waves and also these positions
//and also technically dspace and op space id since those are op space specific now
//TODO RENAME TO Space3D once we update everything
ChordSpace3 :: struct {
	// grid_world_center : Vector2F;
	//TODO should we rename to dspace_world_center?
	//TODO I think we can REMOVE THIS now since we just use the op_space.world_offset
	chord_s3_world_pos : Vector2F;
	//TODO Can we remove this or the viewport?
	chord_s3_dim : Vector2F; //TODO should this be an int vector?

	dspace_id : int;
	//TODO Could move this out and use DSpaceToOpSpace to fetch it like with 2D.
	//Then we could reuse this chord_s3 in other op_spaces... OR maybe not in which case we could just leave it...
	//We could just move the camera to this op_space and keep the text fixed if we want to be able to see it for example
	op_space_id : int;

	//We could pull these out as constants instead if needed
	base_group_id : int = 0;
	vl_group_id : int = 1;

	//NOTE : We can get lp_count from music_pt_count in tuning_system
	//but we keep here both for caching but also because it is the linear point count of the space.
	//So we need to update both of them whenever we set the tuning_system.
	/*DOC : These are the defaults for this 3d space. We can set different ones if we want
	with a separate custom geometry now.
	*/
	lp_count : int;
	//TODO we can rename default tuning system
	tuning_system_id : int; 

	/*Note : We have just a boolean for chord_s4 because everything
	is the same in terms of rendering and most input except for
	moving through the 4th dimension and possibly some filtering
	of vertices later on.
	*/
	//TODO Could make this an enum so we could even map
	//5,6 and higher dim spaces which can then be explored
	//in 3D space and programatically at the same time.
	higher_dim : int;
	//TODO could put filters in a separate table
	cs_filter_aggregate : ChordSpaceFilterAggregate;
	new_cs_filters : [..] CSFilter;

	//TODO This will likely just be calling a synthesizer eventually
	//So it does not matter where we put the data for now.
	//TODO Can remove this now
	osc_waves : [] OscWave;
	synth : SimpleSynth;
	default_wave_type : OscWaveType;

	//TODO Need to make a point creating system like we did
	//with filter system.
	octave_count : int;

	lerp_vl_colors : bool;
	render_vl_order_as_int : bool;
	//TODO can put 6 more bools here since we have an enum u8 in ChordSpaceFilter 

	//TODO implement invariant ids with arrows and arrow changes
	// invariant_ids : [3] int;

	//TODO move this out into separate array for points
	// points_dyn : [] SpacePoint3D;

	//TODO move this out into separate array for edges
	// edges : [..] GridEdge3D;

	/*TODO Should we put all this in the op_space for space_3ds eventually?
	Then we can also have generalized shapes like we do for 2D and have
	cubes, icosahedrons, pyramids and anything else with low number of triangles.
	Then we can treat the 3d spaces the same way as the 2d spaces and probably
	also optimize in very similar ways.
	*/
	depth : float = DEFAULT_3D_DEPTH;
	n : float = DEFAULT_3D_N;
	f : float = DEFAULT_3D_F;

	viewport : Viewport;
	p_frustum : Matrix4F;

	/*TODO should we keep using Matrix4x3F here? or split up into
	Matrix3F for transformation and Vector3F for position.
	this depends on efficiency and how they are accessed otherwise
	*/
	//TODO could remove temp if we did mouse delta and normalized rotation matrix (or used quaternions) every frame
	cam_trans : Matrix4x3F = DEFAULT_CAM_TRANS;
	//TODO can we pull this out and simply recompute every frame?
	temp_cam_rotate : Matrix3F = Matrix3F_Identity;
	is_mouse_rotating : bool;
	mouse_cam_is_moving : bool;

	//TODO can we pull this out and simply recompute every frame?
	mouse_rotate : Matrix3F = Matrix3F_Identity;
	temp_mouse_rotate : Matrix3F = Matrix3F_Identity;

	mouse_start : Vector2F = MOUSE_DEFAULT;

	center_of_rotation : Vector3F;

	//TODO WHY NOTE REPLACE THIS WITH The SpacePoint3D
	//instead of point_index OR at least the space_point_id for now
	//and then fetch it instead of doing points_in_grid...
	//TODO maybe this can also be removed and only be placed per frame
	chosen_cube : TriangleInGrid3F;
	click_cube : TriangleInGrid3F;
}
//TODO Pretty sure this was old 3d code that is no longer used. Maybe it was for connecting 3d points with mouse.
//So I will leave it here just in case we want to re-implement that later.
TriangleInGrid3F_DEFAULT :: TriangleInGrid3F.{Triangle3F.{}, -1, S64_MIN + 100, GridTriangleType.NONE};
TriangleInGrid3F :: struct {
	#as using triangle : Triangle3F;
	point_index : int = -1; //Note : start as not indexable in array
	order : int; //TODO do we need this since we have depth buffer?
	//TODO do we need this or can we optimize by just storing Cube struct or something else?
	type : GridTriangleType;
}
GridTriangleType :: enum {
	NONE;
	VERTEX;
	EDGE;
}
MakeTriangleInGrid3F :: inline (triangle : Triangle3F, point_index : int, order : int, type : GridTriangleType) -> TriangleInGrid3F {
	triangle_mesh : TriangleInGrid3F = ---;
	triangle_mesh.triangle = triangle;
	triangle_mesh.point_index = point_index;
	triangle_mesh.order = order;
	triangle_mesh.type = type;
	return triangle_mesh;
}


/*DOC : Reminder we don't need to split up lines since we an do it programatically
and just change the y value in 3d so it works like multiple lines.

TODO We could increase this to 64 bytes if 32 is not enough but this is supposed to be a label
so we don't want it to be too big
*/
SpaceText3D :: struct {
	//TODO Can just use the op space 3d allocator once we implement that
	text : string;
	text_chars : [32] u8;
	op_pos : Vector3F;
	//We can use this later to add or remove things altogether from a 3d space
	group_id : int;
	//TODO We could add a color here as well if needed
}
//TODO Eventually we can just allocated the string with the op space allocator
//similarly to the space point fun region pos
SetSpaceText3D :: inline (s : string, space_text : *SpaceText3D) {
	count : int = min(s.count, space_text.text_chars.count);
	space_text.text.data = space_text.text_chars.data;
	space_text.text.count = count;
	memcpy(space_text.text.data, s.data, count);
}

//DOC In the renderer we check if .x >= 0 otherwise we set multicolor
DEFAULT_CUBE_MULTI_COLOR :: Vector4F.{-1,-1,-1,-1};
/*TODO so maybe these can remane SpacePoints like the others
but then we have different mesh_ids (3D for cube and rectangle for 2D)
although keeping them separate for now makes sense since we are not sure
exactly or even if they truly have things in common

TODO most of the stuff is no longer used in the new 3d model so we can likely remove it like
dspace id and int pos and all the stack arrays and cube
*/
SpacePoint3D :: struct {
	//TODO Do we really need this id since the points are always used a dspace, maybe for selection?
	//This might be useful for dynamic libraries later
	id : int;
	//DOC : Convenience to group things together and add/delete together later.
	group_id : int;

	rel_pos : Vector3F;
	pitch_set : [] float64;
	fun_region : [] float64;
	//DOC : This is good for setting any text. Someone could set traditional music values
	//or alternative values. By default we set the pitch set but allowing any text
	//allows the point to represent anything and we could add extra info for different geometries
	//within the same 3d space.
	shape_text : string;

	draw_wire_mesh : bool;
	is_selectable : bool = true;
	//TODO Should we name this remove with filter instead? All custom points won't be added
	do_not_remove_with_filter : bool;
	color := DEFAULT_CUBE_MULTI_COLOR;
	//TODO Can have a transformed cube or just have 3x3 for all cubes...
	//TODO Can have this for all 3d shapes and a separate one with 3x3 for arbitrary transforms
	scale_value : float = 1.0;

	render_solid_cube : bool = true;
	// dspace_id : int;
}


/*Start of circle data
*/
AsmMapCircle :: struct {
	dspace_id : int;
	op_space_id : int;

	dspace_shape_group : int;
	pitches : AsmArray(float64);
	// point_count : int;
	// point_data : int;

	//TODO This is a convenience but maybe we only have player
	//draw vl directly themselves with arrows eventually.
	//TODO Should this be an enum or no?
	draw_vl_type : DrawVLType;
} @LibraryAsmGen
DrawVLType :: enum {
	NONE;
	VL_LINE;
	VL_ARROW;
} @LibraryAsmGen

AsmCircleData :: struct {
	ret_dspace_id : int;

	radius : float64 = 5.0;
	//TODO Use Vector2F64 now
	world_center : Vector2F64;
	// world_center_x : float64;
	// world_center_y : float64;
	rotate_theta : float64 = PI64/2;
	//TODO Use Vector2F64 now
	point_dim : Vector2F64;
	// point_dim_x : float64 = 0.6;
	// point_dim_y : float64 = 0.6;
	is_clockwise : AsmBool = #run ToAsmBool(true);
	repeating_interval_ratio : float64 = 2.0;

	tuning_system_id : int;

	//TODO Should this be is_cyclical?
	non_repeating : AsmBool;

	//TODO Not sure if we really need this but in case we want it too look like a different note octave this works.
	//Just need to check how it works for circle audio input as well.
	//This case adds a bit of complexity since we need to subtract it in music_pt rendering but it allows us
	//to do a case we cannot otherwise do, like have 1 octave from G that we can see visually in 12-eq for example.
	start_note : int;

	is_sound_float : AsmBool;
	inner_circle_mute : float64 = 0;

	op_space_id : int;

	show_text : AsmBool;
	no_base_points : AsmBool;
} @LibraryAsmGen

CreateCircleSpaceData :: struct {
	radius : float = 5.0;
	world_center : Vector2F;
	rotate_theta : float = PI/2;
	point_dim := Vector2F.{0.6,0.6};
	is_clockwise : bool = true;
	repeating_interval_ratio : float = 2.0;

	tuning_system_id : int;

	//TODO Should this be is_cyclical?
	//TODO RENAME this to non-repeating and set properly
	is_repeating : bool = true;

	// sort_music_pts : bool = true;

	//TODO Not sure if we really need this but in case we want it too look like a different note octave this works.
	//Just need to check how it works for circle audio input as well.
	//This case adds a bit of complexity since we need to subtract it in music_pt rendering but it allows us
	//to do a case we cannot otherwise do, like have 1 octave from G that we can see visually in 12-eq for example.
	start_note : int;

	is_sound_float : bool;
	inner_circle_mute : float = 0;

	//We can use these if we ever have > 1 circle with the same
	//tuning_system, compass_interval and repeating_interval_ratio for some reason.
	//Maybe someone wants 2 with different colors? Seems like a reasonable option.
	is_default : bool = true;
	//if !is_default then we use point_space_id
	point_dspace_id : int;

	show_text : bool;
	no_base_points : bool;
}

//TODO Where should put this and should we just have 1 120 roots and cycle over that?
//Or maybe 60 is enough in general? Let's see how it is used.
circle_roots :: #run RootsOfUnity(40);

/*TODO IF WE WANTED DYNAMIC POINTS. Then we could compute cos and sin at runtime and have a separate
   dynamic circle which could change shape while things are running more efficiently for example.
   Then we would NOT have SpacePoint and just compute cos and sin here based on tuning_pitches
   and how many points we want to show. This would be the same code we use to create SpacePoint now
   but we would compute it every frame. That would be interesting! Circles changing every frame 
   between tuning_systems for example. I am not sure how useful it is, but is likely worth trying.
*/
//TODO We can make a version of this that passes in num_of_points instead and then one that computes
//num_of_points from repeating_interval_ratio OR just have it be an option in CreateCircleSpaceData
//so that maybe that can make it easier to decide how many points we want either way.
CreateCircleSpace :: inline (
	c_data : CreateCircleSpaceData,
	all_tuning_systems : [] TuningSystem,
	op_spec_data : *OpSpaceSpecData)
-> *CircleSpace 
{
	//NOTE : I think it makes more sense to do this externally since we just need 1 function conversion
	//instead of all this extra code to have to change the entire function here...
	//TODO Can remove this if we never use, just leaving here as a reminder right now.
	// repeating_interval_ratio : float = c_data.repeating_interval_ratio;
	// if c_data.use_num_of_points {
	// 	repeating_interval_ratio = LinearToLogRatio(c_data.num_of_points, tuning_system.compass_interval, tuning_system.music_pt_count);
	// }

	//TODO all_tuning_systems should be properly indexed
	tuning_system := ArrayFindFirstByNameId(all_tuning_systems, c_data.tuning_system_id, "id");

	circle : *CircleSpace = array_add(*op_spec_data.all_op_circle_spaces);
	//TODO Likely use a different id eventually if we don't use SpacePoint anymore especially.
	//For now we use this so it does not conflict with other dspaces for SpacePoint in case we continue to use it
	//for consistency and also so we can draw vls between different spaces more easily and clearly.
	circle.dspace_id = context.ALL_NEXT_IDS.DSPACE_ID;
	context.ALL_NEXT_IDS.DSPACE_ID += 1;
	circle.base_shape_group = -1;
	circle.base_render_order = 7;
	circle.tuning_system_id = c_data.tuning_system_id;
	circle.point_dim = c_data.point_dim;
	circle.world_center = c_data.world_center;
	circle.radius = c_data.radius;
	circle.show_pitch_text = c_data.show_text;
	circle.repeating_interval_ratio = c_data.repeating_interval_ratio;
	// circle.repeating_interval_linear = LogRatioToLinear(c_data.repeating_interval_ratio, tuning_system.compass_interval);
	//TODO Make a function that also does float64 so we don't have to do this directly here
	// circle.repeating_interval_linear = (log(c_data.repeating_interval_ratio) / log(cast(float64) tuning_system.compass_interval));
	// circle.repeating_interval_linear = LogRatioToLinear64(c_data.repeating_interval_ratio, tuning_system.compass_interval);
	circle.repeating_interval_linear = LogRatioToLinear(c_data.repeating_interval_ratio, tuning_system.compass_interval);
	#insert #run SetResizableArrays(CircleSpace, "circle.%.allocator = context.allocator;\n");
	// circle.sort_music_pts = c_data.sort_music_pts;

	circle.is_sound_float = c_data.is_sound_float;
	circle.inner_circle_mute = c_data.inner_circle_mute;
	//TODO can remove this osc_wave once we just use the simple synth
	circle.osc_wave.type = OscWaveType.SINE;

	circle.synth.wave_type = OscWaveType.SINE;
	circle.synth.envelope = MakeVolumeEnvelope();
	s_wave : *OscWave = array_add(*circle.synth.simple_waves);

	/*OVERALL we don't really need a non-repeating circle but I am going to leave
	it here since it is convenient for things like gamma scale over 2.0 compass interval
	or having an octave and a fifth for example BUT it may not be totally clear.
	Overall circles should be used as cyclic structures and if they are not repeating
	then we should not modulo on music_pt mapping to the circle. This can be onde by the
	user though before passing the the pt to the circle.
	*/
	//If the circle is repeating, then we want to make sure that we have a multiple of the
	//compass_interval so that we are repeating exactly.
	if c_data.is_repeating {
		//We make sure here that repeating_interval_ratio is a multiple of the compass_interval
		//by checking that linear is a whole number
		remainder : float = frac(circle.repeating_interval_linear);
		is_repeating_octave : bool = FloatBothEqual(0.0, remainder);
		//TODO This should be returned as an error and not an assertion.
		// assert(is_repeating_octave);
		if !is_repeating_octave {
			print("Circle is not actually repeating but was set to repeating : %.\n", circle);
		}

		if is_repeating_octave && c_data.is_repeating {
			circle.is_repeating = true;
		} else {
			circle.is_repeating = false;
		}
		// circle.is_repeating = c_data.is_repeating;

		//We only set start_note for repeating otherwise it does not make sense
		//as we would just be removing a note. We could do this if needed but for now
		//we just draw out all the points on a non-repetitive circle every time.
		//Only setting the start_note on repeating circles here avoids any
		//extra calculations for music_pt rendering on the circle.
		//Therefore start_note is 0 if the circle is not repeating.
		circle.start_note = c_data.start_note;
	}

	circle.is_default = c_data.is_default;
	//NOTE : Using the transform like this allows us to have multiple different circles with the same tuning system
	//but with with different directions, thetats and radii without changing anything.
	//Alternatively, we could have a set of points for each of these if something like that is more efficient.
	// circle.transform = Matrix2F_IDENTITY;
	//NOTE : This will give identity matrix if rotate_theta = 0
	circle.transform = MakeRotationMatrix2F(c_data.rotate_theta);
	//TODO Maybe we want to keep the radius separate for the music_pt float
	//I Think that might make more sense and then we just have multiple it everywhere and
	//THEN WE DONT HAVE TO DIVIDE ON music_pt float for example which might be confusing later
	//Remove this now and we use CirclePointToWorldPos to do the conversion 
	//systematically with the transform and the radius separately now.
	// circle.transform *= MakeScaleMatrix2F(c_data.radius,c_data.radius);
	if c_data.is_clockwise {
		//Note : circle clockwise is equivalent to reflection about the x-axis
		circle.transform *= REFLECT_0;
	}

	return circle;
}

MakeCircleSpaceShapes :: inline (
	c_space : *CircleSpace,
	op_spec_data : *OpSpaceSpecData,
	all_tuning_systems : [] TuningSystem,
	all_tuning_pitches : [] TuningPitch) 
{
	//TODO Need to check if the tuning_system to dspace already exists first like in linear.
	tuning_system := ArrayFindFirstByNameId(all_tuning_systems, c_space.tuning_system_id, "id");
	tuning_pitches := ArrayFindAllVarName(all_tuning_pitches, c_space.tuning_system_id, "tuning_system_id", temp);
	assert(tuning_system.music_pt_count == tuning_pitches.count);

	/*NOTE : start_note will make space_points[0] have degree 0. This way its basically
	starting from the note and then we continue as normal. This makes us
	have to consider the start_note during computations to keep it relative.
	*/
	//Using linear here makes more sense for thinking and is more efficient than multiplying ratios and converting every loop.
	assert(c_space.start_note < tuning_pitches.count);

	tuning_octave : int = 0;
	total_circle_linear : float64 = 0;
	tp_index : int = 0;
	start_linear_offset : float = 0;
	//We only allow start_note adjustment for repeating circles.
	//If it's non-repeating then adjusting start note would in fact
	//remove a value since we don't repeat so we don't do that and
	//let all the notes be displayed. We can change this later
	//but likely not since a circle is a naturally cyclical structure
	//and should be used as such. The non-repeating is just being placed
	//here for convenience, for example to see the gamma scale over the
	//2.0 compass interval even though it does not repeat.
	if c_space.is_repeating {
		tp_index = c_space.start_note;
		start_linear_offset = tuning_pitches[c_space.start_note].linear_from_start;
	}
	// current_ratio : float = 1.0;
	//Note : leaving here in case we want to use ratio instead.
	// while current_ratio < repeating_interval_ratio {
	//Need to be careful here because of floating point error
	//we could add an extra note so we want to avoid that.
	//This Check is essientially equal to the check below
	/*TODO FROM HERE I THINK it is less confusing to do
	pt_count * log(repeating) / log(compass) here and then cast/round
	down and use that as number of points instead of this cause this
	causes a lot of floating error. Should we just remove start_note
	for my sanity
	*/
	//TODO We could pass in num_of_points instead and have a function that allows us
	//that computes the num_of_points based on the ratio for example.
	//TODO Do we need to round and then cast here or something like that? not sure...
	//TODO We could also 0.000001 or something like that to avoid float errors.
	// num_of_points := cast(int) (tuning_system.music_pt_count * c_space.repeating_interval_linear);
	num_of_points : int = floor_to_int(tuning_system.music_pt_count * c_space.repeating_interval_linear);

	//Explicitly removing 1 here so we remember that we are starting from 0
	//Nevermind we have 20 points in 12-et 3/2 and 35 points in gamma scale over 2.0 compass interval
	//In general non-repeating is just a bonus so it does not have to be perfect.
	// c_space.num_of_points -= 1;
	for 0..num_of_points-1 {
	// while total_circle_linear < 0.999 {
	// while total_circle_linear < 1.0 && !FloatEqual(total_circle_linear, 1.0) {
		//TODO Can also add a filter here if we only want specific points for a specific scale for example.
		// point : *SpacePoint = array_add(all_space_points);
		// point.id = context.ALL_NEXT_IDS.POINT_ID;
		// defer context.ALL_NEXT_IDS.POINT_ID += 1;
		// point.dspace_id = c_space.point_dspace_id;
		// point.int_pos.x = tp_index + tuning_octave * tuning_system.music_pt_count;
		// //We need to store the linear value here so we can compute interpolated values easily.
		// point.rel_pos.x = cast(float) total_circle_linear;
		// point.dspace_pos = GetCirclePoint(cast(float) total_circle_linear);
		// point.color = GetPointColor(tp_index, tuning_system, CIRCLE_COLOR_DEFAULT);


		//ADDING SPACE RECTS DIRECTLY and then we can remove SpacePoint above once this is working.
		rect : *SpaceRect = array_add(*op_spec_data.ass.all_space_rects);
		rect.shape_id = context.ALL_NEXT_IDS.NEXT_SHAPE_ID;
		context.ALL_NEXT_IDS.NEXT_SHAPE_ID += 1;
		rect.op_space_id = op_spec_data.op_space_id;
		rect.dspace_id = c_space.dspace_id;
		rect.dspace_shape_group = c_space.base_shape_group;
		rect.render_order = c_space.base_render_order;
		rect.color = GetPointColor(tp_index, tuning_system, CIRCLE_COLOR_DEFAULT);
		// dspace_pos : Vector2F = GetCirclePoint(cast(float) total_circle_linear);
		// op_pos : Vector2F = c_space.transform * dspace_pos + c_space.world_center;
		op_pos : Vector2F = CirclePointToWorldPos(cast(float) total_circle_linear, c_space);
		array_add(*c_space.inter_points, total_circle_linear);
		// world_rect : Rectangle2 = RectCenterDim(world_pos, c_space.point_dim);
		rect.rect = RectCenterDim(op_pos, c_space.point_dim);
		rect.pitch_set = NewArray(1, float64,,op_spec_data.spec_2D_alloc);
		pitch_value : int = tp_index + tuning_octave * tuning_system.music_pt_count;
		// rect.pitch_set[0] = MusicPtToFrequency(cast(float64) pitch_value, tuning_system, tuning_pitches);
		rect.pitch_set[0] = cast(float64) pitch_value;
		rect.shape_text = sprint("%", pitch_value,,op_spec_data.spec_2D_alloc);

		if c_space.show_pitch_text {
			space_text : *SpaceText = array_add(*op_spec_data.ass.all_space_text);
			space_text.op_pos = CirclePointToWorldPos(cast(float) total_circle_linear,
				c_space.radius + Length(1.5*c_space.point_dim), c_space.world_center, c_space.transform);
			space_text.color = WHITE_V;
			SetSpaceText(rect.shape_text, space_text);
		}


		// rect_value : *SpaceShapeValue = array_add(*ass.all_space_shape_values);
		// rect_value.shape_id = rect.shape_id;
		// rect_value.float_value = MusicPtToFrequency(cast(float64) point.int_pos.x, tuning_system, tuning_pitches);
		// rect_value.float_value = MusicPtToFrequency(total_circle_linear, tuning_system, tuning_pitches);

		//NOTE : Not using this we have only 1 value to check for consistency and to avoid errors, but we could if needed.
		// current_ratio *= tuning_pitches[tp_index].ratio_to_next_music_pt;
		tp_index += 1;
		if tp_index >= tuning_pitches.count {
			tp_index = 0;
			tuning_octave += 1;
		}
		tp : TuningPitch = tuning_pitches[tp_index];
		total_circle_linear = (tp.linear_from_start + tuning_octave - start_linear_offset) / c_space.repeating_interval_linear;
		// total_circle_linear = (tp.linear_from_start + tuning_octave - start_linear_offset) / (c_space.repeating_interval_ratio / tuning_system.compass_interval);
	}
}

/*TODO REVIEW AND TEST AND CLEAN UP THIS FUNCTION 
//MAYBE give this a quick pass to see if we can optimize it a bit but i think it's ok overall.
//Might be good to actually write some tests also OR we can wait till be do asm as well to test all at once,
//BUT it is fresh in my mind right now. May be best to test when fresh
//Then transfer to test so we can put the new circle in op_space and then start on row asm
*/
//TODO Can pull this out of here if we need to use it somewhere else. We likely will so maybe that's a good idea.
//TODO I think this function is worth testing to make sure it works for various different circles and tuning systems.
//with different start notes and different compass intervals for example.
MusicPtToCirclePos :: inline (music_pt : float64, circle : CircleSpace) -> Vector2F {
	//TODO I think maybe we should remove this case because  we should just assume the circle is repeating maybe
	//If the circle is not repeating, then we don't want anything of the # of points.
	//WE COULD make this a user decision instead of doing it here and just generate the notes properly.
	//We can leave it here for now as a reminder and then see how people use it later.
	// if !circle.is_repeating && music_pt >= cast(float64) circle_points.count {
		//TODO Should we return an error or just pull this out?
		// return .{};
	// }
	//Can we do all this a better way while avoiding any floating point errors?
	cp_frac : float64 = frac(music_pt);
	pt_diff : int = round_to_int(music_pt - cp_frac - circle.start_note);
	// if pt_diff < 0 pt_diff += 12; //TODO FROM HERE This needs to be from the tuning_system
	//If its negative from start_note, then we want it to module with tuning_system not circle_points.count
	//Maybe we remove start_note... it reminds me of being able to tune a guitar though... iunno,
	//lets change this and then update the sound and maybe i still remove it and leave it commented out
	//We use PosMod here since this could be negative
	cp1_index : int = PosMod(pt_diff, circle.inter_points.count);
	cp2_index : int = (cp1_index + 1) % (circle.inter_points.count);
	cp1 : float64 = circle.inter_points[cp1_index];
	cp2 : float64 = circle.inter_points[cp2_index];
	rel_delta : float64 = cp2 - cp1;
	//TODO Should make an explicit test for this edge case with start_note > 0 in case we forget
	//In case we wrap around the circle with start_note==1. I think this is the only edge case
	if cp2_index == 0 rel_delta = 1.0 - cp1;
	//NOTE : If we use dspace_pos here then we get a linear interpolation along the line and we don't have to do sin,cos
	// world_pos : Vector2F = circle.transform * (cp1.dspace_pos + cp_frac * (cp2.dspace_pos - cp1.dspace_pos));
	interp : float64 = cp1 + cp_frac * rel_delta;
	// world_pos : Vector2F = circle.transform * circle.radius * GetCirclePoint(interp) + circle.world_center;
	world_pos : Vector2F = CirclePointToWorldPos(cast(float) interp, circle);
	return world_pos;
}
CirclePointToWorldPos :: inline (x : float, c : CircleSpace) -> Vector2F {
	return CirclePointToWorldPos(x, c.radius, c.world_center, c.transform);
}
//DOC : X is where we are along the circle between 0 and 1. So it gets converted to radians by GetCirclePoint
CirclePointToWorldPos :: inline (x : float, radius : float, world_center : Vector2F, transform : Matrix2F) -> Vector2F {
	world_pos : Vector2F = transform * (radius * GetCirclePoint(x)) + world_center;
	return world_pos;
}

CreateCircleInOpSpace :: inline (
	c_data : CreateCircleSpaceData,
	op_spec_data : *OpSpaceSpecData,
	//We pass this in here so we make sure to get the right tuning systems
	all_tuning_systems : [] TuningSystem,
	all_tuning_pitches : [] TuningPitch)
-> *CircleSpace 
{
	circle : *CircleSpace = CreateCircleSpace(c_data, all_tuning_systems, op_spec_data);
	if !c_data.no_base_points {
		MakeCircleSpaceShapes(circle, op_spec_data, all_tuning_systems, all_tuning_pitches); 
	}
	coll : *CollisionEntity = array_add(*op_spec_data.all_op_collision_entities);
	coll.entity_id = circle.dspace_id;
	coll.entity_type = EntityType.OP_CIRCLE_DSPACE;
	coll.op_space_id = op_spec_data.op_space_id;
	coll.shape = CollisionShape.CIRCLE;
	coll.circle.pos = circle.world_center;
	coll.circle.radius = circle.radius + Length(0.6*circle.point_dim);

	return circle;
}
/* End of circle data
*/

/*End op space spec data / op space shapes data
*/
