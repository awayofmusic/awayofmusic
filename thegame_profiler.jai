//TOOD only use if profiling flag is set during compilation

#import "Basic";
#import "Hash_Table";
//TODO could just pull in rdtsc procedure if that's all we use
#import "Machine_X64";

//TODO could do a compile time version since we know all profiler names and
//where they are set at compile time
profiler_table : Table(string, ProfilerData);

GetProfilerPointer :: inline (name : string) -> *ProfilerData {
	profiler := table_find_pointer(*profiler_table, name);
	return profiler;
}

CreateProfiler :: inline (name : string) -> *ProfilerData {
	profiler := table_add(*profiler_table, name, ProfilerData.{});
	return profiler;
}

GetOrCreateProfilerPointer :: inline (name : string) -> *ProfilerData {
	profiler := GetProfilerPointer(name);
	if profiler == null profiler = CreateProfiler(name);
	assert(profiler != null);
	return profiler;
}

FunctionName :: inline () -> string {
	return context.stack_trace.info.name;
}

ProfileProcedure :: () #expand {
	profiler := GetOrCreateProfilerPointer(FunctionName());

	//Runs at beginning of procedure
	ProfilerStart(FunctionName(), profiler);

	//Runs at end of procedure
	`defer {
		ProfilerEnd(FunctionName(), profiler);
		ProfilerPrint(FunctionName(), profiler);
	}
}

ProfilerStart :: (name : string) #expand {
	profiler := GetOrCreateProfilerPointer(name);
	ProfilerStart(name, profiler);
}

ProfilerStart :: (name : string, profiler : *ProfilerData) #expand {
	profiler.start_cycle_count = rdtsc();
	profiler.start_time = get_time();
}

ProfilerEnd :: (name : string) #expand {
	profiler := GetOrCreateProfilerPointer(name);
	ProfilerEnd(name, profiler);
}

ProfilerEnd :: (name : string, profiler : *ProfilerData) #expand {
	profiler.cycle_count_this_frame = rdtsc() - profiler.start_cycle_count;
	profiler.time_this_frame = get_time() - profiler.start_time;
}

ProfilerPrint :: (name : string) #expand {
	profiler := GetOrCreateProfilerPointer(name);
	ProfilerPrint(name, profiler);
}

ProfilerPrint :: (name : string, profiler : ProfilerData) #expand {
	print("% line % - %ms, cycles : %\n", name, 
		//TODO does not give the correct source line number
		context.stack_trace.line_number, 
		formatFloat(profiler.time_this_frame * 1000.0, trailing_width = 6, zero_removal = .NO),
		profiler.cycle_count_this_frame);
}

//TODO have start_this_frame and cleanup_this_frame procedures to startup and reset this data every frame
ProfilerData :: struct {    
    cycle_count_this_frame : u64;
    time_this_frame : float64;
    //TODO compute hit count and can pass in variable for loops so don't have to call profiler every loop
    hit_count_this_frame : u32;

    start_cycle_count : u64;
    start_time : float64;
}