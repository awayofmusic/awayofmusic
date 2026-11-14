/* NOTE
	we are setting the needed string functions here but 
	if we use a lot more then we can just #import the jai String module
*/

//TODO can remove the functions below if we are using the string module directly?
String :: #import "String";

//TODO T
MY_DEFAULT_DELIMITERS : string : "";
MY_DEFAULT_SKIPS : string : " \t\r";

StringTrimLeft :: (s: string, chars := MY_DEFAULT_SKIPS) 
-> string, trim_count : int
{
    index := 0;

    for 0..s.count-1 {
        if String.is_any(s[it], chars) index += 1;
        else break;
    }
    
    return String.slice(s, index, s.count-index), index;
}

StringToken :: struct {
	//TODO Maybe we don't need char_index anymore
	next_char_index : int;
	token : string;
	success : bool;
}

//TODO start_index not supported in String/module so we copy here and support it.
//Can remove if String.find_index_from_right supports it eventually.
FindIndexFromRight :: (s: string, byte: u8, start_index := 0) -> s64  #no_abc {  // Returns -1 if the byte is not found in the string.
	// assert(start_index > 0);
    // cursor := s.count - 1;
    cursor := start_index;
    while cursor >= 0 {
        if s[cursor] == byte  return cursor;
        cursor -= 1;
    }

    return -1;
}
FindIndexFromRight :: (s: string, substring: string, start_index : int) -> s64 {
    if !substring return -1;

    // This is SO SLOW! @Cleanup.
    for < i: 0..start_index {
        t := String.slice(s, i, substring.count);
        if t == substring return i;
    }

    return -1;
}

ParseStringToken :: inline (
	s : string, start_index : int,
	delimiters : string = MY_DEFAULT_DELIMITERS,
	skips : string = MY_DEFAULT_SKIPS)
-> StringToken
{
	//TODO Should this be asserted or just return not successful?
	//This is also currently checked in String.slice. Can probably
	//make my own Slice function with less checks in it.
	if start_index >= s.count return StringToken.{};

    //TODO Should we separate out ParseToken?
    //Should we make our own slice function with less verifications?
    line_copy : string = String.slice(s, start_index, s.count - start_index);
    trim_s, trim_count := StringTrimLeft(line_copy, skips);

    if !trim_s {
        return StringToken.{};
    }

    i : int = 0;
	if trim_s.count > 0 
	{
		if String.is_any(trim_s[i], delimiters) {
			// Delimiters form single character tokens.
			i += 1;
		} else {
			// Otherwise advance until space or delimiter.
			// next_char := trim_s[i];
			while i < trim_s.count && 
				 !String.is_any(trim_s[i], delimiters) && 
				 !String.is_any(trim_s[i], skips) 
			{
				i += 1;
				// next_char = trim_s[i];
			}
		}
	}

	if i > 0 {
		string_token : StringToken = ---;
		string_token.next_char_index = start_index + trim_count + i;
		string_token.token = String.slice(trim_s, 0, i);
		string_token.success = true;
		return string_token;
	} 
	
	return StringToken.{};
}

StringParse :: inline (line: *string, delimiters:=MY_DEFAULT_DELIMITERS, skips:=MY_DEFAULT_SKIPS) 
-> value:string, success:bool 
{
    assert(line != null);
    backup := <<line;

    <<line = String.trim_left(<<line, skips);

    if !line {
        defer <<line = backup;
        return <<line, false;
    }

    i_token : int = 0;
    i_total : int = 0;
    return_value : string = backup;
	if line.count > 0 
	{
    	// read until space or delimiters.
		while i_token < line.count && !String.is_any((<< line)[i_token], delimiters) {
			i_token += 1;
		}
	}

    if i_token > 0 {
        defer advance(line, i_total);
        return String.slice(<<line, 0, i_token), true;
    } else {
        defer <<line = backup;
        return String.slice(<<line, 0, 0), false;
    }
}

ParseResult :: struct {
	success : bool;
	result_string : string;
	next_index : int;
}

MakeParseResult :: inline (
	success : bool,
	result_string : string,
	next_index : int)
-> ParseResult
{
	parse_result : ParseResult = ---;
	parse_result.success = success;
	parse_result.result_string = result_string;
	parse_result.next_index = next_index;
	return parse_result;
}

StringParseInt :: inline (line: *string, delimiters:=MY_DEFAULT_DELIMITERS, skips:=MY_DEFAULT_SKIPS)
-> success:bool, value:int 
{
	immediate_token, has_next_token := StringParse(line, delimiters, skips);
	if !has_next_token return false, 0;
	return_int, int_succes := string_to_int(immediate_token);
	return int_succes, return_int;
}

//TODO Could make one for different types with compile-time type variable as input.
StringParseIntArray :: inline (line: *string, delimiters:=",", skips:="[] \t") -> success:bool, [] int
{
	int_array : [..] int;
	int_array.allocator = temp;

	copy_line : string = << line;
	is_int_token, int_token := StringParseInt(*copy_line, delimiters, skips);
	while is_int_token {
		array_add(*int_array, int_token);
		is_int_token, int_token = StringParseInt(*copy_line, delimiters, skips);
	}

	if !is_int_token {
		<<line = copy_line;
	}
	return is_int_token, int_array;
}

StringCompare :: (a: string, b: string) -> int {
    for 0..min(a.count, b.count)-1 {
        if a[it] > b[it] return 1;
        if a[it] < b[it] return -1;
    }
    if a.count > b.count return 1;
    if a.count < b.count return -1;
    return 0;
}

StringEqual :: inline (a : string, b : string) -> bool {
	result : bool = StringCompare(a, b) == 0;
	return result;
}

//TODO i think this is not returning another string and only pointers to the original string
//if so then we should not free it
StringSlice :: inline (s: string, index: s64, count: s64) -> string {
    assert(index >= 0, "index = %", index);
    assert(count >= 0, "count = %", count);
    if index >= s.count  return "";

    if index + count > s.count {
        count = s.count - index;
    }

    c: string = ---;
    c.data    = s.data + index;
    c.count   = count;
    return c;
}


