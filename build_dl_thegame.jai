#import "Compiler";
#import "Process";
#import "Basic";
#import "String";
#import "shared_names";
// #import "File_Utilities";
// #import "File";

//TODO We now store the lock file with name in the created dl folder which allows for as many as we need
//Can likely remove this if we everything works on mac and windows.
// lock_file_name :: "lock_external_level.tmp";
// Lock file here so we don't grab the new_dll until its fully recompiled
// success := run_command("touch", lock_file_name);
// print("created % : %\n", lock_file_name, success);	
#run build();
build :: () {
	w := compiler_create_workspace();
	options := get_build_options();
	
	output_library_name : string;
	output_dir : string;
	file_name : string;

	lock_file_name : string;
	args := options.compile_time_command_line;
	if args.count == 1 {
		found_slash, output_dir=, output_library_name= := split_from_right(args[0], "/");
		if !found_slash {
			output_library_name = output_dir;
			output_dir = "";
		}
		// print("output_dir=%, output_library=%\n\n\n", output_dir, output_library_name);
		file_name = tprint("%.jai", args[0]);

		lock_file_name = tprint("%_lock.tmp", args[0]);
		success, output_string, error_string := run_command("touch", lock_file_name);
		if success.exit_code == 0 {
			print("created % : %\n", lock_file_name, success);	
		} else {
			print("error creating % : %\n", lock_file_name, error_string);
			return;	
		}
	}
	else {
		print("Need 1 argument for level_name.\n");
		return;
	}

	// options.output_path = tprint("%/%/", args[0]);
	options.enable_bytecode_inliner = false;
	options.output_path = tprint("%", output_dir);
	// options.backend =.X64; // this is the fast backend, LLVM is slower
	options.output_executable_name = output_library_name;
	options.output_type      	   = .DYNAMIC_LIBRARY;
	set_optimization(*options, .DEBUG);
	set_build_options(options, w);


	compiler_begin_intercept(w);
	add_build_file(file_name, w);
	while true {
		message := compiler_wait_for_message();
		if !message continue;
		if message.workspace != w continue;
		if message.kind == .COMPLETE {
			print("done compiling %\n", output_library_name);
			success, output_string, error_string := run_command("rm", lock_file_name);	
			if success.exit_code == 0 {
				print("removed % : %\n", lock_file_name, success);	
			} else {
				print("error removing % : %\n", lock_file_name, error_string);
			}
			break;
		}
	}
	compiler_end_intercept(w);
	
	set_build_options_dc(.{do_output=false});
}