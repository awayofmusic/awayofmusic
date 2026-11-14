#import "Basic";

Serializer :: struct {
	buffer : [..] u8;
}

//TODO Can do a version of this given pointer type and size and then reserve and memcpy to buffer
//OR just have that version with size of 1 as default actually
write_bytes :: (using s : *Serializer, v : $T) {
	byte : *u8 = cast(*u8) *v;
	for 0..size_of(T)-1 array_add(*buffer, <<(byte + it));
}

write_string :: (using s : *Serializer, v : string) {
	//TODO could do this with a memcpy for efficiency
	write_bytes(s, v.count);
	//TODO Can do this in one shot since we know type and count of array
	for 0..v.count-1 {
		array_add(*buffer, v[it]);
	}
}

write_struct :: (using s : *Serializer, v : $T) {
	expand_for_members :: ($T : Type) -> string {
		t_info := cast(*Type_Info_Struct) type_info(T);

		//TODO precheck if we have no structs, strings or arrays
		//then we can just write directly with 1 addition

		sb : String_Builder;
		bytes_written : int = 0; 
		for member : t_info.members
		{
			if member.offset_in_bytes < bytes_written continue;
			bytes_written += member.type.runtime_size;

			print_to_builder(*sb, 
			"write(s, v.%);\n", member.name);
		}
		return builder_to_string(*sb);
	}

	#insert #run expand_for_members(T);
}

write_array :: (s : *Serializer, v : [] $T) {
	write_bytes(s, v.count);
	//TODO Can do this in one shot since we know type and count of array
	for 0..v.count-1 {
		write(s, v[it]);
	}
}

write :: (s : *Serializer, value: $T) {
    #if #run type_info(T).type == Type_Info_Tag.ARRAY {
        write_array(s, value);
    } else #if #run type_info(T).type == Type_Info_Tag.STRUCT {
        write_struct(s, value);
    } else #if #run type_info(T).type == Type_Info_Tag.STRING {
    	write_string(s, value);
    // } else #if #run type_info(T).type == .ENUM {
    //     write_enum(s, value);
    // } else #if #run type_info(T).type == .VARIANT {
    //     write_variant(s, value);
    } else {
    	//TODO should this be more explicit so we can catch non-available types?
		write_bytes(s, value);
    }
}

Deserializer :: struct {
	buffer : [] u8;
	index : int;
}

read_bytes :: (using d : *Deserializer, v : *$T) {
	assert(index + size_of(T) <= buffer.count);

	<< v = << (cast(*T) (buffer.data + index));
	index += size_of(T);
}

read_struct :: (d : *Deserializer, v : *$T) {
	expand_for_members :: ($T : Type) -> string {
		t_info := cast(*Type_Info_Struct) type_info(T);

		//TODO precheck if we have no structs, strings or arrays
		//then we can just write directly with 1 addition

		sb : String_Builder;
		bytes_written : int = 0; 
		for member : t_info.members
		{
			if member.offset_in_bytes < bytes_written continue;
			bytes_written += member.type.runtime_size;

			print_to_builder(*sb, 
			"read(d, *v.%);\n", member.name);
		}
		return builder_to_string(*sb);
	}

	#insert #run expand_for_members(T);
}

read_array :: (d : *Deserializer, array : *[..] $T) {
	count : int = ---; 
	read_bytes(d, *count);
	array_resize(array, count);
	for 0..count-1 {
		read(d, (cast(*T) array.data) + it);
	}
}

read_array :: (d : *Deserializer, array : *[$N] $T) {
	count : int = ---;
	read_bytes(d, *count);
	assert(N == count);
	for 0..N-1 {
		read(d, (cast(*T) array.data) + it);
	}
}

read_array :: (d : *Deserializer, array : *[] $T) {
	count : int = ---;
	read_bytes(d, *count);
	array_resize(array, count);
	for 0..count-1 {
		read(d, (cast(*T) array.data) + it);
	}
}

read_string :: (d : *Deserializer, v : *string) {
	//TODO could do this with a memcpy for efficiency
	count : int = ---;
	read_bytes(d, *count);
	v.data = alloc_string(count).data;
	v.count = count;
	for 0..count-1 {
		v.data[it] = d.buffer[d.index + it];
	}
	d.index += count;
}

read :: (d : *Deserializer, value: *$T) {
    #if #run type_info(T).type == Type_Info_Tag.ARRAY {
        read_array(d, value);
    } else #if #run type_info(T).type == Type_Info_Tag.STRUCT {
        read_struct(d, value);
    } else #if #run type_info(T).type == Type_Info_Tag.STRING {
    	read_string(d, value);
    // } else #if #run type_info(T).type == .ENUM {
    //     read_enum(d, value);
    // } else #if #run type_info(T).type == .VARIANT {
    //     read_variant(bytes, index, value);
    } else {
    	//TODO should this be more explicit so we can catch non-available types?
    	read_bytes(d, value);
    }
}

