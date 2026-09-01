/*VERY IMPORTANT
Currently this compiler is being called with Flat_Pool and therefore the values in memory do not change
for the BinaryTree. This allows the *BinaryNode to work, otherwise, it would not. So we need to use
Flat_Pool or something else with similary behavior when we call this from in the game. It should be fine
as we want to call the compiler or assembler with a separate allocator so we can clear it easily after
every run and reuse it for every compilation. Seems to also work with Pool but I think Flat_Pool should be enough.
Especially considering we can likely not store all the BinaryTrees and also probably use less lexer parsing

This is also important for the type system as we use pointers to reference the various types since
pointer_types and array_types are also recursive types. We could use a separate allocator just for the
type system to avoid any pointer changes. I think the pointer model system is much simpler and more efficient
then having ids and having to do a search for each id down the chain. We can do it that way but it seems
messier and less efficient for no real gain since it is unlikely that we will serialize the compilation data
since we can just recompile it quickly from the code.
*/

/*TODO Try not to use in-game things in here since eventually we will want to allow compilation
maybe outside of the game. So this could be serialized to some OldMusicInstruction or asm
depending on what we decide to do.
*/

/*DOC : Right now we lex different files with the same lexer but we reset it each time and store the lexer_tokens.
TODO Once we do lazy lexing, we can store the current file_string in here and parse directly from there
into lexer_tokesn which could be turned into a fixed circular buffer with something like 100-1000 tokens.
Could test/profile that for efficiency eventually.
*/
CodeLexer :: struct {
	input : string;
	line_number : int;
	//Total char input index
	input_index : int;
	//Line specific char index
	line_index : int;

	next_index : int;
	//TODO Maybe we can rename to just tokens or l_tokens
	//new_lexer_tokens : [..] LCodeToken;
	//TODO Turn this into an array view so we can reuse the tokens from the files and use the resizable array above to generate the tokens.
	lexer_tokens : [..] LCodeToken;

	//TODO If we do lazy lexing, then we can make this = to all_compiler_errors and remove this
	//since the lexer_tokens will be a cyclical array.
	// lexer_errors : [..] CompilerError;
	lexer_errors : CompilationErrors;

	bracket_stack : [..] LCodeToken;

	current_abs_file_path : string;
}

MakeCodeLexer :: inline () -> CodeLexer {
	cl : CodeLexer;
	cl.lexer_tokens.allocator = context.allocator;
	// cl.lexer_errors.allocator = context.allocator;
	InitCompilationErrors(*cl.lexer_errors);

	//TODO Probably can have a temp_compiler allocator so we can use that and clear/reuse it throughout the compiler.
	//Although most things are stored in context.allocator for now I think since they are passed back.
	cl.bracket_stack.allocator = temp;
	return cl;
}

//TODO Could reset this with a general reset dynamic arrays when we implement that.
ResetCodeLexer :: inline (cl : *CodeLexer) {
	cl.line_number = 0;
	cl.input_index = 0;
	cl.line_index = 0;	
	cl.next_index = 0;
	array_reset_keeping_memory(*cl.lexer_tokens);
	array_reset_keeping_memory(*cl.lexer_errors.all_compiler_errors);
	cl.lexer_errors.compiler_errors_string.text_string.count = 0;
	array_reset_keeping_memory(*cl.bracket_stack);
}
SetLoadedFile :: inline (cl : *CodeLexer, loaded_file : DirectiveLoadFile) {
	cl.input = loaded_file.file_string;
	//TODO Im pretty sure we can just copy the array view and not the whole array.
	//I think it's because its resizable for the lexer token generation but we could separate those in the lexer
	//and then use new_lexer_tokens in the lexer and just lexer_tokens (or rename it) in the evaluation part of the compiler
	array_copy(*cl.lexer_tokens, loaded_file.lex_tokens);
}
/*DOC : Using this for now to we can check errors the same way on first load and on subsequent loads
TODO Once we do lazy lexing, then we can just use all_compiler_errors directly and remove all of this entirely.
*/
VerifyLexerErrors :: inline (cd : *CompilationData, cs : CompileSettings) -> bool {
	if cd.lexer.lexer_errors.all_compiler_errors.count > 0 {
		cd.comp_errors = cd.lexer.lexer_errors;
		if cs.print_errors_to_console {
			for cd.comp_errors.all_compiler_errors print("%\n", it.msg);
		}
		return true;
	}
	return false;
}

LCodeToken :: struct {
	//This is separate SoA since we always check this
	token_type : CodeTokenType;

	//Note : Put a union name here for the serializer
	using value : TokenValue;

	//For parsing errors
	token_length : int; //u16
	line_number : int; // u32
	line_char_index : int; //u16
	total_char_index : int;
	//TODO Should we have absolute char index so we can show where the error is in the total string?
	//TODO Do we need this? Would be useful for graphical compilation errors
	/*DOC TODO : THIS IS TEMPORARY
	Storing this here so we can set the file_name in errors or anywhere else we need it, it is convenient
	for now since the lexing tokens are used everywhere. 
	ONCE WE DO LAZY LEXING, then the lexer will have the file it is lexing and so we can use that directly
	to get the name and remove it from having it in each token.
	NOTE : THIS is a case of we know we will update later so no need to refactor now as that will be a waste of time
	since we will do altogether, hollistically and cleanly later and probably notice things I don't know since
	the compiler will be more or less done once we do that.
	*/
	absolute_path_name : string;
}

Token :: LCToken;
LCToken :: MakeLCToken;
MakeLCToken :: inline (type : CodeTokenType) -> LCodeToken {
	t : LCodeToken;
	t.token_type = type;
	return t;
}

MakeLCToken :: inline (type : CodeTokenType, value : $T) -> LCodeToken {
#assert(T == int || T == float || T == string);
	t : LCodeToken;
	t.token_type = type;
	#if T == {
	case int; t.int_value = value;
	case float; t.float_value = value;
	case string; t.token_string = value;
	}
	return t;
}

//TODO We could allow for a string AND a value if needed
//Technically the string is 128 bits, so we could have 2 ints or 2 floats if needed
TokenValue :: union {	
	int_value : int;
	float_value : float64;
	token_string : string;
}

GetLexString :: inline (l_token : LCodeToken, lexer : CodeLexer) -> string {
	lex_s : string = String.slice(lexer.input, l_token.total_char_index, l_token.token_length);
	return lex_s;
}

EatChar :: inline (l : *CodeLexer) {
	if l.input[l.input_index] == #char "\n" {
		l.line_number += 1;
		l.line_index = -1; //gets incremented to 0 below
	}
	l.line_index += 1;
	l.input_index += 1;
}

//We assume this is called after an EatChar that does not eat a "\n".
UnwindChar :: inline (l : *CodeLexer) {
	assert(l.input_index > 0);
	l.line_index -= 1;
	l.input_index -= 1;
}

//TODO We need the bool for some cases like checking is_digit but maybe there is a better way where we can remove
//it since that would be more efficient... not sure since it is just returning an extra u8.
//TODO In jai lexer, basically the value is checked directly. So we could make is_digit that takes an s16
//or also just check directly and then not have a bool here.
PeekChar :: inline (l : *CodeLexer) -> s16, bool {
	if l.input_index >= l.input.count {
		return -1, false;
	}

	c : s16 = l.input[l.input_index];
	return c, true;
}

ParseAlnum :: inline (l : *CodeLexer) -> string {
	next_c, found_next_c := PeekChar(l);
	start_input_index : int = l.input_index;
	while found_next_c && is_alnum(cast(u8)next_c) {
		EatChar(l);
		next_c, found_next_c = PeekChar(l);
	}
	l_string : string = String.slice(l.input, start_input_index, l.input_index - start_input_index);
	return l_string;
}

//NOTE : We associate corresponding open and close brackets here by index.
//Also brackets inside strings are parsed separately, so this only evalutes actual code
open_brackets :: CodeTokenType.[#char "(", #char "[", #char "{", .ARRAY_LITERAL, .STRUCT_LITERAL];
close_brackets :: CodeTokenType.[#char ")", #char "]", #char "}", #char "]", #char "}"];
CheckBracket :: inline (lct : LCodeToken, lexer : *CodeLexer) {
	if AllOrEquals(lct.token_type, open_brackets) {
		array_add(*lexer.bracket_stack, lct);
	} else if AllOrEquals(lct.token_type, close_brackets) {
		if lexer.bracket_stack.count == 0 {
			CreateCompErr(*lexer.lexer_errors, .LEXING, lct, lexer.input,
			sprint("Missing open bracket for close bracket : %.", 
				lct.token_type,,context.allocator));
			return;
		}

		last_open_bracket : LCodeToken = pop(*lexer.bracket_stack);
		for open_brackets if it == last_open_bracket.token_type {
			if lct.token_type != close_brackets[it_index] {
				CreateCompErr(*lexer.lexer_errors, .LEXING, lct, lexer.input,
				sprint("Missing open bracket for close bracket : %.", 
					lct.token_type,,context.allocator));
				return;
			} 
		}
	}
}

/*TODO This could be made much more efficient with a ring buffer so that we reuse
tokens and don't have to allocate all the tokens here at once.
I think then we would have to gradually add on to the tree. Also what if we have a really
big expression? I guess we could over allocate alot or limit the line size to like 1000 chars.
Then we may have to linearize the parsing and the ir and the evaluation per expression up until {.
If we see that this line by line method works, then this would be much more efficient and we would
only have to store the instructions with some extra data in case we have to add things or re-arrange.

Could also just have a dynamic array and keep adding per statement and then array_reset_keeping_memory
for each statement so we don't need to add more memory. Then we could parse the statement and load it up
like we do below with the tree except 1 statement at at time and so there would be very little memory usage.
I think we would not even need to keep the tree other than the current tree.

TODO UPDATE THIS WITH LAZY LOADING RING BUFFER so we would have to not reset line and input data and 
just continue with it as we go along. We would have 1 buffer with maybe 100-1000 tokens and then fill the
entire buffer and only refill it when we need the next token while parsing.
First pass only parses when we find "::" so then we only really use this fully on the second pass.
So maybe on the first pass we can lex less tokens at once since we only do some data declarations
and possibly constants later.

TODO Likely best to make multiple versions of this and then pass in CompilationData in 1 and then can grab
the files directly from there and so then we can leave this function for tests with an empty file name.
*/
//TODO Need to write tests for all the different CodeTokenType cases
LexCodeTokens :: inline (lexer : *CodeLexer, input : string) {
//Reset everytime we parse a new file input
lexer.line_number = 0;
lexer.input_index = 0;
lexer.line_index = 0;
lexer.input = input;

lexer.next_index = 0;

while lexer.input_index < lexer.input.count
{
	//TODO I don't think we need found_next_c here since -1 would not match with anything
	next_c, found_next_c := PeekChar(lexer);
	while found_next_c && String.is_any(cast(u8)next_c, MY_DEFAULT_SKIPS) {
		EatChar(lexer);
		next_c, found_next_c = PeekChar(lexer);
   }

	lt : LCodeToken;
	lt.token_type = cast(CodeTokenType) next_c;
	lt.line_char_index = lexer.line_index;
	lt.line_number = lexer.line_number;
	lt.token_length = 1;
	lt.total_char_index = lexer.input_index;
	//TODO Remove this once we do lazy loading since we should just access the file info 
	//directly from the general info in the lexer (and also generalize anything else based on current file position)
	lt.absolute_path_name = lexer.current_abs_file_path;

	//TODO Could make an is_alnum with an s16 input and same for is_digit to remove the found_next_c return on PeekChar
	if is_alnum(cast(u8)next_c) {
		start_input_index : int = lexer.input_index;
		l_string : string = ParseAlnum(lexer);
		lt.token_length = l_string.count;

		int_value, is_integer := string_to_int(l_string);
		if is_integer {
			next_c = PeekChar(lexer);
			//Need to check double dot here for cases like for 1..3, otherwise the 1. would get tagged as float and we lose the double dot
			not_double_dot := lexer.input_index + 1 < lexer.input.count && lexer.input[lexer.input_index+1] != #char ".";
			if next_c == #char "." && not_double_dot	{
				EatChar(lexer);
				next_c, found_next_c = PeekChar(lexer);
				while found_next_c && is_digit(cast(u8)next_c) {
					EatChar(lexer);
					next_c, found_next_c = PeekChar(lexer);
				}					
				f_string : string = String.slice(lexer.input, start_input_index, lexer.input_index - start_input_index);
				float_value, is_float := string_to_float(f_string);
				if is_float {
					lt.token_type = CodeTokenType.FLOAT;
					lt.float_value = float_value;
					lt.token_length = f_string.count;
				} else {
					//TODO Log proper error here. Maybe using a logger in the context
					//so we can change it depending on if compilation is in-game or out.
					//TODO Do we even need an error here?
					print("WTF are you doing with your life?\n");
				}
			} else {
				lt.token_type = CodeTokenType.INTEGER;
				lt.int_value = int_value;
			}
		} else {
			keyword_token_type : CodeTokenType = CheckKeyword(l_string);
			if keyword_token_type != -1 {
				lt.token_type = keyword_token_type;
			} else {
				lt.token_type = CodeTokenType.IDENT;
			}
			lt.token_string = l_string;
		}
		array_add(*lexer.lexer_tokens, lt);
	} 
	else if next_c == {
	case #char "\n"; {
		//We don't carry over the "\n" as a token.
		EatChar(lexer);
	}
	case #char "!"; {
		//TODO This pattern is used a lot, maybe we can make a function to check for arbitrary second characters
		//and what the other token type would be with an array
		EatChar(lexer);
		peek_c := PeekChar(lexer);
		if peek_c == #char "=" {
			lt.token_type = CodeTokenType.ISNOT_EQUAL;
			EatChar(lexer);
		}
		array_add(*lexer.lexer_tokens, lt);		
	}
	case #char "="; {
		EatChar(lexer);
		peek_c, found_c := PeekChar(lexer);
		if found_c && peek_c == #char "=" {
			//TODO Should we call this DOUBLE_EQUALS?
			lt.token_type = CodeTokenType.IS_EQUAL;
			EatChar(lexer);
		}
		array_add(*lexer.lexer_tokens, lt);		
	}
	case #char "<"; {
		EatChar(lexer);
		peek_c := PeekChar(lexer);
		if peek_c == #char "=" {
			lt.token_type = CodeTokenType.LESS_EQUALS;
			EatChar(lexer);
		}
		array_add(*lexer.lexer_tokens, lt);
	}
	case #char ">"; {
		EatChar(lexer);
		peek_c := PeekChar(lexer);
		if peek_c == #char "=" {
			lt.token_type = CodeTokenType.GREATER_EQUALS;
			EatChar(lexer);
		}
		array_add(*lexer.lexer_tokens, lt);
	}
	case #char "+"; {
		EatChar(lexer);
		peek_c := PeekChar(lexer);
		if peek_c == {
		case #char "=";
			lt.token_type = CodeTokenType.PLUS_EQUALS;
			EatChar(lexer);
		case #char ",";
			EatChar(lexer);
			peek_c = PeekChar(lexer);
			if peek_c == {
			case #char "+"; lt.token_type = CodeTokenType.ADD_COMMA_ADD;
			case #char "-"; lt.token_type = CodeTokenType.ADD_COMMA_SUB;
			}
			EatChar(lexer);
		}
		array_add(*lexer.lexer_tokens, lt);
	}
	case #char "-"; {
		EatChar(lexer);
		peek_c := PeekChar(lexer);
		if peek_c == {
		case #char "=";
			lt.token_type = CodeTokenType.MINUS_EQUALS;
			EatChar(lexer);
		case #char ">";
			lt.token_type = CodeTokenType.RIGHT_ARROW;
			EatChar(lexer);
		case #char ",";
			EatChar(lexer);
			peek_c = PeekChar(lexer);
			if peek_c == {
			case #char "+"; lt.token_type = CodeTokenType.SUB_COMMA_ADD;
			case #char "-"; lt.token_type = CodeTokenType.SUB_COMMA_SUB;
			}
			EatChar(lexer);
		}
		array_add(*lexer.lexer_tokens, lt);
	}
	case #char "*"; {
		EatChar(lexer);
		peek_c := PeekChar(lexer);
		if peek_c == {
		case #char "=";
			lt.token_type = CodeTokenType.TIMES_EQUALS;
			EatChar(lexer);
		}
		array_add(*lexer.lexer_tokens, lt);
	}
	case #char "%"; {
		EatChar(lexer);
		peek_c := PeekChar(lexer);
		if peek_c == {
		case #char "=";
			lt.token_type = CodeTokenType.MOD_EQUALS;
			EatChar(lexer);
		}
		array_add(*lexer.lexer_tokens, lt);
	}
	case #char "~"; {
		EatChar(lexer);
		peek_c := PeekChar(lexer);
		if peek_c == { 
		case #char "=";
			lt.token_type = CodeTokenType.TILDE_EQUALS;
			EatChar(lexer);
		case #char "+";
			lt.token_type = CodeTokenType.TILDE_ADD;
			EatChar(lexer);
		case #char "-";
			lt.token_type = CodeTokenType.TILDE_SUB;
			EatChar(lexer);
		case #char "*";
			lt.token_type = CodeTokenType.TILDE_MUL;
			EatChar(lexer);
		case #char "/";
			lt.token_type = CodeTokenType.TILDE_DIV;
			EatChar(lexer);
		}
		array_add(*lexer.lexer_tokens, lt);		
	}
	case #char "&"; {
		EatChar(lexer);
		peek_c := PeekChar(lexer);
		if peek_c == #char "&" {
			lt.token_type = CodeTokenType.LOGICAL_AND;
			EatChar(lexer);
		}
		array_add(*lexer.lexer_tokens, lt);		
	}
	case #char "|"; {
		EatChar(lexer);
		peek_c := PeekChar(lexer);
		if peek_c == #char "|" {
			lt.token_type = CodeTokenType.LOGICAL_OR;
			EatChar(lexer);
		}
		array_add(*lexer.lexer_tokens, lt);		
	}
	case #char "#"; {
		EatChar(lexer);

		directive_string : string = ParseAlnum(lexer); 
		lt.token_length = 1 + directive_string.count; //'#' + string.count

		is_valid_directive, directive_index := ArrayFindByValue(code_directive_names, directive_string);
		if is_valid_directive {
			lt.int_value = directive_index;
			array_add(*lexer.lexer_tokens, lt);
		} else {
			//TODO LexingError - Parse error properly and return error.
			print("Invalid directive % on line %.\n", directive_string, lt.line_number);
			return;
		}
	}
	case #char ":"; {
		EatChar(lexer);
		peek_c := PeekChar(lexer);
		//TODO Technically we don't need this since PeekChar returns -1 on not found next char, 
		//so it will just not match on any token with -1
		// if found_c if peek_c == {
		if peek_c == {
		case #char ":";
			lt.token_type = CodeTokenType.DOUBLE_COLON;
			EatChar(lexer);
		case #char "=";
			lt.token_type = CodeTokenType.COLON_EQUALS;
			EatChar(lexer);
		}
		array_add(*lexer.lexer_tokens, lt);
	}
	case #char "."; {
		EatChar(lexer);
		peek_c := PeekChar(lexer);
		if peek_c == {
		case #char ".";
			lt.token_type = CodeTokenType.DOUBLE_DOT;
			EatChar(lexer);
		case #char "*";
			lt.token_type = CodeTokenType.POSTFIX_DEREFERENCE;
			EatChar(lexer);
		case #char "[";
			lt.token_type = CodeTokenType.ARRAY_LITERAL;
			EatChar(lexer);
		case #char "{";
			lt.token_type = CodeTokenType.STRUCT_LITERAL;
			EatChar(lexer);
		}
		array_add(*lexer.lexer_tokens, lt);		
	}
	case #char "\""; {
		EatChar(lexer);
    	builder: String_Builder;
    	builder.allocator = context.allocator;
		peek_c, found_peek_c := PeekChar(lexer);
		while found_peek_c && peek_c != #char "\"" {
			EatChar(lexer);
			if peek_c == #char "\\" {
			   // @Robustness: add support for more escapes sequences
			   next := PeekChar(lexer);
			   if next == #char "n" {
					peek_c = #char "\n";
					EatChar(lexer);
			   } else if next == #char "r" {
					peek_c = #char "\r";
					EatChar(lexer);
			   } else if next == #char "t" {
					peek_c = #char "\t";
					EatChar(lexer);
			   } else if next == #char "0" {
					peek_c = 0;
					EatChar(lexer);
			   } else if next == #char "e" {
					peek_c = 0x1B;
					EatChar(lexer);
			   } else if next == #char "\"" {
					peek_c = #char "\"";
					EatChar(lexer);
			   } else if next == #char "\\" {
					peek_c = #char "\\";
					EatChar(lexer);
			   } else if next == #char "%" {
					peek_c = 31;
					EatChar(lexer);
			   } else {
					peek_c = next;
					EatChar(lexer);
			   }
			}
     		append(*builder, cast(u8) peek_c);

			peek_c, found_peek_c = PeekChar(lexer);
		}
		if peek_c != #char "\"" {
			//TODO FROM HERE comp error to work here and maybe just pass in compilation data
			//OR just pass in the lex file string here
			CreateCompErr(*lexer.lexer_errors, .LEXING, lt, lexer.input,
				sprint("No end quote found for : %.\n", lt,,context.allocator));
			//TODO Eventually we could continue and accumulate errors if possible.
			return;
		}
		EatChar(lexer); //eat end quote "\""

		//TODO Either we put the 0 extra here like jai or just add it later, let's see what makes more sense.
		// append(*builder, 0);  // Zero-terminate the string!
		lt.token_string = builder_to_string(*builder,,context.allocator);
		// lt.token_string.count -= 1;   // Don't count the zero-termination in the length.
		lt.token_length = lt.token_string.count;
		lt.token_type = CodeTokenType.STRING;
		array_add(*lexer.lexer_tokens, lt);
	}
	case #char "/"; {
		//Note : If we don't find a second character we just skip over for now
		//so a / is like a space. Maybe we should make it an error eventually though
		//or use it for something in the compiler.
		EatChar(lexer);

		//TODO Technically we don't need found_peek_char since PeekChar returns -1 on not found next char, 
		//so it will just not match on any token with -1
		//WE REMOVED IT but will leave it commented in case we have an issue with comments and need to add it back 
		peek_char, found_peek_char := PeekChar(lexer);
		// if found_peek_char {
		if peek_char == #char "/" {
			// lt.token_type = CodeTokenType.COMMENT_LINE;
			EatChar(lexer);

			comment_c, found_comment_c := PeekChar(lexer);
			while found_comment_c && comment_c != #char "\n" {
				EatChar(lexer);
				comment_c, found_comment_c = PeekChar(lexer);
		    }
		    // \n will be processed on the next pass
		}
		else if peek_char == #char "*" {
			EatChar(lexer);
			// lt.token_type = CodeTokenType.COMMENT_BLOCK_START;

			block_comment_count : int = 1;
			next_comment_char, found_next_comment_char := PeekChar(lexer);
			while found_next_comment_char {
				if next_comment_char == #char "*" {
					EatChar(lexer);
					slash_c, found_slash_c := PeekChar(lexer);
					if found_slash_c && slash_c == #char "/" {
						EatChar(lexer);
						if block_comment_count == 1 {
							break;
						} else {
							block_comment_count -= 1;
						}
					}
				} else if next_comment_char == #char "/" {
					EatChar(lexer);
					star_c, found_star_c := PeekChar(lexer);
					if found_star_c && star_c == #char "*" {
						block_comment_count += 1;
					}
				} else {
					EatChar(lexer);
				}
				next_comment_char, found_next_comment_char = PeekChar(lexer);
			}
			if !found_next_comment_char {
				CreateCompErr(*lexer.lexer_errors, .LEXING, lt, lexer.input,
					"End of input from within a block comment \"/*\".");
			}
		}
		else {
			//Regular divide case
			if peek_char == #char "=" {
				lt.token_type = CodeTokenType.DIV_EQUALS;
				EatChar(lexer);
			}
			//Just add divide if we only have that token since we ate it above.
			array_add(*lexer.lexer_tokens, lt);
		}
		// }
	}
	case; {
		//Doing this on top now so we don't have to do everywhere
		// lt.token_type = cast(CodeTokenType) next_c;
		EatChar(lexer);
		array_add(*lexer.lexer_tokens, lt);				
	}
	}

	//TODO We check brackets in lexer now. This seems cleaner than having it in evaluation but maybe not...
	//Maybe it will need to change when I do lazy lexing eventually...
	CheckBracket(lt, lexer);
	//TODO We could not return here and continue and accumulate errors but I think missing bracket makes things confusing.
	if lexer.lexer_errors.all_compiler_errors.count > 0 return;
}

if lexer.bracket_stack.count > 0 {
	last_open_bracket : LCodeToken = peek(lexer.bracket_stack);
	CreateCompErr(*lexer.lexer_errors, .LEXING, last_open_bracket, lexer.input,
	sprint("Missing close bracket for open bracket : %.", 
		last_open_bracket.token_type,,context.allocator));
}
}

//TODO Copied this from jai lexer so can likely remove whatever we do not use.
CodeTokenType :: enum {
    // Mentally insert ASCII types here

    BITWISE_XOR :: #char "^";
    BITWISE_NOT :: #char "~";
    BITWISE_AND :: #char "&";
    BITWISE_OR  :: #char "|";


    IDENT :: 256;
    INTEGER :: 257;
    FLOAT :: 258;

    PLUS_EQUALS :: 259;
    MINUS_EQUALS :: 260;
    TIMES_EQUALS :: 261;
    DIV_EQUALS :: 262;
    MOD_EQUALS :: 263;
    IS_EQUAL :: 264;
    ISNOT_EQUAL :: 265;
    LOGICAL_AND :: 266;
    LOGICAL_OR :: 267;
    LESS_EQUALS :: 268;
    GREATER_EQUALS :: 269;

    RIGHT_ARROW :: 270;
    DOUBLE_DOT :: 271;
    DOUBLE_DOLLAR :: 272;

    SHIFT_LEFT  :: 273;
    SHIFT_RIGHT :: 274;

    ROTATE_LEFT         :: 275;  
    ROTATE_RIGHT        :: 276;

    TRIPLE_EQUALS       :: 277;  

    SHIFT_LEFT_EQUALS   :: 290;
    SHIFT_RIGHT_EQUALS  :: 291;

    ROTATE_LEFT_EQUALS  :: 292;
    ROTATE_RIGHT_EQUALS :: 293;

    BITWISE_AND_EQUALS  :: 294;
    BITWISE_OR_EQUALS   :: 295;
    BITWISE_XOR_EQUALS  :: 296;

    LOGICAL_AND_EQUALS  :: 297;
    LOGICAL_OR_EQUALS   :: 298;

    POINTER_DEREFERENCE :: 310;
    POSTFIX_DEREFERENCE :: 311;

    // __FIRST_KEYWORD :: KEYWORD_FOR; // Used for a parse error message or two.
    KEYWORD_FOR :: 312;
    KEYWORD_IF :: 313;
    KEYWORD_IFX :: 314;
    KEYWORD_THEN :: 315;
    KEYWORD_ELSE :: 316;
    KEYWORD_CASE :: 317;
    KEYWORD_RETURN :: 318;
    KEYWORD_STRUCT :: 319;
    KEYWORD_WHILE :: 320;
    KEYWORD_BREAK :: 321;
    KEYWORD_CONTINUE :: 322;
    KEYWORD_REMOVE :: 323;
    KEYWORD_USING :: 324;

    KEYWORD_DEFER :: 325;
    KEYWORD_SIZE_OF :: 326;
    KEYWORD_TYPE_OF :: 327;
    KEYWORD_CODE_OF :: 328;
    KEYWORD_INITIALIZER_OF :: 329;
    KEYWORD_DATA_TYPE_INFO :: 330;
    KEYWORD_NULL :: 331;

    KEYWORD_ENUM :: 332;
    KEYWORD_TRUE :: 333;
    KEYWORD_FALSE :: 334;

    KEYWORD_INLINE :: 335;
    KEYWORD_NO_INLINE :: 336;

    KEYWORD_CAST :: 337;
    KEYWORD_AUTO_CAST :: 338;

    KEYWORD_CONTEXT :: 339;
    KEYWORD_PUSH_CONTEXT :: 340;
    KEYWORD_OPERATOR :: 341;
    KEYWORD_IS_CONSTANT :: 342;

    KEYWORD_ENUM_FLAGS :: 343;
    KEYWORD_UNION :: 344;
    KEYWORD_INTERFACE :: 345;

    __LAST_KEYWORD :: KEYWORD_INTERFACE;

    KEYWORD_NEW;
    KEYWORD_NEW_ARRAY;
	 KEYWORD_NEW_RESIZABLE_ARRAY;

	 KEYWORD_NEUME;
    KEYWORD_TANO;
    TILDE_EQUALS;
    TILDE_ADD;
    TILDE_SUB;
    TILDE_DIV;
    TILDE_MUL;
    //TODO Do we want these to be specific operations
    // TILDE_XOR;
    // TILDE_AND;
    // TILDE_OR;
    // TILDE_2_AND;
    // TILDE_2_OR;

    //We need these here because otherwise unary ops + and - would need to have something afterwards.
    //TODO We can probably hardcode for 3d and 4d as well but it wont extrapolate eventually
    //so maybe we could use TokenValue and set the dimension in there although that still would not be enough
    //so would need to think about that for each permutation if we do more than just 2d,3d and 4d.
    //Could also do "+/+" instead of "+,+" if that makes more sense later.
    ADD_COMMA_ADD;
    ADD_COMMA_SUB;
    SUB_COMMA_ADD;
    SUB_COMMA_SUB;


    //TODO Can probably remove this once we have a type system with structs.
    DATA_TYPE_VOID;
    DATA_TYPE_INT;
    DATA_TYPE_FLOAT;
    DATA_TYPE_BOOL;
    DATA_TYPE_STRING;
    //TODO Should this be renamed to KEYWORD_ROWS?
    DATA_MUNIT;
    STRING;

    DOUBLE_COLON;
    COLON_EQUALS;


	 STRUCT_LITERAL;
    ARRAY_LITERAL;

    UNARY_OP;

    // OPEN_CLOSE_CIRCLE_BRACKET;

    // QUICK_LAMBDA;

    // NOTE;

    END_OF_INPUT;

    POINTER_DEREFERENCE_OR_SHIFT_LEFT;

    OPERATOR_ARRAY_SUBSCRIPT :: 500;  
                                      
    OPERATOR_ASSIGNMENT_TO_ARRAY_SUBSCRIPT :: 501;

    ERROR;

    DUMMY_TOKEN_TYPE;


    //Some asm specific tokens.
	FIRST_PASS_SKIP;
}

code_directive_names : [] string : #run enum_names(CodeDirective);
code_directive_enums : [] CodeDirective : #run enum_values_as_enum(CodeDirective);
CodeDirective :: enum {
	asm;
	type;
	load;
}
DirectiveTypeName :: struct {
	t_info : *TypeInfo;
	name : string;
}
/*DOC : We check all other possibly type names here.
Currently structs and #type. Can add enums later as well and anything else for user defined type names.

TODO We could also have 1 array with all type names in it eventually if that is much more efficient.
That could be hashed as well and so might work better overall.
*/
TypeNameAlreadyExists :: inline (node : *BinaryNode, cd : *CompilationData) -> bool {
	directive_type, found_directive_type := GetDirectiveTypeByName(node.value.token_string, cd.all_directive_type_names);
	if found_directive_type {
		CreateCompErr(cd, .EVALUATION, node, "Already have a type with this name.");
		return true;		
	}
	struct_info, found_struct_info := GetTypeInfoStructByName(node.value.token_string, cd.all_type_info_struct);
	if found_struct_info {
		CreateCompErr(cd, .EVALUATION, node, "Already have a struct with this name.");
		return true;		
	}
	enum_info, found_enum_info := GetTypeInfoEnumByName(node.value.token_string, cd.all_type_info_enum);
	if found_enum_info {
		CreateCompErr(cd, .EVALUATION, node, "Already have an enum with this name.");
		return true;
	}
	return false;
}

CheckValidNode :: inline (node : *BinaryNode, null_check_node : *BinaryNode, cd : *CompilationData) -> bool {
	//TODO This case should likely be caught by the parser
	if node == null {
		CreateCompErr(cd, .EVALUATION, null_check_node, "Node is null. This might be an internal compiler error.");
		return false;
	}
	else if node.code_ir.ir_type == .UNKNOWN_IDENT {
		CreateCompErr(cd, .EVALUATION, node, "Unknown identifier.");
		return false;
	} 
	else if node.code_ir.t_info == null {
		CreateCompErr(cd, .EVALUATION, node, "Unknown type.");
		return false;
	}
	return true;
}


DirectiveLoadFile :: struct {
	//NOTE : file_name is the input file_name (maybe we should rename it).
	//TODO Can also store a string view of just the file name for displaying.
	// file_name : string;
	absolute_path_name : string;
	file_string : string;
	//TODO Could use this if needed to differntiate between starting file and loaded files
	// is_starting_file : bool;
	lex_tokens : [] LCodeToken;
}


CheckKeyword :: (name: string) -> CodeTokenType {  // Returns Token_Type -1 if it is not a keyword.
    if name.count == {
    case 2;
        if name == "if" return .KEYWORD_IF;
    case 3;
        if name == "for" return .KEYWORD_FOR;
        if name == "New" return .KEYWORD_NEW;
        if name == "int" return .DATA_TYPE_INT;
    case 4;
        if name == "true" return .KEYWORD_TRUE;
        if name == "else" return .KEYWORD_ELSE;
        if name == "null" return .KEYWORD_NULL;
        if name == "bool" return .DATA_TYPE_BOOL;
        if name == "void" return .DATA_TYPE_VOID;
        if name == "cast" return .KEYWORD_CAST;
        if name == "tano" return .KEYWORD_TANO;
        if name == "enum" return .KEYWORD_ENUM;
    case 5;
        if name == "false" return .KEYWORD_FALSE;
        if name == "while" return .KEYWORD_WHILE;
        if name == "break" return .KEYWORD_BREAK;
        //TODO We could put a few here and see how it goes.
        //muse, mus, mrow, tmus, tano, emus, exmus
        if name == "munit" return .DATA_MUNIT;
        //float is actually float64 in jai... how does this feel if we convert? We could just make a converter.
        //TODO ACTUALLY we could also have float64 so that it works for here and jai interchangeably 
        //and they are just both 64-bit here.
        if name == "float" return .DATA_TYPE_FLOAT;
        if name == "neume" return .KEYWORD_NEUME;
    case 6;
        if name == "return" return .KEYWORD_RETURN;
        if name == "struct" return .KEYWORD_STRUCT;
        if name == "string" return .DATA_TYPE_STRING;
    case 7;
        if name == "size_of" return .KEYWORD_SIZE_OF;
        if name == "float64" return .DATA_TYPE_FLOAT;
    case 8;
        if name == "continue" return .KEYWORD_CONTINUE;
        if name == "NewArray" return .KEYWORD_NEW_ARRAY;
        if name == "operator" return .KEYWORD_OPERATOR;
    case 17;
        if name == "NewResizableArray" return .KEYWORD_NEW_RESIZABLE_ARRAY;
    }

    return -1;
}

IsKeyword :: inline (ctt : CodeTokenType) -> bool {
	if ctt >= 312 && ctt <= 345 return true;
	return false;
}

TypeCheck :: enum {
	NONE;
	UNARY;
	INTEGER;
	FLOAT;
	BOOL; //Technically this can just be an integer
}

//Recursive Descent
//TODO Likely need a new type for this array of expressions to be stored for later.
BinaryNode :: struct {
	//TODO This can probably be collapsed to s32 and an enum or something.
	//TODO Do we want LCodeToken here or some other value? 
	//Could make it $T compile-time as well and then can check type afterwards for generalized BinaryTree.
	//TODO Change this type so we can have more information at compile time, but can still contain this type if needed.
	using code_node : CodeNode;
	//TODO can likely make these u16 or u32 indices instead of pointers 
	//since we will likely have very small trees for these expressions
	left : *BinaryNode = null;
	right : *BinaryNode = null;
	//TODO Can add parent node in here if we traverse up the tree often.
	//Currently we do it for all IDENTIFIERS, so that may in fact be enough.
	parent : *BinaryNode = null;
}

CodeNode :: struct {
	//TODO Can we remove the id in favor of just using *BinaryNode pointers?
	//YES I THINK so and that is likely best so we can remove the BinaryTree as well in favor of using an allocator.
	node_id : int;
	//TODO Why is this called value instead of token or l_token?
	value : LCodeToken;
	//TODO Should this be in here or elsewhere? Maybe it can stay in here since we now have separate tables
	//for variable and function declarations.
	code_ir : CodeIR;
	// code_id : int;
	// is_valid : bool;
}

BNode :: (value : LCodeToken, ir_type : CodeIRType = .NOT_PROCESSED) -> BinaryNode {
	node : BinaryNode;
	node.value = value;
	node.code_ir.ir_type = ir_type;
	return node;
}

/*TODO We could store a bit more information here like if we parse a number we could possibly pre-store that
on the expression parsing portion of compilation.
*/
MakeBinaryNode :: (
	left : *BinaryNode, value : LCodeToken, right : *BinaryNode, tree : *BinaryTree, 
	//Some options for pre-processing during the parsing step. Should we add more for things like numbers
	//or should we have other functions here?
	ir_type : CodeIRType = .NOT_PROCESSED) 
-> *BinaryNode 
{
	/*This method is efficient and also reuses the nodes nicely. We could plain just store the nodes memory
	since they will all be clustered together anyways... That makes it harder to copy them all over though.
	This way allows us to easily copy over the nodes if we need them later AND also reuse memory efficiently.
	*/
	#if 0 {
	node : *BinaryNode;
	if tree.next_node_id < tree.nodes.count {
		//We try to store nodes in a reusable array so that we can reuse the memory after.
		node = array_add(*tree.nodes);
	} else {
		//If we run out of the default size, then we create in memory so it maintains the same pointer
	}
	}

	//TODO Eventually maybe putting this in it's own allocator might be best. Then we can reuse and reset
	//however we want. At least this way the pointer won't change within the same allocator assuming
	//we use an allocator that stays in the same place... I think Pool and Flat_Pool fall under this category.
	//Maybe we can use Pool later if we think it will change
	//TODO THIS If we only use the node per statement and then never again. We can just store the tree for 1 expression
	//and then reset the allocator after every statement and just need to make sure we store all the data
	//for other scopes without the nodes for later use in some cases like control scope and functions.
	//Then we don't need the BinaryTree at all and can set the nodes globally or just as an int and reset them every
	//time we parse a next expression or before every compilation.
	/*TODO REMINDER EVENTUALLY we want this to use a resizable array within CompilationData which is fixed size (maybe 10Mb)
	so much larger than any expression could be and then the pointers would never move and we could reset that easily
	for each statement/expression. We could also use MySimplePool if that works internally and just reset that as well
	and then keep this with New as that might be even simpler. So either array_resize get fixed size or MySimplePool
	*/
	node : *BinaryNode = New(BinaryNode,,context.allocator);
	node.node_id = tree.next_node_id;
	node.value = value;
	node.code_ir.ir_type = ir_type;
	if left != null {
		node.left = left;
		node.left.parent = node;
	}
	if right != null {
		node.right = right;
		node.right.parent = node;
	}

	//TODO I think we can just put this node_id in CompilationData or globally
	tree.next_node_id += 1;

	return node;
}

BinaryTree :: struct {
	next_node_id : int;
	/*TODO Can pull this out into a separate table if needed although this will not persist
	and only used for expression evaluation so maybe we never really need to do that.
	TODO Can also possibly preempt the size based on how many tokens there are and then
	reduce the size after.
	This is the simplest and most flexible for now so we will keep this until we know better.
	*/
	//WE ARE NOT USING THIS RIGHT NOW... We can later for efficieny.
	/*RIGHT NOW we are storing all nodes in the allocator and then just resetting at the end of compilation.
	We can later use this once scopes and functions are properly handled. And then we can reuse this during
	compilation whenever we don't want to store the nodes which should be after every statement.
	*/
	nodes : [..] BinaryNode;
}

//Keeping this here in case we have issues with parents and pointers as we have had.
FindParent :: inline (node : *BinaryNode, tree : [] BinaryNode) -> *BinaryNode {
	for * tree {
		if (it.right != null && it.right.node_id == node.node_id) || 
		   (it.left != null && it.left.node_id == node.node_id) 
	   {
			return it;
		}
	}
	return null;
}

//TODO What about unary operators? Or those separate or the same?
IsBinaryOperator :: (token : LCodeToken) -> bool {
	if token.token_type == {
	case .INTEGER; #through;
	case .FLOAT; #through;
	case .IDENT; 
		return false;
	}
	return true;
}

ParseSingleBinarySimple :: (cd : *CompilationData) -> *BinaryNode {
	//TODO check if leaves are valid
	left, is_valid_left := ParseLeaf(cd);
	op := GetNextToken(*cd.lexer);
	right, is_valid_right := ParseLeaf(cd);

	op_node := MakeBinaryNode(left,op,right,*cd.binary_tree);
	return op_node;
}

//Right leaning
// a + b * c + d
/*
     +
    / \
   a   *
      / \
     b   +
        / \
       c   d

but should be something like
     +
    / \
   a   +
      / \
     d   *
        / \
       c   b
*/
ParseExpressionRightLeaning :: (cd : *CompilationData) -> *BinaryNode {
	left, is_valid_left := ParseLeaf(cd);
	next := GetNextToken(*cd.lexer);
	if IsBinaryOperator(next) {
		// right, is_valid_right := ParseLeaf();
		right := ParseExpressionRightLeaning(cd);
		op_node := MakeBinaryNode(left,next,right, *cd.binary_tree);
		return op_node;
	} else {
		return left;
	}
}

// a + b * c + d
/*
(a + ((b * c) + d))
      +
     / \
    *   d
   / \
  +	  c
 / \   
a   b       
But we want
      +
     / \
    +   a
   / \
  *	  d
 / \   
b   c
*/
//TODO Need to test this to see output and then 
//one below should be essentially correct and can be
//updated to account for "(" in precedence block
//and unary operators in ParseLeaf or preprocessed
ParseSingleBinary :: (cd : *CompilationData, left : *BinaryNode) -> *BinaryNode {
	next := GetNextToken(*cd.lexer);

	if IsBinaryOperator(next) {
		right, is_valid_right := ParseLeaf(cd);
		op_node := MakeBinaryNode(left,next,right, *cd.binary_tree);
		return op_node;		
	} else {
		return left;
	}
}

ParseExpressionLeftLeaning :: (cd : *CompilationData) -> *BinaryNode {
	left, is_valid_left := ParseLeaf(cd);
	while true {
		new_tree := ParseSingleBinary(cd,left);
		if new_tree == left return left;
		left = new_tree;
	}
	return null;
}

//TODO Not really using this yet. Maybe can use for error checking. If not, then we can remove it.
/*Was gonna use this for x,y := foo(0); but ended up having issues with right-leaning vs left-leaning
and so likely would have to parse LHS and RHS separately, so instead I am going to make := a separate token
and use that now.
*/
ParserLevel :: enum {
	STATEMENT;
	// FUNCTION_DECLARATION;
	// PARSE_TANO;
}

//Final Form here
// a * b + c
/*
      +
     / \
    *   c
   / \
  a   b

a > b + c * d + e
*/
//TODO Make this non-recursive if needed although likely that our trees won't be very deep
//for now so maybe we only need it to be non-recursive later if the tree becomes very deep.
ParseIncreasingPrecedence :: (
	cd : *CompilationData, left : *BinaryNode, 
	min_prec : int, pl : ParserLevel = .STATEMENT) 
-> *BinaryNode 
{
	next, found_next_token := PeekNextToken(cd.lexer);
	if !found_next_token return left;

	// if pl == .PARSE_TANO && next.token_type == #char ">" {
	// 	return left;
	// }
	//TODO The inside of this statement should be a pulled out function called ParseBinaryOp.
	//This will simplify making this function non-recursive eventually.
	//Maybe just have to pull out the else statement, can do it when we make the non-recursive version.
	if IsBinaryOperator(next) {
		next_prec := GetCodePrec(next.token_type);
		if next_prec <= min_prec {
			//TODO Can remove these comments if we never use the unwind.
			//TODO We could do a UnwindIndex
			// expr.next_index -= 1;
			return left;
		} else {
			//TODO This should be turned into a function so it's easier to make the iterative version of this parser later.
			if next.token_type == {
			//NOTE CAN REMOVE THIS COLON_EQUAL ":=" is now its own token at the lexer level.
			//TODO Could do a lookahead for ":" to check for ":" or "=" and then parse as 1 node.
			/*This way i think all the code stays the same and we just side BUT if we have colon equals
			be one token it might be the same so would have to check in the "=" evaluation code and that 
			should make the decision but these are the 2 main options. also to check "::" when we do constants
			     =
			    / \
				:   expr
			  /
			 x
			*/
			// case #char ":"; {
			// 	//TODO Could then set RHS to be DATA_TYPE_INFO if we are not in a for loop
			// 	//so that then we can know when we are parsing data types with "," for example
			// 	//but maybe there is a better way when I actually do it
			// 	EatNextToken(*cd.lexer); //Eat ":"
			// 	equals_token := PeekNextToken(cd.lexer);
			// 	if equals_token.token_type == #char "=" {
			// 		EatNextToken(*cd.lexer); //Eat "="
			// 		//We make the ":" node with the variable name on the left 
			// 		colon_node : *BinaryNode = MakeBinaryNode(left,next,null,*cd.binary_tree,.BINARY_OP);
			// 		next_prec = GetCodePrec(equals_token.token_type,pl);
			// 		right := ParseExpression(cd, next_prec, pl);
			// 		//We put ":" on the left and "=" on top and then expression on the right as as shown in tree above
			// 		equals_node : *BinaryNode = MakeBinaryNode(colon_node,equals_token,right,*cd.binary_tree,.BINARY_OP);
			// 		return equals_node;
			// 	} else {
			// 		right := ParseExpression(cd, next_prec, pl);
			// 		return MakeBinaryNode(left,next,right,*cd.binary_tree,.BINARY_OP);
			// 	}
			// }
			//TODO Could also do lookahead for "." to check for .[] or .{} as suggested by Jon.
			case #char ",";
				EatNextToken(*cd.lexer); //Eat ","
				right := ParseExpression(cd, GetCodePrec(#char ",",pl), pl);
				return MakeBinaryNode(left,next,right,*cd.binary_tree,.BINARY_OP);
			// case #char ")"; //Function call binary op
			// 	//TODO Remove this and also remove as precedence if we don't use it so it's just min prec and stops there.
			// 	return left;
			case #char "("; //Function call binary op
				//TODO Can optimize and check right for ")" here and then just finish the node creation
				//instead of parsing the next expression
				//TODO Can check that left is indeed a function here if we parse function declarations
				//before doing this operator precedence tree construction.
				//TODO Can also do some checks for size_of or New/NewArray here if needed. We do them in evaluation now
				//but we can do them here in the parser if needed.
				EatNextToken(*cd.lexer); //Eat "("
				right := ParseExpression(cd, GetCodePrec(#char ")",pl), pl); //")" is currently S64_MIN
				// right := ParseExpression(cd,S64_MIN);
				if right.value.token_type != #char ")" {
					//TODO Check that this or right.token_type is ")" otherwise CompilerError
					EatNextToken(*cd.lexer); //Eat ")"
				}
				return MakeBinaryNode(left,next,right,*cd.binary_tree,.BINARY_OP);
			// case #char "]";
			// 	//TODO Remove this and also remove as precedence if we don't use it so it's just min prec and stops there.
			// 	return left;
			case #char "["; //Array access binary op
				//TODO If this stays the same as "(" then we can have 1 case
				EatNextToken(*cd.lexer); //Eat "["
				//TODO SHOULD LIKELY RETURN COMPILATION ERROR HERE IF NEXT TOKEN IS "]" without anything inside
				right := ParseExpression(cd, GetCodePrec(#char "]",pl), pl); //"]" is currently S64_MIN
				// right := ParseExpression(cd,S64_MIN);
				//TODO Check that this is "]" otherwise compilation error
				EatNextToken(*cd.lexer); //Eat "]"
				return MakeBinaryNode(left,next,right,*cd.binary_tree,.BINARY_OP);
			//TODO .STRUCT_LITERAL would be the same but with ".{" and close on "}"
			case .ARRAY_LITERAL;
				EatNextToken(*cd.lexer); //Eat ".["
				peek_t := PeekNextToken(cd.lexer);
				right : *BinaryNode;
				if peek_t.token_type == #char "]" {
					right = MakeBinaryNode(null,peek_t,null,*cd.binary_tree);
				} else {
					right = ParseExpression(cd, GetCodePrec(#char "]",pl), pl); //"]" is currently S64_MIN
				}
				EatNextToken(*cd.lexer); //Eat "]"
				//TODO Old code can remove if new one is working in all cases
				// right := ParseExpression(cd, GetCodePrec(#char "]",pl), pl); //"]" is currently S64_MIN
				//TODO ParserError if neither right nor next_token are "]"
				// if right.value.token_type != #char "]" {
				// 	EatNextToken(*cd.lexer); //Eat "]"
				// }
				return MakeBinaryNode(left,next,right,*cd.binary_tree,.BINARY_OP);
			case .STRUCT_LITERAL;
				EatNextToken(*cd.lexer); //Eat ".{"
				peek_t := PeekNextToken(cd.lexer);
				right : *BinaryNode;
				if peek_t.token_type == #char "}" {
					right = MakeBinaryNode(null,peek_t,null,*cd.binary_tree);
				} else {
					right = ParseExpression(cd, GetCodePrec(#char "}",pl), pl); //"}" is currently S64_MIN
					//TODO Should check here that we close with "}"
				}
				EatNextToken(*cd.lexer); //Eat "}"
				//TODO ParserError if neither right nor next_token are "}"
				// if right.value.token_type != #char "}" {
				// 	EatNextToken(*cd.lexer); //Eat "}"
				// }
				return MakeBinaryNode(left,next,right,*cd.binary_tree,.BINARY_OP);
			// case #char "{";
			// 	EatNextToken(*cd.lexer);
			// 	right := ParseExpression(cd,S64_MIN);
			// 	EatNextToken(*cd.lexer); //TODO Might have to remove this EatNextToken since we parse it later already.
			// 	return MakeBinaryNode(left,next,right,*cd.binary_tree,.BINARY_OP);
			//TODO Will leave this here for now but I don't think we need anymore as parsing last ";"
			// case #char ";";
			// 	has_next : bool = expr.next_index+1 >= expr.lexer.lexer_tokens.count;
			// 	if !has_next {
			// 		EatNextToken(*cd.lexer);
			// 		return MakeBinaryNode(left,next,null,*cd.binary_tree);
			// 	}
			// 	#through;
			case .POSTFIX_DEREFERENCE;
				//Postfix operators do not get the next expression.
				//TODO Need to make sure the precedence is higher then whatever we want it to stop at.
				EatNextToken(*cd.lexer);
				//TODO Should I put it on the left? Does it matter? I have other UNARY_OPs on the right.
				//Maybe we should put them all on the left... I dunno
				//On left because of this case, which would not work if it was on the right,
				//since we check the tree as parent.left until we hit "." for struct members
				/*
	   	       .
		   	   / \ 
		   	  t   .*
		   	      /
		   	     p
				*/	
				return MakeBinaryNode(left,next,null,*cd.binary_tree,.BINARY_OP);
			case;
				//TODO I THINK WE SHOULD CHECK THAT BOTH LEFT AND RIGHT OR NOT NULL HERE
				//TODO Pass in EXPRESSION_LEVEL flag for binary operators like '='
				//TODO When we hit something like '{' or '}' or ';', then we are back at STATEMENT_LEVEL flag
				//TODO Postfix operators would be like this except without getting the next expression.
				EatNextToken(*cd.lexer);
				right := ParseExpression(cd, next_prec, pl);
				//TODO Could evaluate if children here are of correct type and form for example
				//Would do this after creating but before returning.
				//VerifyNode(node);
				return MakeBinaryNode(left,next,right,*cd.binary_tree,.BINARY_OP);
			}
		}
	} else {
		// expr.next_index -= 1;
		return left;		
	}
}

/*TODO NON-RECURSIVE REASONS
	- faster since we don't use the function stack
	- more space efficient since we don't use the function stack
	- can cleanly return errors instead of having them be passed back up the call stack
*/
//TODO Should we rename this to ParseStatement? I guess expression is more general but
//it really parses a statement the way we are doing it now
//TODO Pass in the expression here and in ParseIncreasingPrecedence as well so we can reuse
//Then also make it not recursive eventually
//TODO Could make default min_prec = S64_MIN
// ParseExpression :: (expr : *CodeExpression, min_prec : int, pl : ParserLevel = .STATEMENT) -> *BinaryNode {
ParseExpression :: (cd : *CompilationData, min_prec : int, pl : ParserLevel = .STATEMENT) -> *BinaryNode {
	left := ParseLeaf(cd, pl);
	if left == null return null; //Error out here
	while true {
		node := ParseIncreasingPrecedence(cd, left, min_prec, pl);
		if node == left break;
		left = node;
	}
	return left;
}

/*TODO Pass in some flags here like EXPRESSION_LEVEL and STATEMENT_LEVEL so we can have
more precise error checking when we do error checking.
*/
// ParseLeaf :: (expr : *CodeExpression, pl : ParserLevel = .STATEMENT) -> *BinaryNode, is_valid_leaf : bool {
ParseLeaf :: (cd : *CompilationData, pl : ParserLevel = .STATEMENT) -> *BinaryNode, is_valid_leaf : bool {
	//TODO If next is empty then it may be the case that we need a token that is not there
	//and therefore this is likely an error in all or most cases.
	//This is the only place we call it so can likely return a true/false validation second return value and then check.
	//TODO We can lazy lex tokens as we need them here instead of doing it all in 1 shot at the beggining
	next, has_next_token := PeekNextToken(cd.lexer);
	if !has_next_token return null, false;
	EatNextToken(*cd.lexer);
	// next := GetNextToken(expr);

	//TODO Do we need this. what if a leaf is an operator? Should test it out.
	//In jon's sample code this only parses string_literals, code_irs and numbers.
	//He mentions later that he also parses unary ops here.
	node : *BinaryNode;
	if next.token_type == {
	//TODO Casting can be a unary operator eg cast(int) expr
	case #char "*"; #through; //Pointer unary op
	case #char "~"; #through;
	case #char "!"; #through;
	case #char "+"; #through;
	case #char "-"; {
		//TODO Is 1 unary precedence ok or should we separate them?
		//In any case for () or [] we will have a new ParseExpression precedence.
		// unary_prec : int = 10000;
		unary_expr := ParseExpression(cd, GetCodePrec(.UNARY_OP,pl), pl);
		//TODO Can set binary op above. Can also create numbers and strings if needed.
		//TODO Should we put unary_exp on the left since the traversal order is post left to right?
		node = MakeBinaryNode(null,next,unary_expr,*cd.binary_tree,.UNARY_OP);
	}
	//TODO Leaving this here as a reminder, decided NOT to use <x,y> notation for tano.
	//It works in general but it is a bit weird if we have something like <x,foo(x>y)>.
	//It can parse but we generally will stop at the ">" and even with something simple like
	//<x,x+y>, that works but it looks weird.
	//In general it looks weird and the handling over-complicates the parse for no good reason imo
	//and the angle brackets themselves are not that clear from a visual perspective and also from
	//thinking perspective because of the use of less than and greater than symbols.
	//ALSO I don't know why but there is something about the <,> brackets that feels wrong with more than
	//one symbol inside. I think it's ok for asm but maybe we change it there too or at least allow <x,y> == tano(x,y)
	// case #char "<"; {
	// 	unary_expr := ParseExpression(cd, S64_MIN, .PARSE_TANO);
	// 	peek_next := PeekNextToken(cd.lexer);
	// 	if peek_next.token_type != #char ">" {
	// 		CreateCompErr(*cd.comp_errors, .PARSER, next,
	// 		"No close > found for open <.");
	// 		return null, false;
	// 	}
	// 	EatNextToken(*cd.lexer); //Eat ">"
	// 	node = MakeBinaryNode(null,next,unary_expr,*cd.binary_tree,.UNARY_OP);
	// }
	case .KEYWORD_CAST;
		/*Unary cast op with type on left and expression on right
		eg cast(int) (f+1)
			 cast
			 / \
		  int  +
		      / \
		     f   1
		*/
		//TODO Test these errors
		peek_next := PeekNextToken(cd.lexer);
		if peek_next.token_type == #char "(" {
			EatNextToken(*cd.lexer);
		} else {
			//NOTE This deals with cast without "("
			CreateCompErr(cd, .PARSER, next, "Invalid cast.");
			return null, false;
		}

		cast_type := ParseExpression(cd, S64_MIN, pl);

		peek_next = PeekNextToken(cd.lexer);
		if peek_next.token_type == #char ")" {
			EatNextToken(*cd.lexer);
		} else {
			//NOTE This deals with both 
			// cast()    : without type
			// cast(TYPE : without ")" close bracket
			CreateCompErr(cd, .PARSER, next, "Invalid cast.");
			return null, false;
		}

		next_expr := ParseExpression(cd, GetCodePrec(.KEYWORD_CAST), pl);
		node = MakeBinaryNode(cast_type,next,next_expr,*cd.binary_tree,.UNARY_OP);
	//TODO Why do we have a unary ":" here? Maybe it would be useful for asm reg declarations?
	//But that would be parsed in the assembler and not here I think.
	// case #char ":";
	case .ARRAY_LITERAL;
		//DO THE SAME THING FOR STRUCT LITERAL but different case with "}". Can remove this once we do that.
		//This should stop at "{" or ";" since ";" < "{". This is for unary "." like .[];
		//TODO So maybe we don't need it if we don't allow this case and only allow int.[] for example.
		next_expr := ParseExpression(cd,S64_MIN,pl);
		// next_expr := ParseExpression(cd,S64_MIN);
		//TODO Not sure we need the .UNARY_OP here but can leave it for now.
		if next_expr.value.token_type != #char "]" {
			//TODO CompilerError ParserError if we don't have "]" here or on next_expr
			EatNextToken(*cd.lexer); //Eat "]"
		}
		node = MakeBinaryNode(null,next,next_expr,*cd.binary_tree,.UNARY_OP);
	//TODO NOTE that I've placed these unary ops here BUT if we don't have type inference for array and struct literals
	//then we can likey remove these and just keep the binary op literal case.
	case .STRUCT_LITERAL;
		next_expr := ParseExpression(cd,S64_MIN,pl);
		if next_expr.value.token_type != #char "}" {
			//TODO CompilerError ParserError if we don't have "}" here or on next_expr
			EatNextToken(*cd.lexer); //Eat "}"
		}
		node = MakeBinaryNode(null,next,next_expr,*cd.binary_tree,.UNARY_OP);
	case #char "["; {
		//Array type specific case
		/*For tree structure with element type on top
			[1] *int

				[
			  / \      
			 *	  2    
      	  \      
			  int  


			[][..] int

			     [
				 / \
				[   ]
			  / \
			int ..
		*/
		//TODO Could make this into a function to parse the next array expression and then
		//re-use it in multi-dimensional loop. Although with errors maybe it's not worth it.
		//Parser first array
		array_expr := ParseExpression(cd, GetCodePrec(#char "]",pl), pl);
		node = MakeBinaryNode(null,next,array_expr,*cd.binary_tree,.DATA_TYPE_INFO);
		if array_expr.value.token_type != #char "]" {
			//TODO CompilerError ParserError if we don't have "]" here.
			//Should be error if either array_expr or next_token are not "]".
			EatNextToken(*cd.lexer); //Eat "]"
		}

		//Check for multi-dimensional array
		prev_node : *BinaryNode = node;
		//TODO Do we have to check has_next_token here? Maybe we can remove because array type should have a next token
		//no matter what and we can just make that a compiler error
		next, has_next_token = PeekNextToken(cd.lexer);
		while has_next_token && next.token_type == #char "[" {
			EatNextToken(*cd.lexer); //Eat "["
			//TODO Should we return on "]" using code_prev instead of min? Does it not matter?
			array_expr := ParseExpression(cd, GetCodePrec(#char "]",pl), pl);
			//TODO ParserError can check the array_expr.right here for "]" alone or ".." alone
			//or otherwise an invalid expression should be returend in the fixed array case.
			if array_expr.value.token_type != #char "]" {
				//TODO CompilerError ParserError if we don't have "]" here.
				//Should be error if either array_expr or next_token are not "]".
				EatNextToken(*cd.lexer); //Eat "]"
			}
			new_node := MakeBinaryNode(null,next,array_expr,*cd.binary_tree,.DATA_TYPE_INFO);
			prev_node.left = new_node;
			prev_node = new_node;
			next, has_next_token = PeekNextToken(cd.lexer);
		}

		//Examples of type array type usage -> x : [] int :  OR  x : [] int =  OR  foo([] int, 0) 
		//So precedence of ":" must be higher than "=" and "," which it is.
		type_node : *BinaryNode = ParseExpression(cd, GetCodePrec(#char ":",pl), pl);
		prev_node.left = type_node;
	}
	//TODO could split these up if need different precedence or different positions
	//TODO Could use flags to reorder precedence for FOR loops of , and :. We need current precedence for function declarations
	//TODO Could also just parse for loop directly until { and have it in 1 node. Could be useful if we make things more linear later.
	//TODO I think we can even add DEFER and RETURN and BREAK here with similar logic and stop at "{" since ";" < "{".
	//Or just make another case that stops at ";" since we can't have those as conditions which stop at "{".
	//TOOD I think we should try else as base case and just pass it back as a single node since we can skip
	//over the token anyways.
	//TODO I think the case is different because we cant inline it with other keywords
	//TODO Likely this will be the same as break, continue and defer (if we do defer)
	case .KEYWORD_RETURN; 
		next_check := PeekNextToken(cd.lexer);
		if next_check.token_type == #char ";" {
			node = MakeBinaryNode(null,next,null,*cd.binary_tree,.UNARY_OP);
		} else {
			next_expr := ParseExpression(cd,S64_MIN,pl);
			node = MakeBinaryNode(null,next,next_expr,*cd.binary_tree,.UNARY_OP);
		}
	case .KEYWORD_FOR; {
		for_loop_data : *ForLoopData = array_add(*cd.all_for_loop_data);
		//We don't use next for before since that holds the for so we can reuse later.
		for_type_token := PeekNextToken(cd.lexer);
		while AllOrEquals(for_type_token.token_type, .[#char "<", #char "*"]) {
			if for_type_token.token_type == {
			case #char "<";
				if for_loop_data.is_reverse {
					CreateCompErr(cd, .PARSER, for_type_token, "Multiple < found on for loop.");
					return null, false;
				}
				for_loop_data.is_reverse = true;
			case #char "*";
				if for_loop_data.is_pointer {
					CreateCompErr(cd, .PARSER, for_type_token, "Multiple * found on for loop.");
					return null, false;					
				}
				for_loop_data.is_pointer = true;
			}
			EatNextToken(*cd.lexer);
			for_type_token = PeekNextToken(cd.lexer);
		}

		next_token := cd.lexer.lexer_tokens[cd.lexer.next_index];
		next_next_token := cd.lexer.lexer_tokens[cd.lexer.next_index+1];
		if next_token.token_type == .IDENT && next_next_token.token_type == #char ":" {
	   	for_loop_data.value_name = next_token.token_string;
	   	EatNextToken(*cd.lexer);
	   	EatNextToken(*cd.lexer);
	   } else if next_token.token_type == .IDENT && next_next_token.token_type == #char "," {
	   	for_loop_data.value_name = next_token.token_string;
   		EatNextToken(*cd.lexer);
   		EatNextToken(*cd.lexer);
   		next_token = cd.lexer.lexer_tokens[cd.lexer.next_index];
			next_next_token = cd.lexer.lexer_tokens[cd.lexer.next_index+1];
   		if next_token.token_type == .IDENT && next_next_token.token_type == #char ":" {
		   	for_loop_data.index_name = next_token.token_string;
		   	EatNextToken(*cd.lexer);
		   	EatNextToken(*cd.lexer);
		   } else {
		   	CreateCompErr(cd, .PARSER, node, "Invalid for loop.");
				return null, false;
		   }
   	}
		next_expr := ParseExpression(cd,S64_MIN,pl); //"{" == S64_MIN
		node = MakeBinaryNode(null,next,next_expr,*cd.binary_tree,.UNARY_OP);
	}
	case .KEYWORD_WHILE; #through;
	case .KEYWORD_IF; //TODO What if we have 1 line if statement? ";" < "{"
		//TODO Should we have any errors in here
		next_expr := ParseExpression(cd,S64_MIN,pl); //"{" == S64_MIN
		node = MakeBinaryNode(null,next,next_expr,*cd.binary_tree,.UNARY_OP);
	case .KEYWORD_ELSE;
		//We separate between if and else if here and then need to check during evaluation as well.
		//Maybe it's better to make a separate token for else if... not sure...
		//We could put the ELSE_IF in the node type...
		next_check := PeekNextToken(cd.lexer);
		if next_check.token_type == {
		/*else if is 
			else
				\
				if
				  \
				  cond

	   and else alone is just
	   	else
		*/
		case .KEYWORD_IF;
			next_expr := ParseExpression(cd,S64_MIN,pl);
			node = MakeBinaryNode(null,next,next_expr,*cd.binary_tree,.UNARY_OP);
		case;
			node = MakeBinaryNode(null,next,null,*cd.binary_tree,.UNARY_OP);	
		}
	// case #char "}";
	// 	next_expr := ParseExpression(cd,S64_MIN);
	// 	node = MakeBinaryNode(null,next,next_expr,*cd.binary_tree,.UNARY_OP);
	case #char "("; {
		// node = ParseExpression(cd,GetCodePrec(#char ")")); //")" is currently S64_MIN
		/*DOC : This is for cases like function pointers eg "() -> ()" where we hav empty input/output
		() = function without input or output which is the same as in jai.
		*/
		check_close := PeekNextToken(cd.lexer);
		if check_close.token_type == #char ")" {
			EatNextToken(*cd.lexer); //Eat ")"
			node = MakeBinaryNode(null,check_close,null,*cd.binary_tree);
		} else {
			node = ParseExpression(cd,S64_MIN,pl);
			/*DOC : Was using != ")" before but since we check that above now, we are explicitly checking ")" to eat
			so we skip over it during a non-"()" parsing. If we have problems then we can put this back.
			*/
			next_check := PeekNextToken(cd.lexer);
			// if node.value.token_type != #char ")" {
			if next_check.token_type == #char ")" {
				EatNextToken(*cd.lexer); //Eat the close bracket ")".
			}
		}
		//OLD VERSION OF checking "(" for reference
		// node = ParseExpression(cd,S64_MIN,pl);
		// if node.value.token_type != #char ")" {
		// 	EatNextToken(*cd.lexer); //Eat the close bracket ")".
		// }
	}
	case #char "#"; {
		code_dir : CodeDirective = code_directive_enums[next.value.int_value];
		if code_dir == {
		case .asm;
			node = MakeBinaryNode(null,next,null,*cd.binary_tree);
		//TODO Could just make this the default case if that is it.
		case .load; #through;
		case .type;
			type_expr := ParseExpression(cd,S64_MIN,pl);
			node = MakeBinaryNode(null,next,type_expr,*cd.binary_tree,.UNARY_OP);
		}
	}
	case .KEYWORD_OPERATOR; {
		//TODO Allowing operators with more chars like "~+^" might be interesting but also confusing...
		peek_op := PeekNextToken(cd.lexer);
		is_valid_op_overload : bool = false;
		for valid_operator_overloads if peek_op.token_type == it {
			is_valid_op_overload = true;
			EatNextToken(*cd.lexer);
			break;
		}
		//Check that the next colon after the operator is a double colon without eating it so we parse later
		peek_double_colon := PeekNextToken(cd.lexer);
		if !is_valid_op_overload || peek_double_colon.token_type != .DOUBLE_COLON {
			CreateCompErr(cd, .PARSER, peek_double_colon, "Invalid operator overload.");
			return null, false;
		}

		op_node := MakeBinaryNode(null,peek_op,null,*cd.binary_tree);
		node = MakeBinaryNode(null,next,op_node,*cd.binary_tree,.UNARY_OP);
	}
	// case #char "]"; #through; 
	// case #char ")"; //Don't want to parse ")" so we can check for "(" on the return either for unary or binary "(".
	// 	UnwindIndex(expr);
	// 	#through; //This returns the closing bracket as a node so we can tell that it was closed
	/*DOC : We put invalid unary ops here so that we error out for ops that are not allowed to be unary.
	So this should error out for things like assignment struct members and function input variables
	eg s.{,y} OR s.{=x}
	and foo(,y) OR foo(=1)
	*/
	case #char "="; #through;
	case #char ","; {
		CreateCompErr(cd, .PARSER, next,
		sprint("Invalid unary op : %.\n", next.token_type));
		return null, false;
	}
	case;
		//TODO ParserError - if certain values cannot be unary ops, then we should check them here,
		//FOR EXAMPLE, LOGICAL_AND and LOGICAL_OR, "&", "|", etc...
		//TODO This is a leaf so we can possibly pre-process string and ints and floats and bools here.
		node = MakeBinaryNode(null,next,null,*cd.binary_tree);
	}
	return node, true;
}

//TODO We set this in the evaluator but we could do it in the parser.
SetIntegerNode :: inline (node : *BinaryNode, int_value : int, cd : *CompilationData) {
	node.code_ir.ir_type = .INTEGER;
	node.code_ir.code_value_type = CodeValueType.R_VALUE;
	node.code_ir.t_info = *cd.int_type_info;
	node.code_ir.op = Imm(int_value);
}

/*NOTE : LARGE NUMBERS ARE ON THE BOTTOM SINCE LARGE NUMBERS ARE LOWER ON THE TREE based on the precedence checking in ParseIncreasingPrecedence
*/
GetCodePrec :: inline (type : CodeTokenType, pl : ParserLevel = .STATEMENT) -> int {
	if type == {
	//Used for inline statements like 'for array if it.x == 2 while it.x > 3 {}'
	//TODO This should probably go after '{', especially if we linearize things.
	//TODO Can these all be S64_MIN so we stop there on parsing? Could make it explicit here.
	// case .KEYWORD_FOR; return -40;
	// case .KEYWORD_WHILE; return -30;
	// case .KEYWORD_ELSE; return -20;
	// case .KEYWORD_IF; return -10;
	// case .KEYWORD_RETURN; return -9;

	// case #char "}"; return -10; //TODO This is not a binary operator anymore so we could remove it
	// case #char ";"; return 0;
	// case #char "{"; return 10;

	//Where do these go? Maybe above the brackets for function declarations and function calls with names and struct calls?
	case .DOUBLE_COLON; return 30;
	case .COLON_EQUALS; return 31;
	// case .RIGHT_ARROW; return 50;
	//Not sure this precedence would work for foo(x = 2, y = 6.0) since "," is higher and "=" it would stop on "="
	//This i believe is currently because of multi-variable assignment like x,y = foo(2)
	//Would it still work though? Need to test with default value for function declaration and functon calls
	//TODO Maybe "=" should be below .ARRAY_LITERAL for case
	//DOC : I think these can always be the same since we can only have 1 per statement anyways.
	case #char "="; return 51;
	case .TILDE_EQUALS; return 51;
	case .PLUS_EQUALS; return 51;
	case .MINUS_EQUALS; return 51;
	case .TIMES_EQUALS; return 51;
	case .DIV_EQUALS; return 51;
	case .MOD_EQUALS; return 51;
	//TODO Put all other equals here

	//TODO Should this go below comma? For int.[int.[0,1],int.[2,3]]
	//Removed these since they close on S64_MIN anyways as we always want to end the expression on them right now.
	// case #char "]"; return 99;
	// case #char ")"; return 100;
	// TODO NOTE IMPORTANT SO FOR ":" and "," we need different precedences depending on if we are in a function
	// declaration or in a value list. For a function declaration, we need the "," higher on the tree
	// but for ":" we may need the ":" higher on the tree, especially if we dont use ":=" as 1 node which i feel like we won't
	// case #char ","; return 101;
	case #char ","; return 40;
	case #char ":"; return 102;
	//NOTE : We place this here lower for function pointers and it seems to work so let's see moving forward.
	case .RIGHT_ARROW; return 103;

	//TODO Can remove this later, was a test for := as separate but did not work smoothly so decided to make 1 token.
		// if pl == .FUNCTION_DECLARATION {
		// 	if type == {
		// 		case #char ","; return 101; //TODO Should this be way up? It's higher up in C
		// 		case #char ":"; return 102;
		// 	}
		// } else if pl == .STATEMENT {
		// 	if type == {
		// 	case #char ","; return 102; //TODO Should this be way up? It's higher up in C
		// 	case #char ":"; return 101;
		// 	}
		// }
	//TODO Shouldn't this be higher up? I think above arithmetic - for x+1..y-5
	//For loop is binary op and, [..] is unary op anyways I am pretty sure.
	//[..] This will be grabbed directly and placed below in any case since it parsed as a unary op in that case.
	//This is needed for "for x+y..2*a" AND for "tano(x,y0..y1)" as a binary op
	//which requires it to be above everything else, including function calls for
	//"tano(x,foo()..foo2())"
	//"for foo()..foo2()""
	case .DOUBLE_DOT; return 104;

	// case #char "("; return 104; //Should this be way up? This is way higher up in C with "[". 

	//TODO Remove these now with new parsing if these dont work.
	// case .DATA_TYPE_INT; return 200;
	// case .DATA_TYPE_FLOAT; return 201;
	// case .IDENT; return 202;

	//TODO Where exactly should this be? Should it be below logical/bitiwse op or will we use those at some point?
	case #char "~"; return 750;


	//Logical operators
	case #char ">"; return 798;
	case #char "<"; return 799;
	case .LOGICAL_OR; return 800;
	case .LOGICAL_AND; return 801;
	case #char "|"; return 802;
	case #char "^"; return 803;
	case #char "&"; return 804;
	case .IS_EQUAL; return 807;
	case .ISNOT_EQUAL; return 808;
	case .LESS_EQUALS; return 809;
	case .GREATER_EQUALS; return 810;
	//TODO Left/right shift and rotate

	case #char "-"; return 900;
	case #char "+"; return 901;
	case #char "%"; return 902;
	case #char "/"; return 903;
	case #char "*"; return 904;

	//NOTE : This needs to be below "(" because of case "-foo(0)" so we can negative functions
	//and also "-tano(x,y)" so we can negate tanos
	case .UNARY_OP; return 970;
	//NOW IT IS WAY UP!
	case #char "("; return 980; //Should this be way up? This is way higher up in C with "[". 

	//TODO Can put cast here i think, would need to test since we want it to stop at binary ops but not structs or arrays or unary ops
	case .KEYWORD_CAST; return 999;
	//TODO Test unary ops eventually with all cases like (----2) and (++++2) and (++-+-2), etc...
	//Unary Op is high up here for things like unary "+" and "-" and "*"
	case #char "."; return 1001;
	//TODO Should this not be below "," and ":"
	case .ARRAY_LITERAL; return 1002;
	//Putting this here for arrays as binary ops should be low since they should be evaluated like variables.
	case #char "["; return 1003;
	// a.*[2] -> so we need "[" to be above ".*" I think so that the "[" is above the ".*" on the tree here
	//Example in Test_ParsePointer if needed
	case .POSTFIX_DEREFERENCE; return 1004;
	//TODO Test to see if this precedence is ok
	case .STRUCT_LITERAL; return 1005;
	

	//TODO Could put IF, THEN, ELSE here as binary operators for single line if statements.
	//TODO Unary operators are processed as leafs, so I don't think we need them here.
	// case .UNARY_MINUS; return 10001;
	// case .UNARY_PLUS;  return 10002;
	}
	return S64_MIN;
}

CodeStatement :: struct {
	top_node : *BinaryNode;
}

/*NOTE : These are used in parse expression. We going through the lexer tokens, so we pass in the lexer.
*/
//We assume here that peek was already called and so bounds were checked.
//TODO Can just replace this with Peek and Eat if needed
GetNextToken :: (lexer : *CodeLexer) -> LCodeToken {
	next_token := lexer.lexer_tokens[lexer.next_index];
	lexer.next_index += 1;
	return next_token;
}

//Right now we only use Peek and Eat so we can remove the others if not needed or put peeak and eat in the get function.
EatNextToken :: (lexer : *CodeLexer) {
	lexer.next_index += 1;
}
PeekNextToken :: (lexer : CodeLexer) -> LCodeToken, has_next_token : bool {
	if lexer.next_index >= lexer.lexer_tokens.count return LCodeToken.{}, false;
	next_token := lexer.lexer_tokens[lexer.next_index];
	return next_token, true;
}
PeekLastToken :: (lexer : CodeLexer) -> LCodeToken, has_token : bool {
	if lexer.lexer_tokens.count == 0 || lexer.next_index == 0 || lexer.next_index > lexer.lexer_tokens.count {
		return LCodeToken.{}, false;
	}
	last_token := lexer.lexer_tokens[lexer.next_index-1];
	return last_token, true;
}
PeekBeforeLast :: (lexer : CodeLexer) -> LCodeToken, has_token : bool {
	if lexer.lexer_tokens.count < 2 || lexer.next_index < 2 || lexer.next_index > lexer.lexer_tokens.count + 1 {
		return LCodeToken.{}, false;
	}
	prev_token := lexer.lexer_tokens[lexer.next_index-2];
	return prev_token, true;
}

UnwindIndex :: (lexer : *CodeLexer) {
	lexer.next_index -= 1;
}



CompilationLevelType :: enum u8 {
	NONE;
	FUNCTION_DECL_INPUT_VARS;
	FUNCTION_DECL_RETURN_VARS;
	//We won't create instructions here and just return data.
	DECLARATION_LEVEL; 
	STATEMENT_LEVEL;
	STRUCT_DECLARATION;
}

//TODO If we don't add anything else here then we can just pass in the flag.
//Leaving as a struct for now in case we do want to add more CompilationLevel data.
CompilationLevel :: struct {
	type : CompilationLevelType;
}

CompilerErrorType :: enum u8 {
	LEXING;
	EVALUATION;
	INTERNAL;
	PARSER;
	ASSEMBLY_ERROR;
}

CompilationErrors :: struct {
	all_compiler_errors : [..] CompilerError;
	compiler_errors_string : DynamicString;
}
InitCompilationErrors :: inline (ce : *CompilationErrors) {
	ce.all_compiler_errors.allocator = context.allocator;
	InitDynamicString(*ce.compiler_errors_string, Kilobyte(5));
}
CompilerError :: struct {
	//TODO Not sure this type is useful... maybe internally
	type : CompilerErrorType;
	msg : string;
	//TODO We could remove the color here but I guess eventually we might highlight messages different colors
	//like different highlighting for errors or warnings
	err_highlight : TextHighlight;
}
//TODO FROM HERE maybe clean up comp errors before startin cs2 or after...
//TODO Remove this function once we only use CreateCompErr
//Can gradually remove it as we go through the compiler and adjust each error
#if 0 {
MakeCompErr :: inline (type : CompilerErrorType, msg : string) -> CompilerError {
	c_error : CompilerError;
	c_error.type = type;
	c_error.msg = msg;
	return c_error;
}
}

//TODO Could make this error different from other one so we can grab node value differently 
//from the compiler than from the lexer or assembler.
CreateCompErr :: inline (cd : *CompilationData, type : CompilerErrorType, node : *BinaryNode, msg : string) {
	CreateCompErr(cd, type, node.value, msg);
}
//TODO Could just pass in load files and compilation error object in here if that is clearer
CreateCompErr :: inline (cd : *CompilationData, type : CompilerErrorType, token : LCodeToken, msg : string) {
	load_file, found_load_file := ArrayFindFirstByNameId(cd.all_directive_load_files,
		token.absolute_path_name, "absolute_path_name");
	//DOC : We need this option because we can compile something without a file or lex tokens and then
	//parse an expression without a file and still want errors. This seems conducive to errors but not really
	//because we only set file names in the token when we have a file, so if it's empty, then we just won't find it.
	if found_load_file {
		CreateCompErr(*cd.comp_errors, type, token, load_file.file_string, msg);
	} else {
		CreateCompErr(*cd.comp_errors, type, token, "", msg, print_lines=false);
	}
}
//TODO We have it this way so we can add lexer_errors as well. So if we want a line, then we need
//to either pass in the whole string and get by total_char_index or some other way.
/*TODO Likely eventually best to just pass in CompilationData so we can grab the current file from there
and then grab the string from there to output the string in compiler errors and also to get the file name
directly instead of storing it in LCodeToken for convenience the way it is now.
*/
CreateCompErr :: inline (
	// all_compiler_errors : *[..] CompilerError,
	comp_errors : *CompilationErrors,
	type : CompilerErrorType,
	token : LCodeToken,
	file_string : string,
	msg : string,
	$print_lines : bool = true)
{
	new_err : CompilerError;
	//TODO Add file_name from CompilationData here once we have separate files
	//We did not add CompilationData because the lexer does not have it but eventually the lexer
	//will either have CompilationData OR files and so we can 
	// token_string := string.{token.token_length, file_string.data+token.total_char_index};
	sb : String_Builder;
	sb.allocator = temp;
	//TODO Should add \n here so we can control it overall and not in the input error msg
	//TODO Could set "Error :" in here before message or warning if we have warnings later.
	print_to_builder(*sb, "%:%,%: Error: %\n\n",
		token.absolute_path_name, token.line_number, token.line_char_index, msg,, temp);
	start_error : string = builder_to_string(*sb, do_reset=false);
	#if print_lines {
	line_start : int = LineStartCharPoint(token.total_char_index, file_string);
	line_end : int = LineEndCharPoint(token.total_char_index, file_string);
	line_count : int = line_end - line_start;
	// if line_end < file_string.count && file_string[line_end] == #char "\n" {
	// 	line_count -= 1;
	// }
	line : string = String.slice(file_string, line_start, line_count);
	remove_start_char_count : int = 0;
	while remove_start_char_count < line.count && is_space(line[remove_start_char_count]) {
		remove_start_char_count += 1;
	}
	line.data += remove_start_char_count;
	//TODO I Think this feels better with just the given line. We could make this a settings though... i guess...
	//and pass it in through compile settings and comp errors here if needed.
	//would need to adjust the highlight position if we add the line before later but not ht eline after
	start_adjust : string = "  ";
	// adjusted_prev_line : string;
	// if line_start > 0 {
	// 	prev_char_point : int = line_start - 1;
	// 	prev_line : string = GetTextLine(prev_char_point, file_string);
	// 	remove_index : int = 0;
	// 	while remove_index < prev_line.count && is_space(prev_line[remove_index]) {
	// 		remove_index += 1;
	// 	}
	// 	prev_line.data += remove_index;
	// 	adjusted_prev_line = tprint("%0%0", start_adjust, prev_line);
	// 	append(*sb, adjusted_prev_line);
	// }
	// print_to_builder(*sb, " - %\n", string.{token.token_length, file_string.data+token.total_char_index});
	//TODO Could add token_string to the compiler error with index and length instead and then
	//just print that out red in rendering and set that as highlighted values in general
	adjusted_line : string = tprint("%0%0\n", start_adjust, line);
	append(*sb, adjusted_line);
	all_error_count : int = 0;
	for comp_errors.all_compiler_errors {
		all_error_count += it.msg.count;
	}
	new_err.err_highlight.char_point = all_error_count + start_error.count + 
		token.line_char_index - remove_start_char_count + start_adjust.count;
	new_err.err_highlight.char_count = token.token_length;
	//TODO This could be passed in as a setting through compile settings and then comp errors
	new_err.err_highlight.highlight_color = MRED_V;

	// next_line : string;
	// if line_end < file_string.count-1 {
	// 	next_char_point : int = line_end + 1;
	// 	next_line = GetTextLine(next_char_point, file_string);
	// 	append(*sb, next_line);
	// 	append(*sb, "\n");
	// }
	}
	comp_err : string = builder_to_string(*sb);
	set_string : string = AddDynamicString(comp_err, *comp_errors.compiler_errors_string);
	new_err.msg = set_string;
	new_err.type = type;
	//TODO We could add a second message which would be the next line OR just put it in as "\n"
	//and then split it on rendering. I think a second message is fine since that is all we need.
	//TODO Do we need to keep the CompilerErrorType or is putting it in the msg enough?
	array_add(*comp_errors.all_compiler_errors, new_err);

	#if 0 {
	check_err_string := string.{new_err.err_highlight.char_count, comp_errors.compiler_errors_string.text_string.data+new_err.err_highlight.char_point};
	print("new_err.err_highlight.char_point=%\n", new_err.err_highlight.char_point);
	print("new_err.err_highlight.char_count=%\n", new_err.err_highlight.char_count);
	print("check_err_string=%\n", check_err_string);
	}
}
IsCompilationFail :: inline (cd : CompilationData) -> bool {
	comp_fail : bool = cd.comp_errors.all_compiler_errors.count > 0;
	return comp_fail;
}

ForLoopData :: struct {
	is_reverse : bool;
	is_pointer : bool;
	value_name : string = "it";
	index_name : string = "it_index";
	//TODO I think we can remove these
	// value_op : MusicOperand;
	// index_op : MusicOperand;

	//TODO Can remove post_instr_count if we only ever have 2 post_loop_instrs anyways
	//which is what we have no in all cases since we just increment index and then jmp back to loop
	//ACTUALLY only using 1 now so we can switch to 1 if that helps
	post_instr_count : int;
	post_loop_instrs : [1] MusicInstruction;
}

MultiReturnMemoryOperand :: struct {
	//TODO Should this be a node pointer or a node_id?
	function_bracket_node : *BinaryNode;
	var_node : *BinaryNode;
	return_mem_op : MusicOperand;
}

/*TODO I am not sure this is the best way to do this but let's try it out and see.
*/
DebugLine :: struct {
	line_number : int;
	start_asm_index : int;
	//DOCU : IN ORDER TO MATCH end_instr_index in scope AND ALSO because it is easier to think about for me.
	//I am making this the last asm_index in the line. For consistency and to remove my confusion.
	end_asm_index : int;
	/*DOC : We need the entire path name here instead of an id because we may not have pulled in those files
	yet. So we could pull in all the files through the compiler and put them as a text file. Then we would have
	to reload them when updating. We could still reference them by absolute_path_name then in that case but
	then maybe we'd be able to do it by id but this seems less ideal if we have lots of files most of which won't be edited.
	In any case, if we pull in the file as a text file in the compiler, we would still check later in the editor anyways
	so maybe that is something we can profile later and see if it's better to do that.
	Another counter-example is if the player is using an external text editor then they may want to just compile and run
	or maybe debug 1 file and then pulling everything in is unnecessary espeically if the files are big.
	Something to think about as we go along.
	*/
	absolute_path_name : string;
}
//TODO Can likely do a binary search on this since it is sorted by line_number
GetDebugLineAsm :: inline (
	asm_index : int, 
	//Passing this in here in case we want better error messages for
	//not finding a debug line.
	comp_data : *CompilationData) 
-> DebugLine //, found_debug_line : bool
{
	for comp_data.all_debug_lines {
		if asm_index >= it.start_asm_index &&
			asm_index <= it.end_asm_index
		{
			return it;
		}
	}
	//TODO Maybe we coudl just return if it was found or not but this
	//should have been created in any case
	assert(false, "No debug line found for asm_index %.\n", asm_index);
	return .{};
}
//NOTE : Likely just use these for tests since in-game we have other considerations for finding lines
/*DOC : This assumes that we are getting the debug line from the main test file with no name.
This avoids possible attempts to load a file with no name path.
*/
GetDebugLineNumber :: inline (
	line_number : int, 
	//Passing this in here in case we want better error messages for
	//not finding a debug line.
	all_debug_lines : [] DebugLine,
	abs_path_name : string = "") 
-> DebugLine //, found_debug_line : bool
{
	for all_debug_lines if line_number == it.line_number && it.absolute_path_name == abs_path_name {
		return it;
	}
	//TODO Maybe we coudl just return if it was found or not but this
	//should have been created in any case
	assert(false, "No debug line found for line_number %.\n", line_number);
	return .{};
}
INVALID_DEBUG_LINE :: DebugLine.{-1,-1,-1,""};
GetDebugLineNumberInFile :: inline (
	line_number : int, 
	file_name : string,
	//Passing this in here in case we want better error messages for
	//not finding a debug line.
	all_debug_lines : [] DebugLine) 
-> DebugLine //, found_debug_line : bool
{
	for all_debug_lines {
		if line_number == it.line_number && String.ends_with(it.absolute_path_name, file_name) {
			return it;
		}
	}
	return INVALID_DEBUG_LINE;
}

/*DOC : Used for the compiler to add constant memory like strings and constant variables eventually.
*/
AddConstantMemory :: inline (ram_data : *u8, byte_count : int, constant_memory : *[..] u8) -> int {
	assert(ram_data && constant_memory);
	const_mem_address : int = constant_memory.count;
	total_new_memory : int = constant_memory.count + byte_count;
	array_reserve(constant_memory, total_new_memory);
	const_ptr : *u8 = constant_memory.data + constant_memory.count;
	memcpy(const_ptr, ram_data, byte_count);
	constant_memory.count += byte_count;
	return const_mem_address;
}

CompilationMode :: enum u8 {
	DEBUG;
	NO_DEBUG;
}
//TODO Can put this in AllData and have scope variables and other compilation data in here.
/*TODO Reminders
	- need to add an allocator which gets cleared at the end of compilation and maybe on that gets cleared
	after each expression parsing. We can then reuse this allocator for other compilations and can have a free
	list if we allow multiple compilation at once. Or we just have 1 compilation at once for now.
	- need to add an allocator that we keep after compilation for things like variable names and other names
	and anything else we might want from compilation. Although we could pass that one in like we do with test_alloc
	and then use that as context.allocator to store everything and specifically store things that get cleared
	in an internal allocator that gets cleared at the end of every loop or at the end and then reuse it.
*/
CompilationData :: struct {
	using compile_ids : CompileIDs;
	scope_stack_index : int;

	//TODO rename CodeExpression -> CodeTreeAndTokens. IT is needed For ParseExpression/ParseStatement
	//TODO If we pull out lexer tokens then we can do everything directly. For now this is convenient
	//For separating the ParseExpression data... Might be better to just move everything in here though.
	//It means we would need to use CompilationData whenever we ParseExpression in tests as well.
	/*TODO Consider pulling tokens and errors out when we do lexer lazy loading and the
	COMBINE ALL_PARSER_ERRORS and ALL_COMPILER_ERRORS since they are just combine in ParseStatement anyways.
	*/
	lexer : CodeLexer;
	binary_tree : BinaryTree;

	// expr : CodeExpression;
	all_code_statements : [..] CodeStatement;

	//TODO Could use MySimplePool with a few megabytes here since we are unlikely to have more than that per expression.
	//Could use Flat_Pool if we want more data and then free it at the end of compilation (or put it somewhere and reuse it).
	//TODO Could also allow resize in MySimplePool (maybe even with a flag)
	//NOTE If arrays get resized then we lose some memory but maybe that's fine. We can just increase the size
	//but if we have any wierd issues then maybe it's best to just use a Flat_Pool and reuse it between compilations.
	//This way does safeguard from over-adding data in any case.
	// expr_pool : MySimplePool;
	//This allocator/pool is reset after every expression during the main compilation phase.
	//It is also used in pre main passes and reset as needed there.
	expr_alloc : Allocator;
	//TODO Might be better to use these for safety to allow more data eventually in case of extremly long expression.
	//Currently we allow 8Mb in expr_pool which is around 1 million nodes
	//TODO MAYBE EVENTUALLY ONCE WE HAVE MULTIPLE COMPILATIONS we can just use a Flat_Pool for safety
	expr_pool : Flat_Pool;


	//TODO Can remove this if we don't use it anymore since we are using the expr allocator above now
	//reusable node array
	comma_node_array : [..] *BinaryNode;

	//TODO Maybe should hve a separate stack for functions and ifs. It depends if we allow function
	//declarations within an if statement. Otherwise all if statements are within function calls.
	//Maybe better to leave as is then since then we have the flexibility.

	//TODO Remove this not once we add.
	//TODO We could store scope ids in here now so we only have them in 1 place.

	//TODO FROM HERE ADD TESTS TO MAKE SURE SCOPE IS WORKING FOR CONTROL STATEMENTS AND INLINE STATEMENTS
	/*DOC : Scopes data is stored in all_scope_data and currently open scope ids are stored in open_scope_stack.
	This way all the data is in one place and then we can just peek(open_scope_stack) to get the current scope.
	ALSO all_scope_data is added sequentially so the scope_id should be fetchable as all_scope_data[scope_id] directly.
	*/
	// open_scope_stack : [..] ScopeData;
	open_scope_stack : [..] int;
	//TODO Sort this by function_id and start_instr_index
	//at the end of compilation just in case. it should be already
	all_scope_data : [..] ScopeData;
	all_control_fjmps : [..] ControlFjmps;
	// all_if_else_data : [..] IfElseData;
	all_if_data : [..] IfData;
	all_else_data : [..] ElseData;

	//Can use this for debugging and testing later and we just copy variable_stack to it directly after a function scope.
	//TODO How should we do constants?
	//TODO Sort this by scope_id at the end of compilation
	all_variables : [..] VariableData;
	//I think we only need a stack here since this can be cleared after every function.
	variable_data_stack : [..] VariableData;
	byte_offset_from_sbp : int;
	max_proc_offset_from_sbp : int;
	//We store this at the start of each expression so that we can reset to it if we need to to
	//assign variables for example and clear all the rvalues from the stack for things like 
	//complex expressions, operator overloads, functions and possibly other things.
	//TODO Maybe call it fixed_expr_byte_offset_from_sbp for clarity since I was confused when coming back to compiler
	expr_byte_offset_from_sbp : int;
	already_reset_stack : bool;


	reset_tano_stack : bool;


	comma_node_stack : [..] CommaNode;

	//TODO This is equivalent to all_function_declarations["main"].start_instr_index
	//so maybe we just keep it in there and don't have it here too?
	main_function_instr_index : int;

	//Need to keep those so we can verify names later even out of this function.
	//TODO This should likely be a Hash_Table so we can get all function overloads with the same
	//name and then simply check argument types to deal with functon overload calls which would be
	//much faster in any case for fetching.
	all_function_declarations : [..] FunctionDeclaration;
	all_function_arguments : [..] FunctionVariable;
	all_function_return_variables : [..] FunctionVariable;
	//TODO Can possibly make this just pointers
	//TODO This should just be id, not pointers in case it grows and then we would be sadge
	//Although this would just 1 value if we don't allow functions inside other functions
	//So consider that if we ever don't allow that.
	//TODO If we don't allow functions inside functions, then we can just make this be current_function_id
	function_stack : [..] int; //TODO Can likely make this a smaller type, maybe with just ids

	//TODO We are using this to update function calls in case we declare the function after the call
	//but maybe we can generalize this with out of order instructions for things like constants
	all_out_of_order_instrs : [..] OutOfOrderInstr;

	//Struct declaration data
	current_struct_decl_id : int;
	current_struct_info : *TypeInfoStruct;
	create_struct_members : [..] TypeInfoStructMember;
	//TODO Maybe we should put this in TypeInfoStruct instead for each struct and just
	//create the array on the second pass since it happens all in 1 go anyways.
	// all_type_info_struct_members : [..] *TypeInfoStructMember;

	//TODO Could make an EnumDeclarationData struct if that is better here and same for struct	
	create_enum_names : [..] string;
	create_enum_values : [..] int;
	create_enum_with_value : [..] bool;


	all_node_to_instruction : [..] NodeToInstruction;

	//TODO Can likely clear these after processing each line
	//TODO Do we still need all_node_values, can we just use all_code_ir_values?
	all_node_values : [..] NodeValue;
	all_code_ir_values : [..] CodeIRValue;

	all_music_instructions : [..] MusicInstruction;

	all_multi_return_memory_ops : [..] MultiReturnMemoryOperand;
	multi_return_type_info_proc : *TypeInfoProcedure;

	current_reg_num : int;
	all_registers : [..] RegisterData;

	//TODO We can just pop these off when generating instructions in case we have inline multiple for loops
	all_for_loop_data : [..] ForLoopData;

	found_loop_first_instr : bool;
	loop_first_instr_index : int;

	comp_level : CompilationLevel;

	non_stack_reg : [] RegDef;

	//TODO Can likely remove this altogether since we likely wont use expressions at all in asm anymore.
	// all_music_operand_expressions : [..] AssemblyIRValue;

	//TODO These should be generated with a function so we can put an assert in for debug build 
	comp_errors : CompilationErrors;

	//TODO Eventually type info can have its own pool and allocator if needed
	// type_info_pool : Flat_Pool;
	using all_type_info : *AllTypeInfo;

	all_directive_type_names : [..] DirectiveTypeName;

	//TODO We could put import and load in the same array to make sure we don't take in same files
	//but import would also keep track of dependencies to check for cyclical dependencies.
	//TODO RENAME Maybe we should just call this CompilerFiles since we set the main file in here
	//and also eventually will likely set imports in here
	all_directive_load_files : [..] DirectiveLoadFile;
	load_index : int;

	constant_memory : [..] u8;

	//TODO Do we even need this? I Guess if we don't want debug info but will that complicate the code...
	compilation_mode : CompilationMode;
	//TODO This is probably a good canidate for indexing or binary search
	//since it will not change unless we compile. Maybe even indexing is better
	//so we can fetch directly based on line_number or asm_index range.
	all_debug_lines : [..] DebugLine;


	disassembly : string;
	disassembly_loc : [] string;
}

/*TODO RIGHT NOW THE POINTERS IN THESE STRUCTS ARE BROKEN ONCE ARRAY_SIZE >= 8. I think the better way to do this
is just assign memory for types NOT IN AN ARRAY and just put a pointer in the array so that the array does not change.
Then if need types after copmilation is finished we can make a clean array of all the types without worrying about adding later.
In particular, TypeInfoPointer and TypeInfoArray really benefit from pointres due to recursion.
Also TypeInfoStructMember for member and also maybe we could put pointer to struct_info instead of id like we have now.
We could also just put [] TypeInfoStructMember like in jai since we will parse the sequentially in the struct declaration.

IF WE WANTED TO STORE TYPE INFO AT RUNTIME then we would use a separate allocator for types to have it all in the same
place and we would go over it at the end and store in such a way that it would be directly copyable to ram.
I think runtime type info would be the same as constand data and store in the same place probably at the start of ram
before the stack and the heap. Then we could access it by pointer in memory when used.
SO WE WOULD STORE A SEQUENCE OF BYTES THAT CONTAINS CONSTANTS AND TYPE INFO AND THEN COPY THAT AT THE START OF
EXECUTION INTO RAM BEFORE EVERYTHING ELSE.
*/
AllTypeInfo :: struct {
	//NOTE : CreateAllTypeInfo creates this in memory so these are stored there in memory and not on the stack somewhere.
	//I don't think this exists, only as a pointer, so we make the size 0.
	void_type_info := TypeInfo.{TypeInfoTag.VOID,0};
	//TODO Should we store these in an array or like this? Like these feels more like a base type.
	//TODO We could store all *TypeInfo in an array for easy access for struct members for example if needed.
	int_type_info := TypeInfo.{TypeInfoTag.INTEGER,8};
	float_type_info := TypeInfo.{TypeInfoTag.FLOAT,8};
	bool_type_info := TypeInfo.{TypeInfoTag.BOOL,8};
	// string_type_info := TypeInfo.{TypeInfoTag.STRING,16};
	string_type_info : TypeInfoStruct;

	// tano_struct_info := TypeInfo.{TypeInfoTag.TANO,size_of(tano)};

	//Void pointer is stored in all_type_info_pointer
	void_pointer_type_info : *TypeInfoPointer;
	all_type_info_pointer : [..] *TypeInfoPointer;

	all_type_info_array : [..] *TypeInfoArray;

	//Keeping this explicitly separate so it does not overlap with other created structs. I am not sure this 
	//is the best way to do it but for now it's ok. Struct members are still in the array so the compiler can
	//access them as it normally does.
	//This way does not overlap because we use it internally but if someone creates a struct_member with the same
	//name, then they can use it and this is will not be accessed all_type_info_struct. Maybe that is best.
	//TODO We can change this though if it makes sense to put these in all_type_info_struct for some other reason.
	array_view_struct_info : TypeInfoStruct;
	resizable_array_struct_info : TypeInfoStruct;
	// string_struct_info : TypeInfoStruct;
	//If we allow using this as a struct then could add it to the array and just have a pointer here.
	music_unit_info : TypeInfoStruct; 
	//TODO Maybe these should be put in all_type_info_struct to avoid name overlaps.
	tano_struct_info : TypeInfoStruct;
	neume_struct_info : TypeInfoStruct;
	all_type_info_struct : [..] *TypeInfoStruct;
	all_type_info_enum : [..] *TypeInfoEnum;

	all_type_info_procedure : [..] *TypeInfoProcedure;
}

CreateAllTypeInfo :: inline (cd : *CompilationData) {
	//TODO We can use an allocator just for type_info so that it's all close to each other in memory
	//and then we can reuse it more easily if needed.
	// type_info_pool : Flat_Pool;
	// cd.ti_alloc = Allocator.{flat_pool_allocator_proc, *type_info_pool};
	// ti_alloc.data = *type_info_pool;
	// init(*cd.ti_alloc, Megabytes(25));

	/*IMPORTANT : This needs to be explicitly created in memory so the pointers dont change
	since we use the type_info pointers in the type_info data model. Since it is discarded after
	compilation it should be fine overall. We embed all the instructions with the type_info at compile time.
	*/
	cd.all_type_info = New(AllTypeInfo,, context.allocator);

	//TODO We could set a specific allocator for type_info if we have to reuse it later
	#insert #run SetResizableArrays(AllTypeInfo, "cd.%.allocator = context.allocator;\n");

	//We add base type pointers here since they are not in an array, so we create them immediately so that they exist.
	//Struct pointers are created on the fly whenever we find them at compile-time.

	cd.void_pointer_type_info = CreateTypeInfoPointer(*cd.void_type_info, cd);
	//TODO Can remove these assignments if we don't use them.
	int_pointer : *TypeInfoPointer = CreateTypeInfoPointer(*cd.int_type_info, cd);
	float_pointer : *TypeInfoPointer = CreateTypeInfoPointer(*cd.float_type_info, cd);
	//TODO Can update this to 1 byte if we implement single byte
	bool_pointer : *TypeInfoPointer = CreateTypeInfoPointer(*cd.bool_type_info, cd);

	//TODO Should this be in struct array or a completely separate struct since it has very different functionality?
	// string_struct : *TypeInfoStruct = *cd.string_struct_info;
	//TODO Maybe we could replace the name string_type_info with string_struct_info for clarity?
	string_struct : *TypeInfoStruct = *cd.string_type_info;
	string_struct.type_enum = TypeInfoTag.STRING;
	string_struct.runtime_size = 16;
	string_struct.name = "NewString";
	string_struct.struct_members = NewArray(1, TypeInfoStructMember);
	string_struct.struct_members[0] = TypeInfoStructMember.{"count", *cd.int_type_info, 0};
	//TODO we could make data just be an integer since we don't have *u8 to access bytes. that way we can still technically access bytes.
	//BUT then we cant use string.data as an array... Maybe we just leave it out for now and if we add a byte type later then
	//we can set this to a byte pointer and use it normally.
	// string_data : *TypeInfoStructMember = CreateTypeInfoStructMember(string_struct.id, "data", cd.void_pointer_type_info, 8, cd);
	string_pointer : *TypeInfoPointer = CreateTypeInfoPointer(*cd.string_type_info, cd);


	//TODO Do we create a pointer for this or for tano_struct_info?
	tano_struct : *TypeInfoStruct = *cd.tano_struct_info;
	//TODO Maybe this should just be a STRUCT. We would have to use the type pointer then to check in the compiler
	tano_struct.type_enum = TypeInfoTag.TANO;
	tano_struct.runtime_size = size_of(tano);
	tano_struct.name = "tano";
	tano_struct.struct_members = NewArray(5, TypeInfoStructMember);
	tano_struct.struct_members[0] = .{"row_start", *cd.int_type_info, 0};
	tano_struct.struct_members[1] = .{"row_end", *cd.int_type_info, 8};
	tano_struct.struct_members[2] = .{"x_start", *cd.float_type_info, 16};
	tano_struct.struct_members[3] = .{"x_end", *cd.float_type_info, 24};
	//TODO should we rename to mspace_index?
	tano_struct.struct_members[4] = .{"mspace_start", *cd.int_type_info, 32};
	// CreateTypeInfoStructMember(tano_struct.id, "mspace_end", *cd.int_type_info, 40, cd);

	CreateTypeInfoPointer(*cd.tano_struct_info, cd);


	neume_struct : *TypeInfoStruct = *cd.neume_struct_info;
	//TODO Maybe this should just be a STRUCT. We would have to use the type pointer then to check in the compiler
	neume_struct.type_enum = TypeInfoTag.NEUME;
	neume_struct.runtime_size = 8*4;
	neume_struct.name = "neume";
	neume_struct.struct_members = NewArray(4, TypeInfoStructMember);
	neume_struct.struct_members[0] = .{"svara", *cd.float_type_info, 0};
	neume_struct.struct_members[1] = .{"row", *cd.int_type_info, 8};
	neume_struct.struct_members[2] = .{"x_start", *cd.float_type_info, 16};
	neume_struct.struct_members[3] = .{"x_end", *cd.float_type_info, 24};

	CreateTypeInfoPointer(*cd.neume_struct_info, cd);



	//TODO Should this be in struct array or a completely separate struct since it has very different functionality?
	//Should it even be a struct or different enum type altogether?
	//TODO PRobably done even want this is a struct and just make a "mus", "muse" or "tano" base type
	//and then hardcode accessing it with "x" and "row" or can also allow "y" for row.
	music_unit : *TypeInfoStruct = *cd.music_unit_info;
	music_unit.type_enum = TypeInfoTag.STRUCT;
	music_unit.runtime_size = 8;
	music_unit.name = "MusicUnit";
	music_unit.struct_members = NewArray(1, TypeInfoStructMember);
	music_unit.struct_members[0] = .{"count", *cd.int_type_info, 0};


   //TODO This pointer will likely have 2 values (row and x)
   //So should it just be a special struct type then? Should we just add it on the fly?
   //Maybe best to create its own struct type or have the same as tano[x][y] and then you can
   //just call either this pointer.x or pointer.row OR tano[row][x].x and tano[row][x].row.
   //This allows us to rename any music unit so we can start from there as well.
   //Have to thinkg about it when I do it with this relative offset, maybe different structs is best.
   //THIS SHOULD LIKELY BE A POINTER TO A STRUCT AND THAT STRUCT CAN HAVE X, ROW and COUNT and so
   //this size would just be 8 when we use it and the size of the struct would be 16 or 24
	CreateTypeInfoPointer(cast(*TypeInfo) music_unit, cd, size=16);


	//TODO How do we want to add this with the procedure name?
	// main_proc : *TypeInfoProcedure = New(TypeInfoProcedure,,context.allocator);
	// main_proc.type_enum = TypeInfoTag.PROCEDURE;


	/*Internal compiler structs
	  I am hardcoding these... we could parse it in through a Preload file with an code struct like in jai.
	  This seems fine though since it is only ever accessed by in the code through the array syntax.
	*/
	//Array View struct and Array View struct pointer
	array_view : *TypeInfoStruct = *cd.array_view_struct_info;
	array_view.type_enum = TypeInfoTag.STRUCT;
	array_view.runtime_size = 2*8;
	array_view.name = "ArrayView";
	/*TODO FROM HERE I WANT TO PUT DATA FIRST SO WE CAN ACCESS THE VARIABLE FIRST LIKE AN ARRAY HERE WHICH I THINK IS 
	BEST FOR THINGS LIKE DEBUGGING LATER I BELIEVE IT MAKES MORE SENSE TO HAVE THE DATA POINTER FIRST.
	Will need to update some code and tests to account for this so better to do it sooner rather than later
	ACTUALLY THis is probably fine, I'll leave the note here but basically there is no technical difference.
	I copied jai which seems to have copied C from main(arg_c)
	*/
	array_view.struct_members = NewArray(2, TypeInfoStructMember);
	array_view.struct_members[0] = .{"count", *cd.int_type_info, 0};
	array_view.struct_members[1] = .{"data", cd.void_pointer_type_info, 8};

	//TODO Do we really need a pointer to this internal type?
	CreateTypeInfoPointer(cast(*TypeInfo) array_view, cd);
	

	//Resizable Array struct and Resizable Array struct pointer
	//TODO Do we need a pointer to this. Maybe we can remove the one for ArrayView as well.
	resizable_array : *TypeInfoStruct = *cd.resizable_array_struct_info;
	resizable_array.type_enum = TypeInfoTag.STRUCT;
	resizable_array.runtime_size = 4*8;
	resizable_array.name = "ResizableArray";
	//Order here matters since we assume this when creating this at compile-time so try not to change it.
	//IF we do it is used in KEYWORD_NEW_RESIZABLE_ARRAY
	resizable_array.struct_members = NewArray(4, TypeInfoStructMember);
	resizable_array.struct_members[0] = .{"count", *cd.int_type_info, 0};
	resizable_array.struct_members[1] = .{"data", cd.void_pointer_type_info, 8};
	resizable_array.struct_members[2] = .{"allocated", *cd.int_type_info, 16};
	resizable_array.struct_members[3] = .{"element_size", *cd.int_type_info, 24};
}

GetArrayType :: inline (
	//TODO Could just pass in all_type_info_array if that seems better
	cd : *CompilationData, 
	element_type : *TypeInfo, 
	array_type : ArrayInfoType,
	array_count : int = -1) 
-> *TypeInfoArray, found : bool
{
	for cd.all_type_info_array {
		if it.element_type == element_type && 
		   it.array_count == array_count &&
		   it.array_type == array_type
	   {
	   	return it, true;
	   }
	}
	return null, false;
}

GetOrCreateArrayType :: inline (
	//TODO Could just pass in all_type_info_array if that seems better
	cd : *CompilationData, 
	element_type : *TypeInfo, 
	array_type : ArrayInfoType,
	array_count : int = -1) 
-> *TypeInfoArray 
{
	a_type, found_type := GetArrayType(cd, element_type, array_type, array_count);
	if found_type return a_type;

	//TODO Could make this into a function to create array types unless this is the only place we do it
	array_info : *TypeInfoArray = New(TypeInfoArray,,context.allocator);
	array_add(*cd.all_type_info_array, array_info);
	array_info.info.type_enum = TypeInfoTag.ARRAY;
	array_info.element_type = element_type;
	array_info.array_type = array_type;
	array_info.array_count = array_count;
	if array_type == {
	case .VIEW;
		array_info.info.runtime_size = cd.array_view_struct_info.runtime_size;
	case .RESIZABLE;
		array_info.info.runtime_size = cd.resizable_array_struct_info.runtime_size;
	case .FIXED;
		array_info.info.runtime_size = array_count * array_info.element_type.runtime_size;
	}
	return array_info;
}

CompileIDs :: struct {
	next_scope_id : int;
	next_function_declaration_id : int;
	next_var_declaration_id : int;
	next_struct_decl_id : int;
}

//TODO I think the all_music_instructions can have its own allocator so we can just copy the array
//over afterwards without copying the memory.
//ALSO debugging info can have its own allocator so we can keep it afterwards.
MakeCompilationData :: inline () -> *CompilationData {
	cd := New(CompilationData,, context.allocator);

	#insert #run SetResizableArrays(CompilationData, "cd.%.allocator = context.allocator;\n");

	InitCompilationErrors(*cd.comp_errors);

	//TODO Could increase size or use Flat_Pool if this is not enough.
	//This currently allows for around 1 million nodes for a comma node array for example.
	// InitMySimplePool(*cd.expr_pool, Megabytes(8));
	init(*cd.expr_pool, Megabytes(8));
	cd.expr_alloc.data = *cd.expr_pool;
	cd.expr_alloc.proc = flat_pool_allocator_proc;
	// cd.expr_alloc.proc = MySimpleAllocProc; 

	for reg_name, reg_index : reg_def_names {
		reg_data : *RegisterData = array_add(*cd.all_registers);
		reg_data.* = RegisterData.{reg_index,reg_name,false,0};
		if reg_index >= non_stack_start_reg_index {
			reg_data.is_available = true;
		}
	}

	cd.current_reg_num = cd.all_registers.count;

	cd.lexer = MakeCodeLexer();
	//TODO Note sure we will use this but just in case
	cd.binary_tree.nodes.allocator = context.allocator;

	cd.non_stack_reg = array_view(reg_def_enums, non_stack_start_reg_index);

	CreateAllTypeInfo(cd);

	return cd;
}

RegisterData :: struct {
	//TODO Should we have a separate for int and float?
	// reg_def : RegDef;
	//TODO Should we just have RegDef here or also reg_index? 
	//What if we want to allow their own register creation with new names?
	reg_index : int;
	name : string;
	is_available : bool;
	int_value : int;
}

//TODO Likely to get next available memory and then eithe return register or a stack value...
//Not sure yet, need to test for cases where we go over the max register count.
OLDGetNextAvailableRegister :: inline (cd : *CompilationData) -> *RegisterData {
	//TODO Should only cycle through non-stack reg here
	for * cd.all_registers if it.is_available {
		it.is_available = false; //TODO We could do this outside but then it's not as consistent.
		return it;
	}
	//TODO Remove this once we know we have enough registers for calculations.
	//I think we only need 3 in general for binary ops. Can add more for optimizations
	//maybe or for other specific uses.
	assert(false, "NOT ENOUGH REGISTERS!\n");
	return null;
}

NewGetNextAvailableReg :: inline (cd : *CompilationData) -> *RegisterData {
	for reusable_start_reg_index..reusable_end_reg_index {
		if cd.all_registers[it].is_available {
			cd.all_registers[it].is_available = false; //TODO We could do this outside but then it's not as consistent.
			return *cd.all_registers[it];
		}
	}
	//TODO Remove this once we know we have enough registers for calculations.
	//I think we only need 3 in general for binary ops. Can add more for optimizations
	//maybe or for other specific uses.
	assert(false, "NOT ENOUGH REGISTERS!\n");
	return null;
}

CodeIRType :: enum u8 {
	NOT_PROCESSED;
	//TODO Should probably replace STACK_VARIABLE with MEMORY_VARIABLE since we may use
	//the same thing for heap and stack and then just use whatever is in the op.
	STACK_VARIABLE;
	REGISTER;

	UNARY_OP;
	BINARY_OP;
	INLINE_STATEMENTS;
	UNKNOWN_IDENT;

	//TODO Should this be INTEGER_CONSTANT and FLOAT_CONSTANT
	INTEGER;
	FLOAT;
	//TODO We could just call this STRING but just to make it clear.
	STRING_LITERAL;

	DATA_TYPE_INFO;

	TANO_RANGE;
	TANO_COUNT;

	DATA_IR_MUNIT;
	//TODO Do we need this or can just check the children directly?
	// DATA_MUNIT_BRACKET1;
	// DATA_MUNIT_BRACKET2;
	//Was using this as separate array type from parser level, 
	//but we can know this by DATA_TYPE_INFO with "[" as token value
	// ARRAY_TYPE;

	UNINITIALIZED_VARIABLE;
	VARIABLE_DECLARATION;

	FUNCTION_NAME;
	FUNCTION;
	FUNCTION_VARIABLE;
	FUNCTION_INPUT_VAR;
	FUNCTION_RETURN_VAR;

	//CORE_IR_VALUE_LIST is for when we cannot see the values in code but still need to accumulate on 1 node.
	//eg multiple return values like x,y := foo(z);
	CODE_IR_VALUE_LIST;
	//NODE_VALUE_LIST is for when we can see the values in the code.
	//eg int.[0,1,2] or .{f,y} or foo(x,y) (input variables)
	NODE_VALUE_LIST;
}

DataType :: enum u8 {
	INTEGER;
	FLOAT;
	BOOL;
	STRUCT;
	POINTER;
}

CodeIR :: struct {
	ir_type : CodeIRType;
	//TODO should we make this #as to reduce some of the words everywhere
	//TODO Why not just move the code in here directly...
	//I think we can now just have to see if all_code_ir_values is unused and comment out the code.
	using ir_value : CodeIRValue;
}

/*Currently using these for things like FIXED_MEMORY and MUSIC_MEMORY so we know what to use
as we move the data and memory up the tree.

TODO Technically we can replace op in here with *MusicOperand since we often times just
pass up a node and then just create new ones in memory when needed.
This is 8+8+3 bytes reduce to 8 bytes. So it would be around 2x less memory but 
maybe not worth it for now to avoid pointer or other issues like tree consistency
and having to store the ops in a different place than the nodes themselves.
*/
CodeIRValue :: struct {
	//TODO Could add a node_id here as well if needed for clarity and separation.
	//NOTE currently using ir_data_id for variable id, struct_type id AND likely tano mspace_index.
	ir_data_id : int;
	using op : MusicOperand;
	//Can't call this type_info because it is a keyword in jai.
	t_info : *TypeInfo;

	//TODO possibly collapse these to individual bits eventually since 3 of them or just 2 options
	node_op_type : NodeOpType;
	code_value_type : CodeValueType;
	node_var_type : NodeVarType;
	on_tano_stack : bool;
}
NodeOpType :: enum u8 {
	DEFAULT;
	//TODO Should we name this something else like with dereference or is that confusing?
	//TEMP_ADDRESS_IN_MEMORY or TEMP_ADDRESS_ON_STACK
	ADDRESS_IN_MEMORY;
}
/*
R_VALUE can only be on right and is neither assignable or declarable.
L_VALUE can be on left or right and is assignable and declarable.
FOR OTHER CASES we use NodeVarType (eg for pointers *x and relative tanos tano(0,0))
*/
CodeValueType :: enum u8 {
	NONE;
	R_VALUE; //Value can only be on right (eg function calls...)
	L_VALUE; //Value can be on left and right so it is assignable/declarable (eg struct members...)
}
/*Doc : Usually L_VALUE is assignable or declarable but in the case of 
- relative tano t0(0,0), those are assignable but not declarable since we can t0(0,0) = t1 BUT NOT t0(0,0) := t1
since the t0(0,0) is temporarily on the stack BUT WE CAN DO t0 := t1 to declare a new tano.
*/
// NodeVarType :: enum_flags u8 {
NodeVarType :: enum u8 {
	//0 here is neither and implies we use CodeValueType rules
	NONE; //This implies that we use CodeValueType R_VALUE and L_VALUE normal rules
	// NOT_ASSIGNABLE;
	NOT_DECLARABLE;
}
//TODO What should we name this? GetValueOp
//TODO Maybe we can make set_reg_available = true as default since we store everything on the stack now
//OR MAYBE it should not have a default so we remember to set it or not
GetValueOpReuseReg :: inline (
	node : *BinaryNode, cd : *CompilationData, 
	$set_reg_available : bool = false) 
-> MusicOperand 
{
	#if 1 {
	reg := RegDef.r0;
	if node.code_ir.node_op_type == {
	case .ADDRESS_IN_MEMORY;
		reg = NewGetOrReuseReg(node, cd, set_reg_available);
	}
	//case .DEFAULT;
	return GetValueOp(node, cd, reg);
	} else {
	if node.code_ir.node_op_type == {
	case .ADDRESS_IN_MEMORY;
		//TODO Should this always be a pointer or should we leave the type that it is
		//since we are getting the value here
		//Could use .r0 here...
		//TODO Since we store everything on the stack now can we set this to be free immediately?
		reg := NewGetOrReuseReg(node, cd, set_reg_available);
		CreateMInstr(.mov, RegMem(reg), node.code_ir.op, Imm(8), d=cd);
		return RamMem(reg);
	}
	//case .DEFAULT;
	return node.code_ir.op;
	}
}
//This does not make the register unavailable which seems better overall than above and to forget about available
//and never use registers outside a specific operation and always set extra variables on the stack as a general rule.
GetValueOp :: inline (
	node : *BinaryNode, cd : *CompilationData, 
	suggested_reg := RegDef.r0) 
-> MusicOperand 
{
	if node.code_ir.node_op_type == {
	case .ADDRESS_IN_MEMORY;
		CreateMInstr(.mov, RegMem(suggested_reg), node.code_ir.op, Imm(cd.void_pointer_type_info.runtime_size), d=cd);
		return RamMem(suggested_reg);
	}
	return node.code_ir.op;
}

//DOC : Use this to specifically set registers for things like RamArray or other conveniences
SetAddressReg :: inline (node : *BinaryNode, reg : RegDef, cd : *CompilationData) {
	SetAddressNode(node, RegMem(reg), cd);
}
SetAddressNode :: inline (node : *BinaryNode, address_op : MusicOperand, cd : *CompilationData) {
	assert(node != null && address_op.operand_type != .NONE);
	if node.code_ir.node_op_type == {
	case .ADDRESS_IN_MEMORY;
		//Address is already in memory at the node op so we just return it.
		// address_op.* = node.code_ir.op;
		CreateMInstr(.mov, address_op, node.code_ir.op, Imm(cd.void_pointer_type_info.runtime_size), d=cd);
	case;
		SetAddressOp(address_op, node.code_ir.op, cd);
	}
}
SetAddressOp :: inline (set_op : MusicOperand, get_op : MusicOperand, cd : *CompilationData) {
	op_0, op_1 := GetMemoryAddressAsOperands(get_op);
	CreateMInstr(.add, set_op, op_0, op_1, d=cd);	
}
//TODO I think we can use this to get addresses in a more systematic way to remove confusion from reference/dereference.
GetAddressOp :: inline (node : *BinaryNode, cd : *CompilationData, suggested_op : MusicOperand) -> MusicOperand {
	assert(node != null && suggested_op.operand_type != .NONE);
	address_op : MusicOperand;
	if node.code_ir.node_op_type == {
	case .ADDRESS_IN_MEMORY;
		//Address is already in memory at the node op so we just return it.
		address_op = node.code_ir.op;
	case;
		//TODO We could grab a reusable register by default but I think setting it on the function call
		//makes it clearer and makes me thing about it more whenever we need to get an address.
		address_op = suggested_op;
		op_0, op_1 := GetMemoryAddressAsOperands(node.code_ir.op);
		CreateMInstr(.add, address_op, op_0, op_1, d=cd);
	}
	return address_op;
}
GetArrayAddressOp :: inline (
	node : *BinaryNode, 
	set_reg : RegDef,
	address_op : MusicOperand,
	cd : *CompilationData,
	$with_index : bool = true,
	index_op : MusicOperand = .{})
{
	assert(node.code_ir.t_info.type_enum == .ARRAY);
	array_info := cast(*TypeInfoArray) node.code_ir.t_info;
	SetAddressNode(node, address_op, cd);
	if array_info.array_type == .VIEW {
		//data address comes 8 bytes after count in array struct info
		CreateMInstr(.add, RegMem(set_reg), address_op, Imm(8), d=cd);
		CreateMInstr(.mov, address_op, RamMem(set_reg), Imm(8), d=cd);
	}
	#if with_index {
	//Store the address of the array position by the index * element_size
	CreateMInstr(.mul, RegMem(set_reg), index_op, Imm(array_info.element_type.runtime_size), d=cd);
	CreateMInstr(.add, address_op, address_op, RegMem(set_reg), d=cd);
	}
}
GetArrayValueOp :: inline (
	node : *BinaryNode,
	set_reg : RegDef,
	//address_op separate from value_op otherwise debugger would have incorrect value if setting the address in the value_op temporarily
	address_op : MusicOperand,
	value_op : MusicOperand,
	index_op : MusicOperand,
	cd : *CompilationData)
{
	assert(node.code_ir.t_info.type_enum == .ARRAY);
	array_info := cast(*TypeInfoArray) node.code_ir.t_info;
	GetArrayAddressOp(node, set_reg, address_op, cd, true, index_op);
	//Get the value at the above index position
	CreateMInstr(.mov, RegMem(set_reg), address_op, Imm(cd.void_pointer_type_info.runtime_size), d=cd);
	CreateMInstr(.mov, value_op, RamMem(set_reg), Imm(array_info.element_type.runtime_size), d=cd);		
}

//TODO We could pass array_info into ArrayToRamArrayOp but since it's just a cast we don't for now.
ArrayToRamArrayOp :: inline (
	array_node : *BinaryNode, 
	cd : *CompilationData,
	reg_0 := RegDef.ax,
	reg_1 := RegDef.bx) 
-> MusicOperand 
{
	ram_array_op : MusicOperand;
	array_info := cast(*TypeInfoArray) array_node.code_ir.t_info;
	if array_info.array_type == .FIXED {
		SetAddressReg(array_node, reg_0, cd);
		ram_array_op = RamArray(array_info.array_count, reg_0);
	} else {
		count_op := GetValueOp(array_node, cd);
		CreateMInstr(.mov, RegMem(reg_0), count_op, Imm(cd.int_type_info.runtime_size), d=cd);
		data_op := AddOperandOffset(cd.int_type_info.runtime_size, count_op);
		CreateMInstr(.mov, RegMem(reg_1), data_op, Imm(cd.void_pointer_type_info.runtime_size), d=cd);
		ram_array_op = RamArray(reg_0, reg_1);
	}
	return ram_array_op;
}


//TODO can remove this array if we don't use it.
type_info_names : [] string : #run enum_names(TypeInfoTag);
TypeInfoTag :: enum u8 {
	INTEGER;
	FLOAT;
	BOOL;
	STRING;
	POINTER;
	STRUCT;
	ENUM;
	ARRAY;
	PROCEDURE;
	VOID;

	TANO;
	NEUME;
	//TODO Maybe just have M_UNIT since M_ROW can just be looped over.
	//What about M_SECTION for mov music_memory with mov_size? Should that be a type or an intrinsic.
	//OR just us #asm and can do it directly for efficiency.
	//TODO Change this name to TANO. Not sure we need row or just make struct or TANO_ROW
	//RENAME to MUSIC_MEMORY. then we allow it to be various strings
	//mrow, mus, tano, tmus...
	MUSIC_UNIT;
	// MUSIC_ROW;
}

TypeInfo :: struct {
	type_enum : TypeInfoTag;
	//TODO Do we need this here?
	runtime_size : int;
}

TypeInfoPointer :: struct {
	using #as info : TypeInfo;
	//TODO Should we replace this with id to avoid pointer issues?
	//If we used id, then we would need a type here to know what the next one is.
	//In jai this is what it looks like to the user but not necessarily in the compiler.
	pointer_to : *TypeInfo;
}

TypeInfoStruct :: struct {
   using #as info: TypeInfo;
   name: string;
   //TODO Maybe I can put this back and remove id if we reuse it for code-level type_info.
   //TODO This should likely be replaced with struct_id in StructMember
   struct_members : [] TypeInfoStructMember;
   //TODO This is used to skip over the struct on the compiler second pass since we already
   //processed it on first pass. Maybe I can put it somewhere else... convenient here but
   //it's only used there so likely attack token index to an the struct_id on a different
   //struct and only use it there, especially if we allow type_info at the code level.
   last_token_index : int;
}

TypeInfoStructMember :: struct {
   name: string;
	//TODO Should we replace this with id to avoid pointer issues?
   t_info: *TypeInfo;
   offset_in_bytes: s64;
}

TypeInfoEnum :: struct {
	using #as info: TypeInfo;
	name : string;
	names : [] string;
	values : [] int;
	// internal_type: *Type_Info_Integer;
	last_token_index : int;
}
EnumIndexByValue :: inline (
	t_info_enum : *TypeInfoEnum,
	value : int) 
-> int, found : bool
{
	for t_info_enum.values if it == value {
		return it_index, true;
	}
	return -1, false;
}

/*Note : FIXED_ARRAY size may need to be known at compile-time otherwise the stack will be inconsistent.
This is why they require constants and not variables because then the stack could change size on
a loop for example which would mess up variable debug info for example because then other things
could be in the wrong place... this happens on the heap so basically debug info needs to associate variable
names to specific line to know what to update per line.
*/
TypeInfoArray :: struct {
   using #as info: TypeInfo;
	element_type: *TypeInfo;
   array_type: ArrayInfoType;
   array_count: s64;        // -1 unless this array is is of a known compile-time size, i.e. array_type is FIXED.
}
ArrayInfoType :: enum u8 {
  FIXED     :: 0;
  VIEW      :: 1;
  RESIZABLE :: 2;
}
IsArrayInfoType :: inline (array_type : ArrayInfoType, t_info : *TypeInfo) -> bool {
	is_array_type : bool = t_info != null && t_info.type_enum == .ARRAY && 
		(cast(*TypeInfoArray) t_info).array_type == array_type;
	return is_array_type;
}

//NOTE : No name here since we can have a function pointer which would not have a name.
TypeInfoProcedure :: struct {
	using #as info : TypeInfo;
	//This is ok as an array because we will add them right here in memory when parsing the function declaration
   argument_types: [] *TypeInfo;
   return_types:   [] *TypeInfo;
}
CreateTypeInfoProc :: inline (
	arg_types : [] *TypeInfo,
	return_types : [] *TypeInfo,
	all_type_info_procedure : *[..] *TypeInfoProcedure) 
-> *TypeInfoProcedure
{
	//Create this separately so the pointer stays in the same place forever
	t_info_proc : *TypeInfoProcedure = New(TypeInfoProcedure,,context.allocator);
	t_info_proc.type_enum = TypeInfoTag.PROCEDURE;
	//I think this will just be a function pointer so 64-bit pointer value...?
	t_info_proc.runtime_size = 8;
	//Note : Explicitly putting context.allocator here to show since we store the other ones in expr_alloc for now
   t_info_proc.argument_types = array_copy(arg_types,,context.allocator);
   t_info_proc.return_types = array_copy(return_types,,context.allocator);
	array_add(all_type_info_procedure, t_info_proc);
	return t_info_proc;
}
GetTypeInfoProc :: inline (
	arg_types : [] *TypeInfo, 
	return_types : [] *TypeInfo,
	all_type_info_procedure : [] *TypeInfoProcedure) 
-> *TypeInfoProcedure, found_t_info_proc : bool
{
	for proc_type : all_type_info_procedure {
		if proc_type.argument_types.count != arg_types.count continue;
		for proc_type.argument_types if it != arg_types[it_index] {
			continue proc_type;
		}
		if proc_type.return_types.count != return_types.count continue;
		for proc_type.return_types if it != return_types[it_index] {
			continue proc_type;
		}
		return proc_type, true;
	}					
	return null, false;
}
GetOrCreateTypeInfoProc :: inline (
	arg_types : [] *TypeInfo,
	return_types : [] *TypeInfo,
	all_type_info_procedure : *[..] *TypeInfoProcedure) 
-> *TypeInfoProcedure
{
	t_info_proc, found_t_info_proc := GetTypeInfoProc(arg_types, return_types, all_type_info_procedure.*);
	if !found_t_info_proc {
		t_info_proc = CreateTypeInfoProc(arg_types, return_types, all_type_info_procedure);
	}
	return t_info_proc;
}

/*REMINDER : In general we should be using this function to check node types so that we can check with function names
as well to resolve the types of functions that have overloads.

NOTE : We would still need to set the node op properly given the funcion instr_index, so I am not sure this works fully.
*/
CheckNodeTypeInfo :: inline (node : *BinaryNode, check_type : *TypeInfo, cd : *CompilationData) -> bool {
	found_type : bool = false;
	if node.code_ir.ir_type == .FUNCTION_NAME {
		found_function_by_name_and_args : bool = false;
		for arg_fd : cd.all_function_declarations {
			if arg_fd.name == node.value.token_string &&
				cast(*TypeInfo) arg_fd.t_info_proc == check_type
			{
				found_type = true;
				break;
			}
		}
	}
	else if check_type == node.code_ir.t_info {
		found_type = true;
	}
	return found_type;
}

/*I am making Create functions for these so that we only need to change in 1 place when we update
the data model. For now we store them in context.allocator so that the pointers don't change but
later we may want them to have their own allocator so we can return them afterwards.

So for now we do New() so the pointer doesn't change and then array_add so that we can loop through them consistently.
It does make it slower since we have to access pointers everywhere but it avoids having pointer issues.
Not sure how else to do it with the pointers other than id but then id makes it tricky because we can't
see in the debugger and we have to fetch it everytime so maybe the efficiency comes out even in that case.

TODO For now there is a size variable in case for music unit pointers may be 2 integer values (x and row)
if we use a completely different type then we can remove it and just use 8 in general for pointers.
Most likely it should just be a struct and then we have pointer to struct so it remains consistent with the
rest of the data model.
*/
CreateTypeInfoPointer :: inline (pointer_to : *TypeInfo, cd : *CompilationData, size : int = 8) -> *TypeInfoPointer {
	new_p : *TypeInfoPointer = New(TypeInfoPointer,,context.allocator);
	array_add(*cd.all_type_info_pointer, new_p);

	new_p.type_enum = TypeInfoTag.POINTER;
	new_p.runtime_size = size;
	new_p.pointer_to = pointer_to;
	return new_p;
}

//TODO Can remove size = 8 here if we make MusicUnit data a struct and then just have a pointer to that struct
GetOrCreateTypeInfoPointer :: inline (pointer_to : *TypeInfo, cd : *CompilationData, size : int = 8) -> *TypeInfoPointer {
	t_info, found_t_info := GetTypeInfoPointer(pointer_to, cd);
	if !found_t_info {
		t_info = CreateTypeInfoPointer(pointer_to, cd, size);
	}
	return t_info;
}

GetTypeInfoPointer :: inline (pointer_to : *TypeInfo, cd : *CompilationData) -> *TypeInfoPointer, found_type : bool {
	for cd.all_type_info_pointer if it.pointer_to == pointer_to {
		return it, true;
	}	
	return null, false;
}


//TODO Eventually we may need to account for importing module names as well.
GetTypeInfoStructByName :: inline (name : string, all_type_info_struct : [] *TypeInfoStruct) -> *TypeInfoStruct, found : bool {
	for all_type_info_struct if it.name == name {
		return it, true;
	}
	return null, false;
}
//TODO Could do duck typing with anything with any struct with variable "name" here.
//TODO Eventually we may need to account for importing module names as well.
GetTypeInfoEnumByName :: inline (name : string, all_type_info_enum : [] *TypeInfoEnum) -> *TypeInfoEnum, found : bool {
	for all_type_info_enum if it.name == name {
		return it, true;
	}
	return null, false;
}
GetDirectiveTypeByName :: inline (name : string, all_directive_type_names : [] DirectiveTypeName) -> DirectiveTypeName, found : bool {
	for all_directive_type_names if it.name == name {
		return it, true;
	}
	return .{}, false;
}

//TODO Can remove this once we know the struct members in struct info is working well everywhere.
#if 0 {
CreateTypeInfoStructMember :: inline (
	struct_id : int, 
	name : string,
	t_info : *TypeInfo,
	offset_in_bytes : int,
	cd : *CompilationData) 
-> *TypeInfoStructMember 
{
	member : *TypeInfoStructMember = New(TypeInfoStructMember,,context.allocator);
	array_add(*cd.all_type_info_struct_members, member);

	member.struct_id = struct_id;
   member.name = name;
   member.t_info = t_info;
   member.offset_in_bytes = offset_in_bytes;

   array_add(*cd.create_struct_members, member.*);

	return member;
}
GetStructMemberFromAll :: inline (
	t_info : *TypeInfo, 
	member_name : string,
	all_type_info_struct_members : [] *TypeInfoStructMember) 
-> *TypeInfoStructMember, found_member_info : bool 
{
	//TODO Could make a constant array for this and reuse it everywhere.
	assert(AllOrEquals(t_info.type_enum, STRUCT_TYPE_INTERNAL));
	struct_info := cast(*TypeInfoStruct) t_info;
	tism, found := GetStructMemberFromAll(struct_info.id, member_name, all_type_info_struct_members);
	return tism, found;
}
GetStructMemberFromAll :: inline (
	struct_id : int, 
	member_name : string,
	all_type_info_struct_members : [] *TypeInfoStructMember) 
-> *TypeInfoStructMember, found_member_info : bool 
{
	for all_type_info_struct_members {
		if it.struct_id == struct_id && it.name == member_name {
			return it, true;
		}
	}
	return null, false;
}
}
//TODO Maybe we should make them all struct to simplify things if that seems better.
//We would have to update the type_enum checks everywhere in the compiler but then we would not need to check
//for neume and tano separate from structs anymore. Maybe this help with doing unique things with neume and tano later though...
STRUCT_TYPE_INTERNAL :: TypeInfoTag.[.STRUCT,.NEUME,.TANO,.STRING];
GetStructMember :: inline (
	member_name : string,
	struct_info : *TypeInfoStruct)
-> TypeInfoStructMember, found_member_info : bool 
{
	//TODO Could make a constant array for this and reuse it everywhere.
	// assert(AllOrEquals(struct_info.type_enum, STRUCT_TYPE_INTERNAL));
	// struct_info := cast(*TypeInfoStruct) struct_info;
	for struct_info.struct_members if it.name == member_name {
		return it, true;
	}
	return .{}, false;
}

DataInfo :: struct {
	data_type : DataType;
	is_pointer : bool;
	pointer_count : u8;
	//TODO Do we want to allow > 1 pointer? I don't think I've ever used > 1 pointer in this entire game so far...
	// struct_id : int;
}

CommaNode :: struct {
	top_comma_node : *BinaryNode;
	node : *BinaryNode;	
	//TODO If we don't use this for the input function stack then we can remove it
	input_index : int;
}

/*Currently these are used for MUSIC_MEMORY array access. I am not sure we would need them
for RAM_MEMORY array access since that would be done with typical pointer math and mov instructions.
rows[0][1] -> [0,1]
code       -> asm operand
*/
NodeValue :: struct {
	value_id : int;
	node : *BinaryNode;
}

MakeNodeValue :: inline (value_id : int, node : *BinaryNode) -> NodeValue {
	nv : NodeValue = ---;
	nv.value_id = value_id;
	nv.node = node;
	return nv;
}

NodeToInstruction :: struct {
	//TODO Could we just store a *BinaryNode here instead of node_id?
	node_id : int;
	instr_id : int;
	//TODO Should we add order here or will that be maintained if we don't delete any of them?
	//I think it will be maintained and then even more so if we linearize the parsing.
	/*TODO I am leaving this separate since then we build the actual asm instructions throughout
	  and then at the end we can efficiently copy them over with memcpy or simd.
	  Or even just add them directly to all_all_music_instructions in fact. If we have multiple
	  allowable compilings then we would have to add a file_id or something to know which is running.

	  Also, most nodes are 1 instruction and will not need this. Only loops need it atm.
	*/
	// instruction : OldMusicInstruction;
}

MakeNodeToInstruction :: inline (node_id : int, instr_id : int) -> NodeToInstruction {
	node_to_instr : NodeToInstruction = ---;
	node_to_instr.node_id = node_id;
	node_to_instr.instr_id = instr_id;
	return node_to_instr;
}

ControlFjmps :: struct {
	//TODO Should this be index or instr.id? We need it to be id if we start to rearrange instructions.
	//If we don't though, then we can remove id from MusicInstructon later and associate a range
	//to a specific file to know what to run eventually when we have multiple compiled files.
	instr_index : int;
	// scope_id : int;
	//TODO We don't actually need the scope_index here but I am leaving it for now for the assertion
	//We only really grab the last one and as long as the code compiles with correct {} then it's ok
	scope_index : int;
}

ScopeDataType :: enum u8 {
	GLOBAL_SCOPE;
	FUNCTION_SCOPE;
	CONTROL_SCOPE;
	//TODO Should this just be a general DIRECTIVE_SCOPE or is a separate asm scope better?
	ASM_SCOPE;
}

ScopeData :: struct {
	//TODO Maybe we should just use an index instead and can remove this id then
	//WE ARE NOW, can remove this id if we never use it and don't need it
	//Leaving it here in case we decide to use ids eventually for some reason
	id : int;
	//TODO Maybe we don't need this here since we just use scope_data_stack as the index anyways.
	scope_index : int;
	//Used for code like "for 1..10 if i == 0 while i < 1" then we need to pop them all off from the same group
	inline_scope_group : int;
	//TODO We store a copy of the token here to check what the scope is for and line number info for error info
	//but maybe we want to store a copy of the BinaryNode?
	scope_token : LCodeToken;
	// rbp : int; //TODO Is scope uniquely defined by rbp? I think so.
	//TODO Could store a data_id or function_id if this is a FUNCTION_SCOPE
	scope_type : ScopeDataType;
	is_final_solo_else : bool;
	start_instr_index : int;
	//NOTE : This is not part of the scope so it is the last instructon after the end of the scope.
	//Is this a problem for the last function? I don't think so since this is just a range
	//but if it is a problem then we can subtract 1 from it and have it be the last instr_index that is in the scope
	/*DOCUM : 
	end_instr_index is part of the scope which seems to make more sense thinking about it.
	considering we have a halt instruction at the end and also the we can check the next
	instruction sometimes to see what will happen in the debugger.
	instr_index is start_instr_index <= i <= end_instr_index if its in this scope
	ALSO it means (end_instr_index - start_instr_index + 1) is the total scope instruction count
	*/
	end_instr_index : int;
	start_byte_offset_from_sbp : int;
	variable_stack_start_index : int;

	//TODO CAN REMOVE THESE 2 MEMBERS ONCE WE REMOVE OLD IF/WHILE UPDATE CODE
	/*I think we can remove this and just store BinaryNode directly or even a LCodeToken
	so we know what the start of the scope is eg function,IF,FOR,WHILE...
	Note sure this scope_node is a good idea since we don't necessarily want to store the old nodes.
	TODO I think we can remove this scope_node now
	YES especially when we onlye parse nodes per statement and then 
	clear that afterwards after each statement.
	*/
	scope_node : *BinaryNode;
	//Here we store either instruction_id or function_id depending on the scope
	//so we can get it later when we have to update asm (eg else if) or call functions.
	//TODO Should this be node_id or maybe even add a *BinaryNode instead.
	//TODO We might be able to remove both of these now with the new method. Can add them later if we need for some reason
	data_id : int;
	function_id : int;
}

//TODO Could do this with 1 stack IfElseData if that makes more sense on implementation. In my head\
//grabbing the if AND THEN going through else makes more sense in case we have 0 else then we just would
//not do anything on the loop and only remove the IfData and continue
// IfElseData :: struct {
// 	if_else_index : int;
// 	jmp_instr_index : int;
// 	is_else : bool;	
// }
/*NOTE : The reason we use this instead of scope for if-else is because even nested ifs are naturally a stack.
So we put an if when we find the first if and then we put else after. Once we close the else the then update
all the corresponding elses. If we find another if before that then we would add it to the if_stack and then
do the same thing for elses. 
If we used scope then we would have to search through the scope so it would actually be slower and more confusing to use scopes.
It would just be more homogeneous because everything would be in the scope but this is not necessarily directly related to the scope
since we are just using it to the jmp instructions at the end of the if statements to skip over the rest.
*/
IfData :: struct {
	if_else_id : int;
}
ElseData :: struct {
	if_else_id : int;
	jmp_instr_index : int;
}

/*NOTE : I am creating a function because evenutally we should just be able to do
cd.all_scope_data[scope_id] since the scopes are added in order of id. We can likely do it 
right away but I'll do this for now in case we want to update it for some reason or issue.
*/
GetScopeData :: inline (scope_id : int, cd : *CompilationData) -> *ScopeData {
	//Don't need this since we assert after anyways.
	//TODO I think this should work but I will leave the loop for now just in case
	//but since we add the scope_id sequentially then the id == order in this case
	#if 0 {
	assert(cd.all_scope_data.count > 0); 
	assert(scope_id >= 0 && scope_id < cd.all_scope_data.count);
	sd : *ScopeData = *cd.all_scope_data[scope_id];
	return sd;
	} else {
	for * cd.all_scope_data if it.id == scope_id {
		return it;
	}
	//sanity check : this should never happen since we should be setting the ids from all_scope_data anyways
	assert(false, "scope % not found", scope_id);
	return null;
	}
}

/*NOTE : Scope data is stored in all_scope_data and we store the currenty open scope in open_scope_stack.
So to get the current scope we peek that stack and then get the data for all_scope_data. This way we only
keep the data in 1 place and can easily get the current scope and close them like a stack since that's
how scopes are naturally.
*/
//TODO Should we return a pointer here. It seems like we don't need it for now.
GetCurrentScope :: inline (cd : *CompilationData) -> ScopeData {
	assert(cd.open_scope_stack.count > 0);
	last_scope_id : int = peek(cd.open_scope_stack);
	last_scope : ScopeData = GetScopeData(last_scope_id, cd);
	return last_scope;
}

CreateScope :: inline (
	//TODO Can we infer the type in this function instead?
	type : ScopeDataType, 
	node : *BinaryNode, 
	in_inline_scope_group : bool,
	cd : *CompilationData)
-> *ScopeData 
{
	//We want the last scope_group or 0 if it's in a scope group. If not, then we want a new one
	inline_scope_group : int = 0;
	if in_inline_scope_group && cd.open_scope_stack.count > 0 {
		last_scope : ScopeData = GetCurrentScope(cd);
		inline_scope_group = last_scope.inline_scope_group;
	} else if cd.open_scope_stack.count > 0 {
		last_scope : ScopeData = GetCurrentScope(cd);
		inline_scope_group = last_scope.inline_scope_group + 1;
	}

	scope_data : *ScopeData = array_add(*cd.all_scope_data);
	// scope_data : *ScopeData = array_add(*cd.open_scope_stack);
	//TODO Should we remove scope_id and just have a scope_index instead since we pop them off permanently
	scope_data.id = cd.next_scope_id;
	cd.next_scope_id += 1;
	//We've already added the scope so need to take the index - 1
	scope_data.scope_index = cd.open_scope_stack.count-1;
	scope_data.inline_scope_group = inline_scope_group;
	//TODO Don't really need this data_id if we store the node... Do we need the node?
	//Leaving the node for now just in case and to help with debugging.
	//TODO Likely we can gather nodes for scopes and then clear them like a stack and pop them when the scope closes.
	//Maybe store the node_index of the array and then just reduce the count very likely.
	scope_data.data_id = node.node_id;
	scope_data.scope_node = node;
	scope_data.scope_token = node.value;
	//TODO Do we need this ScopeDataType, if not then we can pull out ScopeData
	//TODO Can we calculate the scope type in here based on the node or is it better to pass in?
	scope_data.scope_type = type;
	scope_data.start_instr_index = cd.all_music_instructions.count;
	scope_data.start_byte_offset_from_sbp = cd.byte_offset_from_sbp;
	scope_data.variable_stack_start_index = cd.variable_data_stack.count;
	scope_data.function_id = peek(cd.function_stack);

	//NOTE : We add the ScopeData here so that it stays in order in all_scope_data from the top.
	//This way we can access it directly by scope_id with all_scope_data[scope_id]
	// array_add(*cd.all_scope_data, scope_data.*);
	array_add(*cd.open_scope_stack, scope_data.id);

	//TODO This is for the first "if", can we put else in here as well to create ElseData?
	if node.value.token_type == .KEYWORD_IF {
		//This is the first if so we add this to show that we started an if to keep track of the elses later
		if_data : IfData;
		if cd.all_if_data.count > 0 {
			if_data.if_else_id = peek(cd.all_if_data).if_else_id + 1;
		}
		array_add(*cd.all_if_data, if_data);
	}

	return scope_data;
}


CodeFunction :: struct {
	id : int;
	name : string;
	//TODO Could store output name:type list here if needed.
}

OutOfOrderInstr :: struct {
	//TODO We could add a type here if we use this for all out of order instructions
	//The only other example i can think of now is constants which we don't have yet
	function_id : int;
	instr_index : int;
	op_index : int;
}

valid_unary_op_overloads :: CodeTokenType.[#char "-", #char "+"];
valid_operator_overloads :: CodeTokenType.[#char "+", #char "-", #char "*", #char "/", .PLUS_EQUALS]; 
FunctionDeclaration :: struct {
	id : int;
	name : string;
	start_instr_index : int;
	t_info_proc : *TypeInfoProcedure;
	//TODO Can we remove this now? We ar enot using it anywhere
	total_argument_and_return_type_size : int;

	//TODO I think we can use this if we have return vars, then if we don't find a return statement
	//by the end of the function scope, then we can output a compilation error.
	found_return_var : bool;
	found_return_statement_in_function : bool;

	function_code_evaluated : bool;

	//NOTE : This is the .FUNCTION_SCOPE for this function
	scope_id : int;
	//TODO If we allow functions within scope, then we could add a scope_id here to know where it is
	//function_in_scope : bool;

	//TODO Technically this can be an id since it's unique. maybe we can use this instead then.
	//I think we might have to also reference with the file_index/file_id so lets see once we add #load.
	double_colon_char_index : int;

	is_operator_overload : bool;
	//TODO Should we put the whole token here or is this enough?
	op_token_type : CodeTokenType; 
}
SameFuncArgs :: inline (fd : FunctionDeclaration, argument_nodes : [] *BinaryNode) -> bool {
	if fd.t_info_proc.argument_types.count != argument_nodes.count return false;
	for fd.t_info_proc.argument_types if argument_nodes[it_index].code_ir.t_info != it {
		return false;
	}
	return true;
}
ValidFuncArgs :: inline (proc_type : *TypeInfoProcedure, argument_nodes : [] *BinaryNode) -> bool {
	if proc_type.argument_types.count != argument_nodes.count return false;
	for proc_type.argument_types {
		if IsArrayInfoType(.VIEW, it) && IsArrayInfoType(.FIXED, argument_nodes[it_index].code_ir.t_info) &&
			(cast(*TypeInfoArray) it).element_type == (cast(*TypeInfoArray) argument_nodes[it_index].code_ir.t_info).element_type
		{
			//Converting from fixed array to array view with same element type is valid
			continue;
		}
		else if argument_nodes[it_index].code_ir.t_info != it {
			return false;
		}	
	}
	return true;
}


FunctionVariable :: struct {
	function_id : int;
	name : string;
	t_info : *TypeInfo;
	//TODO We don't need this for return values I think so we could have 2 different types for each and remove this.
	//These only matter if we actually return them and then they get set somewhere else on the stack or heap.
	//TODO Can we replace this with an op now, then it would be the same for the stack and the heap.
	//TODO Either replace this with an op or rename from_sbp_byte_offset
	//Leaving like this for now because its < 0.5 the size of MusicOperand but we could put an op if that is 
	//more convenient anywhere for some reason like .KEYWORD_RETURN which creates the op right now.
	var_bytes_from_sbp : int;
}

MakeFunctionVariable :: inline (function_id : int, name : string, t_info : *TypeInfo, var_bytes_from_sbp : int) -> FunctionVariable {
	fv : FunctionVariable = ---;
	fv.function_id = function_id;
	fv.name = name;
	fv.t_info = t_info;
	fv.var_bytes_from_sbp = var_bytes_from_sbp;
	return fv;
}

//TODO Need to use this for debug builds so we should have a table that has all variables in it
//and the variable_stack can be specifically for compilation of the current variables, but
//we would add to both. Could also make the variable_stack pointers possibly at that point.
//TODO Can probably store an op in here based on where there is stored in memory.
VariableData :: struct {
	//TODO Does this really need a separate id if were always getting by name and scope only?
	//Probably can remove this extra id here in that case.
	//I think we can since scope_id, function_id and name are identifiers
	id : int;
	scope_id : int;
	//TODO Maybe we don't need scope_idnex anymore because of scope_id but it could be convenient.
	scope_index : int;
	//TODO I think we can remove this and derive it from the scope...
	//TODO No actually we need function_id or something to identify which function this variable is in.
	//Then we can uniquely identify variable with function_id, scope_index and name
	//TODO We might be able to just get this from scope_id...
	function_id : int;
	name : string;
	t_info : *TypeInfo;
	//TODO This could have stack and memory for example.
	var_type : VariableType;
	//TODO Should probably change this to memory_offset or something for when we have in memory variables.
	// rel_stack_byte : int;
	op : MusicOperand;
}

VariableType :: enum {
	DEFAULT;
	//TODO Can rename to FUNCTION_INPUT and then if we have FUNCTION_INPUT we need to get the FunctionVariable
	//or not use the pointer type from the variable stack. Need to show the proper type for function input variables
	//instead of the pointer type that we are going to use internally if runtime_size > 8 and also restrict changes
	//unless it is actually a pointer. So need a FUNCTION_INPUT and FUNCTION_RESTRICTED_INPUT. Could also have
	//a flag for is_function_arg and then put it as restricted, whichever is the clearest.
	RESTRICTED_INPUT; //Cannot update because it is function input.
}

//TODO Use this function everywhere we add byte offset to keep track of it and also can add .scp after
//if needed OR we replace them all with cd.byte_offset_from_sbp += size;
AddByteOffsetFromSbp :: inline (size : int, cd : *CompilationData) {
	cd.byte_offset_from_sbp += size;
	if cd.byte_offset_from_sbp > cd.max_proc_offset_from_sbp {
		cd.max_proc_offset_from_sbp = cd.byte_offset_from_sbp;
	}
}

//TODO Should we put a push or an add scp in here. Maybe we can have an option
//and call PushStack or CreateAddSCPInstr in here with an option for consistency.
//Likely can think about this and add it when we update everything to work with structs on the stack.
CreateStackVarData :: inline (cd : *CompilationData, name : string, t_info : *TypeInfo, 
	var_type : VariableType = .DEFAULT)
-> *VariableData
{
	stack_var_op : MusicOperand = RamMem(.sbp, cd.byte_offset_from_sbp);
	var : *VariableData = CreateVarData(cd, name, t_info, stack_var_op, var_type);

	//TODO I think we should remove this and add it ourselves since then we can CreateStackVarData first
	//and then move it onto the stack OR MAYBE THIS IS FINE And we can just call this without any push now.
	//Although we would need a mov, maybe we can add the move to this function then.
	//TODO Be careful here since we don't want to add this twice if we forget and then do a PushStack for example
	//Maybe we can remove this from here and only add it in CreateAddSCPInstr and PushStack for consistency and error reduction.
	// cd.byte_offset_from_sbp += var.t_info.runtime_size;
	AddByteOffsetFromSbp(var.t_info.runtime_size, cd);

	return var;
}

CreateVarData :: inline (
	cd : *CompilationData, 
	name : string, t_info : *TypeInfo, 
	operand : MusicOperand,
	var_type : VariableType = .DEFAULT)
-> *VariableData
{
	assert(cd.open_scope_stack.count > 0);

	var : *VariableData = array_add(*cd.variable_data_stack);
	var.id = cd.next_var_declaration_id;
	cd.next_var_declaration_id += 1;
	//TODO We should probably be copying this name with an allocator that stays after compilation
	var.name = name;
	var.t_info = t_info;
	var.op = operand;	

	//TODO Do we still need scope_index if we have scope_id? 
	//I think it is convenient to make sure the scope is open.
	var.scope_index = cd.open_scope_stack.count-1;
	current_scope : ScopeData = GetCurrentScope(cd);
	var.scope_id = current_scope.id;
	//TODO This could also possibly be a function index in case we allow nested functions for convenience
	if current_scope.scope_type != .GLOBAL_SCOPE {
		var.function_id = peek(cd.function_stack);
	}

	//We add a copy here for both testing and debugging info later
	array_add(*cd.all_variables, var.*);
	return var;
}

FindVariableInNearestScope :: inline (name : string, var_stack : [] VariableData) -> VariableData, bool {
	//We search backwards since the variables are ordered in a stack by when they were declared.
	//This stack is assumed to only contain variables within the currently available scope.
	for < var_stack if it.name == name {
		return it, true;
	}
	return .{}, false;
}

//TODO Can implement other non-recursive dfs orders as well.
//Can also pass in Code here like in Walk_Table for Hash_Table. But then we can't know what the node is in the 
//passed in code scope...
// DFSPost :: (node : *BinaryNode, data : *$T, $VisitBinaryNode : $F) {
//TODO type $T used to be forced pointers, I am not sure that is necessary, so I made them any type now
//Obviously if 1 is pointer then they are all pointers soo... not sure why I was doing that
// DFSPost :: (node : *BinaryNode, data : $T, $VisitBinaryNode : (node : *BinaryNode, data : T) -> ())
// $error_out : bool = false, $ErrorOut : (data : T) -> (bool) = null) 
//TODO We could have the error be an object with duck typing an is_error or is_valid in the object.
//This works for now but we could do that if that is better for some reason.
//TODO Maybe passing in *T is better to reduce data size and remind us to use a pointer?
DFSPost :: (node : *BinaryNode, data : $T, $VisitBinaryNode : $F) {
visit :: #type (node : *BinaryNode, data : T) -> ();
error :: #type (node : *BinaryNode, data : T) -> bool;
#assert(F == visit || F == error);
// #assert(F == #type (node : *BinaryNode, data : *T) -> () || F == Code);
	c_node := node;
	stack : [..] *BinaryNode;
	stack.allocator = context.allocator;
	last_visited_node : *BinaryNode = null;
	while stack.count > 0 || c_node != null {
		if c_node != null {
			array_add(*stack, c_node);
			c_node = c_node.left;
		} else {
			peek_node := peek(stack);
			if peek_node.right != null && last_visited_node != peek_node.right {
				c_node = peek_node.right;
			} else {
				//I am suprised this works but it seems to! Let's see if it works over time.
				#if F == visit {
				VisitBinaryNode(peek_node, data);
				} else #if F == error {
				is_valid := VisitBinaryNode(peek_node, data);
				if !is_valid return;
				}
				last_visited_node = pop(*stack);
			}
		}
	}
}

DFSIn :: (node : *BinaryNode, data : *$T, $VisitBinaryNode : (node : *BinaryNode, data : *T) -> ()) {
	c_node := node;
	stack : [..] *BinaryNode;
	stack.allocator = context.allocator;
	while stack.count > 0 || c_node != null {
		if c_node != null {
			array_add(*stack, c_node);
			c_node = c_node.left;
		} else {
			c_node = pop(*stack);
			VisitBinaryNode(c_node,data);
			c_node = c_node.right;
		}
	}
}

DFSPre :: (node : *BinaryNode, data : *$T, $VisitBinaryNode : (node : *BinaryNode, data : *T) -> ()) {
	c_node := node;
	if c_node == null return;
	stack : [..] *BinaryNode;
	stack.allocator = context.allocator;
	array_add(*stack, c_node);
	while stack.count > 0 {
		c_node = pop(*stack);
		VisitBinaryNode(c_node,data);
		// right child is pushed first so that left is processed first
		if c_node.right != null {
			array_add(*stack, c_node.right);
		}
		if c_node.left != null {
		   array_add(*stack, c_node.left);
		}
   }
}

GetOrderedNodes :: inline (node : *BinaryNode, accum : *[..] *BinaryNode) {
	array_add(accum, node);
}

/*According to cracking the coding interview shown here
https://cs.stackexchange.com/questions/116655/which-tree-traversal-string-is-unique
and here
https://cs.stackexchange.com/questions/144593/why-recording-non-existent-children-in-the-pre-order-traversal-will-differentiat/144601#144601
this is unique traversal with pre-order and the nulls stored as leaves
*/
DFSPreWithNull :: (node : *BinaryNode, data : *$T, $VisitBinaryNode : (node : *BinaryNode, data : *T) -> ()) {
	c_node := node;
	if c_node == null return;
	stack : [..] *BinaryNode;
	stack.allocator = context.allocator;
	array_add(*stack, c_node);
	while stack.count > 0 {
		c_node = pop(*stack);
		VisitBinaryNode(c_node,data);
		if c_node != null {
			// right child is pushed first so that left is processed first
			array_add(*stack, c_node.right);
		   array_add(*stack, c_node.left);
		}
   }
}
NULL_NODE :: #run BNode(LCToken(-1,"null"));
GetOrderedNodesWithNull :: inline (node : *BinaryNode, accum : *[..] *BinaryNode) {
	if node == null array_add(accum, *NULL_NODE);
	else array_add(accum, node);
}

//TODO We can possibly remove this now since we use flags in CompilationData instead of different functions.
//Although maybe we can use different functions later but that seems more complicated than just having
//different flags for each operator depending on what we are parsing.
VisitFunctionDeclaration :: (node : *BinaryNode, cd : *CompilationData) {
	if node.value.token_type == {
	case #char ":"; {
		//TODO Declare function variables
	} 
	case #char "="; {
		//TODO Set function defaults
	} 
	case #char "("; #through;
	case #char ")"; {
		//TODO Empty function here so just do nothing or return.
	}
	case; {
		//TODO Could run a VisitConstant function here and then accumulate that
		print("Invalid function declaration value : %\n", node.value);
	}
	}
}

/*TODO Do we use these for parsing or set them in parse expression?
What if we have invalid nodes then maybe this method won't catch them.
Although we can likely check that during ParseExpression.
*/
IsBinaryOpNode :: inline (node : *BinaryNode) -> bool {
	result : bool = (node.left != null) && (node.right != null);
	return result;
}

IsUnaryOpNode :: inline (node : *BinaryNode) -> bool {
	result : bool = (node.left == null) ^ (node.right == null);
	return result;
}

IsLeafNode :: inline (node : *BinaryNode) -> bool {
	result : bool = (node.left == null) && (node.right == null);
	return result;	
}

/*This function always returns an integer as op_1 so that we can just do a .add without having to clear
the register/memory afterwards since the that will just place the value directly in.
so either
add reg_pointer, 0
OR
add sbp, int_offset
*/
GetMemoryAddressAsOperands :: inline (op : MusicOperand) -> op_0 : MusicOperand, op_1 : MusicOperand {
	op_0 : MusicOperand = ValueToOp(op.values[0]);
	//TODO InternalError - maybe this is an internal error and can be left as assertion since
	//we should not have anything else anyways
	assert(op_0.operand_type == .REGISTER || op_0.operand_type == .INTEGER);
	op_1 : MusicOperand = ValueToOp(op.values[1]);
	assert(op_1.operand_type != .FLOAT);
	//In case we don't have a second operand, just put a 0 so we can add into reg anyways.
	//This allows for 1 instruction since reg_def will get replaced.
	if op_1.operand_type == .NONE {
		op_1 = Imm(0);
	}
	return op_0, op_1;
}
//TODO Can remove thses now since these are no reusable resgister anymore once we update all the code
FreeOpValueRegister :: inline (v : MusicOperandValue, all_registers : *[] RegisterData) {
	if v.type == .REGISTER && v.int_value >= non_stack_start_reg_index {
		reg_index : int = v.int_value; 
		all_registers.*[reg_index].is_available = true;
	}
}
FreeOperandRegisters :: inline (op : MusicOperand, all_registers : *[] RegisterData) {
	for op.values FreeOpValueRegister(it, all_registers);
}

FreeReusableReg :: inline (v : MusicOperandValue, all_registers : *[] RegisterData) {
	if v.type == .REGISTER && v.int_value >= reusable_start_reg_index && v.int_value <= reusable_end_reg_index {
		reg_index : int = v.int_value; 
		all_registers.*[reg_index].is_available = true;
	}
}
FreeReusableRegisters :: inline (op : MusicOperand, all_registers : *[] RegisterData) {
	for op.values FreeReusableReg(it, all_registers);
}

FreeAllReusableRegisters :: inline (all_registers : [] RegisterData) {
	for reusable_start_reg_index..reusable_end_reg_index {
		all_registers[it].is_available = true;
	}
}

ReuseRegister :: inline (v : MusicOperandValue, cd : *CompilationData) -> RegDef, is_reused : bool {
	reg : RegDef;
	is_reused : bool = false;
	if v.type == .REGISTER {
		reg = cast(RegDef) v.int_value;
		if reg >= non_stack_start_reg {
			is_reused = true;
		}
	}
	return reg, is_reused;
}

//TODO CAn put a flag in here to make it available afterwards if possibley
OLDGetOrReuseRegister :: inline (node : *BinaryNode, cd : *CompilationData, $free_register : bool = false) -> RegDef, is_reused : bool {
	v : MusicOperandValue = node.code_ir.op.values[0];
	reg : RegDef;
	is_reused : bool = false;
	if v.type == .REGISTER {
		reg = cast(RegDef) v.int_value;
		if reg >= non_stack_start_reg {
			is_reused = true;
		} else if reg == .sbp {
			reg_data : *RegisterData = OLDGetNextAvailableRegister(cd);
			reg = cast(RegDef) reg_data.reg_index;
		} else {
			//TODO InternalError, Maybe we can pass in the node here for a better error message
			assert(false, "Using a non_stack reg for array access : %.\n", node.*);
		}
	} else {
		//InternalError
		assert(false, "not a register as 1st value on node : %\n", node.*);
	}
	#if free_register {
		cd.all_registers[reg].is_available = true;
	}
	return reg, is_reused;
}

//TODO We will only be using this in specific cases for now like pointer dereferencing. 
//Can maybe use for optimizing operations later but not for now.
NewGetOrReuseReg :: inline (node : *BinaryNode, cd : *CompilationData, $set_reg_available : bool = false) -> RegDef, is_reused : bool {
	v : MusicOperandValue = node.code_ir.op.values[0];
	reg : RegDef;
	is_reused : bool = false;
	if v.type == .REGISTER {
		reg = cast(RegDef) v.int_value;
		if reg >= reusable_start_reg {
			is_reused = true;
		} else if reg == .sbp {
			reg_data : *RegisterData = NewGetNextAvailableReg(cd);
			reg = cast(RegDef) reg_data.reg_index;
		} else {
			//TODO InternalError, Maybe we can pass in the node here for a better error message
			assert(false, "Using a non_stack reg for array access : %.\n", node.*);
		}
		#if set_reg_available {
		cd.all_registers[cast(int)reg].is_available = true;
		}
	} else {
		//InternalError
		assert(false, "not a register as 1st value on node : %\n", node.*);
	}
	return reg, is_reused;
}

AddOperandOffset :: inline (offset : int, op : MusicOperand) -> MusicOperand {
	op_with_offset := op;
	AddOperandOffset(offset, *op_with_offset);
	return op_with_offset;
}

AddOperandOffset :: inline (offset : int, op : *MusicOperand) {
	if op.values[1].type == .INTEGER {
		//TODO Could put this as GetDataPointer in case we change the order in memory later
		op.values[1].int_value += offset;
	} else if op.values[1].type == .NONE {
		op.values[1].type = .INTEGER;
		op.values[1].int_value = offset;
	} else {
		assert(false, "Cannot add offset to operand : % for value : %.\n", op.*, op.values[1]);
	}
}

/*TODO With the new way, we can just add to byte_offset_from_sbp and no change the scp ever
and then we can do an .mset if we want to initialize the data to 0.
So we would remove this or CreateAddSCPInstr
*/
/*Convenience functions for stack .push so we don't forget to increment byte_offset_from_sbp
and so we can easily pass in a node if needed.
*/
//TODO Can make a function with size as MusicOperand as well if needed
//TODO We could have this return MusicOperand but it would always be [.sbp,offset] before adding
//so maybe we should set it before th call anyways...
PushStackMov :: inline (op : MusicOperand, size : int, cd : *CompilationData) -> MusicOperand {
	stack_op : MusicOperand = PushStack(size, cd);
	CreateMInstr(.mov, stack_op, op, Imm(size), d=cd);
	return stack_op;
}
PushStackMov :: inline (node : *BinaryNode, cd : *CompilationData) -> MusicOperand {
	value_op : MusicOperand = GetValueOpReuseReg(node, cd, true);
	return PushStackMov(value_op, node.code_ir.t_info.runtime_size, cd);
}
PushStack :: inline (size : int, cd : *CompilationData) -> MusicOperand {
	//We return the position where this var is stored on the stack. Maybe it's not useful
	//but maybe this is clearer than always setting the var before calling PushStack anyways.
	stack_op : MusicOperand = RamMem(.sbp, cd.byte_offset_from_sbp);
	AddByteOffsetFromSbp(size,cd);
	return stack_op;
}

//TODO FROM HERE Pull this out and try it on array literals as well with unit tests.
//Then write integration tests for struct literals and array literals (also with autocast)
//AND ALSO INTEGRATION TESTS FOR ENUMS.
MovWithAutocast :: inline (
	input_node : *BinaryNode, 
	check_info : *TypeInfo,
	set_op : MusicOperand,
	cd : *CompilationData) 
-> bool
{
	assert(input_node != null);
	//TODO Should we assert the types != null here or do that before calling?
	valid_type_check : bool = false;
	if input_node.code_ir.t_info == check_info {
		valid_type_check = true;
		CreateMInstr(.mov, set_op, input_node.code_ir.op, Imm(input_node.code_ir.t_info.runtime_size), d=cd);
	} 
	else if input_node.code_ir.t_info == *cd.int_type_info &&
		check_info == *cd.float_type_info
	{
		valid_type_check = true;
		CreateMInstr(.itof, set_op, input_node.code_ir.op, d=cd);
	}
	return valid_type_check;
	
	// #if 0 {
	// //TODO I THINK THIS SHOULD JUST AUTOCAST for function inputs which we can set later when we do that.
	// if input_node.code_ir.t_info.type_enum == .ARRAY && check_info.type_enum == .ARRAY {
	// 	//We push an array view of the fixed array on the stack and set this node to that array view.
	// 	input_array_info := cast(*TypeInfoArray) input_node.code_ir.t_info;
	// 	check_array_info := cast(*TypeInfoArray) check_info;
	// 	if input_array_info.array_type == .FIXED && check_array_info.array_type == .VIEW {
	// 		// CastArrayFixedToView :: inline (fixed_type : *TypeInfoArray, fixed_node : MusicOperand, view_op : MusicOperand) {
	// 		// 	//Move array count
	// 		// 	CreateMInstr(.mov, view_op, Imm(fixed_type.array_count), Imm(cd.int_type_info.runtime_size), d=cd);
	// 		// 	//Move array data
	// 		// 	array_data_op := AddOperandOffset(8, view_op);
	// 		// 	SetAddressNode(input_node, array_data_op, cd);
	// 		// }
	// 		//Move array count
	// 		CreateMInstr(.mov, set_op, Imm(input_array_info.array_count), Imm(cd.int_type_info.runtime_size), d=cd);
	// 		//Move array data
	// 		array_data_op := AddOperandOffset(8, set_op);
	// 		SetAddressNode(input_node, array_data_op, cd);
	// 	}
	// }
	// }
}

/*DOC : This pushes the tano on the ram stack and also moves the neumes to a new tano on the tano_stack.
The return value is the tano on the tano_stack. Maybe I should call that temp_tano instead since it's only
partially a stack.
*/
//TODO Should we rename this
PushTanoStack :: inline (from_tano_node : *BinaryNode, cd : *CompilationData) -> MusicOperand {
	//NOTE: Need to update the tsp stack since we added a new tano
	//We reset the tano stack at the end of every expression whenever we add neumes to the tano stack
	//since the tano stack only lasts for each expression for each function.
	cd.reset_tano_stack = true;

	from_tano_op : MusicOperand = GetValueOp(from_tano_node, cd, .r0);
   from_tano_ofs := GetTanoOpOffsets(from_tano_op);

   /*NOTE : We create the to_tano here on the stack using the tano stack music space
   */
   //TODO I think we can maybe generalize this as PushTanoStack(tano, cd)
   //Unless we only use it here and then we can just leave this here
   to_tano_op : MusicOperand = PushStackMov(from_tano_node, cd);
   to_tano_ofs := GetTanoOpOffsets(to_tano_op);
   //Current tano stack
   //We only update .tbp on a function call and on function return
   CreateMInstr(.mov, to_tano_op, RegMem(.tsp), d=cd);
   //Get row diff
   CreateMInstr(.sub, RegMem(.ax), from_tano_ofs.row_end_op, from_tano_ofs.row_start_op, d=cd);
   CreateMInstr(.abs, RegMem(.ax), RegMem(.ax), d=cd);
   CreateMInstr(.add, to_tano_ofs.row_end_op, to_tano_ofs.row_start_op, RegMem(.ax), d=cd);
   //Update .tsp to the next available row
   //TODO This can be checked at runtime if ever .tsp is > row_max then we can return an error or stop the program.
   CreateMInstr(.add, RegMem(.tsp), RegMem(.ax), d=cd);
   CreateMInstr(.add, RegMem(.tsp), Imm(1), d=cd);
	//x starts at 0 always so we don't have any offset on tano_stack
   CreateFloatInstr(.mov, to_tano_ofs.x_start_op, FImm(0), d=cd);
   //Get x diff
   CreateFloatInstr(.sub, RegMem(.ax), from_tano_ofs.x_end_op, from_tano_ofs.x_start_op, d=cd);
   CreateFloatInstr(.abs, RegMem(.ax), RegMem(.ax), d=cd);
   CreateFloatInstr(.add, to_tano_ofs.x_end_op, to_tano_ofs.x_start_op, RegMem(.ax), d=cd);

   CreateMInstr(.mov, to_tano_ofs.mspace_op, Imm(TANO_STACK_MSPACE), d=cd);
   //TODO Maybe we remove mspace_end_op and then we can just remove this.
   // to_mspace_end_op := AddOperandOffset(40, to_tano_op);
   // CreateMInstr(.mov, to_mspace_end_op, Imm(TANO_STACK_MSPACE), d=cd);

   //NOTE : Move the values over and the from_tano maintains the direction so it only gets reversed
   //once if needed and then all other operations would be applied directly AND the "~="
   //would also be applied directly since it was already reversed on the stack.
   //TODO NEED TO TEST THIS WITH AN INTEGRATION TEST
   CreateMInstr(.tmov, to_tano_op, from_tano_op, d=cd);

   return to_tano_op;
}
/*DOC : This way we don't have to recopy all these instructions for each test and if we make a change then
we only have to change it 1 place.
REMINDER : This makes we think of optimizing tano stack ops so we only use them in 1 place BUT this only really
works for arithmetic since a "~" operation may necessarily increase the size of the tano depending on what is being added.
So maybe we can do an optimization with neume arithmetic operations later but for now we keep it general to avoid issues.
*/
//TODO Should we put this in the test file instead?
TanoStackTestInstr :: (t_stack_op : MusicOperand, from_op : MusicOperand, cd : *CompilationData) -> [] MusicInstruction {
	t_stack_ofs := GetTanoOpOffsets(t_stack_op);
	from_ofs := GetTanoOpOffsets(from_op);

	arr := NewArray(13, MusicInstruction, false);
	//Create tano on tano_stack
	arr[0] = MakeMI(.mov, t_stack_op, from_op, Imm(cd.tano_struct_info.runtime_size));
	//Move next row_start on tano_stack
	arr[1] = MakeMI(.mov, t_stack_ofs.row_start_op, RegMem(.tsp));
	//to_row_end = abs(from_row_diff)
	arr[2] = MakeMI(.sub, RegMem(.ax), from_ofs.row_end_op, from_ofs.row_start_op);
	arr[3] = MakeMI(.abs, RegMem(.ax), RegMem(.ax));
	arr[4] = MakeMI(.add, t_stack_ofs.row_end_op, t_stack_ofs.row_start_op, RegMem(.ax));
	//update the tsp tano_stack_pointer
	arr[5] = MakeMI(.add, RegMem(.tsp), RegMem(.ax));
	arr[6] = MakeMI(.add, RegMem(.tsp), Imm(1));
	//x starts at 0 always so we don't have any offset on tano_stack
	arr[7] = MakeFloatInstr(.mov, t_stack_ofs.x_start_op, FImm(0));
	//to_x_end = abs(from_x_diff)
	arr[8] = MakeFloatInstr(.sub, RegMem(.ax), from_ofs.x_end_op, from_ofs.x_start_op);
	arr[9] = MakeFloatInstr(.abs, RegMem(.ax), RegMem(.ax));
	arr[10] = MakeFloatInstr(.add, t_stack_ofs.x_end_op, t_stack_ofs.x_start_op, RegMem(.ax));
	//Set the mspace_index
	arr[11] = MakeMI(.mov, t_stack_ofs.mspace_op, Imm(TANO_STACK_MSPACE));
	// MakeMI(.mov, RamMem(.sbp,tano_s+40), Imm(TANO_STACK_MSPACE));
	//Move the music pts over (from_tano maintains the x/row direction)
	//tano_stack = tano(0,0) + 1
	arr[12] = MakeMI(.tmov, t_stack_op, from_op);

	return arr;
}

IsConstant :: inline (node : *BinaryNode) -> bool {
	if node.code_ir.op.operand_type == {
	case MusicOperandType.FLOAT; #through;
	case MusicOperandType.INTEGER;
		return true;
	}

	return false;
}

/*TODO We could store all these defaults in CompilationData if needed
*/
//NOTE: We store -1 for null pointers so if we try to access them at RamMem(-1), that will through
//a NullPointerExceptoin
NULL_POINTER_ADDRESS : int : -1;
NULL_POINTER_OP : MusicOperand : #run Imm(NULL_POINTER_ADDRESS);

//TODO Can use this directly in .ret instruction for clarity.
//This is a constant instruction which is reused. We can place all reused specific instructions here.
// PROC_JMP_RETURN :: MusicInstruction.{-1,.jmp,.INTEGER,.[#run RamMem(.sbp,-8),.{},.{}]};
PROC_JMP_RETURN :: MusicInstruction.{op_code=.ret};
PROC_RETURN_OP :: #run RamMem(.sbp,-8);

//We push all registers on the stack and then the return instruction index so 
//sbp - reg.count - 8 = end of function return vars. So then for each return var we do
//-PRE_PROC_STACK_SIZE - return_type.runtime_size and this lets us add multiple return values if needed
//subtract - 8 because of the return_jmp_instr_index
// -PRE_PROC_STACK_SIZE : int : -ALL_REG_SIZE - 8;
PRE_PROC_STACK_SIZE : int : STACK_REG_SIZE + 8;
//NOTE : This is the previous stack sbp that we push on with push_all_stack_reg
//we need it to get the proper return pointer values for function return values.
//subtract - 8 because of the return_jmp_instr_index
PREVIOUS_SBP_OP :: #run RamMem(.srp, -PRE_PROC_STACK_SIZE);
//LEAVING THE OLD ONE HERE as a reminder
/*DOC : We used to use sbp but now we use srp since we reset sbp on ret instruction.
This way allows us to see the correct variables when we return from a function and then still
do the pop. Doing the pop allows us to come back to the same instruction when we return from a function
and see which function call it was and then we pop everything. If we need to store more registers
on return, then we can do that with more registers, but I think this is fine now.
*/
// PREVIOUS_SBP_OP :: #run RamMem(.sbp, -PRE_PROC_STACK_SIZE);

NEW_FUNC :: true;
//TODO Could return a an error object to check and return so that we can stop on an error and print out an error message.
//TODO We could accumulate instructions in here and then add them afterwards. Not sure if that's needed though.
VisitStatementNode :: inline (node : *BinaryNode, cd : *CompilationData) -> is_valid : bool {
	/*IDEA
	  MUSIC_MEMORY could be an array that is [row,point,point,row,point...] where row contains how many points.
	  Then we can just set points or also memory_units (sections between x_start and x_end)
	  so could even have [row,mem,point,point,mem,point,row,mem,point...] where row and mem store how many
	  values come after it. 
	  Technically this is what we have now just in 2 separate arrays with all_music_lane_rows and all_music_pts.
	*/
	if node.value.token_type == {
	case .KEYWORD_RETURN; {
		//TODO CompilerError? Maybe ParserError? Finding a return value outside of a scope...?
		assert(cd.function_stack.count > 0);
		//TODO Should just store function_id here so we don't have to update twice
		func_decl_id : int = peek(cd.function_stack);
		fd : *FunctionDeclaration = ArrayFindFirstByNameId(cd.all_function_declarations, func_decl_id, "id");
		fd.found_return_statement_in_function = true;
		return_vars : [] FunctionVariable = ArrayFindAllVarName(cd.all_function_return_variables, fd.id, "function_id",,context.allocator);
		#if 1 {
		// return_nodes : [] *BinaryNode = CommaNodeArray(node, cd);
		return_nodes : [] *BinaryNode; 
		if node.right != null {
			return_nodes = NewCommaNodeArray(node.right, cd);
		}
		} else {
		return_comma_nodes : [] CommaNode;
		if node.right.value.token_type == #char "," {
			peek_node := peek(cd.comma_node_stack);
			assert(cd.comma_node_stack.count > 0 && peek_node.top_comma_node == node.right);
			comma_list_count : int = peek_node.input_index + 1; //need to + 1 since the input_index starts from 0
			comma_node_start_index : int = cd.comma_node_stack.count - comma_list_count;
			return_comma_nodes = array_view(cd.comma_node_stack, comma_node_start_index);	
			cd.comma_node_stack.count = comma_node_start_index;
		} else {
			return_comma_nodes = CommaNode.[.{null,node.right,0}];
		}
		}

		if return_nodes.count > fd.t_info_proc.return_types.count {
			CreateCompErr(cd, .EVALUATION, node,
			sprint("Invalid return count should be %.", fd.t_info_proc.return_types.count));
			return false;
		}
		for fd.t_info_proc.return_types if it != return_nodes[it_index].code_ir.t_info {
			CreateCompErr(cd, .EVALUATION, node,
			sprint("Invalid return type on index %.", it_index));
			return false;
		}
		#if NEW_FUNC {
		//NEW WAY : we move value directly to the return value which was stored on the stack from the caller point.
		/*NOTE : The reason this is fine is because even in the case of 
		  x = foo();
		  where x is already set, we are only doing 1 extra mov which is 1 extra memcpy. If we compare this
		  to having to do a dereference and store pointers, that is much more complex but also likely more
		  expensive at runtime to do the pointer dereferencing than just the extra in the 1 case where we already
		  have the extra variable anyways.
		  I prefer this way since it is consistent and simpler overall and very clear since we are placing the 
		  return values on the previous stack frame and if we have an assignment then they are already in the right
		  place even if we have multiple return values.
		*/
		total_return_size : int = 0;
		for return_nodes {
			type_size : int = it.code_ir.t_info.runtime_size;
			total_return_size += type_size;
			CreateMInstr(.mov, RamMem(.sbp, -PRE_PROC_STACK_SIZE - total_return_size), it.code_ir.op, Imm(type_size), d=cd);

			//TODO We can remove this if we just reset registers on assignment instead
			FreeOperandRegisters(it.code_ir.op, *cd.all_registers);
		}
		} else {
		//NOTE : If we wanted to change where the return is set to, then we would have to use these pointers
		//right now it is fixed
		//We move the value to the position that the return pointer points to here
		for return_comma_nodes {
			reg_data : *RegisterData = OLDGetNextAvailableRegister(cd);
			reg_data.is_available = true;
			reg := cast(RegDef) reg_data.reg_index;
			CreateMInstr(.mov, RegMem(reg), RamMem(.sbp, return_vars[it_index].var_bytes_from_sbp), d=cd);
			CreateMInstr(.mov, RamMem(reg), it.node.code_ir.op, Imm(it.node.code_ir.t_info.runtime_size), d=cd);

			FreeOperandRegisters(it.node.code_ir.op, *cd.all_registers);
		}
		}

		/*DOC : In case we return something like "return tano(0,0) + 1;" we don't want to reset the tano stack
		so that we can use the return value on the return expression and then we would reset after that expression.
		*/
		cd.reset_tano_stack = false;
		//We store where to jmp back to the value after .call which is at [sbp,-8]
		//This is now stored in the .ret instruction by default.
		//.ret and .call can now be used for debugging puproses to know when to push and pop the call stack.
		CreateMInstr(.ret, d=cd);
	}
	case #char "("; {
	//TODO We could also have a function here to check if this is a compile-time function
	//and then we can do the same for NewArray and New if we do those as functions as well.
	// if node.left.value.token_type == .KEYWORD_TANO {
	if node.left.code_ir.t_info != null && node.left.code_ir.t_info.type_enum == .TANO {
		//TODO We can make this work for all tano_struct_info and then make it relative and then 
		//tano can just be a base value starting from tano(0,0)
		//BUT maybe it is better to do relative offsets with [] to differentiate... although
		//maybe we don't want to allow negative values in arrays at all

		
		var_nodes : [] *BinaryNode = CommaNodeArrayEmptyToken(node.right, #char ")", cd);
		if !AllOrEquals(var_nodes.count, int.[1,2,3]) {
			CreateCompErr(cd, .EVALUATION, node,
			"Invalid tano - tano(r,x), tano(r:rc,x:xl), tano(r0..r1,x0..x1)");
			return false;			
		}

		/*TODO
		tano(r,x,c)
		tano(r,x0..x1)
		tano(r)? This could be == tano(x,0..row_count)
		tano(r0..r1) Maybe we don't allow this one and just have it be a loop instead
		t1(t0(tano(0,1))) - could allow tano inside a tano and keep adding relative offsets
			- it does feel confusing though, so maybe we add later
			- it is equivalent to t0(r0..r1,x0..x1) we just add the values from the inner tano
			  since we just add the row_start and x_start of the LHS rel_tano to the inner tano
			- interesting because we move around the piece based on sections
			- it is a different way to move around a piece of music
		*/
		//TODO Can do this once we return the value.
		/*TODO We could allow a tano inside the tano and have multiple relative offsets
		which would all get accumulated up the tree anyways

		TODO IMPORTANT WE NEED TO ADD MSPACE_INDEX either to the node itself or on a stack somewhere
		and pop it off when we use it since we will use it on the node above but maybe we can have relative
		tanos and so we need to keep track of those.
		*/
		if var_nodes.count == 1 && 
			var_nodes[0].code_ir.t_info != null && var_nodes[0].code_ir.t_info.type_enum == .TANO 
		{
			//WE NEED TO TEST THIS OUT MANUALLY TO SEE IF IT FEELS LIKE IT MAKES ANY SENSE
			//tano(tano) - recursive relative tanos
			node.code_ir.op = PushStackMov(var_nodes[0], cd);
			//NOTE : tano is assumed tano(0,0) so we don't need to add an offset since it's already from 0.
			if node.left.value.token_type != .KEYWORD_TANO {
				//TODO FROM HERE I think we want to explicitly set registers for this so we keep track of it
				//since we store everything on the stack now and then write tests for tano operations.
				rel_tano_row_start_op := GetValueOpReuseReg(node.left, cd, true);
				CreateMInstr(.add, node.code_ir.op, rel_tano_row_start_op, d=cd);
				// CreateMInstr(.add, AddOperandOffset(8, node.code_ir.op), AddOperandOffset(8, rel_tano_row_start_op), d=cd);
				CreateMInstr(.add, AddOperandOffset(8, node.code_ir.op), rel_tano_row_start_op, d=cd);

				rel_tano_x_start_op := AddOperandOffset(16, rel_tano_row_start_op);
				CreateFloatInstr(.add, AddOperandOffset(16, node.code_ir.op), rel_tano_x_start_op, d=cd);
				// CreateFloatInstr(.add, AddOperandOffset(24, node.code_ir.op), AddOperandOffset(24, rel_tano_op), d=cd);
				CreateFloatInstr(.add, AddOperandOffset(24, node.code_ir.op), rel_tano_x_start_op, d=cd);

				rel_tano_mspace_start_op := AddOperandOffset(32, rel_tano_row_start_op);
				CreateFloatInstr(.add, AddOperandOffset(32, node.code_ir.op), rel_tano_mspace_start_op, d=cd);
			}
		}
		else if var_nodes.count == 1 && 
			AllOrEquals(var_nodes[0].value.token_type, .[.ADD_COMMA_ADD, .ADD_COMMA_SUB, .SUB_COMMA_ADD, .SUB_COMMA_SUB])
		{
			//TODO Should this be in the case below or separate like this? 
			//I think separate since the asm instructions and requirements are different
			if node.left.value.token_type == .KEYWORD_TANO {
				CreateCompErr(cd, .EVALUATION, node,
				"Direction ops can only be applied to relative tanos.");
				return false;				
			}

			//TODO FROM HERE finish this up and then write unit and integration tests for relative tano direction ops
			//TODO Set the op to the new tano on the stack
			// node.code_ir.op = new_row_start_op;
			if var_nodes[0].value.token_type == {
			case .ADD_COMMA_ADD; {
				//We do nothing here so we just pass up the node
				node.code_ir = node.left.code_ir;
			}
			case .ADD_COMMA_SUB; #through;
			case .SUB_COMMA_ADD; #through;
			case .SUB_COMMA_SUB; {
				node.code_ir.op = PushStackMov(node.left, cd);
				new_op := GetTanoOpOffsets(node.code_ir.op);
				left_op := GetValueOpReuseReg(node.left, cd, true);
				old_op := GetTanoOpOffsets(left_op);

				if var_nodes[0].value.token_type == {
				case .SUB_COMMA_SUB; #through;
				case .SUB_COMMA_ADD;
					CreateMInstr(.mov, new_op.row_start_op, old_op.row_end_op, Imm(cd.int_type_info.runtime_size), d=cd);
					CreateMInstr(.mov, new_op.row_end_op, old_op.row_start_op, Imm(cd.int_type_info.runtime_size), d=cd);
				}
				if var_nodes[0].value.token_type == {
				case .SUB_COMMA_SUB; #through;
				case .ADD_COMMA_SUB;
					CreateMInstr(.mov, new_op.x_start_op, old_op.x_end_op, Imm(cd.float_type_info.runtime_size), d=cd);
					CreateMInstr(.mov, new_op.x_end_op, old_op.x_start_op, Imm(cd.float_type_info.runtime_size), d=cd);
				}
			}
			}
		}
		else if AllOrEquals(var_nodes.count, int.[1,2,3]) {
			//TODO Could check values here if we want to allow other 2 value inputs for a tano()
			new_row_start_op : MusicOperand;
			new_row_end_op : MusicOperand;
			if var_nodes[0].value.token_type == #char ":" {
				row_start_node := var_nodes[0].left;
				row_count_node := var_nodes[0].right;
				if row_start_node == null || row_start_node.code_ir.t_info.type_enum != .INTEGER ||
					row_count_node == null || row_count_node.code_ir.t_info.type_enum != .INTEGER
				{
					CreateCompErr(cd, .EVALUATION, node,
					"Invalid tano row count : tano(int:int");
					return false;
				}

				new_row_start_op = PushStack(row_start_node.code_ir.t_info.runtime_size, cd);
				left_row_start_op : MusicOperand = GetValueOpReuseReg(row_start_node, cd, true);
				CreateMInstr(.mov, new_row_start_op, left_row_start_op, Imm(row_start_node.code_ir.t_info.runtime_size), d=cd);

				new_row_end_op = PushStack(row_count_node.code_ir.t_info.runtime_size, cd);
				row_count_op : MusicOperand = GetValueOpReuseReg(row_count_node, cd, true);
				//NOTE : If the row_count is negative, this is fine since we add a negative to the start.
				//So start + (-count) = start - count and so end < start which is a row reversed tano.
				CreateMInstr(.add, new_row_end_op, new_row_start_op, row_count_op, d=cd);
			} 
			else if var_nodes[0].value.token_type == .DOUBLE_DOT {
				row_start_node := var_nodes[0].left;
				row_end_node := var_nodes[0].right;
				if row_start_node == null || row_start_node.code_ir.t_info.type_enum != .INTEGER ||
					row_end_node == null || row_end_node.code_ir.t_info.type_enum != .INTEGER
				{
					CreateCompErr(cd, .EVALUATION, node,
					"Invalid tano row range : tano(int..int");
					return false;
				}

				new_row_start_op = PushStackMov(row_start_node, cd);
				new_row_end_op = PushStackMov(row_end_node, cd);
			} 
			else if var_nodes[0] != null && var_nodes[0].code_ir.t_info != null &&
				var_nodes[0].code_ir.t_info.type_enum == .INTEGER 
			{
				new_row_start_op = PushStackMov(var_nodes[0], cd);
				//NOTE : By default we push on the same end_row = start_row
				new_row_end_op = PushStackMov(var_nodes[0], cd);
			} 
			else {
				CreateCompErr(cd, .EVALUATION, node,
				"Invalid tano row - eg valid is tano(row,x)");
				return false;
			}

			//NOTE : tano is assumed tano(0,0) so we don't need to add an offset since it's already from 0.
			rel_tano_row_start_op : MusicOperand;
			if node.left.value.token_type != .KEYWORD_TANO {
				rel_tano_row_start_op = GetValueOpReuseReg(node.left, cd);
				CreateMInstr(.add, new_row_start_op, rel_tano_row_start_op, d=cd);
				CreateMInstr(.add, new_row_end_op, rel_tano_row_start_op, d=cd);
			}

			if var_nodes.count > 1 {
				new_x_start_op : MusicOperand;
				new_x_end_op : MusicOperand;
				x_node := var_nodes[1];
				if x_node.value.token_type == #char ":" {
					x_start_node := x_node.left;
					x_count_node := x_node.right;
					if x_start_node == null || 
						!AllOrEquals(x_start_node.code_ir.t_info.type_enum, .[.INTEGER, .FLOAT]) ||
						x_count_node == null || 
						!AllOrEquals(x_count_node.code_ir.t_info.type_enum, .[.INTEGER, .FLOAT])
					{
						CreateCompErr(cd, .EVALUATION, node,
						"Invalid tano row count : tano(row,x:x_length)");
						return false;
					}

					new_x_start_op = PushStack(x_start_node.code_ir.t_info.runtime_size, cd);
					left_x_start_op : MusicOperand = GetValueOpReuseReg(x_start_node, cd, true);
					CreateMInstr(.mov, new_x_start_op, left_x_start_op, Imm(x_start_node.code_ir.t_info.runtime_size), d=cd);
					if x_start_node.code_ir.t_info.type_enum == .INTEGER {
						CreateMInstr(.itof, new_x_start_op, new_x_start_op, d=cd);
					}

					new_x_end_op = PushStack(x_count_node.code_ir.t_info.runtime_size, cd);
					x_count_op : MusicOperand = GetValueOpReuseReg(x_count_node, cd, true);
					if x_count_node.code_ir.t_info.type_enum == .INTEGER {
						CreateMInstr(.mov, RegMem(.ax), x_count_op, Imm(cd.int_type_info.runtime_size), d=cd);
						CreateMInstr(.itof, RegMem(.ax), RegMem(.ax), d=cd);
						x_count_op = RegMem(.ax);
					}
					//NOTE : If the x_length is negative, this is fine since we add a negative to the start.
					//So start + (-count) = start - count and so end < start which is an x_reversed tano.
					CreateFloatInstr(.add, new_x_end_op, new_x_start_op, x_count_op, d=cd);
				}
				else if x_node.value.token_type == .DOUBLE_DOT {
					x_start_node := x_node.left;
					x_end_node := x_node.right;
					//TODO This could be int or float and we can convert to float with .itof if it's an int.
					if x_start_node == null || 
						!AllOrEquals(x_start_node.code_ir.t_info.type_enum, .[.INTEGER, .FLOAT]) ||
						x_end_node == null || 
						!AllOrEquals(x_end_node.code_ir.t_info.type_enum, .[.INTEGER, .FLOAT])
					{
						CreateCompErr(cd, .EVALUATION, node,
						"Invalid tano row range : tano(int..int");
						return false;
					}

					new_x_start_op = PushStackMov(x_start_node, cd);
					if x_start_node.code_ir.t_info.type_enum == .INTEGER {
						CreateMInstr(.itof, new_x_start_op, new_x_start_op, d=cd);
					}

					new_x_end_op = PushStackMov(x_end_node, cd);
					if x_end_node.code_ir.t_info.type_enum == .INTEGER {
						CreateMInstr(.itof, new_x_end_op, new_x_end_op, d=cd);
					}
				} 
				else if x_node != null &&
						  AllOrEquals(x_node.code_ir.t_info.type_enum, .[.INTEGER, .FLOAT])
				{
					//TODO If we have an int, then we can conver to integer here for convenience
					new_x_start_op = PushStackMov(var_nodes[1], cd);
					if x_node.code_ir.t_info.type_enum == .INTEGER {
						CreateMInstr(.itof, new_x_start_op, new_x_start_op, d=cd);
					}
					new_x_end_op = PushStack(cd.float_type_info.runtime_size, cd);
					//TODO Allow this x_length = 1 default to be changed in a setting somehow.
					CreateFloatInstr(.add, new_x_end_op, new_x_start_op, FImm(1), d=cd);
				}
				else {
					CreateCompErr(cd, .EVALUATION, node,
					"Invalid tano - tano(row,x)");
					return false;
				}

				//NOTE : tano is assumed tano(0,0) so we don't need to add an offset since it's already from 0.
				//ALSO we separate row and x offset so that if we don't have x then we don't do this
				if node.left.value.token_type != .KEYWORD_TANO {
					rel_tano_x_start_op : MusicOperand = AddOperandOffset(16, rel_tano_row_start_op);
					CreateFloatInstr(.add, new_x_start_op, rel_tano_x_start_op, d=cd);
					CreateFloatInstr(.add, new_x_end_op, rel_tano_x_start_op, d=cd);
				}
			} 
			else if var_nodes.count == 1 {
				//By default if we specify row and don't specify x, then we go x is 0..FLOAT64_MAX
				//TODO We can allow the player to do reverse by doing tano(0,FLOAT64_MAX..0) for example
				//once we implement constants in general, can make it simpler by doing F_MAX :: FLOAT64_MAX.
				PushStackMov(FImm(0), cd.float_type_info.runtime_size, cd);
				PushStackMov(FImm(FLOAT64_MAX), cd.float_type_info.runtime_size, cd);
			}

			node.code_ir.op = new_row_start_op;
			FreeReusableRegisters(rel_tano_row_start_op, *cd.all_registers);

			//TODO Pull this out and check if we have 3 args OR ",," once we implement that
			if var_nodes.count == 3 {
				//TODO This is a copy of the row code so maybe we could reuse it or maybe well change it later
				//so best to just leave it separate for now. NEVERMIND since we removed the mspace_end_op for now
				//so it's not the same since we only have 1 value.
				new_mspace_start_op : MusicOperand;
				// new_mspace_end_op : MusicOperand;
				if var_nodes[2].value.token_type == #char ":" {
					mspace_start_node := var_nodes[2].left;
					// mspace_count_node := var_nodes[2].right;
					if mspace_start_node == null || mspace_start_node.code_ir.t_info.type_enum != .INTEGER
						// mspace_count_node == null || mspace_count_node.code_ir.t_info.type_enum != .INTEGER
					{
						CreateCompErr(cd, .EVALUATION, node,
						"Invalid tano row count : tano(int:int");
						return false;
					}

					new_mspace_start_op = PushStack(mspace_start_node.code_ir.t_info.runtime_size, cd);
					left_mspace_start_op : MusicOperand = GetValueOpReuseReg(mspace_start_node, cd, true);
					CreateMInstr(.mov, new_mspace_start_op, left_mspace_start_op, Imm(mspace_start_node.code_ir.t_info.runtime_size), d=cd);

					// new_mspace_end_op = PushStack(mspace_count_node.code_ir.t_info.runtime_size, cd);
					// mspace_count_op : MusicOperand = GetValueOpReuseReg(mspace_count_node, cd, true);
					// //NOTE : If the row_count is negative, this is fine since we add a negative to the start.
					// //So start + (-count) = start - count and so end < start which is a row reversed tano.
					// CreateMInstr(.add, new_mspace_end_op, new_mspace_start_op, mspace_count_op, d=cd);
				} 
				else if var_nodes[2].value.token_type == .DOUBLE_DOT {
					mspace_start_node := var_nodes[2].left;
					// mspace_end_node := var_nodes[2].right;
					if mspace_start_node == null || mspace_start_node.code_ir.t_info.type_enum != .INTEGER
						// mspace_end_node == null || mspace_end_node.code_ir.t_info.type_enum != .INTEGER
					{
						CreateCompErr(cd, .EVALUATION, node,
						"Invalid tano row range : tano(int..int");
						return false;
					}

					new_mspace_start_op = PushStackMov(mspace_start_node, cd);
					// new_mspace_end_op = PushStackMov(mspace_end_node, cd);
				} 
				else if var_nodes[2] != null && var_nodes[2].code_ir.t_info.type_enum == .INTEGER {
					new_mspace_start_op = PushStackMov(var_nodes[2], cd);
					//NOTE : By default we push on the same mspace_start == mspace_end
					// new_mspace_end_op = PushStackMov(var_nodes[2], cd);
				} 
				else {
					CreateCompErr(cd, .EVALUATION, node,
					"Invalid tano mspace - eg valid is tano(row,x,mspace).");
					return false;
				}

				//NOTE : tano is assumed tano(0,0) so we don't need to add an offset since it's already from 0.
				//TODO Should we have relative tano for mspace_index as well?
				if node.left.value.token_type != .KEYWORD_TANO {
					rel_tano_mspace_start_op : MusicOperand = GetValueOpReuseReg(node.left, cd);
					CreateMInstr(.add, new_mspace_start_op, rel_tano_mspace_start_op, Imm(cd.int_type_info.runtime_size), d=cd);
					// CreateMInstr(.add, new_mspace_end_op, rel_tano_mspace_start_op, Imm(cd.int_type_info.runtime_size), d=cd);
				}
			} else {
				//Default case where we push on default mspace_start=.dfms and mspace_end=.dfms
				PushStackMov(RegMem(.dfms), cd.int_type_info.runtime_size, cd);
				// PushStackMov(RegMem(.dfms), cd.int_type_info.runtime_size, cd);
			}
		}

		node.code_ir.operand_type = .RAM_MEMORY;
		node.code_ir.t_info = *cd.tano_struct_info;
		node.code_ir.code_value_type = CodeValueType.L_VALUE;
		//Set this to avoid statements like "tano(0,0) := t0;" which should not be allowed since
		//the LHS is not declarable and is only a temporary stack value.
		//But since we can do "tano(0,0) ~= t0;" then we do it this way. Maybe checking the operation could be another way
		//but since we allow "tano(0,0) += 1;" as well this way seems better overall and can be reused for other similar structures later.
		node.code_ir.node_var_type = NodeVarType.NOT_DECLARABLE;
	} 
	else if node.left.value.token_type == .KEYWORD_SIZE_OF {
		if node.right.code_ir.ir_type != CodeIRType.DATA_TYPE_INFO {
			CreateCompErr(cd, .EVALUATION, node.left, "Invalid size_of type.");
			return false;
		}
		SetIntegerNode(node, node.right.code_ir.t_info.runtime_size, cd);
	} 
	else if node.left.value.token_type == .KEYWORD_NEW {
		//TODO After further consideration we can instantiate all types on the heap so i think this is the only check.
		if node.right.code_ir.ir_type != CodeIRType.DATA_TYPE_INFO {
			CreateCompErr(cd, .EVALUATION, node.left, "Invalid New type, New requires data type. (eg New(int))");
			return false;
		}

		node.code_ir.op = RamMem(.sbp, cd.byte_offset_from_sbp);
		node.code_ir.code_value_type = CodeValueType.R_VALUE;
		node.code_ir.t_info = GetOrCreateTypeInfoPointer(node.right.code_ir.t_info, cd);

		//Allocate memory in New
		CreateMInstr(.alloc, Imm(node.right.code_ir.t_info.runtime_size), RamMem(.sbp, cd.byte_offset_from_sbp), d=cd);
		//Increment stack by the pointer size
		AddByteOffsetFromSbp(node.code_ir.t_info.runtime_size, cd);
	} 
	else if node.left.value.token_type == .KEYWORD_NEW_ARRAY {
		//TODO Could also have NewResizableArray with a different start count for efficiency maybe.
		if node.right.value.token_type != #char "," {
			CreateCompErr(cd, .EVALUATION, node.left, "NewArray takes 2 arguments : NewArray(count:int,data_type).");
			return false;
		} else if node.right.left.code_ir.t_info.type_enum != TypeInfoTag.INTEGER {
			CreateCompErr(cd, .EVALUATION, node.right.left, "NewArray argument 1 should be count with integer type.");
			return false;
		} else if node.right.right.code_ir.ir_type != CodeIRType.DATA_TYPE_INFO {
			CreateCompErr(cd, .EVALUATION, node.right.right, "NewArray argument 2 should be array data type.");
			return false;
		}

		array_data_type : *TypeInfo = node.right.right.code_ir.t_info;
		//TODO If this is a constant, we could multiply it in the compiler.
		//That adds an extra case, so maybe we can do it later as an optimization once everything is tested and clearer.
		count_op : MusicOperand = node.right.left.code_ir.op;

		node.code_ir.op = RamMem(.sbp, cd.byte_offset_from_sbp);
		node.code_ir.code_value_type = CodeValueType.R_VALUE;
		node.code_ir.t_info = GetOrCreateArrayType(cd, array_data_type, ArrayInfoType.VIEW);

		//TODO UPDATE THIS TO USE .struct_members[i] in order once we do that in array_view_struct_info
		//Store (count,data) to pass up directly
		//DOC : Store count first, then multiply and alloc to the same memory value and then increment sbp so we keep it
		PushStackMov(count_op, cd.int_type_info.runtime_size, cd);
		//Compute the count (we don't store on the stack and just put the heap pointer in the same place)
		CreateMInstr(.mul, RamMem(.sbp, cd.byte_offset_from_sbp), Imm(array_data_type.runtime_size), count_op, d=cd);
		//Allocate memory and store heap pointer on the stack
		//NOTE : The current amount to allocate is at RamMem(scp) and we want to store the heap pointer back there
		//this way we only have to increment the heap size 1 time and so we have less instructions.
		CreateMInstr(.alloc, RamMem(.sbp, cd.byte_offset_from_sbp), RamMem(.sbp, cd.byte_offset_from_sbp), d=cd);
		AddByteOffsetFromSbp(cd.void_pointer_type_info.runtime_size, cd);
	} 
	else if node.left.value.token_type == .KEYWORD_NEW_RESIZABLE_ARRAY {
		//TODO Could also have NewResizableArray with a different start count for efficiency maybe.
		if node.right.value.token_type != #char "," {
			CreateCompErr(cd, .EVALUATION, node.left, "NewResizableArray takes 2 arguments : NewResizableArray(count:int,data_type).");
			return false;
		} else if node.right.left.code_ir.t_info.type_enum != TypeInfoTag.INTEGER {
			CreateCompErr(cd, .EVALUATION, node.right.left, "NewResizableArray argument 1 should be count with integer type.");
			return false;
		} else if node.right.right.code_ir.ir_type != CodeIRType.DATA_TYPE_INFO {
			CreateCompErr(cd, .EVALUATION, node.right.right, "NewResizableArray argument 2 should be array data type.");
			return false;
		}

		array_data_type : *TypeInfo = node.right.right.code_ir.t_info;
		//TODO If this is a constant, we could multiply it in the compiler.
		//That adds an extra case, so maybe we can do it later as an optimization once everything is tested and clearer.
		count_op : MusicOperand = node.right.left.code_ir.op;

		node.code_ir.op = RamMem(.sbp, cd.byte_offset_from_sbp);
		node.code_ir.code_value_type = CodeValueType.R_VALUE;
		array_type : *TypeInfoArray = GetOrCreateArrayType(cd, array_data_type, ArrayInfoType.RESIZABLE); 
		node.code_ir.t_info = *array_type.info;

		//TODO UPDATE THIS TO USE .struct_members[i] in order once we do that in resizable_array_struct_info
		//Store (count:int,data:*void,allocated:int,element_size:int) to pass up directly
		//array.count
		PushStackMov(count_op, cd.int_type_info.runtime_size, cd);
		//Compute the count (we don't store on the stack and just put the heap pointer in the same place)
		CreateMInstr(.mul, RamMem(.sbp, cd.byte_offset_from_sbp), Imm(array_data_type.runtime_size), count_op, d=cd);
		//Allocate memory and store heap pointer on the stack
		//NOTE : The current amount to allocate is at RamMem(scp) and we want to store the heap pointer back there
		//this way we only have to increment the heap size 1 time and so we have less instructions.
		//array.data
		CreateMInstr(.alloc, RamMem(.sbp, cd.byte_offset_from_sbp), RamMem(.sbp, cd.byte_offset_from_sbp), d=cd);
		AddByteOffsetFromSbp(cd.void_pointer_type_info.runtime_size, cd);

		//array.allocated = count * 2
		CreateMInstr(.mul, RamMem(.sbp, cd.byte_offset_from_sbp), Imm(2), count_op, d=cd);
		AddByteOffsetFromSbp(cd.int_type_info.runtime_size, cd);

		//array.element_size
		PushStackMov(Imm(array_type.element_type.runtime_size), cd.int_type_info.runtime_size, cd);
	} else {
		//TODO Be careful with main function, although we should never call it anyways and end on a HALT instruction.
		/*NOTE We push all the function arguments sequentially before arriving here in the "," evaluation 
		unless we have 1 argument and then we do it here. This way if we have a variable or expression we push
		it on the stack as a function argument sequentially and then if we have a function call, we just push let
		it gets pushed here and we don't have to do anything and don't disrupt the flow of evaluation.
		More notes on this are in the "," evaluation in the function call "(" check.

		IMPORTANT NOTE
		For now we will only allow function calls like x,y := foo(); to return multiple values.
		We could allow operator overloads but I will keep that to single value returns for now for simplicity.
		Allow multiple values everywhere really is a combinatorial explosion that seems very confusing programming-wise.
		In jai this does not work either with multi return values only using the first value in practice
		(should ask a question about this here since there may be a bug with the example in quicktest).
		Therefore the case like x,y,z = foo(), foo1(), foo2(); would disregard multiple return values and only
		deal with 1 single value. That case may require storing on the stack anyways for things like
		x,y := foo() + 1 * foo(2) + 12, foo1(). Maybe we just don't allow multiple assignment like that
		and only allow single operations on the RHS. Or something like that... I've never really used multiple
		assignment for anything else than the rare error returned for functions so maybe we only allow it in that case anyways.
		*/

		/*
		if (node.parent == "=" && node.parent.left == ":") || (node.parent != "=") {
			STORE NEW VARIABLE ON THE STACK and if we have ":"-"=" then reuse it in the "=" evaluation
		}
		(Note : for each return value created on the stack, 
		specifically function calls, operator overloads and operators not stored on the stack,
		we want to keep these on the stack so they can be used on the return,
		specifically if they will be reused like foo(x + foo1()), we would need to store the result of
		foo1 so we can do x + foo1() and if that "+" is an operator overload, then we would need
		to store the result of "x + foo1()" on the stack so we can us it in foo(x + foo1()),
		so we create these ahead of time so then the function will use that space as normal
		and then we only reset up until this point as shown below)
		

		push_all_stack_reg
		push sbp ([sbp,-16] is the previous function sbp)
		add reg, ip, after_call_index
		push reg ([sbp,-8] is the value we jmp back to after this function call instruction)
		mov sbp, scp

		//TODO Should we do argument and then return or vice-versa?
		push x
		push y
		... (Note : for each argument
		specifically, pass by value if <= 8 bytes and pass by pointer if > 8 bytes,
		maybe this can be optimized later)

		push ret_pointer_0
		push ret_pointer_1
		...(Note : for each return value we put a pointer here so we can use it within the function,
		for example x,y = foo() where x,y already have memory somewhere, we would just reuse that then and
		just push the pointers in here so they would be used as pointers.
		for x,y := foo() OR foo() + z we would have created x,y OR foo() first return value 
		on the stack beforehand and then put pointers here so that they get cleared at the end of the function)

		call foo

		mov scp, sbp
		pop sbp
		pop_all_stack_reg

		**********
		NEW FUNCTION (Best to look at Test_CompileFunc)
		- return values are added with AddByteOffsetFromSbp since those will stay on the stack they count for max sbp
		- push_all_stack_reg to save previous procedures stack values (including sbp and scp are store here)
		- push arguments onto the next stack based on last stack to starting on [sbp+PRE_PROC_STACK_SIZE]
		- set the new sbp using [sbp+PRE_PROC_STACK_SIZE]
		- move the the instr_index after call to [sbp-8]
		- pop_all_stack_reg from PREVIOUS_SBP_OP directly so we skip over sbp-8 instr_index AND we get back sbp and scp
		**********
		MEMORY LOOKS LIKE
		PRE_PROC_STACK
     [sbp-PRE-r1.size-r0.size] [sbp-PRE-r1.size] [sbp-PRE_PROC_STACK_SIZE] [sbp-8]
		return_0,                return_1,         push_all_stack_reg,       post_call_instr_index, 

		PROC_STACK
		[sbp+0] [sbp+arg_0_size], ...
		arg_0,  arg_1, ... stack within function call
		*/

		//Note : First we validate function types so we can get the function declaration in case of function overloads.
		assert(node.left != null);
		is_func_pointer : bool = false;
		proc_type : *TypeInfoProcedure;
		func_decl : FunctionDeclaration;
		found_function : bool = false;
		comma_node_start_index : int;
		argument_nodes : [] *BinaryNode = CommaNodeArrayEmptyToken(node.right, #char ")", cd);
		for argument_nodes if !AllOrEquals(it.code_ir.code_value_type, .[.L_VALUE,.R_VALUE]) {
			CreateCompErr(cd, .EVALUATION, it,
			sprint("Invalid function argument \"%\".\n", it.value.token_string));
			return false;
		}
		if node.left.code_ir.ir_type == .FUNCTION_NAME {
			//TODO IF there are no overloads for this function, then we can just get the func_decl directly
			//but since we have to go through anyways, we do this for now. If we have a hashmap later
			//or can store the value somewhere, then maybe we can use that. I guess we could
			//store the value in the ir_data_id...
			//If we use a hash map later for function declaration, then we can just get that directly by name
			for fd : cd.all_function_declarations if fd.name == node.left.value.token_string {
				valid_func_args := ValidFuncArgs(fd.t_info_proc, argument_nodes);
				if valid_func_args {
					found_function = true;
					func_decl = fd;
					proc_type = func_decl.t_info_proc;
					break;
				}
				/*NOTE : Technically we are not allowing overloaded functions by name yet but
				  this shows how we would start since the type would be resolved and then we would
				  have to adjust the operand for it afterwards in case we have not evaluated the function yet.

				  IF WE DON'T ALLOW function name with overloads, THEN WE CAN SET THIS BACK and remove this altogether.
				  That might be the best way for now to discourage function overloads in general.
				*/
				// valid_type : bool = CheckNodeTypeInfo(argument_nodes[it_index], it, cd);
				// if !valid_type continue fd;
			}		
		} 
		else {
			//We have a function pointer so we need to check based on the procedure type directly.
			is_func_pointer = true;
			proc_type = cast(*TypeInfoProcedure) node.left.code_ir.t_info;
			#if 0 {
			check_type : bool = proc_type.argument_types.count == argument_nodes.count;
			if check_type for proc_type.argument_types {
				check_type &&= argument_nodes[it_index].code_ir.t_info == it;
			}
			} else {
			found_function = ValidFuncArgs(proc_type, argument_nodes);
			}
			/*DOC : Need to set the .fp reg here so we can still use the function pointer on the call.
			Otherwise we lost the current stack var when we reset the sbp.
			We do it before pushing all stack reg so we can still have it later if needed.
			*/
			CreateMInstr(.mov, RegMem(.foop), node.left.code_ir.op, Imm(cd.void_pointer_type_info.runtime_size), d=cd);
		}
		//TODO Would have to recheck the argument_nodes here for FunctionName and resolve function overloads
		//here with instructions if we did not evaluate the function yet.

		if !found_function {
			CreateCompErr(cd, .EVALUATION, node.left,
			sprint("Function not found for call \"%\".", node.left.value.token_string));
			return false;
		}

		cfcd : CompFuncCallData;
		cfcd.node = node;
		cfcd.argument_nodes = argument_nodes;
		cfcd.func_decl = func_decl;
		cfcd.is_function_pointer = is_func_pointer;
		cfcd.proc_type = proc_type;

		success := CompileFunctionCall(cfcd, cd);
		if !success return false;

		//Shorten the comma node stack now that we have generated the instructions for the function call
		cd.comma_node_stack.count = comma_node_start_index;
	}
	}
	case .KEYWORD_CAST; {
		//Sanity check can remove or return error eventually but this should be checked at parse level anyways.
		assert(node.left && node.right);

		//Casting is grabbing the type of the left node and the op of the right node.
		//See Test_ParseCast for examples of cast tree structure.
		node.code_ir = node.right.code_ir;
		//Set t_info after to override with left type
		node.code_ir.t_info = node.left.code_ir.t_info;	
		
		cast_type : TypeInfoTag = node.left.code_ir.t_info.type_enum;
		value_type : TypeInfoTag = node.right.code_ir.t_info.type_enum;
		if node.left.code_ir.t_info == node.right.code_ir.t_info {
			//Explicitly do nothing since we have the same type
		}
		// else if cast_type == .ARRAY && value_type == .ARRAY &&
		// 	(cast(*TypeInfoArray) node.left.code_ir.t_info).array_type == .VIEW &&
		// 	(cast(*TypeInfoArray) node.right.code_ir.t_info).array_type == .FIXED
		else if IsArrayInfoType(.VIEW, node.left.code_ir.t_info) && IsArrayInfoType(.FIXED, node.right.code_ir.t_info){
			//We push an array view of the fixed array on the stack and set this node to that array view.
			//NOTE : We could make this a function with other fixed to array view casting but maybe it's
			//not worth it if we only do it here and when we assign the variable from fixed to view.
			//I think autocasting to array view should ONLY be done for function input vars.
			fixed_array_type := cast(*TypeInfoArray) node.right.code_ir.t_info;
			node.code_ir.op = PushStackMov(Imm(fixed_array_type.array_count), cd.int_type_info.runtime_size, cd);
			array_data_op := PushStack(cd.void_pointer_type_info.runtime_size, cd);
			SetAddressNode(node.right, array_data_op, cd);
		}
		else if cast_type == .INTEGER && value_type == .FLOAT {
			node.code_ir.op = PushStack(node.code_ir.t_info.runtime_size, cd);
			CreateMInstr(.ftoi, node.code_ir.op, node.right.code_ir.op, d=cd);
		} 
		else if cast_type == .FLOAT && value_type == .INTEGER {
			node.code_ir.op = PushStack(node.code_ir.t_info.runtime_size, cd);
			CreateMInstr(.itof, node.code_ir.op, node.right.code_ir.op, d=cd);
		} 
		else if (cast_type == value_type) ||
			(cast_type == .POINTER && value_type == .POINTER) ||
			(cast_type == .INTEGER && value_type == .BOOL) ||
			(cast_type == .BOOL    && value_type == .INTEGER) ||
			(cast_type == .INTEGER && value_type == .ENUM) ||
			(cast_type == .ENUM    && value_type == .INTEGER)
		{
			//Explicitly putting all default cases here
		} 
		else {
			CreateCompErr(cd, .EVALUATION, node,
			sprint("Cannot cast from % to %.", value_type, cast_type));
			return false;
		}
	}
	case #char "."; {
		//TODO This is likely an InternalError so can possibly leave as an assertions or log.
		//TODO This can also be checked at the parser level
		assert(node.left != null && node.right != null);
		//We removed this because for fixed_array.count, that is known at compile-time and gets passed up
		//as an immediate integer.
		// assert(node.right.code_ir.op.operand_type == .RAM_MEMORY);
		//We only pass the node up now since we compute member access at the member node
		//so that we can pass up the chain if we have an array or dereference.
		node.code_ir = node.right.code_ir; 

		/*DOC : This should be set elsewhere due to different cases such as
			1) enum - EnumType.enum_value - is r_value
			2) struct - s.s_member - is l_value
			3) array 
				- arr.count is l_value
				- arr.data is l_value for fixed and r_value for view
				- arr.data[0] is r_value for .data but then [ binary op sets the [ node to l_value
		*/
		// if node.code_ir.code_value_type == .NONE {
			// node.code_ir.code_value_type = .L_VALUE;
		// }
	}
	case #char ","; {
		/*TODO IMPORTANT I think maybe we can skip over this entirely now that we use CommaNodeArray instead
		and then we can just remove the comma_node_stack altogether. I will leave here for now but once
		we switch all "," use cases to the CommaNodeArray, then we can remove it.
		*/
		/*TODO FOR FUNCTION TYPES we would check here if the parent all the way up is instead a RIGHT_ARROW
		and then we could either accumulated the nodes or just check at the RIGHT_ARROW but in any case
		it would be different since it's just a type and so we would need to associate the correct TypeInfoProcedure
		and then be able to assign function pointers to this value so we can use function pointers!
		*/

		//TODO NEED TO DO LHS AND RHS difference here, so if we have "," on lhs then each value
		//must either be known in memory if we dont have ":" as parent, and if we do have a ":" as parent,
		//then we want each value to be unidentified. Anything else other than MEMORY_VALUE or UNIDENTIFIED
		//would then need to give a CompilerError. Then we can compare CommaNode list at the "=" depending.
		//Also we need to parse LHS first since if the RHS requires pointers for functions, we would want
		//to know what that is beforehand.

		//TODO Maybe this should be checked with node_ids instead of pointers...
		//Can maybe add an == operator that checks based on node_id instead of pointers to avoid pointer issues...
		//TODO Should this be a function since we reuse here and for "."
		top_comma_node : *BinaryNode = node;
		// while top_comma_node.parent != null && top_comma_node == top_comma_node.parent.left {
		while top_comma_node.parent != null && top_comma_node.parent.value.token_type == #char "," {
			top_comma_node = top_comma_node.parent;
		}
		list_token_type : CodeTokenType;
		if top_comma_node.parent != null {
			list_token_type = top_comma_node.parent.value.token_type;
			// l_node = l_node.parent;
		}
		//TODO We could validate that the list_token_type is valid for "," separate value list.

		//TODO Can probably remove this note. Will leave until we do STRUCT_LITERAL just in case.
		/*It seems like ARRAY_LITERAL, STRUCT_LITERAL and also "," for function calls "(" will all be the same
		and just push the values to the stack and then store the values which can be used later and then cleared
		SO we may be able to generalize it but only once we implement STRUCT_LITERAL as well to make sure.
		If so then we can pull the push functions and the CommaNode and then reset comma_node_stack on each list node.
		Then we can use the enum below to do any extra specific things like CreateOpenFunctionInstrs and 
		passing up the type for .ARRAY_LITERAL

		TODO This may be the same as .ARRAY_LITERAL below EXCEPT the code_ir.op and the code_ir.t_info
		could be set explicitly for this case in case we need it. Likely STRUCT_LITERAL would be different
		So once we do STRUCT_LITERAL here then we can pull out the stack pushing with CommaNode if they
		all have that in common and then 
		*/
		//TODO ParserError different cases for "," should be checked at th parser level for whether we should
		//have right and left nodes and what they should be like if node.left == "," then node.right != null
		if list_token_type == {
		// case .STRUCT_LITERAL;
		// case .ARRAY_LITERAL; {
		// 	#if 0 {
		// 	if node.left.code_ir.t_info != node.right.code_ir.t_info {
		// 		array_add(*cd.comp_errors.all_compiler_errors, MakeCompErr(.EVALUATION,
		// 			sprint("Not same types for array literal % and %.", node.left.*, node.right.*,,context.allocator)));
		// 		return false;
		// 	}

		// 	//We want to pass up the starting op so we can get the starting point
		// 	if node.left.value.token_type != #char "," {
		// 		node.code_ir.op = RamMem(.sbp, cd.byte_offset_from_sbp);
		// 	} else {
		// 		//Carry the initial op of the array literal up the "," tree since that will be
		// 		//where the fixed array starts on the stack.
		// 		node.code_ir.op = node.left.code_ir.op;
		// 	}

		// 	node.code_ir.t_info = node.left.code_ir.t_info;
		// 	}

		// 	//TODO make sure this is working for functions but also array literals should be checked
		// 	//for fixed arrays like b : [4] int = int.[0,1,2,3]
		// }
		case; {
			//Comma is on lhs so it is an l_value. We are not allowing rhs commas right now.
			node.code_ir.code_value_type = .L_VALUE;
		}
		}

		if node.left.value.token_type != #char "," {
			array_add(*cd.comma_node_stack, CommaNode.{top_comma_node,node.left,0});
		}

		next_index : int = peek_pointer(cd.comma_node_stack).input_index + 1;
		array_add(*cd.comma_node_stack, CommaNode.{top_comma_node,node.right,next_index});

		//TODO We could also accumulate and update the parent on the way up the tree here
		//and do index based on how many nodes we already found. It would result in the same thing though... hmmm
		//TODO If we don't use this for the input function stack then we can remove it
		#if 0 {
		//TODO We can remove this now because of stack but i'll leave it here in case until we test.
		input_index : int = 1;
		node_check := node;
		while node_check.left.value.token_type == #char "," {
			input_index += 1;
			node_check = node_check.left;
		}
		}
	}
	case .ARRAY_LITERAL; {
		//TODO ParserError - this should be checked by the parser
		assert(node.right != null);
		array_element_info : *TypeInfo;
		if node.left != null && node.left.code_ir.ir_type == .DATA_TYPE_INFO && node.left.code_ir.t_info != null {
			array_element_info = node.left.code_ir.t_info;
		}

		node.code_ir.op = RamMem(.sbp, cd.byte_offset_from_sbp);
		node.code_ir.code_value_type = CodeValueType.R_VALUE;
		// var_nodes : [] *BinaryNode = CommaNodeArray(node, cd);
		var_nodes : [] *BinaryNode = CommaNodeArrayEmptyToken(node.right, #char "]", cd);
		array_count : int = var_nodes.count;
		for var_nodes {
			//TODO Can this check be better? If there is no type or the type does not match the infered type then it is invalid.
			//TODO We could make this PushStackMovWithAutocast function if we reuse it elsewhere.
			stack_op := PushStack(it.code_ir.t_info.runtime_size, cd);
			success := MovWithAutocast(it, array_element_info, stack_op, cd);
			if !success {
				CreateCompErr(cd, .EVALUATION, node, sprint("Invalid array literal value %.\n", node.*));
				return false;
			}
		}

		//TODO Maybe we should make this array view and remove fixed altogether.
		array_info : *TypeInfoArray = GetOrCreateArrayType(cd, array_element_info, ArrayInfoType.FIXED, array_count);
		node.code_ir.t_info = *array_info.info;
		//TODO Could set the code_ir_type here as well but I think we have enough info the type info and op
	}
	case .STRUCT_LITERAL; {
		//TODO ParserError - should we check this in the parser instead?
		//Could just check in both places for resilience.
		if node.right == null || node.left == null {
			CreateCompErr(cd, .EVALUATION, node, "Invalid struct literal.");
			return false;
		}
		if node.left.code_ir.ir_type != .DATA_TYPE_INFO ||
			!AllOrEquals(node.left.code_ir.t_info.type_enum, STRUCT_TYPE_INTERNAL) 
		{
			CreateCompErr(cd, .EVALUATION, node, "Not struct type.");
			return false;			
		}

		struct_info := cast(*TypeInfoStruct) node.left.code_ir.t_info;
		node.code_ir.op = RamMem(.sbp, cd.byte_offset_from_sbp);
		node.code_ir.code_value_type = CodeValueType.R_VALUE;
		node.code_ir.t_info = cast(*TypeInfo) struct_info;
		//TODO Could set the code_ir_type here as well but I think we have enough info the type info and op

		/*DOC : By default, we initialize the struct data to 0 if we have an empty struct literal.
	  	So this deals with the case if we have an empty struct literal (s.{}) automatically.
		Then we set each member individually based on the offset in bytes for both the equals and non-equals cases.			

		TODO If we have struct default eventually we can just store them in constant memory and then 
		copy that here with const_mov and store the struct default constant memory somewhere based on struct name since it is unique.
		*/
		PushStack(struct_info.runtime_size, cd);
		CreateMInstr(.mset, node.code_ir.op, Imm(0), Imm(struct_info.runtime_size), d=cd);

		if node.right.value.token_type != #char "}" {
			/*DOC : >= 1 values, so node.right is a "," if we have > 1 value.
			We check for an = node and if we find one then we split them otherwise we just use the non-equals nodes
			and check if they are all there an then compile them and check for types.
			So if we find nodes with = then we will process both arrays, if not, then we will only process
			no_equals nodes and for now that needs to be the same size as struct_members.

			TODO We could add autocasting in here overall when we check for the types. 
			Particularly from int to float and potentially for array view eventually if we do fixed array or resizable array.
			Autocasting would likely be similar to array literals so there might be some overlap there and we could
			put some generalized code somewhere to do auto casting although maybe we should just do that with int to float
			and maybe array views later on.
			*/
			// var_nodes : [] *BinaryNode = CommaNodeArrayEmptyToken(node.right, #char "}", cd);
			struct_mem_nodes : [] *BinaryNode = NewCommaNodeArray(node.right, cd);
			found_node_with_equals : bool = false;
			equal_start_index : int;
			for struct_mem_nodes if it.value.token_type == #char "=" {
				found_node_with_equals = true;
				equal_start_index = it_index;
				break;
			}

			no_equals_nodes : [] *BinaryNode = struct_mem_nodes;
			nodes_with_equals : [] *BinaryNode;
			if found_node_with_equals {
				no_equals_nodes = array_view(struct_mem_nodes, 0, equal_start_index);
				/*DOC : We found node with equals eg .{x=3} and we parse that and if we find one without afterwards
				that is an error like .{x,y,z=4,q}, the q would be an error so we can only start without = and then end with equals.
				Since we go from the first = index we find to the end, then if there is a node without =, then we error out.
				*/
				nodes_with_equals = array_view(struct_mem_nodes, equal_start_index);
				for eq_node : nodes_with_equals {
					if eq_node.value.token_type != #char "=" {
						CreateCompErr(cd, .EVALUATION, eq_node, 
						"Cannot have non-\"=\" after \"=\" struct member assigment.");
						return false;						
					}
					//TODO Should check that this works on parsing as well.
					if eq_node.right == null || eq_node.left == null {
						CreateCompErr(cd, .EVALUATION, eq_node, 
						"Invalid struct member with assignment.");
						return false;
					}
				}
			} else {
				/*DOC : We check here that we have all values for the struct in the literal.
				We could not do this and then the default (currently 0) would be left for those values.
				For now we will check it like this as this is how jai does it and it seems like this was
				chosen to avoid forgetting variables unless there are expliclit defaults which we have not added yet.
				So we could add those eventually and then do it like that OR also allow 0 defaults if people prefer eventually.
				*/
				if no_equals_nodes.count != struct_info.struct_members.count {
					CreateCompErr(cd, .EVALUATION, node, 
					"Not enough values provided in this struct literal.");
					return false;					
				}
			}

			for literal_node : no_equals_nodes {
				member_info : TypeInfoStructMember = struct_info.struct_members[it_index];
				member_op := AddOperandOffset(member_info.offset_in_bytes, node.code_ir.op);
				success := MovWithAutocast(literal_node, member_info.t_info, member_op, cd);
				if !success {
					CreateCompErr(cd, .EVALUATION, literal_node, 
					sprint("Invalid struct member type : %\n", member_info.name));
					return false;					
				}
			}

			for eq_node : nodes_with_equals {
				found_member_info : bool = false;
				member_info : TypeInfoStructMember;
				for struct_info.struct_members if it.name == eq_node.left.value.token_string {
					found_member_info = true;
					member_info = it;
					break;
				}
				if !found_member_info {
					CreateCompErr(cd, .EVALUATION, eq_node, 
					sprint("Struct member not found : %\n", eq_node.left.value.token_string));
					return false;			
				}

				member_op := AddOperandOffset(member_info.offset_in_bytes, node.code_ir.op);
				success := MovWithAutocast(eq_node.right, member_info.t_info, member_op, cd);
				if !success {
					CreateCompErr(cd, .EVALUATION, eq_node.right, 
					sprint("Invalid struct member type : %\n", member_info.name));
					return false;					
				}
			}
		}
	}
	//TODO Since this is a binary operator, we can just put with the other ones I think
	//Also remove the UNARY_OP since we don't use "[" as a unary op
	case #char "["; {
		//TODO This UNARY "[" should be replace with BINARY_OP ".[" and lexed appropriately.
		//Same should be done for struct literal token ".{"
		//TODO We are doing that now with .ARRAY_LITERAL so I think we can remove this case as
		//there is no unary "[" operator anymore
		if node.code_ir.ir_type == CodeIRType.UNARY_OP {
			//TODO Should we use a switch here?
			node.code_ir.operand_type = node.right.code_ir.operand_type;
			if node.right.value.token_type == #char "," {
				//TODO Can make a function that updates all NodeValue value_id to the given node_id.
				for * cd.all_node_values if it.value_id == node.right.node_id {
					it.value_id = node.node_id;
				}
			} else {
				//TODO array literal error
			}
		} else if node.code_ir.ir_type == CodeIRType.BINARY_OP {
			//Array variables
			//TODO CompilerError/ParserLevel (probably can check at the parser level for left and right)
			assert(node.left != null && node.right != null);

			node.code_ir.code_value_type = CodeValueType.L_VALUE;

			//TODO Should this be a separate data_type with its own type info?
			//It would allow us to do type checking...
			if node.left.code_ir.ir_type == .DATA_IR_MUNIT {
				//TODO CompilerError (only allowed int for now but may allow floats later as well for rhythm... not sure)
				assert(node.right.code_ir.t_info == *cd.int_type_info);

				//Carry over previous music_unit node so we keep track of all the data.
				node.code_ir = node.left.code_ir;

				/*TODO Should this be like this tano[0][0] or is tano[0,0] better?
				It is one less character but which one is clearer and more consistent with the rest of the code?
				Right now this is tano[0][0] since that is how arrays are normally.
				tano[0,0] would also be something that differentiates it from typical ram memory arrays
				COULD ALLOW BOTH and then remove one later if there's a preference
				POINTS FOR tano[0,0]
					- 1 less character
					- it looks cleaner
					- it is different from typical 2d arrays [0,0] vs [0][0]
				*/
				if node.left.value.token_type == {
				case .DATA_MUNIT;
					//We are processing the row element of the music memory
					if node.right.code_ir.op.operand_type == {
					case .RAM_MEMORY;
						reg := OLDGetOrReuseRegister(node.right, cd);
						CreateMInstr(.mov, RegMem(reg), node.right.code_ir.op, Imm(8), d=cd);
						node.code_ir.op.values[0].type = .REGISTER;
						node.code_ir.op.values[0].int_value = cast(int) reg;
					case .REGISTER; #through;
					case .INTEGER;
						node.code_ir.op.values[0] = node.right.code_ir.op.values[0];
					case;
						//TODO CompilerError (could be InternalError if I set it wrong... in any case, it's a problem)
						assert(false, "Invalid music unit access type on node : %\n", node.right.*);
					}
				case #char "[";
					/*TODO This is a copy paste from above but I will leave it separate since I want to implement
					a ".." syntax after for the second music access so we can have an x-range with simple syntax.
					LIKELY PUT SECOND VALUE OR RANGE IN A SEPARATE TABLE so we don't have to bloat the CodeNode data.
					WE CAN CLEAR THAT TABLE AFTER EVERY LINE OF CODE FOR EXAMPLE SINCE WE WON'T REUSE IT I THINK.
					*/
					//We are processing the x element of the music memory
					if node.right.code_ir.op.operand_type == {
					case .RAM_MEMORY;
						reg := OLDGetOrReuseRegister(node.right, cd);
						CreateMInstr(.mov, RegMem(reg), node.right.code_ir.op, Imm(8), d=cd);
						node.code_ir.op.values[1].type = .REGISTER;
						node.code_ir.op.values[1].int_value = cast(int) reg;
					case .REGISTER; #through;
					case .INTEGER;
						node.code_ir.op.values[1] = node.right.code_ir.op.values[0];
					case;
						//TODO CompilerError (could be InternalError if I set it wrong... in any case, it's a problem)
						assert(false, "Invalid music unit access type on node : %\n", node.right.*);
					}
				case;
					//TODO ParseError (Can likely be caught at the parser level)
					assert(false, "Invalid left child of music access node % : %\n", node.*, node.left.*);
				}
			} else {
				//TODO NOTE : I think this should go with the other binary ops
				//That makes sense since then we could allow overriding eventually 
				//although in general the functionality is different from other binary ops
				a_types := TypeInfoTag.[node.left.code_ir.t_info.type_enum, node.right.code_ir.t_info.type_enum];
				if ArraysFixedEqual(a_types, .[.ARRAY, .INTEGER]) || 
					ArraysFixedEqual(a_types, .[.POINTER, .INTEGER])
				{
					//NOTE : explicit valid cases for array access
				} else {
					CreateCompErr(cd, .EVALUATION, node, 
					sprint("Invalid array access types left : %, right : %.", a_types[0], a_types[1]));
					return false;
				}

				//If we already stored the address in memory then we can just keep using that value.
				//I think this works overall. This was a case found in Test_CompileMultiArray
				//eg f[1][2], when we get the second array access then the left node is already set
				//to ADRESS_IN_MEMORY so we reuse that here and continue.
				//TODO I Think we can just pull this out and reuse it for all arrays if we have multi-dimensional
				//array so taht we reuse where we stored the memory.
				//TODO Could also check that node.left.value == "[" if that helps as well but this should also
				//work the same for pointers so maybe best to pull it out entirely.
				//DOC : MAYBE WE JUST DONT ALLOW MULTI DIMENSIONAL ARRAYS FOR NOW This makes the multi dimnesional array fail
				// if node.left.code_ir.node_op_type == .ADDRESS_IN_MEMORY && node.left.value.token_type == #char "[" {
				if node.left.code_ir.node_op_type == .ADDRESS_IN_MEMORY && node.left.value.token_type != .POSTFIX_DEREFERENCE {
					//NOTE : This is to pass up the address which is already in memory in the case of 
					//pointers already in memory and multi-dimensional arrays.
					node.code_ir.op = node.left.code_ir.op;
				} else {
					//NOTE : This is the case where we are accessing a single dimensional array
					//NOTE : Pointers are always 8 bytes. Maybe there is a better way to get this.
					node.code_ir.op = PushStack(8, cd);
					if node.left.code_ir.t_info.type_enum == {
					case .POINTER;
						CreateMInstr(.mov, node.code_ir.op, node.left.code_ir.op, Imm(node.left.code_ir.t_info.runtime_size), d=cd);
					case .ARRAY;
						array_info := cast(*TypeInfoArray) node.left.code_ir.t_info;
						if array_info.array_type == {
						case .RESIZABLE; #through;
						case .VIEW;
							SetAddressNode(node.left, RegMem(.ax), cd);
							CreateMInstr(.add, RegMem(.ax), Imm(8), d=cd);
							CreateMInstr(.mov, node.code_ir.op, RamMem(.ax), d=cd);
						case .FIXED;
							SetAddressNode(node.left, node.code_ir.op, cd);
							// op_0, op_1 := GetMemoryAddressAsOperands(node.left.code_ir.op);
							// CreateMInstr(.add, node.code_ir.op, op_0, op_1, d=cd);
						}
					}
				}

				value_type : *TypeInfo;
				if node.left.code_ir.t_info.type_enum == {
				case .POINTER;
					pointer_info := cast(*TypeInfoPointer) node.left.code_ir.t_info;
					value_type = pointer_info.pointer_to;
				case .ARRAY;
					array_info := cast(*TypeInfoArray) node.left.code_ir.t_info;
					value_type = array_info.element_type;
				}
				CreateMInstr(.mul, RegMem(.ax), node.right.code_ir.op, Imm(value_type.runtime_size), d=cd);
				CreateMInstr(.add, node.code_ir.op, RegMem(.ax), d=cd);
				
				node.code_ir.ir_type = .STACK_VARIABLE; //TODO Change this name to .MEMORY_VARIABLE for heap memory
				node.code_ir.t_info = value_type;
				node.code_ir.node_op_type = .ADDRESS_IN_MEMORY; 
			}
		} else if node.code_ir.ir_type == CodeIRType.DATA_TYPE_INFO {
			//TODO CompilerError (could likely do this at parser level as well).
			assert(node.left != null);
			array_type : ArrayInfoType;
			array_count : int = -1;
			//TODO CompilerError (this can definitely be checked at parser level)
			assert(node.right != null);
			if node.right.value.token_type == {
			case #char "]";   array_type = .VIEW;
			case .DOUBLE_DOT; array_type = .RESIZABLE;
			case; {
				if !(IsConstant(node.right) && node.right.code_ir.t_info.type_enum == .INTEGER) {
					CreateCompErr(cd, .EVALUATION, node, "Fixed array requires constant integer size.");
					return false;
				}
				array_count = node.right.code_ir.op.values[0].int_value;
				array_type = .FIXED;
			}
			}

			array_info : *TypeInfoArray = GetOrCreateArrayType(cd, node.left.code_ir.t_info, array_type, array_count);
			node.code_ir.t_info = *array_info.info;
		}
	}
	case .KEYWORD_FOR; {
		//TODO Check this at ParserLevel
		assert(node.right != null);
		assert(cd.all_for_loop_data.count > 0);
		fld : *ForLoopData = peek_pointer(cd.all_for_loop_data);
		
		if node.right.value.token_type == .DOUBLE_DOT {
			dots_node := node.right;
			right_valid : bool = CheckValidNode(dots_node.right, dots_node, cd);
			if !right_valid return false;
			left_valid : bool = CheckValidNode(dots_node.left, dots_node, cd);
			if !left_valid return false;

			//TODO Keep this here in case we allow other types in for loop range later
			// valid_for_range :: TypeInfoTag.[.INTEGER];
			// if !AllOrEquals(dots_node.left.code_ir.t_info.type_enum, valid_for_range) ||
			//  	!AllOrEquals(dots_node.right.code_ir.t_info.type_enum, valid_for_range)
		 	// {
			if dots_node.left.code_ir.t_info.type_enum != .INTEGER || dots_node.right.code_ir.t_info.type_enum != .INTEGER {
				CreateCompErr(cd, .EVALUATION, node, "Invalid for loop range type must be integer.");
				return false;
			}
			if fld.is_pointer {
				CreateCompErr(cd, .EVALUATION, node, "Cannot have pointer range for loop.");
				return false;				
			}

			//Start of for loop check if range is still good
			index_var : *VariableData = CreateStackVarData(cd, fld.value_name, *cd.int_type_info);
			right_op : MusicOperand = GetValueOp(dots_node.right, cd, .r0);
			left_op : MusicOperand = GetValueOp(dots_node.left, cd, .r1);
			check_reg : MusicOperand = RegMem(.ax);
			// post_op : OpCode;
			if fld.is_reverse {
				CreateMInstr(.add, index_var.op, right_op, Imm(1), d=cd);
				CreateMInstr(.sub, index_var.op, Imm(1), d=cd);
				CreateMInstr(.cgte, check_reg, index_var.op, left_op, d=cd);
				// post_op = OpCode.sub;
			} else {
				CreateMInstr(.sub, index_var.op, left_op, Imm(1), d=cd);
				CreateMInstr(.add, index_var.op, Imm(1), d=cd);
				CreateMInstr(.clte, check_reg, index_var.op, right_op, d=cd);
				// post_op = OpCode.add;
			}
			//Set here so we restart from the comparison operator
			jmp_instr_index : int = cd.all_music_instructions.count-2;

			CreateMInstr(.fjmp, Imm(0), check_reg, d=cd);
			ctrl_fjmp : *ControlFjmps = array_add(*cd.all_control_fjmps);
			ctrl_fjmp.instr_index = cd.all_music_instructions.count-1;
			ctrl_fjmp.scope_index = cd.open_scope_stack.count-1;

			//TODO Can remove this if we only have 2 post_loop_instrs
			fld.post_instr_count = 1;
			//Increment/decrement instruction
			//Notes on why we put this at beginning of the loop instead in for array case below
			// fld.post_loop_instrs[0] = MakeMusicInstruction(post_op, index_var.op, Imm(1));
			//Jmp back to start of loop comparison check
			fld.post_loop_instrs[0] = MakeMusicInstruction(.jmp, Imm(jmp_instr_index));

		} else {
			//We have an array or music memory (not implementing music memory for now since we can convert tano to arrays)
			// valid_for_iter :: TypeInfoTag.[.ARRAY,.MUSIC_UNIT];
			valid_for_iter :: TypeInfoTag.[.ARRAY];
			if !AllOrEquals(node.right.code_ir.t_info.type_enum, valid_for_iter) {
				CreateCompErr(cd, .EVALUATION, node,
				sprint("Invalid for iterator type. Must be one of %\n", valid_for_iter));
				return false;
			}

			if node.right.code_ir.t_info.type_enum == {
			case .ARRAY; {
				array_info := cast(*TypeInfoArray) node.right.code_ir.t_info;
				//restricted var for loop so we can't update it unless it's a pointer for loop
				//NOTE : It is easier to implement and clearer for player if we do pass by value here directly.
				//WE are doing pass by value now and will likely keep that way unless we have a reason to optimize without.
				// var_type := VariableType.RESTRICTED_INPUT;
				value_type : *TypeInfo = array_info.element_type;
				if fld.is_pointer {
					value_type = GetOrCreateTypeInfoPointer(array_info.element_type, cd);
				}
				//This variable will keep track of the loop array value and is pushed in the next instruction below
				value_var : *VariableData = CreateStackVarData(cd, fld.value_name, value_type, .DEFAULT);
				array_count_op : MusicOperand = ---;
				if array_info.array_type == {
				case .FIXED;
					array_count_op = Imm(array_info.array_count);
				case .RESIZABLE; #through;
				case .VIEW;
					array_count_op = GetValueOp(node.right, cd, .bx);
				}

				jmp_instr_index : int;
				// post_op : OpCode;
				index_var : *VariableData = CreateStackVarData(cd, fld.index_name, *cd.int_type_info);
				if fld.is_reverse {
					//Start at count since we are subtracting 1 below as part of the loop
					CreateMInstr(.mov, index_var.op, array_count_op, Imm(cd.int_type_info.runtime_size), d=cd);
					CreateMInstr(.sub, index_var.op, Imm(1), d=cd);
					jmp_instr_index = cd.all_music_instructions.count-1; //jump to last instruction
					CreateMInstr(.cgte, RegMem(.ax), index_var.op, Imm(0), d=cd);
					// post_op = OpCode.sub;
				} else {
					//NOTE : This push is tracked by the index_var above. Start from 0 and then increment
					//Start at -1 since we are add below in the loop to start the loop at index 0
					CreateMInstr(.mov, index_var.op, Imm(-1), Imm(index_var.t_info.runtime_size), d=cd);
					if array_info.array_type == .VIEW {
						//Only need count var for array view since for fixed array the count is known at compile time and is set above
						array_count_op = GetValueOp(node.right, cd, .bx);
					}
					CreateMInstr(.add, index_var.op, Imm(1), d=cd);
					if array_info.array_type == .VIEW && node.right.code_ir.node_op_type == .ADDRESS_IN_MEMORY {
						//If the temp address is on the stack then we need to get it with an extra instruction in get value op above
						jmp_instr_index = cd.all_music_instructions.count-2;
					} else {
						jmp_instr_index = cd.all_music_instructions.count-1;
					}
					CreateMInstr(.clt, RegMem(.ax), index_var.op, array_count_op, d=cd);
					// post_op = OpCode.add;
				}

				//Add .fjmp in any case and then keep track of it so we know where to fjmp to later when closing the loop
				CreateMInstr(.fjmp, Imm(0), RegMem(.ax), d=cd);
				ctrl_fjmp : *ControlFjmps = array_add(*cd.all_control_fjmps);
				ctrl_fjmp.instr_index = cd.all_music_instructions.count-1;
				ctrl_fjmp.scope_index = cd.open_scope_stack.count-1;

				if fld.is_pointer {
					GetArrayAddressOp(node.right, .ax, value_var.op, cd, true, index_var.op);
				} else {
					GetArrayValueOp(node.right, .ax, RegMem(.bx), value_var.op, index_var.op, cd);
				}

				//TODO Set it to [2] MusicInstruction if this is how it stays
				fld.post_instr_count = 1;
				//Add post loop instructions and jump back to the comparison check
				//NOTE : We move this to beginning of loop because otherwise it_index updates at the bottom of the loop
				//and then it updates at the top which feels weird while debugging since we have it_index does not match it
				//while we are on the first line. Also we go over the limit of the for loop. This way it and it_index are
				//always in sync and we jump out right away of the foor loop before reaching the next value.
				//Downside is we start one off and immediately add/sub but that seems fine since the value can be wrong
				//if we are grabbing some memory on the stack which is already set.
				// fld.post_loop_instrs[0] = MakeMI(post_op, index_var.op, Imm(1));
				//Jmp back to start of loop comparison check
				fld.post_loop_instrs[0] = MakeMI(.jmp, Imm(jmp_instr_index));
			}
			case .MUSIC_UNIT; {
				//TODO Cycle through tano notes or tano row
				//This would require us to apply operations on specific notes like munit[0][1][2]
				//where the [2] would then be a fixed array that we would apply operations on directly
				//for each value in the array and the loop would update the value in the fixed array
				//TODO Could allow a range here like tano[0][0..10] and so we loop through the x there
			}
			}
		}
	}
	//TODO Should we separate if and while if they become different?
	//Right now they generate the same instructions at the start but the
	//scopes start in different places since we want to the see the inner variables
	//when we jump back on the while loop but we don't want to see the if varaibles
	//if the if condition is not met.
	case .KEYWORD_WHILE; #through;
	// case .KEYWORD_ELSE; #through;
	case .KEYWORD_IF; {
		//TODO I think we could even allow float here since it's a != 0 check in the jmp instruction.
		//Jai even allows strings here as well so we could do it with strings and bytes if we allow that later.
		//It even allows all pointers and arrays and checks for null and count == 0 respectively i think.
		//I'm not sure I want that since you could just make a function but maybe it's a good idea later...
		valid_if_types :: TypeInfoTag.[.INTEGER,.BOOL];
		if !AllOrEquals(node.right.code_ir.t_info.type_enum, valid_if_types) {
			CreateCompErr(cd, .EVALUATION, node,
			sprint("Invalid if statement condition type. Must be one of %.", valid_if_types));
			return false;
		}

		CreateMInstr(.fjmp, Imm(0), node.right.code_ir.op, d=cd);

		//TODO Create a function for this so we can do some consistent validation
		ctrl_fjmp : *ControlFjmps = array_add(*cd.all_control_fjmps);
		ctrl_fjmp.instr_index = cd.all_music_instructions.count-1;
		ctrl_fjmp.scope_index = cd.open_scope_stack.count-1;

		FreeOperandRegisters(node.right.code_ir.op, *cd.all_registers);

		if node.value.token_type == .KEYWORD_IF {
			/*DOC : We want to store if and else start_instr_index after the if since we want the scope to only
			start if we branch into the condition. For .KEYWORD_WHILE and .KEYWORD_FOR we want the scope to start 
			before at the for/while because we want to see the variables change even on the loop line.
			*/
			if_scope : *ScopeData = peek_pointer(cd.all_scope_data);
			if_scope.start_instr_index = cd.all_music_instructions.count;
		}

		/*TODO We could add the post while instructions here if that makes more sense instead of at end of while }.
		I don't think we can add if because we don't know whether there is an else at the end anyways.
		*/
	}
	//TODO Can we split this up better since there are only a few unary ops?
	case #char "~"; #through;
	case .TILDE_ADD; #through;
	// case #char "^"; #through;
	case .LOGICAL_AND; #through;
	case .LOGICAL_OR; #through;
	case .IS_EQUAL; #through;
	case .ISNOT_EQUAL; #through;
	case .LESS_EQUALS; #through;
	case .GREATER_EQUALS; #through;
	case #char ">"; #through;
	case #char "<"; #through;
	case #char "%"; #through;
	case #char "/"; #through;
	case #char "*"; #through;
	case #char "-"; #through;
	case #char "+"; {

		//NOTE : All operators are R_VALUE since this is not an assignable value and we just
		//store it temporarily on the stack.
		//TODO If we allow LHS pointer arithmetic later, then we can update it down there
		node.code_ir.code_value_type = CodeValueType.R_VALUE;

		//TODO Should we check that certain types are UNARY and BINARY here or at Parser level?
		if node.code_ir.ir_type == CodeIRType.UNARY_OP {
			#if 0 {
			if !AllOrEquals(node.right.code_ir.code_value_type, .[.R_VALUE,.L_VALUE]) {
				CreateCompErr(cd, .EVALUATION, node, 
				sprint("\"%\" not valid value.\n", node.right.value.token_string,,context.allocator));
				return false;				
			}
			else if node.right.code_ir.t_info == null {
				CreateCompErr(cd, .EVALUATION, node, 
				sprint("\"%\" type not found.\n", node.right.value.token_string,,context.allocator));
				return false;
			}
			}

			if node.value.token_type == {
			case #char "+"; {
				//NOTE : This case does not require asm out so we only have to update the node.
				node.code_ir = node.right.code_ir;
				//TODO Should we allow unary + operator overloads?
				return true;
			}
			case #char "-"; {
				right_op := GetValueOpReuseReg(node.right,cd,true);
				node.code_ir = node.right.code_ir;
				if node.right.code_ir.op.operand_type == {
				case .FLOAT;
					node.code_ir.values[0].float_value = -node.right.code_ir.values[0].float_value;
				case .INTEGER;
					node.code_ir.values[0].int_value = -node.right.code_ir.values[0].int_value;
				case .REGISTER; #through;
				case .RAM_MEMORY; 
					if node.right.code_ir.t_info.type_enum == {
					case .FLOAT; #through;
					case .INTEGER; {
						node.code_ir.op = PushStack(node.right.code_ir.t_info.runtime_size, cd);
						CreateMInstr(.sub, node.code_ir.op, Imm(0), right_op, d=cd);
					} 
					case .TANO; {
						//negative tano reverses the row and x
						//This is the same as rel_t(-,-) so maybe we could use this for something else
						//but this seems intuitive and also allows for double negation if desired.
						node.code_ir.op = PushStack(node.right.code_ir.t_info.runtime_size, cd);
						neg := GetTanoOpOffsets(node.code_ir.op);
						old := GetTanoOpOffsets(right_op);
						CreateMInstr(.mov, neg.row_start_op, old.row_end_op, Imm(cd.int_type_info.runtime_size), d=cd);
						CreateMInstr(.mov, neg.row_end_op, old.row_start_op, Imm(cd.int_type_info.runtime_size), d=cd);
						CreateMInstr(.mov, neg.x_start_op, old.x_end_op, Imm(cd.float_type_info.runtime_size), d=cd);
						CreateMInstr(.mov, neg.x_end_op, old.x_start_op, Imm(cd.float_type_info.runtime_size), d=cd);
						CreateMInstr(.mov, neg.mspace_op, old.mspace_op, Imm(cd.int_type_info.runtime_size), d=cd);
					}
					case; {
						argument_nodes : [1] *BinaryNode = .[node.right];
						valid_unary_op : bool = false;
						for fd : cd.all_function_declarations if fd.is_operator_overload && fd.op_token_type == node.value.token_type {
							valid_func_args := ValidFuncArgs(fd.t_info_proc, argument_nodes);
							if valid_func_args {
								valid_unary_op = true;

								cfcd : CompFuncCallData;
								cfcd.node = node;
								cfcd.argument_nodes = argument_nodes;
								cfcd.func_decl = fd;
								cfcd.is_function_pointer = false;
								cfcd.proc_type = fd.t_info_proc;

								success := CompileFunctionCall(cfcd, cd);	
								if !success return false;
								
								break;
							}
						}

						if !valid_unary_op {
							CreateCompErr(cd, .EVALUATION, node, "No operator function found.");
							return false;
						}
					}
					}
				case;
					CreateCompErr(cd, .EVALUATION, node, "Invalid negation op.");
					return false;
				}
			}
			case #char "*"; {
				//TODO CompilerError, I think this would be caught in ParseExpression.
				//I am catching it here too since having double checks is resilient in a compiler.
				// assert(node.right != null);
				if node.right == null || node.right.code_ir.t_info == null {
					CreateCompErr(cd, .EVALUATION, node, "No pointer type.");
					return false;
				} 
				/*We have to prevent (but maybe this has a mathematical meaning later)
				*tano(0,0) 

				BUT NOT PREVENT
				t : tano;
				tp : *tano = *t;

				TECHNICALLY THIS COULD BE ALLOWED BUT would return a pointer which would be lost after
				this statement. I Think for now we disallow it and maybe we add a mathematical meaning to it later.
				*/
				else if node.right.value.token_type == #char "(" && 
					node.right.left != null && node.right.left.code_ir.t_info.type_enum == .TANO
				{
					//TODO Should we have "*" be a unary op for a tano? What would that mean?
					CreateCompErr(cd, .EVALUATION, node, "No relative tano pointers.");
					return false;
				}

				node.code_ir = node.right.code_ir;
				//A pointer to something is always an R_VALUE since we store it temporarily 
				//on the stack and it is not assignable.
				node.code_ir.code_value_type = .R_VALUE;

				//Pointer unary op
				if node.right.code_ir.ir_type == {
				//TODO Can this be replace with this is either R_VALUE OR L_VALUE?
				case .STACK_VARIABLE;
					//TODO InternalError (we have some memory here that is not identifiable)
					assert(node.code_ir.op.values[0].type != .NONE);
					assert(node.code_ir.op.values[0].type != .FLOAT && node.code_ir.op.values[1].type != .FLOAT);

					//TODO If we have issues with pointers here maybe we need to get ADDRESS_IN_MEMORY instead
					//We are doing that so this should work now even if we have ADRESS_IN_MEMORY
					stack_op := PushStack(8, cd);
					node.code_ir.op = GetAddressOp(node, cd, stack_op);
					// node.code_ir.op = PushStack(8, cd);
					// op_0, op_1 := GetMemoryAddressAsOperands(node.right.code_ir.op);
					// CreateMInstr(.add, node.code_ir.op, op_0, op_1, d=cd);
					#through; //We set the data type for the pointer variable
				case .DATA_TYPE_INFO;
					p_type : *TypeInfoPointer = GetOrCreateTypeInfoPointer(node.right.code_ir.t_info, cd);
					node.code_ir.t_info = *p_type.info;
				case;
					CreateCompErr(cd, .EVALUATION, node, 
					sprint("Invalid pointer type : %.\n", node.right,,context.allocator));
				}
			}
			case;
				CreateCompErr(cd, .EVALUATION, node, "Invalid unary op.");
			}
		} 
		else if node.code_ir.ir_type == CodeIRType.BINARY_OP {
			//TODO This should be checked at the parser level.
			assert(node.left != null && node.right != null);

			if !AllOrEquals(node.left.code_ir.code_value_type, .[.R_VALUE,.L_VALUE]) {
				CreateCompErr(cd, .EVALUATION, node, 
				sprint("\"%\" not valid LHS.\n", node.left.value.token_string,,context.allocator));
				return false;				
			} 
			else if !AllOrEquals(node.right.code_ir.code_value_type, .[.R_VALUE,.L_VALUE]) {
				CreateCompErr(cd, .EVALUATION, node, 
				sprint("\"%\" not valid RHS.\n", node.right.value.token_string,,context.allocator));
				return false;				
			}
			else if node.left.code_ir.t_info == null {
				CreateCompErr(cd, .EVALUATION, node, 
				sprint("\"%\" type not found LHS.\n", node.left.value.token_string,,context.allocator));
				return false;
			} 
			else if node.right.code_ir.t_info == null {
				CreateCompErr(cd, .EVALUATION, node, 
				sprint("\"%\" type not found RHS.\n", node.right.value.token_string,,context.allocator));
				return false;
			}

			//TODO Should we check these types and return error if their null? Is that an internal error?
			left_type : *TypeInfo = node.left.code_ir.t_info;
			right_type : *TypeInfo = node.right.code_ir.t_info;

			//TODO Can remove the sorting code below since we now longer sort if we don't use it again.
			//We sort the types so we can always compare in the same order and not have to check symmetric cases.
			b_types : [2] TypeInfoTag = .[left_type.type_enum, right_type.type_enum];
			// if left_type.type_enum <= right_type.type_enum {
			// 	b_types[0] = left_type.type_enum;
			// 	b_types[1] = right_type.type_enum;
			// } else {
			// 	b_types[0] = right_type.type_enum;
			// 	b_types[1] = left_type.type_enum;
			// }

			/*NOTE REMINDER : All the valid array checks must be in sorted order here so make sure before
			changing an array or adding a new one. This way we don't have to check symmetric cases.
			*/
			valid_binary_op : bool = false;
			is_default_op : bool = false;
			if ArraysFixedEqual(b_types, .[.INTEGER,.POINTER]) {
				//Pointer arithmetic
				if node.value.token_type == #char "+" {
					pointer_to_size := (cast(*TypeInfoPointer) node.right.code_ir.t_info).pointer_to.runtime_size;
					stack_op : MusicOperand = PushStack(8, cd);
					CreateMInstr(.mul, stack_op, node.left.code_ir.op, Imm(pointer_to_size), d=cd);
					CreateMInstr(.add, stack_op, node.right.code_ir.op, stack_op, d=cd);

					valid_binary_op = true;
					//Pointer type is on the right
					node.code_ir.t_info = right_type;
					node.code_ir.op = stack_op;
					// node.code_ir.code_value_type = node.right.code_ir.code_value_type;
					node.code_ir.code_value_type = .R_VALUE;
				}
			}
			else if ArraysFixedEqual(b_types, .[.POINTER,.INTEGER]) {
				//Pointer arithmetic
				if node.value.token_type == {
				case #char "-"; #through;
				case #char "+"; {
					pointer_to_size := (cast(*TypeInfoPointer) node.left.code_ir.t_info).pointer_to.runtime_size;
					stack_op : MusicOperand = PushStack(8, cd);
					CreateMInstr(.mul, stack_op, node.right.code_ir.op, Imm(pointer_to_size), d=cd);

					op_code : OpCode;
					if node.value.token_type == {
					case #char "+"; op_code = OpCode.add;
					case #char "-"; op_code = OpCode.sub;
					}
					//Either have (*i + p) or (*i - p)
					CreateMInstr(op_code, stack_op, node.left.code_ir.op, stack_op, d=cd);

					valid_binary_op = true;
					node.code_ir.t_info = left_type;
					node.code_ir.op = stack_op;
					//TODO We could do this but I will not allow pointer arithmetic on LHS for now since it is confusing
					//as to when it should work and when it does not and also prone to error in general.
					// node.code_ir.code_value_type = node.left.code_ir.code_value_type;
					node.code_ir.code_value_type = .R_VALUE;
				}
				}
			}
			else if ArraysFixedEqual(b_types, .[.BOOL,.BOOL]) ||
					  ArraysFixedEqual(b_types, .[.INTEGER,.BOOL]) ||
					  ArraysFixedEqual(b_types, .[.BOOL,.INTEGER])
			{
				if node.value.token_type == {
				case .LOGICAL_AND; #through;
				case .LOGICAL_OR; {
				   node.code_ir.t_info = *cd.bool_type_info;
				   valid_binary_op = true;
				   is_default_op = true;
				}
				}
			}
			else if ArraysFixedEqual(b_types, .[.INTEGER,.INTEGER]) ||
						//TODO Should this be a separate case? They are the same here but maybe will differ later
					  ArraysFixedEqual(b_types, .[.FLOAT,.FLOAT])
			{
				if node.value.token_type == {
				case .IS_EQUAL; #through;
				case .ISNOT_EQUAL; #through;
				case .LESS_EQUALS; #through;
				case .GREATER_EQUALS; #through;
				case #char "<"; #through;
				case #char ">"; {
				   node.code_ir.t_info = *cd.bool_type_info;
				   valid_binary_op = true;
				   is_default_op = true;
				}
				case #char "*"; #through;
				case #char "/"; #through;
				case #char "-"; #through;
				case #char "+"; #through;
				case #char "%"; {
				   node.code_ir.t_info = left_type;
				   valid_binary_op = true;
				   is_default_op = true;
				}
				}
			}
			//TODO [.TANO,.INTEGER], .[.INTEGER, .TANO], .[.TANO, .FLOAT]... and all other possibilities
			//with floats and arrays for example
			//DOC : The tilde is specific in it's usage and uses other types like [tano, int] which is used
			//with arithmetic ops above, so we make it it's own case and check for valid type cases inside.
			else if node.value.token_type == #char "~" {
				valid_tilde_types : bool = 
					ArraysFixedEqual(b_types, .[.TANO,.TANO]) ||
					ArraysFixedEqual(b_types, .[.TANO,.ARRAY]) ||
					ArraysFixedEqual(b_types, .[.ARRAY,.TANO]) ||
					ArraysFixedEqual(b_types, .[.TANO,.NEUME]) ||
					ArraysFixedEqual(b_types, .[.NEUME,.TANO]) ||
					ArraysFixedEqual(b_types, .[.INTEGER,.TANO]) ||
					ArraysFixedEqual(b_types, .[.TANO,.INTEGER]) ||
					ArraysFixedEqual(b_types, .[.FLOAT,.TANO]) ||
					ArraysFixedEqual(b_types, .[.TANO,.FLOAT]);
				if !valid_tilde_types {
					CreateCompErr(cd, .EVALUATION, node,
						"Invalid ~ type. Valid types are tano, neume, int, float or int/float/neume array.");
						return false;
				}
				//TODO FROM HERE write unit tests for "~" here and above and clean code below and then "+="
				//and then start on functions with neumes and maybe arrays and tanos or do ui and continue
				//that when its easier to debug later
				//TODO Should we allow this or is it too complicated. I think we have to test it once
				//we have things working a bit more. Likely do tadd, tsub, etc... first
				tano_node : *BinaryNode;
				other_node : *BinaryNode;
				if node.left.code_ir.t_info.type_enum == .TANO {
					tano_node = node.left;
					other_node = node.right;
				} else if node.right.code_ir.t_info.type_enum == .TANO {
					tano_node = node.right;
					other_node = node.left;
				}

				tano_stack_op := PushTanoStack(tano_node, cd);
				other_op := GetValueOp(other_node, cd, .r0);
				if other_node.code_ir.t_info.type_enum == {
				case .INTEGER; {
		   		CreateMInstr(.mov, RegMem(.ax), other_op, d=cd);
				   CreateMInstr(.tmov, tano_stack_op, RegMem(.ax), d=cd);
				}
				case .FLOAT; {
		   		CreateMInstr(.mov, RegMem(.ax), other_op, d=cd);
				   CreateFloatInstr(.tmov, tano_stack_op, RegMem(.ax), d=cd);
				}
				case .TANO; {
			   	CreateMInstr(.tmov, tano_stack_op, other_op, ImmEnum(TMovRamType.TANO), d=cd);
			   }
			   case .NEUME; {
			   	CreateMInstr(.tmov, tano_stack_op, other_op, ImmEnum(TMovRamType.NEUME), d=cd);
			   }
			   case .ARRAY; {
			   	//TODO We could pass array_info into ArrayToRamArrayOp but since it's just a cast we don't for now.
					array_info := cast(*TypeInfoArray) other_node.code_ir.t_info;
					assert(array_info.element_type != null); //sanity check
					if !AllOrEquals(array_info.element_type.type_enum, .[.INTEGER,.FLOAT,.NEUME]) {
						CreateCompErr(cd, .EVALUATION, node,
						"Invalid ~ array type. Valid array types are int, float and neume.");
						return false;
					}

					ram_array_op := ArrayToRamArrayOp(other_node, cd, .ax, .bx);
					tmov_array_type := TMovArrayType.DEFAULT;
					if array_info.element_type.type_enum == .NEUME {
				   	tmov_array_type = TMovArrayType.NEUME;
				   }
			   	CreateMInstr(.tmov, tano_stack_op, ram_array_op, ImmEnum(tmov_array_type), d=cd);
			   }
			   }

				node.code_ir.op = tano_stack_op;
			   node.code_ir.t_info = *cd.tano_struct_info;
			   node.code_ir.on_tano_stack = true;
			   valid_binary_op = true;
			}
			/*DOC : I am keeping this separate from the [array,tano] and [neume,tano] cases below because
			arithmetic operations updates the neumes in a tano while the "~" combines neumes but does not update them.
			*/
			else if 
				(ArraysFixedEqual(b_types, .[.TANO, .INTEGER]) || 
				ArraysFixedEqual(b_types, .[.INTEGER, .TANO]) ||
				ArraysFixedEqual(b_types, .[.TANO, .FLOAT]) || 
				ArraysFixedEqual(b_types, .[.FLOAT, .TANO])) 
				//NOTE : The "~" is checked above, so we don't need it, but we can make it explicit here if necessary.
				// &&
				// node.value.token_type != #char "~"
			{
				//TODO Can make this right or left depending on 
				from_tano_node : *BinaryNode;
				value_node : *BinaryNode;
				if node.left.code_ir.t_info.type_enum == .TANO {
					from_tano_node = node.left;
					value_node = node.right;
				} else if node.right.code_ir.t_info.type_enum == .TANO {
					from_tano_node = node.right;
					value_node = node.left;
				}
				#if 1 {
				to_tano_op : MusicOperand = PushTanoStack(from_tano_node, cd);
				} else {
				//TODO Need to add suggested regs here instead of freeing so we can see what we are using
				//and then need to udpate that everywhere else as well.
			   from_tano_op : MusicOperand = GetValueOpReuseReg(from_tano_node, cd, true);
			   from_tano_ofs := GetTanoOpOffsets(from_tano_op);

			   /*NOTE : We create the to_tano here on the stack using the tano stack music space
			   */
			   //TODO I think we can maybe generalize this as PushTanoStack(tano, cd)
			   //Unless we only use it here and then we can just leave this here
			   to_tano_op : MusicOperand = PushStackMov(from_tano_node, cd);
			   to_tano_ofs := GetTanoOpOffsets(to_tano_op);
			   //Current tano stack
			   //We only update .tbp on a function call and on function return
			   CreateMInstr(.mov, to_tano_op, RegMem(.tsp), d=cd);
			   //Get row diff
			   CreateMInstr(.sub, RegMem(.ax), from_tano_ofs.row_end_op, from_tano_ofs.row_start_op, d=cd);
			   CreateMInstr(.abs, RegMem(.ax), RegMem(.ax), d=cd);
			   CreateMInstr(.add, to_tano_ofs.row_end_op, to_tano_ofs.row_start_op, RegMem(.ax), d=cd);
			   //Update .tsp to the next available row
			   //TODO This can be checked at runtime if ever .tsp is > row_max then we can return an error or stop the program.
			   CreateMInstr(.add, RegMem(.tsp), RegMem(.ax), d=cd);
			   CreateMInstr(.add, RegMem(.tsp), Imm(1), d=cd);
				//x starts at 0 always so we don't have any offset on tano_stack
			   CreateFloatInstr(.mov, to_tano_ofs.x_start_op, FImm(0), d=cd);
			   //Get x diff
			   CreateFloatInstr(.sub, RegMem(.ax), from_tano_ofs.x_end_op, from_tano_ofs.x_start_op, d=cd);
			   CreateFloatInstr(.abs, RegMem(.ax), RegMem(.ax), d=cd);
			   CreateFloatInstr(.add, to_tano_ofs.x_end_op, to_tano_ofs.x_start_op, RegMem(.ax), d=cd);

			   CreateMInstr(.mov, to_tano_ofs.mspace_op, Imm(TANO_STACK_MSPACE), d=cd);
			   //TODO Maybe we remove mspace_end_op and then we can just remove this.
			   // to_mspace_end_op := AddOperandOffset(40, to_tano_op);
			   // CreateMInstr(.mov, to_mspace_end_op, Imm(TANO_STACK_MSPACE), d=cd);

			   //NOTE : Move the values over and the from_tano maintains the direction so it only gets reversed
			   //once if needed and then all other operations would be applied directly AND the "~="
			   //would also be applied directly since it was already reversed on the stack.
			   //TODO NEED TO TEST THIS WITH AN INTEGRATION TEST
			   CreateMInstr(.tmov, to_tano_op, from_tano_op, d=cd);
				} 

		   	//NOTE : The value needs to be in the register since RAM_MEMORY is a tano for tadd/top instructions.
			   t_op_code : OpCode;
				if node.value.token_type == {
			   case #char "+"; t_op_code = OpCode.tadd;
			   case #char "-"; t_op_code = OpCode.tsub;
			   case #char "*"; t_op_code = OpCode.tmul;
			   case #char "/"; t_op_code = OpCode.tdiv;
			   //TODO Does this work or do we need an escape character?
			   case #char "%"; t_op_code = OpCode.tmod;
			   //TODO "~+" can be an in-place add that adds the value directly to that tano instead of temp tano on tano stack
			   // case .TILDE_ADD;
				}

			   value_op : MusicOperand = GetValueOpReuseReg(value_node, cd, true);
				//TODO If it's a constant, we can just use immediate directly. This way is more consistent though.
			   CreateMInstr(.mov, RegMem(.ax), value_op, d=cd);
			   left_op : MusicOperand;
			   right_op : MusicOperand;
		   	if node.left.code_ir.t_info.type_enum == .TANO {
		   		left_op = to_tano_op;
		   		right_op = RegMem(.ax);
				} else if node.right.code_ir.t_info.type_enum == .TANO {
		   		left_op = RegMem(.ax);
		   		right_op = to_tano_op;
				}
				if value_node.code_ir.t_info.type_enum == .INTEGER {
				   CreateMInstr(t_op_code, left_op, right_op, d=cd);
				} else if value_node.code_ir.t_info.type_enum == .FLOAT {
				   CreateFloatInstr(t_op_code, left_op, right_op, d=cd);
				}

				//NOTE : R_VALUE is set at the top for all op values
			   // node.code_ir.code_value_type = CodeValueType.R_VALUE;
			   node.code_ir.t_info = *cd.tano_struct_info;
			   node.code_ir.op = to_tano_op;
			   node.code_ir.on_tano_stack = true;
			   valid_binary_op = true;
			}
			else {
				argument_nodes : [2] *BinaryNode = .[node.left, node.right];
				for fd : cd.all_function_declarations if fd.is_operator_overload && fd.op_token_type == node.value.token_type {
					valid_func_args := ValidFuncArgs(fd.t_info_proc, argument_nodes);
					if valid_func_args {
						valid_binary_op = true;

						cfcd : CompFuncCallData;
						cfcd.node = node;
						cfcd.argument_nodes = argument_nodes;
						cfcd.func_decl = fd;
						cfcd.is_function_pointer = false;
						cfcd.proc_type = fd.t_info_proc;

						success := CompileFunctionCall(cfcd, cd);	
						if !success return false;

						break;
					}
				}
			}
			
			//TODO Need to do the case for mrow and arrays so we setup the RamArray and use the default case
			// else if ArraysFixedEqual(b_types, .[.INTEGER,.FLOAT]) {
				//TODO Need to use .itof or .ftoi to convert here before setting it
			// } 
			//TODO Implement operator overloads here and then check for valid operator overloads with
			//the given type and if so then it is valid and we make the function call directly
			//and then I think we do not use the default case below.
			//We can have 2 cases is_base_type and !is_base_type
			//if is_base_type we use the default case below, otherwise we don't and setup for a function call
			//with an operator overload here directly.
			// else {
			// }

			if !valid_binary_op {
				CreateCompErr(cd, .EVALUATION, node, 
				sprint("\"%\" operator not found for left type % and right type %.\n", 
					GetLexString(node.value, cd.lexer), left_type.type_enum, right_type.type_enum,,context.allocator));
				//TODO We should be erroring out here since we don't want to accumulate anymore errors.
				//Use the other compile-time DFSPost with error
				return false;
			}

			if is_default_op {
				//TODO Shuold we set these hear or while checking the types above?
				//I think we should do this as a default case and then operator overload otherwise
				op_code : OpCode;
				if node.value.token_type == {
				case .LOGICAL_AND;		op_code = OpCode.and;
				case .LOGICAL_OR; 		op_code = OpCode.or;
				case .IS_EQUAL;   		op_code = OpCode.ceq;
				case .ISNOT_EQUAL;		op_code = OpCode.cneq;
		    	case .LESS_EQUALS;		op_code = OpCode.clte;
    			case .GREATER_EQUALS; 	op_code = OpCode.cgte;
				case #char "<";      	op_code = OpCode.clt;
				case #char ">";      	op_code = OpCode.cgt;
				case #char "-";      	op_code = OpCode.sub;
				case #char "+";      	op_code = OpCode.add;
				case #char "*";      	op_code = OpCode.mul;
				case #char "/";      	op_code = OpCode.div;
				case #char "%";      	op_code = OpCode.mod;
				//TODO I think this depends on if it's logical or not...
				// case #char "^";    		op_code = OpCode.xor;
				}

				//TODO Definetely refactor this to always store it on the stack
				/*TODO We could just always store this on the stack and then clear everything at the end
				of each statement or at the "=". That would be more consistent overall and then we would not
				need to worry about running out of registers. We could have both but then we need to make
				sure to do the stack anyways if we run out of registers... I prefer the stack way then since
				we are not limited by any kind of hardware anyways and then we only have 1 method to debug and maintain.
				Maybe do this at the same time as we do operator overload since we will be in this area of the code then
				and instead do a 2-input/1-return function call if we have an overload here instead of a base arithemtic operator.
				*/
				//TODO Could make a function to get or reuse register for 2 ops and then free maybe...
				//Not sure if we'll use this somewhere else...
				//TODO Eventually we could optimize to use and reuse registers but for now stack is clearer and more consistent.
				//NOTE : Using stack consistently is likely less prone to errors.
				//ALSO we can see where things are more clearly and systematically in the debugger and in tests.
				#if 0 {
				reg, is_reused := ReuseRegister(node.left.code_ir.op.values[0], cd);
				if !is_reused {
					reg, is_reused = ReuseRegister(node.right.code_ir.op.values[0], cd);
					if !is_reused {
						reg_data : *RegisterData = OLDGetNextAvailableRegister(cd);
						reg = cast(RegDef) reg_data.reg_index;
					}
				}

				FreeOperandRegisters(node.left.code_ir.op, *cd.all_registers);
				FreeOperandRegisters(node.right.code_ir.op, *cd.all_registers);
				cd.all_registers[reg].is_available = false;
				node.code_ir.op = RegMem(reg);
				} else {
				assert(node.code_ir.t_info != null); //sanity check. should have been checked above
				stack_op : MusicOperand = PushStack(node.code_ir.t_info.runtime_size, cd);
				node.code_ir.op = stack_op;
				}
				//NOTE : We free reigsters no matter what
				//TODO Can likely remove this now that we don't reuse registers and add it later only if we do reuse registers.
				// FreeOperandRegisters(node.left.code_ir.op, *cd.all_registers);
				// FreeOperandRegisters(node.right.code_ir.op, *cd.all_registers);

				//TODO we could just not allow non-imperative declarations in global scope.
				//So in the else here we could return a compiler error if scope_index == 0 or check scope_stack == GLOBAL_SCOPE
				// if IsConstant(node.left) && IsConstant(node.right) {
					//TODO If both sides are IsConstant (ie both operands are Immediates) then just do the calculation here
					//for ints, bools and float. For constants, we would check the type here or afterwards anyways.				
				// } else {
					//TODO This will be MusicMem if we are doing music/array values
					//TODO Should we just make this a stack value every single time to avoid issues with many function arguments
					//and so then we can always clear the value at the end of an assignment.
				/*TODO We want to always store this on the stack now for consistency and with the new way
				we would just set it to that value currently from the stack so we would not even need any extra instructions.
				*/
					//This way never makes the op unavailable since we won't be using it again after
   				right_op : MusicOperand = GetValueOp(node.right, cd, .ax);
					left_op : MusicOperand = GetValueOp(node.left, cd, .bx);
					if node.code_ir.t_info.type_enum == .FLOAT {
						FInstr(op_code, node.code_ir.op, left_op, right_op, d=cd);
					} else {
						CreateMInstr(op_code, node.code_ir.op, left_op, right_op, d=cd);
					}
				// }
			}
		}
	}
	case .POSTFIX_DEREFERENCE; {
		//TODO This can be checked at the parser level
		//TODO MAybe I prefer leaving node.left everywhere cause it's easier to think about
		var_node : *BinaryNode = node.left;

		valid_node : bool = CheckValidNode(var_node, node, cd);
		if !valid_node return false;

		if var_node.code_ir.t_info.type_enum == .POINTER {
			//TODO Should we be doin this with .STACK_VARIABLE or just grabbing the op and checking that?
			//Also should rename to MEMORY_VARIABLE but maybe a valid op is enough in any case since
			//we could have ram or register.
			//TODO I think we can remove this in case we do pointer arithmetic we may still want to dereference
			//YES REMOVE THIS for a case like in Test_Derference "x1p = (*x + 1).*" that should be allowed
			//although weird and should not be done by anybody but is useful for data structure dereference
			//like arrays or pools for example.
			// if var_node.code_ir.ir_type == .STACK_VARIABLE {
				//NOTE : We want to reuse the register in any case. In particular with a.*.* we will reuse the same
				//register on the way up and then we only need <= 2 registers for pointer dereferencing in general.
				#if 0 {
				//TODO Leaving this here for now but we can remove it later if we don't use it
				//and also check pointer on top instead and remove all these comments
				//and just use node.left everywhere instead of var_node for clarity.
				reg_def := NewGetOrReuseReg(var_node, cd);
				CreateMInstr(.mov, RegMem(reg_def), var_node.code_ir.op, Imm(8), d=cd);

				//Use register as data access in RamMem and update the type info.
				node.code_ir.op = RamMem(reg_def);
				} else {
				//TODO Should re rename to ADDRESS_IN_MEMORY_REUSE?
				if var_node.code_ir.node_op_type == .ADDRESS_IN_MEMORY {
					//NOTE : We set address in memory and so therefore we can just reuse that value and carry it up the tree.
					//We only use it for postfix dereference and array access now, so it makes sense to reuse it up the tree.
					//TODO We use to use .ax here but now we use .r0 since we don't reuse it up the tree anymore.
					CreateMInstr(.mov, RegMem(.r0), var_node.code_ir.op, Imm(8), d=cd);
					CreateMInstr(.mov, var_node.code_ir.op, RamMem(.r0), Imm(8), d=cd);
					node.code_ir.op = var_node.code_ir.op;
				} else {
					node.code_ir.op = PushStackMov(var_node, cd);
				}
				} 
				node.code_ir.node_op_type = .ADDRESS_IN_MEMORY;
				p_type := cast(*TypeInfoPointer) var_node.code_ir.t_info;
				node.code_ir.t_info = p_type.pointer_to;
				node.code_ir.ir_type = .STACK_VARIABLE; //TODO Likely should change this name to MEMORY_VARIABLE
				//We want the code_value_type to only be L_VALUE if the pointer we are dereferencing is also L_VALUE.
				//Otherwise the pointer itself is R_VALUE so we cannot assign to it.
				//TODO We could likely make this always l_value so we can pointer arithmetic on LHS but i dont really like
				//pointer arithmetic on LHS. I feel like that was a C optimization thing that is confusing to look at
				//and hard to understand which cases work or not without compiling.
				node.code_ir.code_value_type = var_node.code_ir.code_value_type;
				// node.code_ir.code_value_type = .L_VALUE;
			// } else {
			// 	//TODO Probably an InternalError here
			// 	assert(false, "Postfix dereference not implemented for %.\n", var_node.*);
			// }
		} else {
			CreateCompErr(cd, .EVALUATION, node, 
			"Invalid dereference for non-pointer value.");
			return false;
		}
	}
	case .DOUBLE_COLON; #through;
	case #char ":"; {
		//TODO Sanity check : This can be remove once we check it in the parser.
		assert(node.left != null && node.right != null);

		if node.value.token_type == .DOUBLE_COLON {
			assert(cd.comp_level.type == .STATEMENT_LEVEL, 
				"Only evaluating :: for constant variables. All other :: should be evaluated externally in the parser. : %\n", node);
		}

		/*Maybe we could check this somewhere else but this just skips the node for now for constants.
		This is case where we parse the lower ":" and so we want to skip it since we do everything on the above one.
			 :
		   / \
		  :   1
		 / \
		x  int
		*/
		if node.value.token_type == #char ":" && node.parent != null && node.parent.value.token_type == #char ":" {
			return true;
		}

		/*TODO Can set a flag in CompilationData to check if we are in a statement or a loop,
		  similar to the flag in ParseExpression that we should set then we can tell if we are
		  EXPRESSION_LEVEL, FOR_LOOP_LEVEL...
		TODO Can check here that ":" has 2 children and that both are valid.
		TODO Can check for any data type here once we have more than 1.

		TODO should also get some memory here and set it to zero, generally from RAM_MEMORY
		*/
		//TODO ALSO If node.right is no type and we don't use ":=" as 1 node, then we just scope
		//over and do everythin in the "=" evaluation so we could also check parent in that case

		//TODO If changes the ":" to being consistently ":" works, then we can parse this as always a Variable
		//and generate it at the top level OR also check the parent... or just generate them all here depending
		//although if we don't have the type, then we would need a "=" or ":" above it to check and so that
		//could be an error if we don't have one.
		//We can convert to Variable Declaration here and then if we don't have a type on right
		//we wait to go up the tree. If we do have a type, then we can create the appropriate variable
		//below and later pull that out if needed. Keeping in one place for now so everything we are
		//doing for variable declaration creation is clear.

		//TODO Add another case for "for x, y : array" since the "," and the ":" are special cases in for loops

		if cd.comp_level.type == .STRUCT_DECLARATION && node.value.token_type == #char ":" {
			//TODO CompilerError
			is_valid_struct_decl : bool = 
				node.left != null && node.left.value.token_type == .IDENT && node.right != null && 
				node.right.code_ir.ir_type == .DATA_TYPE_INFO;
			if !is_valid_struct_decl {
				CreateCompErr(cd, .EVALUATION, node, "Invalid struct declaration.");
			}

			assert(cd.current_struct_info != null);

			member : *TypeInfoStructMember = array_add(*cd.create_struct_members);
			member.name = node.left.value.token_string; 
			member.t_info = node.right.code_ir.t_info;
			member.offset_in_bytes = cd.current_struct_info.runtime_size;

		   cd.current_struct_info.runtime_size += member.t_info.runtime_size;
		}
		else if cd.comp_level.type == .FUNCTION_DECL_INPUT_VARS && node.value.token_type == #char ":" {
			//TODO CompilerError
			assert(node.left != null && node.left.value.token_type == .IDENT && node.right != null && 
					 node.right.code_ir.ir_type == .DATA_TYPE_INFO);

			/*NOTE : We are doing this in here instead of on the first pass outer loop because if we allow "="
			default values later then we want that to be able to parse arithmetic. That MAY be a separte tree traversal
			in which case we can pull this out, but for now it would be constant arithmetic or struct/array literals
			which involves some processing in here even if it is constant since we can have constants in other places.
			Once we implement constants that is...
			*/
			//TODO CompilerError
			assert(cd.function_stack.count > 0);
			func_decl_id : int = peek(cd.function_stack);
			//TODO Technically we could parse this in the first pass and only pass in the default values
			//into here which would check for constants
			/*Note : We start on 0 here because the new stack scop starts with function arguments
			*/
			#if 0 {
			next_index : int = 0;
			if cd.all_function_arguments.count > 0 {
				last_var : *FunctionVariable = peek_pointer(cd.all_function_arguments);
				if last_var.function_id == func_decl_id {
					next_index = last_var.var_bytes_from_sbp + last_var.t_info.runtime_size;
				}
			}
			}
			//TODO This needs to be updated so we actually access the function variable on the stack properly
			//relative to the sbp of the functon and depending on where the input and return vars are
			input_var : *FunctionVariable = array_add(*cd.all_function_arguments);
			input_var.function_id = func_decl_id;
			input_var.name = node.left.value.token_string;
			input_var.t_info = node.right.code_ir.t_info;
			//TODO Should we store byte offset here directly instead of just index?
			input_var.var_bytes_from_sbp = cd.byte_offset_from_sbp;
			cd.byte_offset_from_sbp += input_var.t_info.runtime_size;
		}
		//TODO Commenting out for now in case but we can remove if we don't use it
		// else if cd.comp_level.type == .FUNCTION_DECL_RETURN_VARS {
		// 	//TODO CompilerError. Maybe this can be checked in ParseExpression.
		// 	assert(node.right != null && node.right.code_ir.ir_type == .DATA_TYPE_INFO);

		// 	node.code_ir.ir_type == node.right.code_ir.ir_type;
		// 	node.code_ir.t_info == node.right.code_ir.t_info;
		// }
		else if cd.comp_level.type == .STATEMENT_LEVEL &&
				//x :: 0;
				(node.value.token_type == .DOUBLE_COLON || 
					//x : int : 0;
			  		(node.value.token_type == #char ":" && node.left.value.token_type == #char ":")
				)
	   {
	   	//TODO We can check this out of order on global scope as well on second pass by keeping track
	   	//of scope there and then running it here at statement level in scopes and in order when in scope.

	   	//TODO Could check this in the if above if that is better.
	   	if node.right != null && node.right.value.token_type == #char "#" {
	   		//We already parsed this on second pass so no need to parse here in this case
	   		return true;
	   	}

	   	/*In general, we only have constant ints, float and bools. We don't want other constant types. 
	   	For structs, just use a regular type with struct_literal in the global scope and that will be stored 
	   	on the stack in the global scope. This way we can just copy it over with 1 instruction.
	   	Can do the same for struct default values and just store in global scope if we have default values
	   	and then just copy it over with a .mov and otherwise we just do .mset 0 if no defaults are set.
	   	*/
	   	//NOTE : This also checks that we only allow ints, floats and bools as constant for now.
	   	if !IsConstant(node.right) {
				CreateCompErr(cd, .EVALUATION, node.right, "Constant value required.");
				return false;
			}

			//TODO Maybe we should just separate these cases. They are the same just different syntax that is why.
			//So any common functionality like the IsConstant check would remain the same as above.
			//TODO We could just add base literals (float, int, bool) constants for now.
			//Struct would require storing where they are and then going over them on the code pass so we now
			//the size and values of each struct, but then that would require in order processing.
			//SO we could allow global struct constants but they have to be after the declaration of the struct.
	   	if node.value.token_type == .DOUBLE_COLON {
				if node.left.value.token_type != .IDENT {
					CreateCompErr(cd, .EVALUATION, node.left.left, "Identifier required.");
					return false;
				}

				//TODO We could pull out name and type here and just call this on the bottom to reuse
				CreateVarData(cd, node.left.value.token_string, node.right.code_ir.t_info, node.right.code_ir.op);
	   	}
			else if node.left.value.token_type == #char ":" {
				//TODO Can remove this assertion once we know COLON and DOUBLE_COLON are working properly.
				assert(node.left.right != null, "Internal Error : Invalid double colon with no type on node : %.\n", node);
				if node.left.right.code_ir.ir_type != .DATA_TYPE_INFO {
					CreateCompErr(cd, .EVALUATION, node.left.right, "Data type required.");
					return false;
				}
				if node.left.left.value.token_type != .IDENT {
					CreateCompErr(cd, .EVALUATION, node.left.left, "Identifier required.");
					return false;
				}

				right_t_info : *TypeInfo = node.right.code_ir.t_info;
				left_t_info : *TypeInfo = node.left.right.code_ir.t_info;
				if left_t_info != right_t_info {
					CreateCompErr(cd, .EVALUATION, node.right, "Constant value required.");
					return false;
				}

				CreateVarData(cd, node.left.left.value.token_string, left_t_info, node.right.code_ir.op);
			}
		}
		//TODO Check this based on new CompilationLevel flag
		else if cd.comp_level.type == .STATEMENT_LEVEL &&
				node.value.token_type == #char ":" &&
				node.left.value.token_type == .IDENT && 
				node.right.code_ir.ir_type == .DATA_TYPE_INFO 
		{
			//ACTUALLY, I think having this add here works in all cases because even if we create a pointer
			//on the heap, this would still add the pointer size. So I think this is works in all cases.
			//x : int; AND x : int = 0; AND x : *int = New(int);
			//TODO Could check parent.right if we want uninitialized memory.
			node.code_ir.code_value_type = .L_VALUE;
			if node.parent != null && node.parent.value.token_type == #char "=" {
				//TODO I think maybe we don't need this case anymore since we have ":=" as one token now
				//TODO Technically we can just set this later... especially if we can node.right == null
				node.code_ir.t_info = node.right.code_ir.t_info;
			} else if node.parent == null {
				/*TODO If this is a struct, then we need to set it's default values. We could do that with either
				a set of single mov instructions OR store the default struct as a constant and just copy it over
				with one mov instruction with mov_size.
				We can store default struct values in global scope like any global value and then copy it over with 1 .mov.
				*/
				//We only have a declaration and so we want to set default values here.
				//TODO Can put default here and then just mov the default values for structs and things from
				//the constant part in memory at the beggining. Also pointers should default to whatever 
				//null is RamMem(-10000) and store that somewhere.
				//Constant memory copied at the beginning instead of instructions is faster and less instructions than outputting instructions for all constants and struct defaults.
				var := CreateStackVarData(cd, node.left.value.token_string, node.right.code_ir.t_info);
				//TODO Could add default struct or other assignments if needed.
				if var.t_info.type_enum == .POINTER {
					//Default pointer assignment (eg "x : *int;")
					CreateMInstr(.mov, var.op, NULL_POINTER_OP, Imm(var.t_info.runtime_size), d=cd);
				} else {
					//Default assignment is memset to 0
					CreateMInstr(.mset, var.op, Imm(0), Imm(var.t_info.runtime_size), d=cd);
				}

				//TODO We don't really need this since we'll just use the var afterwards I think
				node.code_ir.op = var.op;
				node.code_ir.t_info = var.t_info;
				node.code_ir.ir_type = CodeIRType.STACK_VARIABLE; //Should this be STACK_VARIABLE_DECLARATION?
				node.code_ir.code_value_type = .L_VALUE;

				cd.already_reset_stack = true;
			} else {
				assert(false, "Parent of \":\" : % is invalid node : %.\n", node.*, node.parent.*);
			}
		} 
		else if node.value.token_type == #char ":" && node.left.value.token_type == .IDENT && node.right == null {
			//TODO If we use COLON_EQUALS only, then we can remove this case
			//This is a valid case eg 'y := x + 1;' but we don't do anything and process it at the "=" i think.
			//TODO If we end up doing some processing here, then we can maybe combine it with the above case,
			//since there might be some overlap in the code.
			node.code_ir.code_value_type = .L_VALUE;
		}
		//NOT sure why we had this since the lhs is not declared yes so is unknown but not an error
		// else if node.left != null && node.left.code_ir.ir_type == .UNKNOWN_IDENT {
		// 	CreateCompErr(cd, .EVALUATION, node.left, "Unknown identifier.\n");
		// }
		else if node.right != null && node.right.code_ir.ir_type == .UNKNOWN_IDENT {
			CreateCompErr(cd, .EVALUATION, node.right, "Unknown identifier.");
		}
		else {
			//TODO Maybe this should be an unknown internal error? We have some errors on top as well.
			//NOTE REMINDER : NOW WE IGNORE THIS BECAUSE WE CAN HAVE COLONS INSIDE TANOS like tano(0:2)
			//for count. Maybe we can use something else if it makes more sense.
			//Maybe we can check in that this is in a tano here since the above would be either a comma or
			//then up the tree "," and then tano-"(" so we could check those cases otherwise the ":" is not valid
			// print("Invalid node %\n", node.value);
			//TODO Could set a return value flag to break out of tree traversal loop.
		}
	} 
	case .COLON_EQUALS; #through;
	case #char "="; {
		//TODO This doesn't get processed on evaluation but should I copmile it out just in case?
		/*I've left the code here for "=" BUT we have compiled out the 
		evaluation in favor of moving it 1 level up both for evaluation on lhs
		and also to be able to check if the lhs expression is valid in general.
		HOWEVER we can still use this here for struct member default values
		and also function input default values if we implement those eventually.
		So, if we do, then I can use this here. Can also remove the old "=" code
		once we know it's working after a while which is compiled out below.

		Can reuse the "=" branch default case; below if we decide to put assignment
		evaluation back in here later for some reason.
		*/
		//TODO This can be checked at the parser level and then removed here
		// assert(node.right != null && node.left != null);
		//TODO CompilerError if the left and right types are not the same.
		//TODO Could validate left and right types here and other validation and return error directly.
		//TODO Should this check between ARRAY_LITERAL and other be it's own function?
		//Maybe not since we can reuse it if needed and MULTI_VALUE might be different.
		//TODO CAN LIKELY REMOVE THIS It is unlikely that we need this now since we would check this
		//with the new checking comma nodes while parsing the list there.
		if cd.comp_level.type == .FUNCTION_DECL_INPUT_VARS {
			//TODO ACTUALLY THE RIGHT NODE CAN JUST ACCUMULATE AS A CONSTANT HERE AND THEN WE JUST NEED TO 
			//MAKE SURE IT IS A CONSTANT AND IF ITS AN UNPROCESSED CONSTANT THEN WE STORE IT AND COME BACK TO IT LATER
			//LEFT NODE COULD BE VERIFIED HERE TO BE VALID TYPE AND TOKEN SHOULD BE ":"
			/*TODO We should be able to chek for constant DEFAULT values here on function input.
			  THE WAY CONSTANT SHOULD WORK (at least as a first attempt), is that on first_pass
			  we parse everything that is constant and then if there is anything that does not have
			  a yet parsed constant variable, we store that in an unfinished array and after we finish the first pass
			  we continuously go over that unfinished array until all constants are settled.
			  Technically we can do this with an event-based system where whenever a constant is found, then
			  we can have an event which gets broadcasted and everything that requires that constant would 
			  get updated. This is beneficial because it could happen on a separate thread in some cases.
			  Although then if things depend on those it could get a bit messy.
			*/
		} else if cd.comp_level.type == .STRUCT_DECLARATION {
			//TODO Struct declaration default values can be set here.
			/*THESE COULD BE SET IN MEMORY AS A CONSTANT (maybe at the beginning of memory with other constants).
			Then in order to initialize it with default, we would just have to do a mov from the default constant.
			*/
		} else {
			#if 0 {
			//TODO Reuse this branch if we put "=" back since we will update
			//it in this function from now on afterwards
			EvaluateAssignment(node, cd);
			if cd.comp_errors.all_compiler_errors.count > 0 return false;
			}
		}
	} 
	case .RIGHT_ARROW; {
		//TODO This can be checked at Parser level.
		assert(node.right != null);
		/*DOC : If we have .FUNCTION_DECL_RETURN_VARS && node.left == null then we are the top
		return right arrow since we cannot have node.left == null for a procedure type.

		If .FUNCTION_DECL_RETURN_VARS && node.left != null then
		we can parse a procedure type as a return type normally in the else below
		*/
		if cd.comp_level.type == .FUNCTION_DECL_RETURN_VARS && node.left == null {
			//TODO Can remove this check now that we also use this for function pointers.
			#if 0 {
			if cd.comp_level.type != .FUNCTION_DECL_RETURN_VARS {
				array_add(*cd.comp_errors.all_compiler_errors, MakeCompErr(.EVALUATION,
						sprint("Found right arrow not on return vars : %\n", node.*,,context.allocator)));
				return false;
			}
			}

			func_decl_id : int = peek(cd.function_stack);

			//TODO Can also make this an operand that we add to and then set as an operand in FunctionVariable
			#if 0 {
			return_bytes_from_sbp : int = 0;		
			last_input_var : *FunctionVariable = peek_pointer(cd.all_function_arguments);
			if last_input_var != null && last_input_var.function_id == func_decl_id {
				return_bytes_from_sbp = last_input_var.var_bytes_from_sbp + last_input_var.t_info.runtime_size;
			}
			}

			if node.right.value.token_type == #char "," {
				for cd.comma_node_stack {
					assert(it.top_comma_node == node.right);//Sanity check
					return_var : *FunctionVariable = array_add(*cd.all_function_return_variables);
					return_var.function_id = func_decl_id;
					return_var.var_bytes_from_sbp = cd.byte_offset_from_sbp;
					if it.node.value.token_type == #char ":" {
						return_var.name = node.right.left.value.token_string;
						return_var.t_info = it.node.right.code_ir.t_info;
					} else if it.node.code_ir.ir_type == .DATA_TYPE_INFO {
						return_var.t_info = it.node.code_ir.t_info;
					} else {
						CreateCompErr(cd, .EVALUATION, it.node, "Invalid return value.");
						return false;
					}
					cd.byte_offset_from_sbp += return_var.t_info.runtime_size;
				}
				//Note : We are resetting this on the first pass outer loop so we do it for all cases just in case
				// cd.comma_node_stack.count = return_start_index;
			} else if node.right.code_ir.ir_type == .DATA_TYPE_INFO || node.right.value.token_type == #char ":" {
				return_var : *FunctionVariable = array_add(*cd.all_function_return_variables);
				return_var.function_id = func_decl_id;
				return_var.t_info = node.right.code_ir.t_info;
				return_var.var_bytes_from_sbp = cd.byte_offset_from_sbp;
				if node.right.value.token_type == #char ":" {
					return_var.name = node.right.left.value.token_string;
				}
				//TODO Is this really necessary on function declaration?
				cd.byte_offset_from_sbp += node.right.code_ir.t_info.runtime_size;
			} else {
				CreateCompErr(cd, .EVALUATION, node.right, "Invalid return value.");
				return false;
			}
		} else {
			/*DOC : This is the case of a function pointer with a right arrow and therefore
			we have both input and return arguments.
			eg "x : (int) -> int;" 
			and "() -> ()" 
			and NOT "()" (which is a function with no input or return values)

			NOTE : We are only allowing function pointers with the right arrow notation for now.
			Instead of allowing "(int)" and "(int,int)". The comma parses well but the (int) case
			is ambiguous since it is just a type and I feel like the shorthand is not worth the extra
			parsing for now. Maybe it is later. It will parse properly otherwise and is test in 
			Test_ParseFuncPointer to see which cases are working.
			In any case it feels like requiring the right arrow makes things clearer anyways.
			*/
			arg_nodes : [] *BinaryNode = CommaNodeArrayEmptyToken(node.left, #char ")", cd);
			arg_types : [] *TypeInfo = NewArray(arg_nodes.count, *TypeInfo, false,,cd.expr_alloc);
			for arg_nodes arg_types[it_index] = it.code_ir.t_info;

			return_nodes : [] *BinaryNode = CommaNodeArrayEmptyToken(node.right, #char ")", cd);
			return_types : [] *TypeInfo = NewArray(return_nodes.count, *TypeInfo, false,,cd.expr_alloc);
			for return_nodes return_types[it_index] = it.code_ir.t_info;

			t_info_proc : *TypeInfoProcedure = GetOrCreateTypeInfoProc(arg_types, return_types, *cd.all_type_info_procedure);
			node.code_ir.t_info = cast(*TypeInfo) t_info_proc;
			node.code_ir.ir_type = .DATA_TYPE_INFO;
		}
	}
	//TODO Should this be renamed to .KEYWORD_ROWS?
	//TODO Maybe this should be a base data type like everything else or a struct with x and row members?
	case .DATA_MUNIT; {
		node.code_ir.ir_type = .DATA_IR_MUNIT;
		node.code_ir.operand_type = .MUSIC_MEMORY;
		node.code_ir.t_info = *cd.music_unit_info;
		node.code_ir.code_value_type = CodeValueType.L_VALUE;
	}
	case .KEYWORD_NULL; {
		node.code_ir.t_info = cd.void_pointer_type_info;
		//TODO I think this should be Immediate and not RamMem since the cpu should return
		//NullPointerException if ever we try to get from RamMem(0)
		//Or we could have a negative value and return NullPointerExcpetion at runtime if we ever try to get 
		//a negative value in RamMem like RamMem(-1) or -1000
		node.code_ir.op = NULL_POINTER_OP;
		// node.code_ir.op = RamMem(-1);
		node.code_ir.code_value_type = CodeValueType.R_VALUE;
	}
	case .KEYWORD_TRUE; {
		node.code_ir.t_info = *cd.bool_type_info;
		node.code_ir.op = Imm(1);
		node.code_ir.code_value_type = CodeValueType.R_VALUE;
	}
	case .KEYWORD_FALSE; {
		node.code_ir.t_info = *cd.bool_type_info;
		node.code_ir.op = Imm(0);
		node.code_ir.code_value_type = CodeValueType.R_VALUE;
	}
	//TODO Should this just be an ident with "int" or "float" or "bool" instead of separate token type?
	case .DATA_TYPE_VOID;
		node.code_ir.ir_type = .DATA_TYPE_INFO;
		node.code_ir.t_info = *cd.void_type_info;
	case .DATA_TYPE_BOOL;
		node.code_ir.ir_type = .DATA_TYPE_INFO;
		node.code_ir.t_info = *cd.bool_type_info;
	case .DATA_TYPE_FLOAT;
		node.code_ir.ir_type = .DATA_TYPE_INFO;
		node.code_ir.t_info = *cd.float_type_info;
	case .DATA_TYPE_INT;
		node.code_ir.ir_type = .DATA_TYPE_INFO;
		node.code_ir.t_info = *cd.int_type_info;
	case .DATA_TYPE_STRING;
		node.code_ir.ir_type = .DATA_TYPE_INFO;
		node.code_ir.t_info = *cd.string_type_info;
	case .KEYWORD_TANO;
		//TODO Might be better to set this as default struct tano(0..row_count,0..x_length)
		//and then we can use it like any other tano
		//Then the size of the large tano can be adjusted just by adjusting this but
		//Setting as a type by default so we can do "t0 : tano;" and tano is a data type.
		node.code_ir.ir_type = .DATA_TYPE_INFO;
		node.code_ir.t_info = *cd.tano_struct_info;
	case .KEYWORD_NEUME;
		node.code_ir.ir_type = .DATA_TYPE_INFO;
		node.code_ir.t_info = *cd.neume_struct_info;
	case .IDENT; {
		//We check if an identifier is in fact a struct member by looking up the tree.
		/*We need to do this because of the 2 following cases where the variable has been explicitly
		placed on the left so that this works in both cases. In both of these cases, we need to 
		go up the tree and check parent.left until we hit a "." with parent.right below. Then that shows
		us that this is a struct member so we compute the offset directly before doing the rest.
		This is now tested for the first struct pointer dereference case and works well.
		Still need to test the second case once we're implementing arrays.
		 	  .
   	    / \ 
   	   t   .*
   	       /
   	      p

   		  .
			 / \
			s   [
			   / \
			  x   0
		*/

		//TODO Could make this into a function to find first left parent node
		l_node : *BinaryNode = node;
		while l_node.parent != null && l_node == l_node.parent.left {
			l_node = l_node.parent;
		}
		found_dot_operator : bool = false;
		if l_node.parent != null && l_node == l_node.parent.right && l_node.parent.value.token_type == #char "." {
			found_dot_operator = true;
		}
	
		is_struct_member : bool = false;
		is_enum_dot_value : bool = false;
		if found_dot_operator {
			if l_node.parent.left == null || l_node.parent.left.code_ir.t_info == null {
				//TODO I think we don't need to put identifier since we can set that in the error creation.
				CreateCompErr(cd, .EVALUATION, l_node.parent.left, 
				sprint("Unknown identifier : %.\n",l_node.parent.left.value.token_string));
				return false;
			}
			//TODO We could spit up struct and array case here below if that helps, but there is some overlap
			//since the array can act like a struct and we deal with that below... maybe splitting is clearer, maybe not...
			is_struct_member = 
				AllOrEquals(l_node.parent.left.code_ir.t_info.type_enum,  STRUCT_TYPE_INTERNAL) ||
				l_node.parent.left.code_ir.t_info.type_enum == .ARRAY;
			if !is_struct_member {
				is_enum_dot_value = l_node.parent.left.code_ir.t_info.type_enum == .ENUM;
			}
		}
		if is_struct_member {
			//TODO Should make sure this is a variable and not a DATA_TYPE_INFO
			//TODO Maybe change the name of this...
			struct_node : *BinaryNode = l_node.parent.left;
			struct_info : *TypeInfoStruct = cast(*TypeInfoStruct) struct_node.code_ir.t_info;

			/*TODO Can be do .POINTER auto-dereference in a similar way as arrays here as well?
			TODO We could separte array and struct since we also have an array case on the bottom.
			There is overlap in the case of array view and resizable array since those can be treated as structs
			but maybe it is clearer to separate it anyways.
			IF WE COME BACK HERE OFTEN And get confused between array and struct, then I think we can separate it.
			*/
			array_info : *TypeInfoArray;
			if struct_node.code_ir.t_info.type_enum == .ARRAY {
				array_info = cast(*TypeInfoArray) struct_node.code_ir.t_info;
				if array_info.array_type == {
				case .FIXED;
					//NOTE : We cannot change the values of a fixed array so its an r value.
					//In the case of fa.data[0] then the [ binary op sets the node to an l value.
					node.code_ir.code_value_type = CodeValueType.R_VALUE;
					if node.value.token_string == {
					case "count";
						/*TODO Technically we can remove some instruction in this case since we only need the integer
						for cases like f[1].count then we would have fetched the array in memory but then we only
						need the count which is at compile-time. I will leave the superfluous instructions for now,
						but we could maybe remove them later...
						*/
						//TODO Should this ir data be different since it's a compile-time integer?
						node.code_ir.ir_type = .INTEGER;
						//TODO Maybe this should be more systematic when we are setting operands up the tree.
						FreeOperandRegisters(struct_node.code_ir.op, *cd.all_registers);
						node.code_ir.op = Imm(array_info.array_count);
						node.code_ir.t_info = *cd.int_type_info;
					case "data";
						if struct_node.code_ir.node_op_type == .ADDRESS_IN_MEMORY {
							//If we already have an address in memory then continue using it
							//eg f[1].data[2] in Test_CompileMultiArray
							node.code_ir = struct_node.code_ir;
						} else {
							p_type, found_p_type := GetTypeInfoPointer(array_info.element_type, cd);
							assert(found_p_type);

							//TODO FROM HERE I think we can just store this value on the stack.
							//ALSO use new reusable registers for array access and write some
							//integration tests for that and also something like x.*[0] and x[0].*
							//and then do simple music access as well.
							op_0, op_1 := GetMemoryAddressAsOperands(struct_node.code_ir.op);
							stack_op := PushStack(p_type.runtime_size, cd);
							CreateMInstr(.add, stack_op, op_0, op_1, d=cd);

							node.code_ir.ir_type = .STACK_VARIABLE;
							node.code_ir.op = stack_op;
							node.code_ir.t_info = p_type;
						}
					case;
						//TODO CompilerError
						assert(false, "Invalid fixed array member : %.\n", node.*);
					}
					//Return here since we do not process fixed arrays as structs.
					return true;
				case .VIEW;
					//We set the struct info and then process the array like a struct below.
					struct_info = *cd.array_view_struct_info;
				case .RESIZABLE;
					struct_info = *cd.resizable_array_struct_info;
				}
			}

			//TODO MAYBE WE CAN PULL THIS OUT ONCE WE DO STRUCT POINTER and just reuse v0 and v1
			//So we would just grab the address and set in register and then reuse this same code after.
			//Maybe should do pointer dereference first.
			member_info, found_member_info := GetStructMember(node.value.token_string, struct_info);
			if !found_member_info {
				CreateCompErr(cd, .EVALUATION, node, 
				sprint("Unknown struct member : %.", node.value.token_string));
				return false;
			}

			//TODO InternalError? Maybe we should put this in AddOperandOffset
			assert(struct_node.code_ir.op.values[0].type == .REGISTER);
			node.code_ir.op = struct_node.code_ir.op;
			if struct_node.code_ir.node_op_type == .ADDRESS_IN_MEMORY {
				//TODO FROM HERE Should we put this on the stack? I think ADDRESS_IN_MEMORY is always on the stack though.
				//We could just add it to the stack anyways to avoid any issues later anyways.
				//I THINK WE SHOULD DOCUMENT THAT THIS IS TEMPORARILY ON THE STACK and 
				/*DOC : If we remove the following line on the stack then we just add the member offset directly to the
				value already on the stack. I think that that would actually work in general but in case I am not thinking
				about a specific edge case where that's not true we will always push on the stack here for array access.
				It adds an extra mov instruction which is a bit annoying, but I would rather be safe than have a wierd issues later.
				I guess testing would be a bit simpler without this as well. I don't know what the right answer is in any case.

				Currently this only applies to array access and dereference operator so maybe it's fine overall.
				*/
				// node.code_ir.op = PushStackMov(struct_node.code_ir.op, cd.void_pointer_type_info.runtime_size, cd);
				// node.code_ir.op = PushStackMov(struct_node, cd);
				node.code_ir.node_op_type = .ADDRESS_IN_MEMORY;
				CreateMInstr(.add, node.code_ir.op, Imm(member_info.offset_in_bytes), d=cd);
			} else {
				AddOperandOffset(member_info.offset_in_bytes, *node.code_ir.op);
			}

			node.code_ir.code_value_type = CodeValueType.L_VALUE;
			node.code_ir.ir_type = .STACK_VARIABLE;
			if struct_node.code_ir.t_info.type_enum == .ARRAY && member_info.name == "data" {
				//NOTE : We process this here so it can be the same as other structs except
				//we just the data member for arrays to the proper pointer type here.
				//TODO Could use something like this for other auto-casting behavior eventually.
				t_pointer_info := GetOrCreateTypeInfoPointer(array_info.element_type, cd);
				node.code_ir.t_info = cast(*TypeInfo) t_pointer_info;
			} else {
				node.code_ir.t_info = member_info.t_info;
			}
		} else if is_enum_dot_value {
			enum_node : *BinaryNode = l_node.parent.left;
			enum_info := cast(*TypeInfoEnum) enum_node.code_ir.t_info;

			found_enum_value : bool = false;
			enum_value : int;
			for enum_info.names if it == l_node.value.token_string {
				enum_value = enum_info.values[it_index];
				found_enum_value = true;
				break;
			}
			assert(found_enum_value); //sanity check

			l_node.code_ir.t_info = enum_info;
			l_node.code_ir.op = Imm(enum_value);
			l_node.code_ir.code_value_type = .R_VALUE;

		//TODO Should we keep this here for generalize unknown ident?
		// } else if node.code_ir.ir_type == .UNKNOWN_IDENT {
		// 	CreateCompErr(cd, .EVALUATION, node, "Unknown identifier.");
		// 	return false;
		} else {
			//We can check in here if we either have a stack var or heap memory or a function name.
			//TODO If we did a reverse array search here then we would find the correct variable right away
			var, found_var := ArrayFindFirstByNameId(cd.variable_data_stack, node.value.token_string, "name");

			//TODO Maybe this is inefficient to check here and we should just check it on function calls?
			/*DOC : For now we don't do function name overload type inference so we just error out if we find > 1.
			A current work around is setting a function pointer eg (x : (int) -> int = Foo;) by specific type.
			I will likely implement it later but it seems better to wait until all type check cases 
			(eg .[], .{}, Foo(), return...) are checked before setting them all to resolve the type or error out in a similar way.

			TODO We could set all overloads in a map here and then just get the map directly instead.
			*/
			func_overload_count : int = 0;
			func_decl : FunctionDeclaration;
			for cd.all_function_declarations if it.name == node.value.token_string {
				func_overload_count += 1;
				func_decl = it;
			}

			struct_type, found_struct_type := GetTypeInfoStructByName(node.value.token_string, cd.all_type_info_struct);

			found_enum_type : bool = false;
			enum_type : *TypeInfoEnum;
			if !found_struct_type {
				enum_type, found_enum_type = GetTypeInfoEnumByName(node.value.token_string, cd.all_type_info_enum);
			}

			found_directive_type_name : bool = false;
			directive_type_name : DirectiveTypeName;
			if !found_enum_type {
				directive_type_name, found_directive_type_name = GetDirectiveTypeByName(node.value.token_string, cd.all_directive_type_names);
			}

			//We check for local var here first, if we find it then we use that. This allows us to have local
			//variables with the same name as structs or enums. I think this is how it's done in jai.
			//If we have structs or functions with the same now, that should return a CompilerError.
			if found_var {
				node.code_ir.code_value_type = CodeValueType.L_VALUE;
				node.code_ir.ir_type = .STACK_VARIABLE;
				node.code_ir.ir_data_id = var.id;
				//TODO Do we have to cast type_info here, or should we just use id and type instead of pointer?
				node.code_ir.t_info = var.t_info;
				//TODO Maybe this variable is in a reg so we could set something like that as well.
				//TODO Also if it's in memory then the address would be somewhere and we'd have to create an
				//instruction and then load the register we store that in here.
				//THIS MIGHT WORK NOW WITH NEW VARIABLE STRUCTURE.
				//TODO If we have an array here, should we put the data and count in registers.
				//TODO If we have an array here then make a RamArray Op from the var op so that we can
				//pass that up and then free the registers later. We can't store it in var.op directly
				//because the register will get reused.
				node.code_ir.op = var.op;
			} 
			else if found_struct_type {
				node.code_ir.ir_type = .DATA_TYPE_INFO;
				// node.code_ir.ir_data_id = struct_type.id;
				//TODO Should we use type and id here instead of pointer to avoid pointer memory issues?
				node.code_ir.t_info = cast(*TypeInfo) *struct_type.info;
				node.code_ir.code_value_type = CodeValueType.R_VALUE;
			} 
			else if found_enum_type {
				node.code_ir.ir_type = .DATA_TYPE_INFO;
				// node.code_ir.ir_data_id = struct_type.id;
				//TODO Should we use type and id here instead of pointer to avoid pointer memory issues?
				node.code_ir.t_info = cast(*TypeInfo) *enum_type.info;
				node.code_ir.code_value_type = CodeValueType.R_VALUE;				
			}
			else if found_directive_type_name {
				node.code_ir.ir_type = .DATA_TYPE_INFO;
				node.code_ir.t_info = directive_type_name.t_info;
				// node.code_ir.code_value_type = CodeValueType.R_VALUE;				
			}
			else if func_overload_count > 0 {
				node.code_ir.ir_type = .FUNCTION_NAME;
				node.code_ir.t_info = cast(*TypeInfo) func_decl.t_info_proc;
				node.code_ir.code_value_type = CodeValueType.R_VALUE;

				/*DOC : If this is a function pointer assignment, then we set it later. This allows us to not
				implement type inference for now since we would have to do it everywhere and it is likely better
				to do once everything is workign and all type inference cases are known.
				"x : (int) -> int = Foo;"
				where x can replace foo when using function pointers if Foo is function overloaded.
				SO we have 3 cases
				1) if parent is assignment("=" or ":=") or function call("(") then we evaluate the types with overloads later.
				2) not an assignment or function call, but we only have 1 function so we use it directly
					if the function code is not evaluated yet, then we set the value on the stack and 
					update the value of the asm index of the function call later with out of order instrs
				3) we have function overloads and so we suggest setting it to a function pointer.
					we will likely implement this later when we do type inference everywhere with
					things like eg(.[], .{}, return, foo(args),...), unless we remove function overloads altogether

				REMINDER : We could remove function overloads altogether and then we would just have to create
				the instruction here if we have not evaluated the function code yet. This might be the best option
				overall since I usually just rename my function with different names for clarity.
				NO FUNCTION OVERLOADS would remove all the extra type checking as well since everything could be done here.

				ALSO THE ARGUMENT of keeping it this way so we can use function overloads and function pointers if needed
				but function overloads are discouraged in this language, just like strings.
				*/
				if AllOrEquals(node.parent.value.token_type, .[#char "=", .COLON_EQUALS]) {
					//Explicitly don't do anything so we evaluate this later WITH function overloads.
					//This allows us to still have a way of using function with overloads as function pointers,
					//eg to pass in function as arguments.
				} 
				else if node.parent.value.token_type == #char "(" && node == node.parent.left {
					//We have a function call "Foo()" and currently allow overloading for that so we check it at the function call.
					//NOTE : If we only have 1 function then the type is good so we could use it directly in "(" evaluation
					//So we store that here with ir_data_id as this is likely going to be the most common case.
					//I think this is confusing and will be more properly replace by a hash map later anyways
					// node.code_ir.ir_data_id = func_overload_count;
				}
				else if func_overload_count == 1 {
					if !func_decl.function_code_evaluated {
						/*DOC : If it's not evaluated yet, we put it on the stack so we can make an instruction
						so we can update the value later. It is true that we could just update the op but that would
						be more complicated in the compiler for no real gain.
						This is necessary whether we have function overloads or not so this will likely remain this way regardles.
						*/
						array_add(*cd.all_out_of_order_instrs, .{func_decl.id, cd.all_music_instructions.count, 1});
						node.code_ir.op = PushStackMov(Imm(0), cd.void_pointer_type_info.runtime_size, cd);
					} else {
						node.code_ir.op = Imm(func_decl.start_instr_index);
					}
				}
				else if func_overload_count > 1 {
					CreateCompErr(cd, .EVALUATION, node, 
#string DONE
Multiple function overloads found. 
Function pointer by name inference not implemented yet. 
Can assign to a specific function pointer with specified function type.
DONE
					);
					return false;
				}
			} 
			else {
				//TODO This can be checked for errors up the tree on nodes where we should have a known identifier.
				node.code_ir.ir_type = .UNKNOWN_IDENT;
				node.code_ir.code_value_type = CodeValueType.NONE;
			}
		}
		//TODO If we don't find it then we just continue. This means that we may not have declared that variable yet.
		//So we should also check this on things like operators. 

		//TODO Would also check for struct data type names here after we have structs and should collect
		//those beforehand or more conveniently with a first pass together with function declarations and enums and constants.
	}
	case .INTEGER; {
		//TODO This could be done in ParseExpression when creating a leaf for all constants
		SetIntegerNode(node, node.value.int_value, cd);
	}
	case .FLOAT; {
		//TODO This could be done in ParseExpression when creating a leaf for all constants
		node.code_ir.ir_type = .FLOAT;
		node.code_ir.code_value_type = CodeValueType.R_VALUE;
		node.code_ir.t_info = *cd.float_type_info;
		node.code_ir.op = FImm(node.value.float_value);
	}
	case .STRING; {
		//TODO This could be done in ParseExpression when creating a leaf for all constants
		node.code_ir.ir_type = .STRING_LITERAL;
		node.code_ir.code_value_type = CodeValueType.R_VALUE;
		node.code_ir.t_info = *cd.string_type_info;

		/*Right now we allocate the actual string (eg "test") to the heap and then push (4,heap_pointer) to the stack for future reference.
		The problem with this is for a case like function call Foo("test") then that heap memory is lose. It does not really matter
		in general but we should probably check cases like that to create the string on the stack.
		For now I will just recommend using NewString() function which will store it and return it.
		In general strings people should create strings in a special place which is either used throughout or reused and cleared.
		*/
		//TODO Should we make this a function GetStackCurrentOp or is this function enough?
		node.code_ir.op = RamMem(.sbp, cd.byte_offset_from_sbp);
		PushStackMov(Imm(node.value.token_string.count), cd.int_type_info.runtime_size, cd);
		//We store the string bytes on the heap and then put the heap data pointer on the stack
		data_address := RamMem(.sbp, cd.byte_offset_from_sbp);
		CreateMInstr(.alloc, Imm(node.value.token_string.count), data_address, d=cd);
		AddByteOffsetFromSbp(cd.int_type_info.runtime_size, cd);

		const_address : int = AddConstantMemory(node.value.token_string.data, node.value.token_string.count, 
			*cd.constant_memory);
		CreateMInstr(.mov, RegMem(.ax), data_address, Imm(cd.void_pointer_type_info.runtime_size), d=cd);
		CreateMInstr(.const_mov, RamMem(.ax), Imm(const_address), Imm(node.value.token_string.count), d=cd);

		//TODO Best to store it on the stack actually
		//TODO FROM HERE we just removed the "mov x, x" same place AND ALSO strings should be stored on the stack
		//OR in a constant space somewhere (could be in between stack and heap) OR we can just put constants
		//in compilation data and have a special constant instructions which moves from there since we would
		//be copying from there anyways before executing. Then we could use
		//const RamMem(stack/heap), RamMem(constant), Imm(size)
		//to copy it over at runtime from constant memory and not effect the stack and heap
		//USING const instruction would also be easier to debug in general. We could store it in a separate
		//executable data in any case for execution instead of compile-time. This would be similar to
		//the .text section of asm for c
		//OR copy it to a constant section (between stack and heap maybe with a .const or .hp register)
		//before executing and just copy from there at runtime
		//USING A constant section allows us to not add any extra instructions and we can just add a .const reg
		//and access it with that and set const values to RamMem(.const, x)
		//Then we would load up all the values before executing and access them directly
		//could write tests to make sure everything is set properly. This could be used to save constant
		//strings and constant struct literals or default struct literals and we can store the op on the first
		//pass if it's in global scope.
		//WE COULD JUST STORE STRINGS IN THE CONSTANT SECTION and have everything else be declared
		//then struct literals and array literals would be embedded in the code instead
		//could store struct defaults in the constant section
		#if 0 {
		//We set the string in heap memory with the given pointer
		//TODO Likely better to just do this in a constant section with a .const pointer once we implement that.
		CreateMInstr(.add, RegMem(.ax), RegMem(.sbp), Imm(cd.byte_offset_from_sbp));
		for string_char : node.value.token_string {
			CreateMInstr(.mov, RamMem(.ax), Imm(string_char), Imm(1), d=cd);
			CreateMInstr(.add, RegMem(.ax), Imm(1));
		}
		}
	}
	}
	//TODO Should this not return false if we did not find a valid case for the node?
	//TODO we can also have some invalid nodes like "~=" binary op at the bottom here that if we find can return
	//a clear and explicit error and use the bottom here for unknown errors so at least we 
	//don't compile something that we do not know about
	return true;
}

CompFuncCallData :: struct {
	node : *BinaryNode;
	argument_nodes : [] *BinaryNode;
	is_function_pointer : bool;
	proc_type : *TypeInfoProcedure;
	//IF is_function_pointer the we don't use this since we only have the specific function at runtime.
	func_decl : FunctionDeclaration;
}
CompileFunctionCall :: inline (cfcd : CompFuncCallData, cd : *CompilationData) -> success : bool {
	//TODO If we allow RHS commas, then we would have to go up the "," tree to check if we have "="
	//ALSO TODO If we allow things like "+=" and "-=" with node_comma_list then we would have to
	//check for any of those assignment type operators and LHS would be the same node
	node := cfcd.node;
	all_return_ops : [] MusicOperand;
	if node.parent == null {
		//Explicitly do nothing since this is just a function call
	} else {
		//TODO Could use CommaNodeArray and just do it from "," to get multi-return values array
		//In this case, we store the values on the stack so we can point to them in the function directly
		//to populate the return value during function execution.
		return_count : int;
		if !cfcd.func_decl.is_operator_overload &&
			(node.parent.value.token_type == .COLON_EQUALS || node.parent.value.token_type == #char "=") &&
			 node.parent.left != null && node.parent.left.value.token_type == #char "," 
		{
			//This is the only case where we return multiple values
			//eg x,y = foo(); OR x,y := foo();
			for cd.comma_node_stack if it.top_comma_node == node.parent.left {
				return_count += 1;
				array_add(*cd.all_multi_return_memory_ops, .{node, it.node, .{}});
			}

			if cfcd.proc_type.return_types.count < return_count {
				CreateCompErr(cd, .EVALUATION, node,
				sprint("Max # of return types for procedure is : %.", cfcd.proc_type.return_types.count));
				return false;
			}

			all_return_ops = NewArray(return_count, MusicOperand,, context.allocator);
			for 0..return_count-1 {
				return_type : *TypeInfo = cfcd.proc_type.return_types[it];
				all_return_ops[it] = RamMem(.sbp, cd.byte_offset_from_sbp);
				//TODO Would update this with struct defaults later if needed.
				//TODO What if we allowed push to do a .mset on mov_size push with single_value... hmmm, maybe this is clearer
				CreateMInstr(.mset, RamMem(.scp), Imm(0), Imm(return_type.runtime_size), d=cd);
				AddByteOffsetFromSbp(return_type.runtime_size, cd);

				//If we have multiple return values, then we store them here so we can know where they are in memory later.
				//This also allows for optimizations later if we decide to for cases like x,y = foo() where we already know where x,y is in memory.
				cd.all_multi_return_memory_ops[it].return_mem_op = all_return_ops[it];
			}

			cd.multi_return_type_info_proc = cfcd.proc_type;
		} else {
			return_count = 1;
			if cfcd.proc_type.return_types.count < return_count {
				CreateCompErr(cd, .EVALUATION, node,
				sprint("Max # of return types for this procedure is : %.", cfcd.proc_type.return_types.count));
				return false;
			}

			all_return_ops = NewArray(return_count, MusicOperand,, context.allocator);
			return_type : *TypeInfo = cfcd.proc_type.return_types[0];
			//NOTE : This is on the previous stack before storing registers so we store it directly without negative sbp
			all_return_ops[0] = RamMem(.sbp, cd.byte_offset_from_sbp);
			// all_return_ops[0] = RamMem(.sbp, -PRE_PROC_STACK_SIZE - return_type.runtime_size);
			AddByteOffsetFromSbp(return_type.runtime_size, cd);

			/*DOC : We reset tano stack here in case we have something like "return tano(0,0) + 1;"
			This way the return value stays on the stack for the statement which contains the function call.
			foo :: (t : tano) -> tano {
				return t + 1; -> WE SET this on the tano stack but dont reset the tsp so it stays on
			main :: () {
				tano(1,0) ~= foo(tano(0,0)); -> foo returns tano so we reset tano stack after this expression

			TODO IMPLEMENT THIS FOR A FULL TEST IF WE HAVE Test_TanoFunc
			tano(1,0) ~= foo(tano(0,0) + 1) ~ foo(tano(1,1) - 1);
			THEN The the .tsp will only be reset after the entire expression so each return value will still
			be stored properly on the tano stack. the tbp will be set to tsp for each function call since we
			have a tano op but then it will get reset with the pop_all_stack_reg
			*/
			if return_type.type_enum == .TANO {
				cd.reset_tano_stack = true;
			}
		}

		//TODO should we put all the return ops somewhere or is the first one good enough.
		//We can derive the rest from the FunctionVariable with type sizes
		//TODO We can set this above now if we only set this
		node.code_ir.op = all_return_ops[0];
		node.code_ir.t_info = cfcd.proc_type.return_types[0];
		node.code_ir.code_value_type = CodeValueType.R_VALUE;
	} 


	/*TODO We can use this optimization later if the parent is "=" BUT we would have to store the values
	AHEAD of time if we had a x,y := foo() situation since x,y are not in memory yet... sooo we'll see.
	Although this would work pretty easily for x,y = foo() case since we could just get x,y from the LHS here.
	We could also create the variables here and set them as being already created somewhere for x,y := foo()
	that is likely the best option for optimization.
	*/
	//TODO Can remove this optimization case now once everything is working because this is only for the case
	//x, y = foo() so we reuse x, y but it is not worth it and we just push instead and then mov it over later now
	#if 0 {
	if node.parent.value.token_type == #char "=" {
		//We want to grab the values on the left since they are already assigned variables
		//TODO Check that these are already assigned variables... Although maybe we could check that in "," LHS instead
		if node.parent.left.value.token_type == #char "," {
			return_comma_nodes : [] CommaNode = ArrayFindAllVarName(cd.comma_node_stack, node.parent, "top_node",,context.allocator);
			if cfcd.proc_type.return_types.count < return_comma_nodes.count {
				CreateCompErr(cd, .EVALUATION, node,
				sprint("Max # of return types for this procedure : %.\n", cfcd.proc_type.return_types.count));
				return false;
			}
			all_return_ops = NewArray(return_comma_nodes.count, MusicOperand,,context.allocator);
			for return_comma_nodes {
				all_return_ops[it_index] = it.node.code_ir.op;
			}
		} else {
			all_return_ops = NewArray(1, MusicOperand,,context.allocator);
			all_return_ops[0] = node.parent.left.code_ir.op;
		}
	}
	}

	//TODO Is this enough or should we check if we want to make sure it's reset properly... although it gets
	//reset by the instructions anyways with .mov scp, sbp
	//I think we can remove this altogether now since we don't update it again
	last_function_byte_offset_from_sbp : int = cd.byte_offset_from_sbp;

	//NOTE REMINDER IMPORTANT : This uses the RAM location and not the value in memory
	//worth remembering that since it caused a bug
	CreateMInstr(.push_all_stack_reg, RamMem(.sbp, cd.byte_offset_from_sbp), d=cd);

	// cd.byte_offset_from_sbp += PRE_PROC_STACK_SIZE;
	//NOTE : We add the stack_reg_size + 8 here for all the register and 8 for the post_call_index
	AddByteOffsetFromSbp(PRE_PROC_STACK_SIZE, cd);


	BEFORE :: false;
	#if BEFORE {
	/*TODO Why are we not doing this before setting the args and then adding input args starting at [sbp,0]? 
	Maybe there is a good reason but I forget... I think it's worth trying but maybe there is a good reason indeed.
	*/
	//We set the sbp here to the current position
	CreateMInstr(.add, RegMem(.sbp), RegMem(.sbp), Imm(cd.byte_offset_from_sbp), d=cd);

	//TODO Should we set this before are after setting arg nodes?
	//We set the tbp if we have values on the tano stack (ie have tano operations in the function arguments)
	for cfcd.argument_nodes if it.code_ir.on_tano_stack {
		CreateMInstr(.mov, RegMem(.tbp), RegMem(.tsp), d=cd);
		break;
	}
	}

	//Note : Push on function arguments to the next stack before changing the .sbp
	#if BEFORE {
	next_stack_p : int = 0;
	} else {
	next_stack_p : int = cd.byte_offset_from_sbp;
	}
	values_on_tano_stack : bool = false;
	for arg_node : cfcd.argument_nodes {
		// if arg_node.code_ir.t_info.runtime_size <= 8 {
			//Copy by value (pointers and values <= 8 bytes)
			//TODO We could just put a .push since we don't need to update the byte_offset_from_sbp
			// PushStackMov(arg_node, cd);
			#if BEFORE {
			arg_size : int = arg_node.code_ir.t_info.runtime_size;
			CreateMInstr(.mov, RamMem(.sbp,next_stack_p), arg_node.code_ir.op, Imm(arg_size), d=cd);
			//NOTE : We don't want to do AddByteOffsetFromSbp() because this is on the next stack, so it does not
			//count for the max.
			// AddByteOffsetFromSbp(arg_size, cd);
			next_stack_p += arg_size;
			} else {
			if IsArrayInfoType(.VIEW, cfcd.proc_type.argument_types[it_index]) &&
				IsArrayInfoType(.FIXED, arg_node.code_ir.t_info)
			{
				arg_fixed_array_type := cast(*TypeInfoArray) arg_node.code_ir.t_info;
				//Move array count
				CreateMInstr(.mov, RamMem(.sbp,next_stack_p), Imm(arg_fixed_array_type.array_count), Imm(cd.int_type_info.runtime_size), d=cd);
				//Move array data
				SetAddressNode(arg_node, RamMem(.sbp,next_stack_p+8), cd);
				next_stack_p += cd.array_view_struct_info.runtime_size;
			} else {
				arg_node_op : MusicOperand = GetValueOp(arg_node, cd, .r0);
				arg_size : int = arg_node.code_ir.t_info.runtime_size;
				CreateMInstr(.mov, RamMem(.sbp,next_stack_p), arg_node_op, Imm(arg_size), d=cd);
				//NOTE : We don't want to do AddByteOffsetFromSbp() because this is on the next stack, so it does not
				//count for the max.
				next_stack_p += arg_size;
			}
			}
		// } else {
			//TODO COMMENT THIS CASE OUT CAN JUST COPY FOR NOW for simplicity in compiler and debugger
			//Copy by reference (should be restricted pointer if it's not an actual pointer)
			//TODO we could make a function get pointer probably since we reuse this quite often
			// reg := OLDGetOrReuseRegister(arg_node, cd);
		// 	op_0, op_1 := GetMemoryAddressAsOperands(arg_node.code_ir.op);
		// 	CreateMInstr(.add, RegMem(.ax), op_0, op_1, d=cd);
		// 	PushStackMov(RegMem(.ax), 8, cd);
		// }
		FreeOperandRegisters(arg_node.code_ir.op, *cd.all_registers);

		if arg_node.code_ir.on_tano_stack {
			values_on_tano_stack = true;
		}
	}

	/*DOC : We are doing this after because otherwise we cannot pass on the argument from the previous stack sbp
	directly. So if on the previous stack we had something at [sbp+40], after we update the sbp reg, we would
	lose that value. So instead of updating each previous value we update the input values since we know
	exactly where they are since we keep track of the stack anyways.
	*/
	#if !BEFORE {
	/*TODO Why are we not doing this before setting the args and then adding input args starting at [sbp,0]? 
	Maybe there is a good reason but I forget... I think it's worth trying but maybe there is a good reason indeed.
	*/
	//We set the sbp here to the current position
	CreateMInstr(.add, RegMem(.sbp), RegMem(.sbp), Imm(cd.byte_offset_from_sbp), d=cd);

	//We set the tbp if we have values on the tano stack (ie have tano operations in the function arguments)
	if values_on_tano_stack {
		CreateMInstr(.mov, RegMem(.tbp), RegMem(.tsp), d=cd);
	}
	}

	//TODO Maybe we can move around the stack setting before adding this maybe if we do it change it
	//Set the tsp (tano stack pointer) to the current tano stack position
	// CreateMInstr(.add, RegMem(.tsp), RegMem(.tsp), Imm(cd.row_offset_from_tsp), d=cd);

	//TODO We could set this at RamMem(.sbp,0) if needed and then move the add scp here.
	//This way our function arguments are the first thing on the stack which seems cleaner but 
	//maybe there is another reason to have the return value on first.
	#if 1 {
	return_jmp_instr_index : int = cd.all_music_instructions.count;
	}
	// CreateMInstr(.mov, PROC_RETURN_OP, Imm(post_call_index), d=cd);
	//TODO We can just set this to below without return_jmp_instr_index since we only have call after this
	//NOTE : We set this here because we can set it instr.count+2 (this+call+pop) so it jmps back to pop_all_stack_reg directly 
	//ALSO we can set it to [sbp-8] after we reset the sbp for the new function stack
	//which makes it clear what the return instruction is in the same because of the [sbp-8]
	// post_call_index : int = cd.all_music_instructions.count + 2;
	CreateMInstr(.mov, PROC_RETURN_OP, Imm(0), d=cd);

	//TODO We can remove this now that removed function return values as pointers
	#if !NEW_FUNC {
	if all_return_ops.count > 0 {
		//TODO should we put all the return ops somewhere or is the first one good enough.
		//We can derive the rest from the FunctionVariable with type sizes
		//TODO We can set this above now if we only set this.
		//We are setting it in both places so I think we can remove it from 1 of them.
		//Maybe we can clean it up once we complete multiple return ops.
		node.code_ir.op = all_return_ops[0];
		node.code_ir.t_info = cfcd.proc_type.return_types[0];
		node.code_ir.code_value_type = CodeValueType.R_VALUE;
		//Note : Push on function return pointers
		for all_return_ops {
			op_0, op_1 := GetMemoryAddressAsOperands(it);
			//sanity check since all return values should be stored on the stack from before right now.
			//If we allow them to be stored somewhere else then we would have to add the pointer somehow after.
			assert(op_0.operand_type == .REGISTER && op_0.values[0].int_value == cast(int) RegDef.sbp);
			CreateMInstr(.add, RegMem(.ax), PREVIOUS_SBP_OP, op_1, d=cd);
			PushStackMov(RegMem(.ax), 8, cd);
		}
	}
	}

	if cfcd.is_function_pointer {
		//We have a function pointer so we call to the position in the pointer in memory;
		CreateMInstr(.call, RegMem(.foop), d=cd);		
	}
	//NOTE : Need to check node.left != null for unary op overloads (although putting op overload check probably resolves that too)
	else if cfcd.func_decl.is_operator_overload || 
		(node.left != null && node.left.code_ir.ir_type == .FUNCTION_NAME)
	{
		if !cfcd.func_decl.function_code_evaluated {
			array_add(*cd.all_out_of_order_instrs, .{cfcd.func_decl.id, cd.all_music_instructions.count, 0});
		}
		CreateMInstr(.call, Immediate(cfcd.func_decl.start_instr_index), d=cd);
	} 
	else {
		assert(false, "Invalid function call %.\n", node);
	} 

	#if 1 {
	//TODO Can remove this and just use set it direclty before since now we just have the call after
	//We set the value here so we can jmp back here on a KEYWORD_RETURN.
	//TODO We can remove this and just set it above to cd.all_music_instructions.count+1 since it is just the next one.
	return_instr : *MusicInstruction = *cd.all_music_instructions[return_jmp_instr_index];
	return_instr.operands[1].values[0].int_value = cd.all_music_instructions.count;
	}

	//Inverse of CreateOpenFunctionInstrs we "sub scp, sbp, 8" and then pop RamMem(.scp) to .sbp
	//We subtract 8 from sbp since the last value is where to jmp back to and we no longer need it.
	//TODO I think we can remove this when we don't reset scope since we get it from the stack anyways
	//YES WE CAN REMOVE because the .scp will get reset from the stack anyways.
	// CreateMInstr(.sub, RegMem(.scp), RegMem(.sbp), Imm(8), d=cd);
	// CreateMInstr(.pop, RegMem(.sbp), d=cd);
	/*DOC : We pop from srp since we want to set it on ret instruction so we can see proper variables
	when we return from the function but then still hit an instruction and pop the rest of the registers after.
	*/
	//NOTE REMINDER IMPORTANT : This uses the RAM location and not the value in memory
	//worth remembering that since it caused a bug
	CreateMInstr(.pop_all_stack_reg, PREVIOUS_SBP_OP, d=cd);


	cd.byte_offset_from_sbp = last_function_byte_offset_from_sbp;
	return true;
}

CommaNodeArray :: inline (node : *BinaryNode, cd : *CompilationData) -> [] *BinaryNode {
	//TODO Can add struct literals here once we implement that
	//TODO We could remove this and just assume it is the "," structure
	assert(AllOrEquals(node.value.token_type, .[#char "(", .ARRAY_LITERAL, .KEYWORD_RETURN]));
	array_reset_keeping_memory(*cd.comma_node_array);
	if node.right.value.token_type == #char "," {
		//TODO Can pull this out and reuse for commas instead of the comma_node_stack which might be more efficient
		//because we load up while were traversing the tree. But this seems less prone to error even though
		//we have to grab the var_nodes again down the comma stack. Also makes more sense in my head overall.
		// var_nodes : [..] *BinaryNode;
		// var_nodes.allocator = cd.expr_alloc;
		//TODO We just reset this everytime we use it and can do this in a function afterwards
		//and then reuse this for array literals and test that on music mem.
		//TODO This is also something we can use an allocator which gets reset after every expression for.
		//So we would just accumulate the arrays and then reset it afterwards.
		comma_node := node.right;
		while comma_node.left.value.token_type == #char "," {
			array_add(*cd.comma_node_array, comma_node.right);
			comma_node = comma_node.left;
		}
		//NOTE : Right goes on first so we keep the reverse order and put the left (first node in list) on last.
		if comma_node.right != null {
			array_add(*cd.comma_node_array, comma_node.right);
		}
		if comma_node.left != null {
			array_add(*cd.comma_node_array, comma_node.left);
		}
		ArrayReverseInPlace(cd.comma_node_array);
	} else if node.right != null {
		//TODO If there is nothing on the right then we should return an empty array.
		//We only have 1 input to tano so we just take that input
		// var_nodes = .[node.right];
		array_add(*cd.comma_node_array, node.right);
	} else {
		//Explicit case where the comma_node_array.count == 0 since we have no values
	}
	return cd.comma_node_array;
}

CommaNodeArrayEmptyToken :: inline (node : *BinaryNode, empty_token : CodeTokenType, cd : *CompilationData) -> [] *BinaryNode {
	assert(node != null, "This should be checked outside for non-null");
	cna : [] *BinaryNode;
	if node.value.token_type == empty_token {
		//Explicitly return an empty array
	} else {
		cna = NewCommaNodeArray(node, cd);
	}
	return cna;
}

//REMOVE the old function if we just use this one now and rename this to CommaNodeArray
NewCommaNodeArray :: inline (node : *BinaryNode, cd : *CompilationData) -> [] *BinaryNode {
	//TODO Can add struct literals here once we implement that
	//TODO We could remove this and just assume it is the "," structure
	// assert(AllOrEquals(node.value.token_type, .[#char "(", .ARRAY_LITERAL, .KEYWORD_RETURN]));
	assert(node != null, "This should be checked outside for non-null");
	//TODO Test expr_alloc here, we could allow resize in MySimplePool (maybe even with a flag)
	//OTHERWISE we can use a Flat_Pool that we free after every compilation. Maybe that would be slower though...
	//OR we could store that somewhere else and reuse it every time. This way we just use memory from the given allocator
	//and then we reset that after every loop.
	c_nodes : [..] *BinaryNode;
	//TODO FROM HERE need to use an allocator
	c_nodes.allocator = cd.expr_alloc;
	// array_reset_keeping_memory(*cd.comma_node_array);
	if node.value.token_type == #char "," {
		comma_node := node;
		while comma_node.left.value.token_type == #char "," {
			array_add(*c_nodes, comma_node.right);
			comma_node = comma_node.left;
		}
		//NOTE : Right goes on first so we keep the reverse order and put the left (first node in list) on last.
		if comma_node.right != null {
			array_add(*c_nodes, comma_node.right);
		}
		if comma_node.left != null {
			array_add(*c_nodes, comma_node.left);
		}
		ArrayReverseInPlace(c_nodes);
	} 
	else {
		//TODO If there is nothing on the right then we should return an empty array.
		//We only have 1 input to tano so we just take that input
		// c_nodes = .[node.right];
		array_add(*c_nodes, node);
	}
	return c_nodes;
}


AddedToStack :: inline (cd : CompilationData) -> bool {
	added_to_stack : bool = cd.expr_byte_offset_from_sbp < cd.byte_offset_from_sbp;
	return added_to_stack;
}
ResetStack :: inline (cd : *CompilationData) {
	//If we did not add anything to the stack, then no need to reset.
	//TODO Could also check already_reset_stack here if that works everywhere.
	// if !AddedToStack(cd.*) return;
	// CreateMInstr(.mov, RegMem(.scp), Imm(cd.expr_byte_offset_from_sbp), d=cd);
	// CreateMInstr(.add, RegMem(.scp), RegMem(.sbp), Imm(cd.expr_byte_offset_from_sbp), d=cd);
	cd.byte_offset_from_sbp = cd.expr_byte_offset_from_sbp;
	cd.already_reset_stack = true;
}

IsDeclarationAssignment :: inline (node : *BinaryNode) -> bool {
	is_decl : bool = 
		(node.value.token_type == #char "=" && node.left.value.token_type == #char ":") || 
		 node.value.token_type == .COLON_EQUALS;
	return is_decl;
}
GetDeclarationVarNode :: inline (node : *BinaryNode) -> *BinaryNode {
	if node.left.value.token_type == #char ":" {
		return node.left.left;
	} else if node.value.token_type == .COLON_EQUALS {
		return node.left;
	}
	//This should not happen since we should be checking IsDeclarationAssignment before this.
	assert(false, "Invalid declaration var node : %\n", node);
	return null;
}

/*NOTE : We are doing this so we can reuse for inline statements and default statements.
This is because in general we want a post order traversal but for assignment statements
we want to parse right and then left nodes so we know where to place things in the case of eg
s.* = foo();
OR
also this way we know that we are parsing RHS and LHS and can check that LHS does not have some invalid expression
which can only be used on rhs and same for something on RHS. should make things easier overall and if not
then we can change it back later since I left some of the code in "=" and we can use the EvaluateAssignment function
in there anyways. 
*/
EvaluateDefaultStatement :: inline (node : *BinaryNode, cd : *CompilationData) {
	cd.expr_byte_offset_from_sbp = cd.byte_offset_from_sbp;

	if node.value.token_type == {
	case .TILDE_EQUALS; #through;
	case .PLUS_EQUALS; #through;
	case .MINUS_EQUALS; #through;
	case .TIMES_EQUALS; #through;
	case .DIV_EQUALS; #through;
	case .MOD_EQUALS; #through;
	case .COLON_EQUALS; #through;
	case #char "="; {
		DFSPost(node.right, cd, VisitStatementNode);
		DFSPost(node.left, cd, VisitStatementNode);
		//If we found an error on RHS or LHS then we want to return since we will have an invalid assignment.
		if cd.comp_errors.all_compiler_errors.count > 0 return;
		//TODO I think we can call this in binary op code to evaluate assignment after applying the binary operation
		//for operators like "+=", "-=", etc... Maybe we can for int and float but can also separate and have 
		//2 operand instructions separate from 3 operand although with int and float they are basically the same.
		EvaluateAssignment(node, cd);
	}
	case; {
		DFSPost(node, cd, VisitStatementNode);
	}
	}

	//Reset the tano stack at the end of every statement if we updated it by using the TANO_STACK_MSPACE
	//TODO Should we rename this to cd.reset_tano_stack? Maybe that is clearer
	if cd.reset_tano_stack {
		CreateMInstr(.tclear, Imm(TANO_STACK_MSPACE), RegMem(.tbp), d=cd);
		CreateMInstr(.mov, RegMem(.tsp), RegMem(.tbp), d=cd);
		cd.reset_tano_stack = false;
	}

	//Put this here so we reset the stack for all expressions like Foo("test", int.[0,1,2]);
	//or operator overloads or anything else which is not already cleared.
	//We store everything on the stack and always clear after every expression unless we already did
	//or don't need to like with variable assignments.
	if !cd.already_reset_stack ResetStack(cd);	

	reset(*cd.expr_pool, true);
}

EvaluateAssignment :: inline (node : *BinaryNode, cd : *CompilationData) {
	//TODO If we have a struct then we could make that CodeIRType and then we would
	//generate a mov for each variable in the struct. With strings, we can make a specific
	//function to mov a string, since it will likely be systematically stored on the heap.
	//TODO We could set the variable stack index here based on where we are and just do a push.
	//TODO Verify left and right types here and return a CompilerError otherwise.
	//TODO Checking left and right null can likely be done at ParserLevel I think
	assert(node.left != null && node.right != null);

	if node.right.code_ir.ir_type == {
	//TODO Finish testing new CreateMusicInstr on UNARY_OP and BINARY_OP.
	//Need to store registers on the stack and then put them back when we call a function.
	//If a BINARY_OP or UNARY_OP has a register has input then we can even just use 1 of those registers
	//and then we don't need to make it available. For multiple return values, we just set the node
	//to the first value and then use that. And if we find an '=' with > 1 value on the left then we 
	//check for multiple return values.
	//Check multi-variable return functions and do .COLON_EQUALS.
	//Then do CreateCompInstr for out of order function declarations with .jr in function stack call on '('
	//Then test a bit and then start on pointer, structs, enums and arrays.
	//Maybe do some examples from tonality first with code / jai to have some new test cases first.

	//TODO We may not need CODE_IR_VALUE_LIST and NODE_VALUE_LIST anymore since we can just store
	//array literals, struct literals and function arguments on the stack directly.
	//It's an interesting idea though that I can keep for reference but it does not seem be consistent
	//and also no longer seems to have any kind of practical purpose.
	case .CODE_IR_VALUE_LIST;
		//TODO This could be an error check. Multiple return values requires multiple data positions to put them in.
		assert(node.left.code_ir.ir_type == .CODE_IR_VALUE_LIST);
		array_left : [] CodeIRValue = ArrayFindAllVarName(cd.all_code_ir_values, node.left.node_id, "ir_data_id");
		array_right : [] CodeIRValue = ArrayFindAllVarName(cd.all_code_ir_values, node.right.node_id, "ir_data_id");
		assert(array_left.count == array_right.count);
		for left_ir, l_index : array_left {
			right_ir : CodeIRValue = array_right[l_index];
			CreateMInstr(.mov, left_ir.op, right_ir.op, d=cd);
		}
	case .NODE_VALUE_LIST;
		//TODO We can do the same thing for multi-values, like multi-value return functions
		//and also STRUCT_LITERAL if we do those.
		//We create a mov instruction for each base value found in the .ARRAY_LITERAL
		for cd.all_node_values if it.value_id == node.right.node_id {
			CreateMInstr(.mov, node.left.code_ir.op, it.node.code_ir.op, d=cd);
		}
	case; {
		//DOC : This means we have an new assignment so we need to set the left variable as an l_value
		if node.value.token_type == .COLON_EQUALS && node.left.code_ir.ir_type == .UNKNOWN_IDENT {
			node.left.code_ir.code_value_type = .L_VALUE;
		}

		if node.left.code_ir.code_value_type != .L_VALUE {
			CreateCompErr(cd, .EVALUATION, node.left, "Left assignment not l_value.");
			return;
		} else if node.right.code_ir.code_value_type != .R_VALUE && node.right.code_ir.code_value_type != .L_VALUE {
			CreateCompErr(cd, .EVALUATION, node.right, "Right assignment not l_value or r_value.");
			return;
		} else if IsDeclarationAssignment(node) {
			var_node : *BinaryNode = GetDeclarationVarNode(node);
			if var_node.code_ir.node_var_type == .NOT_DECLARABLE {
				CreateCompErr(cd, .EVALUATION, var_node, "Not a declarable variable.");
				return;
			} else if var_node.code_ir.ir_type != .UNKNOWN_IDENT {
				CreateCompErr(cd, .EVALUATION, var_node, 
				//TODO Maybe we can make this more explicit by fetching exactly what is already being used.
				sprint("Variable already in use : %.", var_node.code_ir.t_info.*));
				return;
			}
		}
		/*IMPORTANT TODO REMINDER
		I think we should update this to check both sides now that everything is updated
		so we just have if statements checking left and right types like a binary op
		and then the default case for everything else to just do the .mov.
		I think that is clearer overall and then we can have specific cases for each other type
		and then 1 specific case for multi-return functions if we end up doing that.
		*/

		//TODO Leaving this note here for now because of operator overloading, but can likely remove it later.
		/*TODO IMPORTANT : THIS NEEDS TO GENERALLY BE UPDATED TO CONSIDER THE R_VALUE AND L_VALUE concepts.
		so if RHS is R_VALUE and we have a ":=" then we want to convert the R_VALUE with the lhs to make an l_value.
		BUT If RHS is R_VALUE and only have an "=" then we only want to move the value over and then discard it.
		In both cases if we have RHS I think we want to reset the scp to expr_byte_offset_from_sbp.
		Basically only ":=" assign a new variable to the stack and "=" just does a mov in call cases.
		This simplifies things here for both array literals and function returns and operator overloads.
		So that should all work together now and we can double check soon when we implement operator overloads
		I think no matter what you reset.
		With operator overloading, if we have r_value, we can reset and put the result of the operator
		in the lowest r_value on the stack and overwrite it since now both will be scrapped. This way
		we keep accumulating in 1 position on the stack and then only use that here. 

		DO TEST FOR 1 INPUT, 2 INPUT and then multi-return (I think we need ":=" for this)
		and then update this with r_value l_value concept. maybe could do this first and then multi-return
		*/

	   //If we have an specific assign, then it is not default and we can set this on that assign.
	   //TODO I Think we should just set default case on the bottom and all special cases can be checked
	   //before it like array assignment and "~="
	   is_default_assign : bool = true;

	   /*TODO IF the RHS is undefined ".[" OR ".{" then we have to infer the type from the LHS here
	   */
		//TODO Should we bring this up to the top and reuse it in the "=" in general
		//It is now, let's see how that goes. Basically if the LHS declares the type we use that,
		//otherwise we use the RHS type. We can check if this is valid above.
		//TODO We removed this now in favor of checking left_t_info and right_t_info
		//where we use left_t_info for assignment.
		// assign_t_info : *TypeInfo;
		//NOTE TODO : These checks can be updated/removed accordingly once we actually implement the checks
		if node.left.value.token_type == #char ":" && node.left.right != null {
			if node.left.right.code_ir.t_info == null {
				CreateCompErr(cd, .EVALUATION, node, "Invalid LHS type for this assignment.");
				return;
			}
			//Use LHS type if we have defined eg - x : int = 5;
			// assign_t_info = node.left.right.code_ir.t_info;
		} else {
			if node.right.code_ir.t_info == null {
				CreateCompErr(cd, .EVALUATION, node, "No valid type found for this assignment.");
				return;
			}
			//Use RHS for eg - "x := 5;" OR "x = 5;"
			// assign_t_info = node.right.code_ir.t_info;
			//TODO for "x := 5;" then lr_types should both be RHS if it is valid
		}

		//TODO For undefined type ".[" OR ".{" we have to take both to be LHS type if it is valid.
		left_t_info : *TypeInfo;
		right_t_info : *TypeInfo;
		if node.value.token_type == .COLON_EQUALS {
			left_t_info = node.right.code_ir.t_info;
			right_t_info = node.right.code_ir.t_info;
		} else {
			left_t_info = node.left.code_ir.t_info;
			right_t_info = node.right.code_ir.t_info;
		}
		lr_types : [2] TypeInfoTag = .[left_t_info.type_enum, right_t_info.type_enum];
		//TODO We could just check the types here and then check the operator node and 
		//then call it from there with .tadd, .tsub, etc...
   	if node.value.token_type == .TILDE_EQUALS {
			//TODO FROM HERE get this working with new things and then write unit tests for code
			//and then integration tests to see everything is working.
			//Should likely do RELATIVE TANO so we just add from the lhs t0(r,x)
			//t0.row + r and t0.x + x for start and end ( or maybe just start )
			//I think just start and then depending on the relative tano we would know which point
			//we are starting from which feels really cool in some way.
			//Then the base tano would not need to add anything as it would be (0,0,0,0) default
			//TODO Can just set this to .r0 with being fixed and then we don't have to free it below
			left_tano_op : MusicOperand = GetValueOpReuseReg(node.left, cd);
			right_op : MusicOperand = GetValueOpReuseReg(node.right,cd);
			if ArraysFixedEqual(lr_types, .[.TANO, .TANO]) {
				//TODO Maybe we should be explicit with the ram type here instead of using default
				// CreateMInstr(.tmov, left_tano_op, right_op, ImmEnum(TMovRamType.TANO), d=cd);
				CreateMInstr(.tmov, left_tano_op, right_op, d=cd);
			}
			else if ArraysFixedEqual(lr_types, .[.TANO, .NEUME]) {
				CreateMInstr(.tmov, left_tano_op, right_op, ImmEnum(TMovRamType.NEUME), d=cd);
			}
			else if ArraysFixedEqual(lr_types, .[.TANO, .INTEGER])
			{
				//NOTE : We need to place the value in a register since the instruction "tmov ram, ram" == "tmov tano, tano"
				//so "tmov tano, int" == "tmov tano, reg"
				CreateMInstr(.mov, RegMem(.ax), right_op, Imm(cd.int_type_info.runtime_size), d=cd);
				CreateMInstr(.tmov, left_tano_op, RegMem(.ax), d=cd);
			} 
			else if ArraysFixedEqual(lr_types, .[.TANO, .FLOAT])
	   	{
				CreateFloatInstr(.mov, RegMem(.ax), right_op, Imm(cd.float_type_info.runtime_size), d=cd);
				CreateFloatInstr(.tmov, left_tano_op, RegMem(.ax), d=cd);
	   	}
			else if ArraysFixedEqual(lr_types, .[.TANO, .ARRAY]) {
				//NOTE : This cannot be t0 := array; because we would not know where to place the values
				//and this is checked above only can do t0 := t1 for both tanos with ":="
				//TODO Can allow music point arrays here once we implement that.
				array_info := cast(*TypeInfoArray) node.right.code_ir.t_info;
				assert(array_info.element_type != null); //sanity check
				if !AllOrEquals(array_info.element_type.type_enum, .[.INTEGER,.FLOAT,.NEUME]) {
					CreateCompErr(cd, .EVALUATION, node,
					"Invalid tano RHS array type assignment. Valid array types are int, float and neume.");
					return;					
				}

		   	ram_array_op := ArrayToRamArrayOp(node.right, cd, .ax, .bx);	
				//The default array type accounts for integer or float so we only need to set it to 
				//TMovArrayType.MUSIC_POINT if we have a [] MusicPoint.
				if array_info.element_type.type_enum == .INTEGER {
					CreateMInstr(.tmov, left_tano_op, ram_array_op, d=cd);
				} else if array_info.element_type.type_enum == .FLOAT {
					CreateFloatInstr(.tmov, left_tano_op, ram_array_op, d=cd);
				} else if array_info.element_type.type_enum == .NEUME {
					CreateMInstr(.tmov, left_tano_op, ram_array_op, ImmEnum(TMovArrayType.NEUME), d=cd);
				}
				//In case we used registers for memory
				// FreeReusableRegisters(ram_array_op, *cd.all_registers);
			} 
			else {
				CreateCompErr(cd, .EVALUATION, node, "Invalid tano RHS type assignment.");
				return;
			}

			ResetStack(cd);
			FreeReusableRegisters(left_tano_op, *cd.all_registers);

			return;
		}
	   /*Depending on if we have ":=" be 1 token or have it as (: \ =) imagine as a tree
	   then we would just have to check if the left is ":" and the right is null and do the same in ":"
	   */
	   //TODO Should probably have this case work for all r_values
	   //TODO This should be .TEMP_MEMORY And "," once we fix the above in tests.
	   //TODO FROM HERE TEMP_MEMORY and also likely put that TEMP_MEMORY and ASSIGNED_VALUE in CodeIRType
	   //SHOULD WE HAVE R_VALUE AND L_VALUE AS A TYPE OR JUST CHECK HERE?
	   //Probably better to set it on the way up the tree since all the cases are already there
	   //and then we know we set it properly after validation of those specific nodes.
		else if node.right.value.token_type == #char "(" && 
			node.right.left.code_ir.t_info != null &&
			node.right.left.code_ir.t_info.type_enum == .PROCEDURE &&
			node.left.value.token_type == #char ","
		{
			/*NOTE THIS IS UNUSED SINCE THIS IS ONLY THE CASE FOR MULTI RETURN VARS which works in terms
			of tree forming and parsing but NOT in terms of evaluation. So can use this case if we implement that.
			*/
			//TODO MAYBE WE PULL THIS OUT AND HAVE A COMPLETELY SEPARATE CASE FOR FUNCTIONS

			//We have to reset the scp here in case we had any r_values on the RHS, this clears them all
			//but we still can access any return values since they're still on the stack and then
			//put them into place here as needed whether it's a push or just a mov.
			//eg x := foo(f1(f2()), f3() + 9 * f6());
			//everything from f1,f2,f3,g6 and the expression which could be an operator overload
			//needs to be cleared from the stack since it will never be reused. Only the final value
			//whether on a stack or in a register will be used here.

			//TODO I am not sure we can just pull this out as it is different for different cases
			ResetStack(cd);

			//TODO COULD MAKE node.right have a specific type for multi-return values since that is the only
			//case which allows the "," anyways, unless we decide to change it but i did not like any of the other options.
			// if node.left.value.token_type == #char "," {
				//If we have only 1 return value then we do default below but with multiple we have this special case.
				is_default_assign = false;
				for cd.all_multi_return_memory_ops {
					//Sanity check for now. Can we remove the node member in MultiReturnMemoryOperand once things are tested? 
					assert(it.function_bracket_node == node.right);
					return_type : *TypeInfo = cd.multi_return_type_info_proc.return_types[it_index];
					if node.value.token_type == .COLON_EQUALS {
						//TODO I don't think we need this push since the return values were already put on the stack.
						//This is because we reset the stack first and then push BUT if we have ":=" then we already
						//have the values on the stack so no need. Only need to make sure scp is in the right place.
						CreateMInstr(.push, it.return_mem_op, Imm(return_type.runtime_size), d=cd);
						CreateStackVarData(cd, it.var_node.value.token_string, return_type);
					} else {
						CreateMInstr(.mov, it.var_node.code_ir.op, it.return_mem_op, Imm(return_type.runtime_size), d=cd);
					}
				}
				//We will only have 1 multi-return at a time however the number of returns can be any amount.
				//So we can reset each time here and reuse the memory later.
				array_reset_keeping_memory(*cd.all_multi_return_memory_ops);
				cd.multi_return_type_info_proc = null;
				//Because this is a very specific case for multiple return value for now, we just return and don't
				//try to do common processing like for the single value case where things are similar below.
				//Maybe in general we should separate the processing out a bit more instead of having just the mov
				//and var creation at the bottom since things will likely change between types over time.
				return;
			// } else {
				//TODO We can remove this case and just use this branch for multi return functions
				//If the value is already pushed on the stack then we don't want to do the move but
				//the types should still be correct
				//TODO FROM HERE this case can be moved in the default case below and then
				//also comment out pointer function args.
			// 	assert(node.left.code_ir.t_info == node.right.code_ir.t_info);
			// }
		} else if node.left.code_ir.t_info == *cd.music_unit_info {
			/*TODO We can either remove this case now OR we can eventually leave music rows with music memory
			and have that be another way to interact with 1 slice of the tano maybe to introduce the concept
			or to do quick simple computations.
			*/
			is_default_assign = false;
			/*I am making .mov music_memory a separate case in "=" for now but I am not sure I want that
			as the mov operator or at least we would have a clear as well. In any case it is quite different
			so we put it as a separate case altogether and then can move it out easily later if I decide
			to use a different binary operator for .mov music_memory without the clear.
			*/
			//TODO Technically we could allow some structs here which could be interesting
			//but for now just this since it's very simple.
			//POINTER TO MUSIC_UNIT could be a struct with MusicUnitInfo type or maybe a different type
			//that has x and row members and that can be used as a music_unit_info as well.
			//TODO CompilerError
			if node.right.code_ir.t_info.type_enum == .ARRAY {
				array_info := cast(*TypeInfoArray) node.right.code_ir.t_info;
				assert(array_info.element_type == *cd.int_type_info ||
						 array_info.element_type == *cd.float_type_info);

				/*NEGATIVE ROW MUSIC MEMORY values can be used as registers MusicMem(-1,0)
				and we can ignore the x value size since we won't be rendering it. So then we can have
				arbitrarily long music point collections and however many we want regardless of the row_size
				that the user places. These can also be used by the user however we could reserve a set of them
				and if you are writing code, then you write over them at your own risk.
				*/
				//TODO Likely can make a function since we will do the same for operators
				//TODO Should we be updating node.right.code_ir.op or just creating a new one and setting that?
				if array_info.array_type == .FIXED {
					op_0, op_1 := GetMemoryAddressAsOperands(node.right.code_ir.op);
					array_data_reg := OLDGetOrReuseRegister(node.right, cd);
					CreateMInstr(.add, RegMem(array_data_reg), op_0, op_1, d=cd);
					node.right.code_ir.op = RamArray(array_info.array_count, array_data_reg);
				} else {
					count_reg := OLDGetOrReuseRegister(node.right, cd);
					reg : *RegisterData = OLDGetNextAvailableRegister(cd);
					array_data_reg := cast(RegDef) reg.reg_index;

					array_op := node.right.code_ir.op;
					CreateMInstr(.mov, RegMem(count_reg), array_op, d=cd);
					AddOperandOffset(8, *array_op);
					CreateMInstr(.mov, RegMem(array_data_reg), array_op, d=cd);

					node.right.code_ir.op = RamArray(count_reg, array_data_reg);
				}
			} else {
				//TODO CompilerError
				assert(node.right.code_ir.t_info == *cd.music_unit_info ||
						 node.right.code_ir.t_info == *cd.int_type_info ||
						 node.right.code_ir.t_info == *cd.float_type_info);
			}

			//TODO This is without range, so with range would require a 3 op instruction.
			//TODO Need to make this a float instruction if the value is float or array type is float.
			CreateMInstr(.mov, node.left.code_ir.op, node.right.code_ir.op, d=cd);

			ResetStack(cd);

		}  
		else if left_t_info.type_enum == .POINTER {
			//TODO Have to clear the stack here too since we could add pointers to the stack for multi pointers once we implement that.
			//If this is the same as the default case other than type check, then we can do this in default case on bottom instead.
	   	valid_pointer_type := left_t_info == right_t_info || right_t_info == cd.void_pointer_type_info;
	   	ResetStack(cd);
	   	//Pointer can be either a pointer type or null type.
	   	//TODO CompilerError
	   	assert(valid_pointer_type, "Invalid pointer assignment left : %, right : %.\n", node.left.*, node.right.*);
	   } 
	   /*DOC : Special case for function pointers where we copy from the function name.
		If we have ":=" then we cannot have function overloads to infer the type so only can have 1 function with that name.
		If we have "x : (T) -> (R) = foo", then we just need to make sure the procedure types match.

	   If we do function pointer variable to variable, then it's just copying the asm instruction index from
	   memory so this would be a default assignment and so we don't need that case to be different.
	   */
		else if ArraysFixedEqual(lr_types, .[.PROCEDURE, .PROCEDURE]) &&
			node.right.code_ir.ir_type == .FUNCTION_NAME
		{			
			func_decl : FunctionDeclaration;
			if node.value.token_type == .COLON_EQUALS {
				/*DOC : We need to infer the type from the FUNCTION_NAME and if it is overloaded then we can't
				know which one to take so we error out. If there is only 1 function with that name
				then we set the left var to be of that type.
				*/
				//TODO Could make a function for checking if function name has overloads if we reuse it
				overload_count : int = 0;
				function_is_overloaded : bool = false;
	   		for fd : cd.all_function_declarations if fd.name == node.right.value.token_string {
	   			func_decl = fd;
	   			overload_count += 1;
	   			if overload_count > 1 {
	   				function_is_overloaded = true;
	   				break;
	   			}
	   		}

	   		if function_is_overloaded {
					CreateCompErr(cd, .EVALUATION, node, 
					sprint("Cannot infer type from overloaded function : %.\n", 
					node.right.value.token_string));
					return;	
	   		}
			} 
			else {
	   		found_func : bool = false;
	   		for fd : cd.all_function_declarations {
	   			if fd.name == node.right.value.token_string &&
	   				cast(*TypeInfo) fd.t_info_proc == left_t_info 
   				{
						found_func = true;
						func_decl = fd;
						break;
					}
	   		}

	   		if !found_func {
	   			t_info_proc := cast(*TypeInfoProcedure) left_t_info;
					CreateCompErr(cd, .EVALUATION, node, 
					sprint("No function found with name : % and type info args : % and return values : %.\n", 
					node.right.value.token_string, t_info_proc.argument_types, t_info_proc.return_types));
					return;
	   		}
	   	}

	   	//TODO Technically we only have to reset the stack if we have a declaration here, so we can do that if it makes a difference.
	   	//If we don't have a declaration, then we are just moving the function start index to the function pointer variable in memory.
	   	//I guess it is better to be resilient here but it would get done externally anyways...
   		ResetStack(cd);

   		left_op : MusicOperand;
			if IsDeclarationAssignment(node) {
				var_node : *BinaryNode = GetDeclarationVarNode(node);
				var_data : *VariableData = CreateStackVarData(cd, var_node.value.token_string, cast(*TypeInfo) func_decl.t_info_proc);
				left_op = var_data.op;
			} else {
				left_op = GetValueOp(node.left, cd, .r0);
			}

   		//Function name to function pointer so this is fixed since the function name is always the same asm start index
   		//NOTE : If we have not evaluated the function yet, then we set it later like we do with function calls.
			if !func_decl.function_code_evaluated {
				array_add(*cd.all_out_of_order_instrs, .{func_decl.id, cd.all_music_instructions.count, 1});
			}
			CreateMInstr(.mov, left_op, Imm(func_decl.start_instr_index), Imm(left_t_info.runtime_size), d=cd);

			return;
   	}
	   else if left_t_info.type_enum == .ARRAY {
	   	if ArraysFixedEqual(lr_types, .[.ARRAY, .ARRAY]) {

	   		ResetStack(cd);

	   		//TODO FROM HERE Music mem and array literals and then refactor this
				//with assignment default in one place and loops like multi_return and multi_row and be
				//specific cases externally. So we just set right_op and left_op and size to move
				//and then move afterwards. This way we reset the stack and do moves with optimizations
				//in a consistent way unless we have alternative cases with loops
				//ALSO cleanup array setting code and also pointer and dereference with new code
				//postfix should just set ADDRESS_IN_MEMORY
				right_op : MusicOperand = GetValueOpReuseReg(node.right, cd);
				right_array_info := cast(*TypeInfoArray) right_t_info;
				left_array_info := cast(*TypeInfoArray) left_t_info;
				array_types : [2] ArrayInfoType = .[left_array_info.array_type, right_array_info.array_type];

				left_op : MusicOperand;
		   	if IsDeclarationAssignment(node) {
					var_node : *BinaryNode = GetDeclarationVarNode(node);
					//NOTE : the name can be different vars, but the type is always node.right since we know what the type is.
					//TODO Actually if we had no-type array literal ".[]", then we would need to check node.left but if we have
					//":=" we would need to check node.right
					var_data : *VariableData = CreateStackVarData(cd, var_node.value.token_string, left_t_info);
					left_op = var_data.op;
		   	} else {
					left_op = GetValueOpReuseReg(node.left, cd);
		   	}

				if ArraysFixedEqual(array_types, .[.VIEW, .FIXED]) {
			   	//TODO Could make a function if AfterStack
					//IF we just stored the fixed array on the stack, then we want to keep it
					//This is indeed an edge case that only happens when we convert fixed array to array view
					//if we just created the fixed array on RHS like in Test_CompArrayLiteral and so we want to 
					//keep and we copy it over
					//eg - a : [] int = int.[0,3,7];
					if node.right.code_ir.op.values[0].type == .REGISTER && 
						node.right.code_ir.op.values[0].int_value == cast(int) RegDef.sbp &&
						node.right.code_ir.op.values[1].type == .INTEGER && 
						node.right.code_ir.op.values[1].int_value >= cd.expr_byte_offset_from_sbp
					{
						right_op = PushStackMov(node.right, cd);
			   	}
					//Set array view count from fixed array
					CreateMInstr(.mov, left_op, Imm(right_array_info.array_count), Imm(cd.int_type_info.runtime_size), d=cd);
					//Set array view data from fixed array
					//NOTE : right and left op deal with address in memory case from above
					data_op := AddOperandOffset(8, left_op);
					op0, op1 := GetMemoryAddressAsOperands(right_op);
					CreateMInstr(.add, data_op, op0, op1, d=cd);
				} 
				else if left_array_info == right_array_info {
					//TODO This should be default on the bottom so pull.
					//So we want to rearrange everything so that the defaults are set properly.
					/*This deals with 
						- view = view - we copy the (count,data) over 
						- fixed = fixed - we copy the entire fixed array over
							- if we already set the array literal then no need to copy it over
							eg - a : [3] int = int.[0,1,2];
							we already placed the array literal on the stack.
							it's one case but avoids unecessary copies in general
					*/
					copying_to_same_place : bool = EqualsMOperand(left_op, right_op);
					if !copying_to_same_place {
						CreateMInstr(.mov, left_op, right_op, Imm(left_t_info.runtime_size), d=cd);
					}
				} 
				else {
					CreateCompErr(cd, .EVALUATION, node, 
					sprint("Invalid array assignment for types LHS : % and RHS : %.\n", array_types[0], array_types[1]));
					return;
				}
				//TODO Maybe better to explicitly use certain registers for GetValueOp
				//In case we used registers for memory
				FreeReusableRegisters(left_op, *cd.all_registers);
				FreeReusableRegisters(right_op, *cd.all_registers);
				cd.already_reset_stack = true;
			} 
			else if ArraysFixedEqual(lr_types, .[.ARRAY, .TANO]) {
				array_info := cast(*TypeInfoArray) node.left.code_ir.t_info;
				if node.value.token_type == .COLON_EQUALS {
					CreateCompErr(cd, .EVALUATION, node, 
					"Need to specify array type [] int, [] float or [] neume.");
					return;					
				} 
				else if !AllOrEquals(array_info.element_type.type_enum, .[.INTEGER,.FLOAT,.NEUME]) {
					CreateCompErr(cd, .EVALUATION, node, 
					"tano can only be moved to [] int, [] float or [] MusicPoint.");
					return;
				}

				tano_op := GetValueOpReuseReg(node.right, cd);
				//TODO I think we want to push array and then settings and then reset to right before settings
				//if we have a variable assignment/declaration.
				// t2a_settings : TanoToArraySettings;
				//TODO Just push everything and the mov the values that need to be updated so then we don't have to
				//update this later if we add/change the t2a_settings
				t2a_settings_array_op := PushStack(size_of(TanoToArraySettings), cd);
				//NOTE : The first 2 values are set by the instruction so we don't need to do anything to them here
				//since it does not matter what they are or if they are set to 0 but we NEED to set that array type
				//in case the value on the stack is not 0.
				t2a_array_type_op := AddOperandOffset(24, t2a_settings_array_op);
				// SetAddressNode(node.left, t2a_settings_op, cd);
				if array_info.element_type.type_enum == .INTEGER {
					CreateMInstr(.mov, t2a_array_type_op, ImmEnum(TMovArrayType.DEFAULT), Imm(cd.int_type_info.runtime_size), d=cd);
					//NOTE : We use the RamArray type to say it is an array but the array return address is stored
					//in the t2a_settings so as not to create confusion about the RamArray parameters.
					CreateMInstr(.tmov, RamArray(0,0), tano_op, t2a_settings_array_op, d=cd);
				} else if array_info.element_type.type_enum == .FLOAT {
					CreateMInstr(.mov, t2a_array_type_op, ImmEnum(TMovArrayType.DEFAULT), Imm(cd.int_type_info.runtime_size), d=cd);
					// PushStackMov(ImmEnum(TMovArrayType.DEFAULT), cd.int_type_info.runtime_size, cd);
					CreateFloatInstr(.tmov, RamArray(0,0), tano_op, t2a_settings_array_op, d=cd);
				} else if array_info.element_type.type_enum == .NEUME {
					CreateMInstr(.mov, t2a_array_type_op, ImmEnum(TMovArrayType.NEUME), Imm(cd.int_type_info.runtime_size), d=cd);
					// PushStackMov(ImmEnum(TMovArrayType.NEUME), cd.int_type_info.runtime_size, cd);
					CreateMInstr(.tmov, RamArray(0,0), tano_op, t2a_settings_array_op, d=cd);
				}

				//We reset after assignment in this case so we can push on t2a_settings before
				ResetStack(cd);
				left_op : MusicOperand;
		   	if IsDeclarationAssignment(node) {
					var_node : *BinaryNode = GetDeclarationVarNode(node);
					//NOTE : the name can be different vars, but the type is always node.left since we know it's an array type.
					var_data : *VariableData = CreateStackVarData(cd, var_node.value.token_string, left_t_info);
					left_op = var_data.op;
		   	} else {
					left_op = GetValueOpReuseReg(node.left, cd);
		   	}
				CreateMInstr(.mov, left_op, t2a_settings_array_op, Imm(cd.array_view_struct_info.runtime_size), d=cd);
			} 
			else {
				CreateCompErr(cd, .EVALUATION, node, "Invalid RHS array type required.");
			}

			return;
	   } 
	   else if AllOrEquals(node.value.token_type,
			.[.MINUS_EQUALS, .TIMES_EQUALS, .DIV_EQUALS, .MOD_EQUALS, .PLUS_EQUALS])
		{
			if left_t_info.type_enum == .TANO {
				if !AllOrEquals(right_t_info.type_enum, .[.INTEGER, .FLOAT]) {
					CreateCompErr(cd, .EVALUATION, node,
					"Invalid tano RHS type assignment. Requires int or float on RHS.");
					return;					
				}

			   t_op_code : OpCode;
				if node.value.token_type == {
			   case .PLUS_EQUALS; t_op_code = OpCode.tadd;
			   case .MINUS_EQUALS; t_op_code = OpCode.tsub;
			   case .TIMES_EQUALS; t_op_code = OpCode.tmul;
			   case .DIV_EQUALS; t_op_code = OpCode.tdiv;
			   case .MOD_EQUALS; t_op_code = OpCode.tmod;
				}

			   left_op : MusicOperand = GetValueOp(node.left, cd, .ax);
			   right_op : MusicOperand = GetValueOp(node.right, cd, .bx);
			   CreateMInstr(.mov, RegMem(.ax), right_op, d=cd);
				if right_t_info.type_enum == .INTEGER {
				   CreateMInstr(t_op_code, left_op, RegMem(.ax), d=cd);
				} else if right_t_info.type_enum == .FLOAT {
				   CreateFloatInstr(t_op_code, left_op, RegMem(.ax), d=cd);
				}

				//This is an assignment node so we don't have to set any of theses.
			   // node.code_ir.t_info = *cd.tano_struct_info;
			   // node.code_ir.op = node.left.code_ir.op;
			}
			else if ArraysFixedEqual(lr_types, .[.INTEGER, .INTEGER]) || 
				ArraysFixedEqual(lr_types, .[.FLOAT, .FLOAT])
			{
				op_code : OpCode;
				if node.value.token_type == {
				case .PLUS_EQUALS; op_code = OpCode.add;
				case .MINUS_EQUALS; op_code = OpCode.sub;
				case .DIV_EQUALS; op_code = OpCode.div;
				case .TIMES_EQUALS; op_code = OpCode.mul;
				case .MOD_EQUALS; op_code = OpCode.mod;
				}

				//This way never makes the op unavailable since we won't be using it again after	
				right_op : MusicOperand = GetValueOp(node.right, cd, .ax);
				left_op : MusicOperand = GetValueOp(node.left, cd, .bx);
				if right_t_info.type_enum == .INTEGER {
					CreateMInstr(op_code, left_op, right_op, d=cd);
				} else if right_t_info.type_enum == .FLOAT {
					CreateFloatInstr(op_code, left_op, right_op, d=cd);
				}
				ResetStack(cd);
			} 
			else {
				if !AllOrEquals(right_t_info.type_enum, .[.INTEGER, .FLOAT]) {
					CreateCompErr(cd, .EVALUATION, node,
					tprint("Invalid types %.", lr_types));
					return;					
				}
			}

			return;
		}
	   else {
			//TODO CompilerError : Ever other case must be the same type
			//CHANGE THIS TO COMPILER ERROR WHEN WE REDO THIS AS WELL
			/*TODO FROM HERE IF left is unknown identifier, then we need to use right side type
			UNLESS right side is tano and then we have to specify if we want an array or a tano on
			the LHS for declaration assignments.
			*/
			// assert(node.left.code_ir.t_info == node.right.code_ir.t_info);
			// if node.left.value.token_type == #char ":" && 
			// if node.value.token_type != .COLON_EQUALS && 
			// 	node.left.code_ir.t_info != node.right.code_ir.t_info 
			if left_t_info != right_t_info {
				CreateCompErr(cd, .EVALUATION, node, 
				sprint("Types don't match on both sides. Left type : %, right type : %.", 
					TypeToString(node.left.code_ir.t_info), TypeToString(node.right.code_ir.t_info)));
				return;
			}
			//TODO I think we want to always reset the stack so maybe we can pull this out
			//Let's see as we redo assignment for everything
			ResetStack(cd);
			//TODO I think this does not work for example if we add something but it's not the actual value.
			//I will leave it out for now and maybe we can add it as an optimization later but maybe not.
			// only_1_value_in_expression : bool = 
			// 	cd.byte_offset_from_sbp == cd.expr_byte_offset_from_sbp + node.right.code_ir.t_info.runtime_size;
		}

		var_data : *VariableData;
		if IsDeclarationAssignment(node) {
			var_node : *BinaryNode = GetDeclarationVarNode(node);
			var_data = CreateStackVarData(cd, var_node.value.token_string, left_t_info);
		}
		// var_data : *VariableData;
		// if node.left.value.token_type == #char ":" {
		// 	var_data = CreateStackVarData(cd, node.left.left.value.token_string, assign_t_info);
		// } else if node.value.token_type == .COLON_EQUALS {
		// 	var_data = CreateStackVarData(cd, node.left.value.token_string, assign_t_info);
		// }
		/*TODO Should I remove this default behavior and just put it in each case above instead?
		YES I think that would be best once we come and change this and do assign with stack for everything.
		We can leave the CreateStackVarData outside though since we always create that
		but also remove the FreeOperandRegisters eventually since we should be always creating on the stack
		but will need to update some code and tests before we do that everywhere.
		*/
		if is_default_assign {
			//TODO If node.right is struct literal or function return value then we would just assign the new variable
			//to that instead of creating a new one. Doing it here allows us to do each specific case instead of just
			//doing it at ":". WE CAN LABEL THESE AS UNASSIGNED VARIABLES for example in ir_type to know
			//compared to other variables on stack or heap where we would have to copy them over.

			//NOTE : We get the right node first for consistency since we evaluate RHS before LHS.
			//This is because if we need to get ADDRESS_IN_MEMORY then we grab the right node first.
			right_op : MusicOperand = GetValueOpReuseReg(node.right, cd);
			left_op : MusicOperand;
			if IsDeclarationAssignment(node) {
				left_op = var_data.op;
			} else {
				left_op = GetValueOpReuseReg(node.left, cd);
			}
			copying_to_same_place : bool = EqualsMOperand(left_op, right_op);
			if !copying_to_same_place {
				CreateMInstr(.mov, left_op, right_op, Imm(left_t_info.runtime_size), d=cd);
			}
			//In case we used registers for memory
			FreeReusableRegisters(left_op, *cd.all_registers);
			FreeReusableRegisters(right_op, *cd.all_registers);
		}

		//TODO We don't need to reset the stack if we have an assignment in any case.
		//We could make this more explicit and add a create_variable check OR also just
		//rename this to do_not_reset_stack
		cd.already_reset_stack = true;

		//TODO WE CAN REMOVE THIS IF WE ONLY USE THE STACK FOR OPERATIONS AT SOME POINT FOR SIMPLIFICATION.
		/*We free registers for the right side since we will not use that anymore.
		The left side also needs to be freed because if we have something like a[0] = x
		then a[0] will use registers, but then if we access it later, it will be different.
		The thing on the left needs to have storage somewhere in memory so after assignment it should
		be stored there and then accessed from memory later. 
		We only use registers to gather operations at the moment.
		*/
		FreeOperandRegisters(node.right.code_ir.op, *cd.all_registers);
		FreeOperandRegisters(node.left.code_ir.op, *cd.all_registers);
	}
	}
}

/*TODO Basically linearized the input down the right chain. If this pattern remains throughout
	then we can simplify and optimize by lexing and parsing each statement ending with ";" and "{"
	1 by 1 and this would significantly save on space and also be easier to think about and also
	would simplify the parser because we would not need to maintain the right leaning structure with
	";","{","}" on the right since these would be in the linearized processed expressions anyones which
	would tell use the same thing we are doing now except linearized instead of a tree. ALSO faster because
	we are going through linearly instead of traversing down a right leaning tree. 
	DRAW HERE right leaning tree general example that we have in krita.


REASONS FOR SINGLE LINE PARSING as described above.
	- Double semicolons are like x = x + 2;; can be dealt with automatically and discarded without processing.
	- Invalid expressions like x = x + y can be found easily because + will not have child at all.
	  Whereas in the current method, the ';' needs to be checked as an invalid leaf.
	- x = x + 
	  y = 2;
	  This case can actually be solved with a flag with STATEMENT_LEVEL and EXPRESSION_LEVEL so if we find
	  an '=' at expression level, then that would be a parsing error.
	- if y == 2 for 0..10 while y < 3 { This is a good case for single line parsing because then we can parse
	  each conditional statement (if x) then (for 0..10) then (while y < 3) normally and sequentially whereas
	  with the current method we rely on '{' and ';' which we do not have in this case.
    - IF we linearize then the inline statements can be parse up until the next statement. So even an inline
    if would then be parsed as 2 statements, whereas now it cannot be parsed without the 'then' keyword.
    So then we would able to have something like 'if y == 2 x = 1;' which would parse 'if y == 2' and stop
    and then parse 'x = 1;' and stop and then we would have 2 statements as binary trees which we could
    then parse in the way we are parsing now.
	- We would lex until a certain point (eg ';' or '{') and then parse those tokens only and then compile
	or turn into IMM_MEM representation. Less memory used in any case with linearized. Less memory means
	more in the cache and therefore faster. 
	- IT also makes it easier for error checking since we explicitly check each statement or condition. 
	- Gives us ending on ';' for free and skipping extra ';' for free.
	- We would get the loop below but it would not be a tree. Therefore linearization is also easier to reason about
	and we don't have to ensure that the tree structure remains for all cases. We can make the structure different
	for different statements if needed or split everything up into being small binary trees.
	- asm parsing is another strong point. Then we could parse the asm with the same lexer tokens line by line
*/


//TODO In case we need to pass in some settings for compilation
CompileSettings :: struct {
	print_errors_to_console : bool = false;
	main_file_absolute_path : string;
}

/*TODO Ideas
- LEXER LAZY LOADING WHILE PARSING EXPRESSION (so move LexCodeTokens to ParseExpression GetNexToken functions)

- non-recursive parse expression
- Eventually we could have multiple memories for separate pieces of music which can all play at the same time if needed.
  This fixes the offset playing problem and also allows pieces to access data between them however they want by 
  allowing maybe a syntax like rows_0[0] or rows[0][0][0] or allow them to name memory for each piece.
  Could do this with a special directive '#music_memory = "rows"' or also like before 'music_memory $= "rows'
- Should we rename this to Compiler?
- Now we could lex, parse and generate 1 statement at a time. 1 statement is more efficient and can reuse memory.
- Should we return CompilationData or just the instruction data eventually? Right now we pass it in for ease and reuse.
- for cycles for #import https://stackoverflow.com/questions/546655/finding-all-cycles-in-a-directed-graph/549402#549402
   also can look at tarjan's algorithm

//TODO Likely need a version where we pass in the file_name somewhere so we can print as error.
//Also might want to do other things so maybe best to have a version that takes a file and then
//passes that in to CompileSettings or something like that.
//Maybe this version with string can be a secondary compiler function for convenience.
DEFINETELY NEED a version where we pass in a file because of #load and #import
Can still have a version where we pass in just code but we need all_text_files no matter what
and possibly a way to load in text_files from the system. Maybe from a specific folder if we have
not found them for now.
REMINDER : we need to make sure that context.allocator passed in is used for all allocation that is needed after compilation
and we need to add an internal allocator that gets cleared at the end of compilation and also maybe one that gets cleared
after each pass OR also for each expression/statement parsing and evaluation.
*/
CompileCode :: inline (cs : CompileSettings, code : string) -> *CompilationData {
	//TODO I think we only need to return some of the data in here eventually.
	cd : *CompilationData = MakeCompilationData();

	//Create the global_scope. We don't use CreateScope because there is no actual data associated to it.
	//TODO We could pull this out if needed and we want to use it everywhere and since it will be constant.
	global_scope := ScopeData.{id=0,scope_index=0,scope_type=.GLOBAL_SCOPE};
	array_add(*cd.all_scope_data, global_scope);
	array_add(*cd.open_scope_stack, global_scope.id);
	cd.next_scope_id = 1;


	//TODO We can lazy lex tokens as we need them while expression parsing instead of doing it all in 1 shot here
	//DEFINITELY LAZY LEX TOKENS then we can use a ring buffer of smaller size for lexing which is much more efficient.
	//Then we can just call the lexer whenever we need to get more tokens while parsing
	#if 0 {
	LexCodeTokens(*cd.lexer, code);
	//We return here so we can return all errors in the same array.
	//TODO Eventually if we do lazy lexing, then we can remove this and only use all_compiler_errors instead
	found_lex_errors := VerifyLexerErrors(cd, cs);
	if found_lex_errors return cd;
	}
	//TODO Load the starting file. Should we set a name or boolean here for clarity?
	//I guess we also know that the first file will always be the starting file like this.
	starting_file : *DirectiveLoadFile = array_add(*cd.all_directive_load_files);
	starting_file.file_string = code;
	/*DOC : We are setting this here from CompileSettings for now for convenience. This allows non-system files without
	an absolute path to be set here with no name and therefore not retrieved. This is used in tests and also can be used
	for files that are not saved on the system.
	REMINDER the main test file from CreateTestTextFile is not a system file so if we want to check the main file
	we can create another CompileCode function that takes in a file name and then grab that
	HOWEVER, evenetually we likely want all created text files to be system files. We can store them as temporary files somewhere
	and call them temp_text_01, temp_text_02... and then remove them when they are saved. This way people can create files without saving
	and if the text op space is closed, then we would delete the file. If they quit and forget to save, it will still be there.
	This allows the creation of quick code to add some music or other patterns without having to save the file for things like
	a quick music or math script that does not necessarily need to be persisted.
	TODO Therefore for tests, eventually we can 
		- NOW : store all tests in no file with no name
		- MAYBE LATER 
			- tests are stored in empty file without being saved and that file is reused for all tests
			- OR we create a temp file for all tests and then delete it at the end of each test
	*/
	starting_file.absolute_path_name = cs.main_file_absolute_path;
	#if 0 {
	starting_file.file_name = starting_file.absolute_path_name;
	found_slash, left, right := String.split_from_right(starting_file.absolute_path_name, "\\");
	if found_slash {
		starting_file.file_name = right;
	}
	}
	// starting_file.absolute_path_name = copy_string(absolute_path_name);
	// starting_file.lex_tokens = array_copy(cd.lexer.lexer_tokens);
	/*DOC : The load pass will do load and import directives (For now we only have load).
	We assume that all load and import directives are at the top of the file, otherwise we have to do
	an entire extra pass just for loading since we would need to check for import cyclical dependencies anyways.
	I think it's best to leave it this way, reminds me of when I started coding in java on simple notepad.

	REMINDER that the loads can be out of order just need to be on top BUT maybe we leave them anywhere
	and just have an extra pass fuck it. Maybe then later we can profile and see if it makes a huge difference.
	Maybe it will with lazy loading...
	JUST NEED OT COMMENT OUT else statement below to not have the restriction of it being on top anyways.

	For LAZY LEXING, I think we just have to change PeekNextToken and EatNextToken to read from the file strings
	directly and then stop at the end of each file and go to the next file afterwards. We would do this for each
	pass and then possibly optimize later if needed, although lexing and searching for a "::" or "#" token might be enough.
	*/
	//TODO Maybe we should store load_index in the lexer
	cd.load_index = 0;
	while load_pass := cd.load_index < cd.all_directive_load_files.count {
		defer cd.load_index += 1;//put here in case we call continue
		loaded_file : *DirectiveLoadFile = *cd.all_directive_load_files[cd.load_index];
		//TODO lex the loaded file here and then loop over it in each pass as well.
		//Eventually lazy lexing will make this more memory efficient.
		ResetCodeLexer(*cd.lexer);
		//TODO Passing this in for convenience so we can know which file for errors. 
		//Eventually once we do lazy lexing, then we will pass in all files to lexer so it can use that
		//to check end of file and move to the next file while lazy lexing.
		cd.lexer.current_abs_file_path = loaded_file.absolute_path_name;
		LexCodeTokens(*cd.lexer, loaded_file.file_string);
		found_lex_errors := VerifyLexerErrors(cd, cs);
		//NOTE : VerifyLexerErrors already checks compile_errors properly so we return here directly.
		if found_lex_errors return cd;
		loaded_file.lex_tokens = array_copy(cd.lexer.lexer_tokens);
		// array_copy(*cd.lexer.lexer_tokens, loaded_file.lex_tokens);
		//TODO When we do lazy lexing, then we can just put peek and eat here instead so we just use the same 
		//processing and just need to change the files once we hit the end, which can maybe be done in the
		//eat next token anyways and then we only need the single loop here again
		while cd.lexer.next_index < cd.lexer.lexer_tokens.count {
			defer cd.lexer.next_index += 1;
			//TODO Can use this if we have to parse everything sequentially like when we checked brackets here.
			// current_index : int = cd.lexer.next_index;
			current_token : LCodeToken = cd.lexer.lexer_tokens[cd.lexer.next_index];
			if current_token.token_type == #char "#" && 
				//TODO Can add import here later when we implement it
				AllOrEquals(code_directive_enums[current_token.int_value], .[.load])
			{
				/*DOC : For now for simplicity, we are lexing each file completely and then looping over each file and
				parsing each file on each pass that we load in.
				TODO EVENTUALLY with lazy lexing, we can just lex the tokens directly from the file string for each pass
				and just have 1 lexer with 1 cyclical array and then we just have to keep store the file_strings in memory.
				*/
				//TODO Make a version of CompileCode which takes in a file_id or file_name and loads that first.
				//So we might have to make this into a function... If the file is already loaded by text then we just
				//use that but otherwise we have to load it from the system. Can maybe just do text file for now and do system later.
				node : *BinaryNode = ParseExpression(cd,S64_MIN);
				//TODO Can verify the tree structure is could and that the next token is ";" and pass over it here for clarity.
				is_valid_load_node : bool = node.value.token_type == #char "#" &&
					node.right != null && node.right.value.token_type == .STRING &&
					node.left == null;
				if !is_valid_load_node {
					CreateCompErr(cd, .EVALUATION, node,
					"Invalid load directive.");
					break load_pass;
				}

				//TODO We could make this a function to load files with TextFile as well
				//and then reuse to load the main file or grab from text file if we already have it.
				//Have separate compile code functions that go from file_name or text_file as main and then
				//call here with the first string.

				//if no directory then we can default to code_load directory or something like that.
				//Can do things relative to the main file was well.
				//can use get_absolute_path i think to get current working diretory if needed
				/*DOC : "code_load/Basic" will fetch relative path and then an absolute path will also work.
				So overall this seems fine for load and we can set a default path for import later.

				DOC : We load the file from the system so that everything is considered to be stored in the system.
				If we load from our text files then there is more of a chance for inconsistencies which we want to try to avoid.
				So we always load from the system and with the text editor we reload every frame (or at some other rate later)
				to ensure that everything is as consistent as possible.
				We now have a separate pre-pass for load/import to avoid cyclical dependencies. 
				We only check on top of the file for efficiency like C.
				To remove this, we just need to remove the else below which is documented below and then we would have
				a full pass to check all files. Then we could just skip them later.
				Right now, we skip loads later if it's not at the top anyways
				Could have a default import folder and could do importdir like jai or just allow multiple import folders.
				*/
				file_name : string = node.right.value.token_string;
				#if 0 {
				//TODO Can use something like this for default directory and also for import later
				file_path : Path = parse_path(node.right.value.token_string, false);
				if file_path.words.count == 1 {
					//TODO assume default directory code_load. could allow changing default directory somewhere later.
					//so we can add the relative or absolute diretory name here
					// file_name = node.right.value.token_string;
				} else {
					//TODO assume absolue/relative path and I think that will just work but let's test it
					file_name = node.right.value.token_string;
				}
				}

				//TODO Write a test to make sure this error is working
				absolute_path_name, found_path := get_absolute_path(file_name);
				if !found_path {
					CreateCompErr(cd, .EVALUATION, node,
					sprint("Path not found for : %.\n", file_name));
					break load_pass;					
				}
				for cd.all_directive_load_files if it.absolute_path_name == absolute_path_name {
					CreateCompErr(cd, .EVALUATION, node,
					sprint("Already loaded file : %.\n", absolute_path_name));
					break load_pass;					
				}

				//TODO Should we use absolute path here or the one that was passed in?
				modtime, resource_file_size, read_time_success := file_modtime_and_size(absolute_path_name);
				//TODO Can add back max file-size here if needed.
				// if !(read_time_success && resource_file_size < max_allowable_file_size) {
				if !read_time_success {
					CreateCompErr(cd, .EVALUATION, node,
					sprint("Could not read modtime or file size : %.\n", absolute_path_name));
					break load_pass;
				}

				resource_file, resource_is_open := file_open(absolute_path_name);
				if !resource_is_open {
					CreateCompErr(cd, .EVALUATION, node,
					sprint("Resource file : % could not be opened.\n", absolute_path_name));
					break load_pass;
				}

				//TODO We should probably use a separate allocator to store these files and then maybe clear
				//it at the end of compilation. Could even technically use the temp allocator and then have it
				//clear on the next frame or use an allocator in the compiler that gets reused after each compilation
				//or something like that. Right now this gets held on afterwards which is unnecessary.
				file_string := alloc_string(resource_file_size);
				read_file_success := file_read(resource_file, file_string.data, resource_file_size);
				// Make sure we close the resource file after using it since we now have the file_string
				file_close(*resource_file);
				if !read_file_success {
					CreateCompErr(cd, .EVALUATION, node,
					sprint("Resource file : % could not be read.\n", absolute_path_name));
					break load_pass;
				}

				//Later we can make this more efficient with lazy lexing.
				load_file : *DirectiveLoadFile = array_add(*cd.all_directive_load_files);
				// load_file.file_name = copy_string(file_name);
				load_file.absolute_path_name = copy_string(absolute_path_name);
				//TODO Storing the file string here so we can use this once we do lazy lexing.
				load_file.file_string = file_string;

				if IsSemicolonError(cd) break load_pass;
			}
			else {
				/*DOC : since we only allow load and import at beggining, once we don't have them, continue to next file.
				TODO If we remove this line, then we would do a full load pass here and then they could be placed everywhere.
				Currently we just skip over load and import if not at the beginning so there is no error.
				TODO I guess we would have to store where this ended and then check later if we have a load or import
				after that token to output an error. That way would also work for lazy loading.
				*/
				continue load_pass;
			}
		}
	}


	/*TODO OTHER THINGS TO PARSE ON FIRST PASS
		- Can check {} and also other brackets if needed to make sure everything closes properly. Although
		I think other brackets will be processed at the parser level later. This will also prevent issues with
		doing ControlFjmps for if and else statements. (Once we have lazy lexing, then doing bracket close check on first pass is best)
		- We could parse all global statements on the first pass (but not allow conditional structures in global scope)
		and then this would be all setup for when we parse functions after. Since we parse the function declarations
		on the first pass, we can keep track of where they are on the second pass and just jump to those and
		start parsing them directly and so we could also keep the function declaration trees for that as well
		- Out of order processing can be done with global variables and structs and enums where if we find something we
		dont have, then we store the operand that is missing with the var name and each instruction that uses it.
		Then when we find it compared to the name, we update all the missing operands in each instruction. Can do the
		same for struct and enum types if we have structs out of order or function variable types out of order. We can
		reference these directly with function variable for example if needed
		- I think just do out of order by continuing to loop without storing anything. We only parse things in global scope
		so I think that makes more sense and less prone to bugs. Worst case is everything is stored backwards
		so just write examples where everything is in order to encourage mostly in order to reduce first passes.
		- PROBABLY SECOND PASS - Can check #if{} as well so we can skip over it in second pass and also #if{} else #if {} else.
		OR PROBABLY do #if on second pass so we can make sure we have the #if cond and then just have a loop that
		skips over everything in the second pass then.
	*/
	//TODO Process constants and structs and enums on first pass. I am not sure how far I want to go with that
	//but for now I think that makes the most sense.
	//First pass : Currently being used for out of order function declarations
	/*TODO I am not sure this is the best way to do brackets. I would need to add struct literals
	and anything else that pops up. Maybe it is best to leave this in the OR do this in the lexer.
	I guess we can see once we do lazy lexing and keep track of it in there while lexing.
	ACTUALLY YES do this in the lexer since then we can just check specific brackets and then
	when we do lazy lexing, we can still check there as we go along and store brackets in stack in lexer.
	ONCE WE DO lazy lexing, then we won't need to copy the tokens and can just grab from the file_string
	directly and just need to update the eat/peek token functions.
	*/
	cd.load_index = 0;
	while first_pass := cd.load_index < cd.all_directive_load_files.count {
		//TODO Maybe we should store cd.load_index in the lexer
		loaded_file : *DirectiveLoadFile = *cd.all_directive_load_files[cd.load_index];
		ResetCodeLexer(*cd.lexer);
		SetLoadedFile(*cd.lexer, loaded_file);
		defer cd.load_index += 1;//put here in case we call continue
		if cd.lexer.lexer_tokens.count > 0 && cd.lexer.lexer_tokens[0].token_type == .DOUBLE_COLON {
			CreateCompErr(cd, .EVALUATION, cd.lexer.lexer_tokens[0],
			"Invalid first file token.");
			break first_pass;
		}
		//TODO When we do lazy lexing, then we can just put peek and eat here instead so we just use the same 
		//processing and just need to change the files once we hit the end, which can maybe be done in the
		//eat next token anyways and then we only need the single loop here again
		while cd.lexer.next_index < cd.lexer.lexer_tokens.count {
			defer cd.lexer.next_index += 1;
			//TODO Can use this if we have to parse everything sequentially like when we checked brackets here.
			// current_index : int = cd.lexer.next_index;
			current_token : LCodeToken = cd.lexer.lexer_tokens[cd.lexer.next_index];
			current_token_type : CodeTokenType = current_token.token_type;
			if current_token_type == .DOUBLE_COLON {
				//NOTE : We used to go back to line_char_index == 0 here but that does not make sense since
				//things do not need to start from the char 0.
				//WE ONLY PARSE struct and enum declarations in the first pass so going back 1 token is enough.
				//Second pass requires considering op overloads so we add that check on the second pass.
				cd.lexer.next_index -= 1;

				node : *BinaryNode = ParseExpression(cd,S64_MIN);
				if cd.comp_errors.all_compiler_errors.count > 0 break first_pass;
				//TODO Can also do enums on the first pass
				//TODO Check if we have any other declarations of the same name. (Ie structs or enums)
				if IsStructDeclaration(node) {
					//TODO Technically we only need to check structs, but to be consistent we will put both since we will check enums eventually.
					type_name_already_exists := TypeNameAlreadyExists(node.left, cd);
					if type_name_already_exists break first_pass;

					struct_info : *TypeInfoStruct = New(TypeInfoStruct,,context.allocator);
					array_add(*cd.all_type_info_struct, struct_info);
					struct_info.type_enum = TypeInfoTag.STRUCT;
					struct_info.name = node.left.value.token_string;

					//We create the struct pointer type here as well while we're at it.
					CreateTypeInfoPointer(cast(*TypeInfo) struct_info, cd);
				}
				else if IsEnumDeclaration(node) {
					type_name_already_exists := TypeNameAlreadyExists(node.left, cd);
					if type_name_already_exists break first_pass;

					enum_info : *TypeInfoEnum = New(TypeInfoEnum,,context.allocator);
					array_add(*cd.all_type_info_enum, enum_info);
					enum_info.info.type_enum = TypeInfoTag.ENUM;
					enum_info.info.runtime_size = 8;
					enum_info.name = node.left.value.token_string;

					//We create the struct pointer type here as well while we're at it.
					CreateTypeInfoPointer(cast(*TypeInfo) enum_info, cd);
				}

				array_reset_keeping_memory(*cd.binary_tree.nodes);
			} 
			// cd.lexer.next_index = current_index + 1;
		}
	}

	//TODO Can make a function for this maybe since we use it everywhere. But we have to return.
	if cs.print_errors_to_console {
		for cd.comp_errors.all_compiler_errors print("%\n", it.msg);
	}
	if cd.comp_errors.all_compiler_errors.count > 0 return cd;

	found_main_function : bool = false;
	cd.byte_offset_from_sbp = 0;
	cd.comp_level.type = .NONE;
	cd.lexer.next_index = 0;
	cd.load_index = 0;
	while second_pass := cd.load_index < cd.all_directive_load_files.count {
		loaded_file : *DirectiveLoadFile = *cd.all_directive_load_files[cd.load_index];
		ResetCodeLexer(*cd.lexer);
		SetLoadedFile(*cd.lexer, loaded_file);
		defer cd.load_index += 1; //put here in case we call continue
		while cd.lexer.next_index < cd.lexer.lexer_tokens.count {
			defer cd.lexer.next_index += 1;
			//TODO Can also check for variable declaration on second pass and declare variables
			//and place them on global scope but without initialization, so just also check ":" here and
			//keep track of global scope. So there should be no code associated with global scope variable declaration.
			if cd.lexer.lexer_tokens[cd.lexer.next_index].token_type == .DOUBLE_COLON {
				/*DOC : We only need to do this on the second pass since we only process functions and operator overloads
				  on the second pass. The cases are
				  1) enum - "name :: enum"
				  2) struct - "name :: struct"
				  3) function - "name :: ()"
				  4) op overload - "operator + :: ()"
				  5) type directive - "name :: #type"

				  TODO CONSTANT is not parsed here for now but maybe later we will since they are all global
				  and we can just store it in constant memory now for things like constant structs.
				  Constant 8-byte values are currently parsed in the third pass since they can be stored in the node directly.
				  6) constant - "name :: value"

				  NOTE : Only op overload requires going back 2, so we add an extra check for that.
				*/
				cd.lexer.next_index -= 1;
				if cd.lexer.next_index > 0 && 
					cd.lexer.lexer_tokens[cd.lexer.next_index-1].token_type == .KEYWORD_OPERATOR 
				{
					cd.lexer.next_index -= 1;
				}

				node : *BinaryNode = ParseExpression(cd,S64_MIN);
				if cd.comp_errors.all_compiler_errors.count > 0 break second_pass;

				//TODO Can we do IsFunctionDeclaration with a linear lexer token check?
				if IsFunctionDeclaration(node) {
					p_token, has_next_token := PeekNextToken(cd.lexer);
					if p_token.token_type != #char "{" {
						CreateCompErr(cd, .EVALUATION, node, 
						"Function declaration missing \"{\"");
					}
					EatNextToken(*cd.lexer); //Eat "{"

					//Reset this here so the input and return vars get placed properly on the stack
					cd.byte_offset_from_sbp = 0;

					//TODO Can store this expression so that we can reuse later when we find it on the second pass
					//and we don't have to parse the tree again and can access it directly when we find that token.
					//I am not sure if that's more efficient though since well have to check every token.
					new_fd : FunctionDeclaration;
					new_fd.id = cd.next_function_declaration_id;
					cd.next_function_declaration_id += 1;
					new_fd.double_colon_char_index = node.value.total_char_index;
					//TODO Should copy this name to an allocator that is maintained after compilation to reuse this for debugging.
					if node.left.value.token_type == .KEYWORD_OPERATOR {
						new_fd.is_operator_overload = true;
						assert(node.left.right != null); //sanity check. should be checked in parser already
						new_fd.op_token_type = node.left.right.value.token_type;
						op_string := String.slice(cd.lexer.input, node.left.right.value.total_char_index, node.left.right.value.token_length);
						//TODO Could add the word "operator" or "op" here if that seems helpful.
						new_fd.name = sprint("%", op_string);
					} else {
						new_fd.name = node.left.value.token_string;
					}

					//TODO Should we only allow 1 main function
					if new_fd.name == "main" {
						found_main_function = true;
					}

					//TODO Check if we have any other declarations of the same name. (Ie function, structs or enums)

					//TODO This function stack is only useful if we allow functions inside functions.
					//If we don't (maybe for now we can remove and get functions directly from cd.all_function_declarations). 
					//TODO Test that this correctly creates the variables. Also, this should
					//move the data over to this stack frame so likely these need to be special.
					array_add(*cd.function_stack, new_fd.id);


					//TODO We could just process this directly here and only pass in default values to DFSPost with constants
					//if we need to. Then it would just be a line
					if node.right.value.token_type == {
					case .RIGHT_ARROW; //1-n return and 0-n input
						//TODO WE COULD ACCUMULAT values inside of VisitStatementNode and then add them here. This way
						//we don't have to have a bunch of ifs for each declaration type (function, struct, enum...).
						//Can do the same for return values. We could also parse each expression up to "," but that may
						//cause some errors with precedence...
						cd.comp_level.type = .FUNCTION_DECL_INPUT_VARS;
						DFSPost(node.right.left, cd, VisitStatementNode);
						//We reset here since we've added them to cd.all_function_arguments already
						array_reset_keeping_memory(*cd.comma_node_stack);

						//This allows us to parse return values without parsing the input variables.
						#if 0 {
						DFSPost(node.right.right, cd, VisitStatementNode);
						cd.comp_level.type = .FUNCTION_DECL_RETURN_VARS;
						VisitStatementNode(node.right, cd);
						} else {
						//IF keeping node.left as null is unique then this works since we 
						//check for node.left == null in case we have a function type as the return value.
						right_arrow_copy : BinaryNode = node.right.*;
						right_arrow_copy.left = null;
						cd.comp_level.type = .FUNCTION_DECL_RETURN_VARS;
						DFSPost(*right_arrow_copy, cd, VisitStatementNode);
						}
					case #char ":"; #through; //Single input function
					case #char ","; //Input list
						cd.comp_level.type = .FUNCTION_DECL_INPUT_VARS;
						DFSPost(node.right, cd, VisitStatementNode);					
					case #char ")"; //Empty function
						//Explicitly do nothing as we have no input or return vars
					case;
						//TODO Return this as a compiler error. CompilerError
						assert(false, "Invalid function declaration on token %.\n", cd.lexer.lexer_tokens[cd.lexer.next_index]);
					}
					//Reset here again just in case for clarity since we added them to cd.all_function_return_variables
					array_reset_keeping_memory(*cd.comma_node_stack);


					//TODO These can likely be array views directly since the arguments were just added
					func_args : [] FunctionVariable = ArrayFindAllVarName(cd.all_function_arguments, new_fd.id, "function_id",,cd.expr_alloc);
					arg_types : [] *TypeInfo = NewArray(func_args.count, *TypeInfo, false,,cd.expr_alloc);
					for func_args arg_types[it_index] = it.t_info;

					func_return : [] FunctionVariable = ArrayFindAllVarName(cd.all_function_return_variables, new_fd.id, "function_id",,cd.expr_alloc);
					return_types : [] *TypeInfo = NewArray(func_return.count, *TypeInfo, false,,cd.expr_alloc);
					for func_return return_types[it_index] = it.t_info;
					if func_return.count > 0 {
						new_fd.found_return_var = true;
					}

					/*DOC : Currently op overloads are assumed to have 1 or 2 args (unary or binary operators) and 
					we have can have 0 or 1 return value
					eg "+=", "~="... dont need a return value since they apply the value to the left operand
					and also we can allow n + 1; to just apply and not return (maybe there is a case where that is natural)
					*/
					if node.left.value.token_type == .KEYWORD_OPERATOR {
						if func_args.count == 1 {
							found_unary_op := ArrayFindByValue(valid_unary_op_overloads, node.left.right.value.token_type);
							if !found_unary_op {
								CreateCompErr(cd, .EVALUATION, node, 
								sprint("Invalid unary op overload. Valid unary op overloads are %.\n", valid_unary_op_overloads));
								break second_pass;
							}
						}
						else if func_args.count == 2 {
							found_op := ArrayFindByValue(valid_operator_overloads, node.left.right.value.token_type);
							if !found_op {
								CreateCompErr(cd, .EVALUATION, node, 
								sprint("Invalid op overload. Valid op overloads are %.\n", valid_operator_overloads));
								break second_pass;
							}
						} 
						else if func_args.count == 0 || func_return.count > 1 {
							CreateCompErr(cd, .EVALUATION, node, 
							"Operator overloads require 1 or 2 arguments and 0 or 1 return value.");
							break second_pass;									
						}
					}

					//Check for equivalent functions (same name and args)
					for fd : cd.all_function_declarations {
						same_name : bool = false;
						if node.left.value.token_type == .KEYWORD_OPERATOR {
							same_name = fd.is_operator_overload && fd.op_token_type == new_fd.op_token_type;
						} else {
							same_name = fd.name == new_fd.name;
						}
						if same_name {
							if fd.t_info_proc.argument_types.count != arg_types.count continue;
							for fd.t_info_proc.argument_types if it != arg_types[it_index] {
								continue fd;
							}
							CreateCompErr(cd, .EVALUATION, node, 
							sprint("Function already found with same name and args : %.", fd));
							break second_pass;
						}
					}

					//NOTE : We don't check by name since TypeInfoProcedure could also be for a function pointer.
					new_fd.t_info_proc = GetOrCreateTypeInfoProc(arg_types, return_types, *cd.all_type_info_procedure);
					array_add(*cd.all_function_declarations, new_fd);
					//DOC : We set the function id for when we evaluate the function code
					node.code_ir.ir_data_id = new_fd.id;


					//TODO Can remove this if we don't allow functions inside functions
					array_reset_keeping_memory(*cd.function_stack);

					#if 0 {
						//Create this separately so the pointer stays in the same place forever
						t_info_proc = New(TypeInfoProcedure,,context.allocator);
						array_add(*cd.all_type_info_procedure, t_info_proc);
						t_info_proc.type_enum = TypeInfoTag.PROCEDURE;
						//I think this will just be a function pointer so 64-bit pointer value...?
						t_info_proc.runtime_size = 8;
						//This is ok as an array because we will add them right here in memory when parsing the function declaration
					   t_info_proc.argument_types = array_copy(arg_types);
					   t_info_proc.return_types = array_copy(return_types);
			   	}


					//TODO I keep going back to wanting to parse this with a separate tree traversal. I think I will
					//Maybe one for function declarations and then a separate one for constants.
					#if 0 {
					//TODO Maybe this would be more efficient to do with a separate tree traversal? I am not sure depending
					//on error checking and things like that. This is clearer and default constant expressions can still
					//be done with a separate constant tree traversal.
					fi += 1;
					//TODO CompilerError
					assert(cd.lexer.lexer_tokens[fi].token_type == #char "(");
					fi += 1;
					input_index : int = 0;
					while cd.lexer.lexer_tokens[fi].token_type != #char ")" {
						if fi + 2 < cd.lexer.lexer_tokens.count &&
							cd.lexer.lexer_tokens[fi].token_type == .IDENT &&
							cd.lexer.lexer_tokens[fi+1].token_type == #char ":" &&
							//TODO Allow this for any data type
							(cd.lexer.lexer_tokens[fi+2].token_type == .DATA_TYPE_INT ||
							 cd.lexer.lexer_tokens[fi+2].token_type == .DATA_TYPE_FLOAT)
						{
							input_var : *FunctionVariable = array_add(*cd.all_function_arguments);
							input_var.function_id = func_decl.id;
							input_var.name = it.node.left.value.token_string;
							input_var.data_type = it.node.right.code_ir.data_type;
							input_var.var_bytes_from_sbp = input_index;
							input_index += 1;

							fi += 3;
							if cd.lexer.lexer_tokens[fi].token_type == #char "=" {
								//TODO Implement setting default constant function variables with a separate DFSPost
								//which we can then use for constants everywhere.
								//TODO This should also update fi until the next "," or ")" token
								assert(false, "Default function variables not implemented yet for token : %\n", cd.lexer.lexer_tokens[fi+3]);
							}

							if cd.lexer.lexer_tokens[fi].token_type == #char "," {
								fi += 1;
							} else if cd.lexer.lexer_tokens[fi].token_type != #char ")" {
								//Do nothing since we will check this to end the input
							} else {
								//TODO CompilerError
								assert(false, "Invalid function variable declaration : %\n", cd.lexer.lexer_tokens[fi]);
							}
						} else {
							//TODO CompilerError
							assert(false, "Invalid function variable declaration : %\n", cd.lexer.lexer_tokens[fi]);
						}
					}
					
					if cd.lexer.lexer_tokens[fi].token_type != #char ")" {
						//TODO CompilerError
						assert(false, "Invalid function variable declaration : %\n", cd.lexer.lexer_tokens[fi]);
					}
					fi += 1;
					if cd.lexer.lexer_tokens[fi].token_type == .RIGHT_ARROW {
						//TODO Parse return variables
					}
					}
				} else if IsStructDeclaration(node) {
					//TODO Do we want to allow structs within scope? Or just all structs are parsed globally no matter what?
					//TODO We could have a set of tokens which are already parsed and then check that on second pass.
					//So we would skip over to the token on the second pass instead of reparsing the struct.
					p_token, has_next_token := PeekNextToken(cd.lexer);
					if p_token.token_type != #char "{" {
						CreateCompErr(cd, .EVALUATION, node, 
						"Struct declaration missing \"{\"");
						break second_pass;
					}
					EatNextToken(*cd.lexer); //Eat "{"

					//TODO Check if we have any other declarations of the same name. (Ie function, structs or enums)
					//ACTUALLY I think checking that on the first pass is enough now.

					struct_info, found_struct_info := 
						GetTypeInfoStructByName(node.left.value.token_string, cd.all_type_info_struct);
					//Internal Error (maybe we can show this more clearly)
					assert(found_struct_info, "Struct % was not created.\n", node.left.value.token_string);

					cd.current_struct_info = struct_info;

					//TODO Could make a general parse statement to check if we have ";" after
					//although we use those in the second pass so not sure we should make that...
					s_node : *BinaryNode = ParseExpression(cd,S64_MIN);
					while s_node != null && s_node.value.token_type != #char "}" {
						cd.comp_level.type = CompilationLevelType.STRUCT_DECLARATION;
						DFSPost(s_node, cd, VisitStatementNode);
						// p_token, has_next_token = PeekNextToken(cd.lexer);
						// if p_token.token_type != #char ";" {
						// 	CreateCompErr(cd, .EVALUATION, s_node, 
						// 	"Statement does not end with \";\".");
						// 	break second_pass;
						// }
						if IsSemicolonError(cd) break second_pass;
						EatNextToken(*cd.lexer);
						s_node = ParseExpression(cd,S64_MIN);
					}
					struct_info.struct_members = NewArray(cd.create_struct_members.count, TypeInfoStructMember);
					memcpy(struct_info.struct_members.data, cd.create_struct_members.data, 
						cd.create_struct_members.count * size_of(TypeInfoStructMember));
					array_reset_keeping_memory(*cd.create_struct_members);

					//TODO Maybe we should store this somewhere else referenced by token_index and struct_info.id?
					//This is convenient or now but is not really part of TypeInfo, especially if we pass that 
					//back to the user and allow them to see it as well.
					struct_info.last_token_index = cd.lexer.next_index;

					//NOTE : Set this to null now so we don't accidentally keep it for something else and error out instead
					cd.current_struct_info = null;
				} else if IsEnumDeclaration(node) {
					//DOC : Remember that enums are just integers in memory and we lose the enum type/concept at runtime. 
					//THEREFORE we can have enum values that are not in the enum range and this is still valid. This is also how jai behaves.
					p_token, has_next_token := PeekNextToken(cd.lexer);
					if p_token.token_type != #char "{" {
						CreateCompErr(cd, .EVALUATION, node, 
						"Enum declaration missing \"{\"");
						break second_pass;
					}
					EatNextToken(*cd.lexer); //Eat "{"

					enum_info, found_enum_info := 
						GetTypeInfoEnumByName(node.left.value.token_string, cd.all_type_info_enum);
					//Internal Error (maybe we can show this more clearly)
					assert(found_enum_info, "Enum % was not created.\n", node.left.value.token_string);

					//TODO Could make a general parse statement to check if we have ";" after
					//although we use those in the second pass so not sure we should make that...
					s_node : *BinaryNode = ParseExpression(cd,S64_MIN);
					while s_node != null && s_node.value.token_type != #char "}" {
						without_value : bool = s_node != null && s_node.value.token_type == .IDENT;
						with_value : bool = s_node.value.token_type == .DOUBLE_COLON;
						is_valid_enum_decl : bool = with_value || without_value;
						if !is_valid_enum_decl {
							CreateCompErr(cd, .EVALUATION, s_node, "Invalid enum value.");
							break second_pass;
						}

						enum_name : string;
						enum_value : int;
						if without_value {
							enum_name = copy_string(s_node.value.token_string);
							enum_value = cd.create_enum_values.count;
						} else if with_value {
							valid_value : bool = s_node.left != null && s_node.left.value.token_type == .IDENT;
							is_pos_int : bool = s_node.right != null && s_node.right.value.token_type == .INTEGER;
							//NOTE : Jai allows negative enum values so we do the same. Maybe we shouldn't as it requires 
							//the negative parsing as extra but maybe it will be useful for someone down the line.
							is_neg_int : bool = s_node.right != null &&
							  s_node.right.value.token_type == #char "-" && s_node.right.code_ir.ir_type == .UNARY_OP &&
							  s_node.right.right != null && s_node.right.right.value.token_type == .INTEGER;
						   is_valid_with_value : bool = valid_value && (is_pos_int || is_neg_int);
						   if !is_valid_with_value {
								CreateCompErr(cd, .EVALUATION, s_node, "Invalid enum value.");
								break second_pass;					   	
						   }

							enum_name = copy_string(s_node.left.value.token_string);
							if is_pos_int {
								enum_value = s_node.right.value.int_value;
							} else if is_neg_int {
								enum_value = -s_node.right.right.value.int_value;
							}
						}

						array_add(*cd.create_enum_names, enum_name);
						array_add(*cd.create_enum_values, enum_value);
						array_add(*cd.create_enum_with_value, with_value);

						// p_token, has_next_token = PeekNextToken(cd.lexer);
						// if p_token.token_type != #char ";" {
						// 	CreateCompErr(cd, .EVALUATION, s_node, 
						// 	"Statement does not end with \";\".");
						// 	break second_pass;
						// }
						if IsSemicolonError(cd) break second_pass;
						EatNextToken(*cd.lexer);
						s_node = ParseExpression(cd,S64_MIN);
					}
					assert(cd.create_enum_names.count == cd.create_enum_values.count); // sanity check
					assert(cd.create_enum_names.count == cd.create_enum_with_value.count); // sanity check

					if cd.create_enum_with_value.count > 0 {
						check_value : bool = cd.create_enum_with_value[0];
						for cd.create_enum_with_value if it != check_value {
							CreateCompErr(cd, .EVALUATION, s_node, 
							"All enum values must either have specific integer value set or not.");
						}
						array_reset_keeping_memory(*cd.create_enum_with_value);
					}

					enum_info.names = NewArray(cd.create_enum_names.count, string);
					memcpy(enum_info.names.data, cd.create_enum_names.data,
						cd.create_enum_names.count * size_of(string));
					array_reset_keeping_memory(*cd.create_enum_names);

					enum_info.values = NewArray(cd.create_enum_values.count, int);
					memcpy(enum_info.values.data, cd.create_enum_values.data, 
						cd.create_enum_values.count * size_of(int));
					array_reset_keeping_memory(*cd.create_enum_values);

					//TODO Maybe we should store this somewhere else referenced by token_index and struct_info.id?
					//This is convenient or now but is not really part of TypeInfo, especially if we pass that 
					//back to the user and allow them to see it as well.
					// struct_info.last_token_index = cd.lexer.next_index;
					enum_info.last_token_index = cd.lexer.next_index;
				}
				else if node.right != null && node.right.value.token_type == #char "#" {
					/*DOC : For now we allow #type anywhere but sicne it get's added to an array separate from
					other variables it is fine.
					Note : It is best to check this on the second pass since we could use struct names as types
					in a #type definition and this allows us to do that out of order.
					HOWEVER this means we need to use these in order on the global scope.

					TODO We could also allow global variable declarations (without assignment) on the global scope
					here out of order in the local scopes then.
					Tehcnically we could even set the unknown type variables in an array and then just double check
					those after but lets see as we add things in global scope.
					Could also have an extra pass for this and global constants... Let's see what is best and how we use it.
					I THINK FOR GLOBAL VARIABLE DECLARATION we can have an array with unknown global var types
					and then at the end just set those based on any #type we found or error if we found nothing.
					OR also just set them all every time we find the type like we do with out of order function instructions.

					TODO We could keep track of scope and only allow this in global scope.
					Just need to keep track of {} on second pass and whether were in a scope or in global scope.
					Can do the same thing for constants to parse all global constants on the second pass.
					Right now we allow them anywhere but they have to be in order.
					Maybe the best is global constant out of order and scope constant in order.

					DIRECTIVE TYPES IN DIRECTIVE TYPES
					TODO WE COULD JUST not allow types in types to avoid the ordering issue. This also creates a problem
					for loading and importing whereas if everything is out of order, then it does not matter.
					SO WE COULD CHECK the node identifiers and if they are directive type name then compiler error
					to prevent types in types so we can maintain everything out of order like in jai.
					We could leave it but then we can only have types in types within the same file which seems
					like an odd and confusing restriction compared to just not allowing directive types in directive types.
					*/
					code_dir : CodeDirective = code_directive_enums[node.right.value.int_value];
					if code_dir == {
					case .type; {
						//We need to evaluate right node here in case we have eg a procedure type
						//eg "tp :: #type (int) -> int;"
						DFSPost(node.right, cd, VisitStatementNode);

						if node.right.right == null || node.right.right.code_ir.ir_type != .DATA_TYPE_INFO {
							CreateCompErr(cd, .EVALUATION, node.right, "Invalid #type.");
							break second_pass;
						}
						type_name_already_exists := TypeNameAlreadyExists(node.left, cd);
						if type_name_already_exists break second_pass;

						dtn : *DirectiveTypeName = array_add(*cd.all_directive_type_names);
						dtn.name = copy_string(node.left.value.token_string);
						dtn.t_info = node.right.right.code_ir.t_info;
					}
					case; {
						CreateCompErr(cd, .EVALUATION, node, 
						"Invalid directive usage. Valid directives here are \"#type\".");
						break second_pass;
					}
					}
			   }

				array_reset_keeping_memory(*cd.binary_tree.nodes);
			}

			reset(*cd.expr_pool, true);

			if cd.comp_errors.all_compiler_errors.count > 0 break;
		}
	}

	if cd.comp_errors.all_compiler_errors.count == 0 && !found_main_function {
		CreateCompErr(cd, .EVALUATION, LCodeToken.{}, "No main function found.");
		return cd;
	}
	//Output errors and return after first pass
	if cs.print_errors_to_console {
		for cd.comp_errors.all_compiler_errors print("%\n", it.msg);
	}
	if cd.comp_errors.all_compiler_errors.count > 0 return cd;

	//Reset the byte_offset_from_sbp here since we used it in first pass for function declaration args and returns.
	cd.byte_offset_from_sbp = 0;

	//TODO Need to set .sbp to whatever it should be past the constants and null starting value
	// stack_start_value : int = 8;
	// CreateMInstr(.mov, RegMem(.sbp), Imm(stack_start_value), d=cd);

	//Second pass : Main pass to generate music instructions
	//TODO Need a third pseudo pass that goes over all call instructions and updates them with appropriate instruction index
	cd.comp_level.type = .STATEMENT_LEVEL;
	cd.lexer.next_index = 0;
	cd.load_index = 0;
	while third_pass := cd.load_index < cd.all_directive_load_files.count {
		loaded_file : *DirectiveLoadFile = *cd.all_directive_load_files[cd.load_index];
		ResetCodeLexer(*cd.lexer);
		SetLoadedFile(*cd.lexer, loaded_file);
		defer cd.load_index += 1;//put here in case we call continue
		while cd.lexer.next_index < cd.lexer.lexer_tokens.count {
			//TODO Errors could returned here and reported in the tree creation and then if we find error we break.
			s_node : *BinaryNode = ParseExpression(cd,S64_MIN);
			//TODO Should we check null her or check for compiler errors...? Maybe can do again when we make
			//the parsing function non-recursive.
			if s_node == null break third_pass;
			//TODO Could just store these in a buffer and clear once we hit a ';' or '{' or '}'
			//The full storage could just be set for testing.
			/*For now we store them all since we were using them for scope but we don't need to do that and can
			remove this and use the reusable array once we update the scope to work without all the code_statement.
			*/
	   	/*ANOTHER OPTION IS ONE array for general expression nodes thats gets cleared every expression 
	   		and then another stack for control nodes / scopes start that gets popped everytime we close a scope.
	   		so we would keep track of all the nodes for that scope start and then pop that many on close.
	   		It would be like a expression node scope stack.
	   	*/
			array_add(*cd.all_code_statements, CodeStatement.{s_node});

			/*TODO We can put some optimizations at this level if possible. For example #char "("
			means we don't need return values since that is just a straight function call.
			*/

			//Always reset stack before starting so we have a fresh stack when analyzing this statement no matter what.
			cd.already_reset_stack = false;

			start_asm_instr_index : int = cd.all_music_instructions.count;
			d_line_instr_index : int = -1;
			cd.comp_level.type = .STATEMENT_LEVEL;
			//We check for a parsed termination token and process otherwise we 
			if s_node.value.token_type == #char ";" {
				continue;
			} else if s_node.value.token_type == #char "#" {
				//TODO We can leave this here I think and create things separately ALTHOUGH, the scope 
				//would likely be a different type and we need it in case we can create variables in asm.

				//to create variables from within asm like in jai with the (op x:) syntax where x: would create
				//a variable on the stack probably... hmmm not sure i want that but let's see
				//TODO Can make this for #asm {} once we remove arrays from assembler
				if cast(CodeDirective) s_node.value.int_value == {
				case CodeDirective.asm;
					peek_token := PeekNextToken(cd.lexer);
					if peek_token.token_type == #char "{" {
						//TOOD Could allow #asm on the next pass or even check that here to make sure it's valid on the next pass
						EatNextToken(*cd.lexer); //Eat "{"
						CreateScope(.ASM_SCOPE, s_node, false, cd);

						asm_start_index : int = cd.lexer.next_index;
						//TODO Once we have lazy lexing, then maybe we can lex directly in the assembler instead of this
						while cd.lexer.next_index < cd.lexer.lexer_tokens.count && 
								cd.lexer.lexer_tokens[cd.lexer.next_index].token_type != #char "}"
						{
							cd.lexer.next_index += 1;
						}
						//TODO Since we already checked brackets we don't have to check again here but maybe we can for resilience.
						if cd.lexer.next_index >= cd.lexer.lexer_tokens.count || 
							cd.lexer.lexer_tokens[cd.lexer.next_index].token_type != #char "}" 
						{
							CreateCompErr(cd, .EVALUATION, s_node, "#asm scope does not end with \"}\".");
							break third_pass;
						}
						//NOTE : We will process the "{" on the next loop.
						// EatChar(*cd.expr); //Eat "{"
						asm_end_index : int = cd.lexer.next_index;
						asm_token_count : int = asm_end_index - asm_start_index;
						asm_lexer_tokens := array_view(cd.lexer.lexer_tokens, asm_start_index, asm_token_count);
						//TODO FROM HERE grab the lexer tokens with the indices
						//AND THEN Remove "}" check from Assembler and change it so we pass in tokens directly.
						//ALSO put lexer in CompilationData and use that everywhere
						//TODO Do we need to push and pop registers here? Maybe not and we just make them reset it if they
						//do it otherwise it can get messed up. What about if they update the instruction pointer?
						//I think it's fine and if they want to mess with fixed registers then they just do push and pop reg asm call.
						Assembler(asm_lexer_tokens, asm_start_index, cd);
						if cd.comp_errors.all_compiler_errors.count > 0 break third_pass;
						//We could pop later but we pop here for convenience to avoid the next loop.
						//TODO Maybe better to pop this later and check for "}" so we can close it properly
						//if we have any other asm scope things to do.
			   		// pop(*cd.open_scope_stack);
					} else {
						CreateCompErr(cd, .EVALUATION, s_node, "Invalid #asm directive not followed by '{'");
						break third_pass;
					}
				}
			} else if s_node.value.token_type == #char "}" {
				//TODO I think we should also check this on the first pass so we can output an early error in case
				//we don't have closing {}. Should we check all braces then? We are already checking many during parsing.
				if cd.open_scope_stack.count <= 1 {
					//TODO More general error system where we print general error message with line 
					//and char number and then break out of the compilation tree parsing loop to end compilation.
					CreateCompErr(cd, .EVALUATION, s_node, "Found close } without open {.");
					break third_pass;
				}

		   	//TODO Should we just store scope_index then instead of an id?
		   	//It would also make it clearer how deep the scope is. We could keep both i guess...
		   	//TODO Leaving this here since it was a pointer before but it was being passed into CloseControlScope as a non-pointer
				// last_scope_id : int = peek(cd.open_scope_stack).id;
				// last_scope : ScopeData = GetScopeData(last_scope_id, cd);
				last_scope : ScopeData = GetCurrentScope(cd);
	   		if last_scope.scope_type == .CONTROL_SCOPE {
	   			last_scope_group : int = last_scope.inline_scope_group;
	   			while last_scope.inline_scope_group == last_scope_group {
	   				//NOTE : We were popping before here but now we pop and close after to get the final instruction after closing
	   				//in case we add some instruction in CloseControlScope
	   				// pop(*cd.open_scope_stack);
		   			CloseControlScope(last_scope, cd, s_node);
		   			PopAndCloseScope(cd);
						if cd.comp_errors.all_compiler_errors.count > 0 break third_pass;
						last_scope = GetCurrentScope(cd);
					}
			   } else if last_scope.scope_type == .FUNCTION_SCOPE {
			   	//TODO This might be an internal error since we have a scope closing with a scope stack but not a function stack
			   	assert(cd.function_stack.count > 0);
					func_decl_id : int = pop(*cd.function_stack);
					func_decl : *FunctionDeclaration = ArrayFindFirstByNameId(cd.all_function_declarations, func_decl_id, "id");
					//TODO This should be a warning instead of an error once we implement those.
					//Put this back once we implement compiler warnings.
					#if 0 {
					if func_decl.found_return_var && !func_decl.found_return_statement_in_function {
						CreateCompErr(cd, .EVALUATION, s_node, "Statement does not end with \";\".");
						break third_pass;
					}
					}

					//Avoid a double jmp instruction if the function already ends with a return statement, which is common.
					if cd.all_music_instructions.count > 0 && func_decl.name != "main" {
				   	last_instr : MusicInstruction = peek(cd.all_music_instructions);
			   		if last_instr.op_code != OpCode.ret {
							CreateMInstr(.ret, d=cd);
						}
					} else if func_decl.name == "main" {
						//TODO We could set a default .exit instruction here to cleanup data if needed like in C.
						//However we could also have the .HALT instruction do that anyways.
						CreateMInstr(.exit, d=cd);
					}

			   	//TODO This is only 1 if we don't allow function declarations inside functions
			   	//but that likely should work for convenience if needed, although they won't have scope...
			   	//or I guess they could 
			   	//TODO We were doing this at the beginning of FUNCTION_SCOPE pop but now we are doing it here.
			   	//It seems to be working with tests and writing this note as a reminder.
			   	// pop(*cd.open_scope_stack);
			   	PopAndCloseScope(cd);

					//TODO I think this is for function within a function. We can remove it if we don't allow that eventually.
					//Maybe it's useful for function pointers... maybe we can add it later if needed.
					cd.variable_data_stack.count = last_scope.variable_stack_start_index;
					cd.byte_offset_from_sbp = 0;
					if cd.variable_data_stack.count > 0 {
						last_var_op : MusicOperand = cd.variable_data_stack[last_scope.variable_stack_start_index-1].op;
						last_var_type : *TypeInfo = cd.variable_data_stack[last_scope.variable_stack_start_index-1].t_info;
						cd.byte_offset_from_sbp = last_var_op.values[1].int_value + last_var_type.runtime_size;
					}
					// array_reset_keeping_memory(*cd.variable_data_stack);
			   } else if last_scope.scope_type == .ASM_SCOPE {
			   	//TODO We no longer pop here for asm so we could just make this a default.
			   	//We pop asm write after the assembler runs for convenience to avoid an extra loop.
			   	//TODO This could be a default case if we have other scopes. Then maybe this could be a switch statement.
			   	// pop(*cd.open_scope_stack);
			   	PopAndCloseScope(cd);
			   }
			} else if AllOrEquals(s_node.value.token_type, .[.KEYWORD_IF,.KEYWORD_FOR,.KEYWORD_WHILE,.KEYWORD_ELSE]) {
				//TODO Should we create scopes in here or in IF, FOR, WHILE, EVALUATION DIRECTLY?
				/*DOCU : FOR and WHILE we create in here because we want the scope to be accessible with the loop line.
				  For IF and ELSE, we create it after the if because we only want the scope if the condition is valid.
				   for 0..10 {} -> scope starts at for line start_asm_index 
				  		- we want to see variables change on the loop
				   while x < 0 {} -> scope starts at while line start_asm_index 
				  		- we want to see variables change on the loop
				   if x < 0 { x = 10; } -> scope starts at x=10; line start_asm_index 
				  		- we only want to see the variables in scope if the if condition is true
					else if x < 0 { x = 10; } -> scope starts at x=10; line start_asm_index like with if
					else {} -> scope starts in {} because the "else" does not produce any instructions anywyas.

					NOTE : If and else scope.start_instr_index are created in DFSPost since then we have added the conditions
					and while and for are created here since we want to start their debug scopes immediately.

					TODO NEED TO TEST cases like (or maybe we just disallow it for else)
					if x == 0 for 0..10 {
					} else if x == 2 {
					}
					AND 
					for 0..10 if x == 0 {
					} else if x == 2 {
					}
				*/
				scope_data : *ScopeData = CreateScope(.CONTROL_SCOPE, s_node, false, cd);
				//TODO We should check somehow to not have else in an inline statement... although this separate case might be enough
				if s_node.value.token_type == .KEYWORD_ELSE {
					//TODO Should this be a CompilerError? Should we put it in an else below here?
					assert(s_node.right == null || s_node.right.value.token_type == .KEYWORD_IF);
					if s_node.right == null {
						//NOTE : We don't have to change the scope start_instr_index here since there are no conditional instructions
						//in a is_final_solo_else. So we set it for KEYWORD_IF and KEYWORD_ELSE in the parse expression for KEYWORD_IF
						scope_data.is_final_solo_else = true;
					} else if s_node.right.value.token_type == .KEYWORD_IF {
						DFSPost(s_node.right, cd, VisitStatementNode);	
					}
				} else {
					DFSPost(s_node, cd, VisitStatementNode);
					peek_token := PeekNextToken(cd.lexer);
					while AllOrEquals(peek_token.token_type, .[.KEYWORD_IF,.KEYWORD_FOR,.KEYWORD_WHILE]) {
						//TODO FROM HERE test inline and cleanup parsing and evaluation code
						//ALSO CLEANUP OLD IF/FOR/WHILE code above before starting on functions
						//CHECK TO NOT HAVE ELSE IN AN INLINE STATEMENT
						//SHOULD WE DO GLOBAL SCOPE BEFORE DOING FUNCTIONS
						s_node = ParseExpression(cd,S64_MIN);
						scope_data = CreateScope(.CONTROL_SCOPE, s_node, true, cd);
						DFSPost(s_node, cd, VisitStatementNode);
						peek_token = PeekNextToken(cd.lexer);
					}
				}

				peek_token := PeekNextToken(cd.lexer);
				if peek_token.token_type == #char "{" {
					//TOOD Could allow #asm on the next pass or even check that here to make sure it's valid on the next pass
					EatNextToken(*cd.lexer);
					//TODO We are doing this in the parsing KEYWORD_IF but I will leave here just in case as a reminder.
					// if AllOrEquals(scope_data.scope_token.token_type, .[.KEYWORD_IF, .KEYWORD_ELSE]) {
					// 	scope_data.start_instr_index = cd.all_music_instructions.count;
					// }	
				} else {
					//This means we have an inline statement so we parse it and then close the scopes.
					inline_expr : *BinaryNode = ParseExpression(cd,GetCodePrec(#char ";"));
					// peek_token = PeekNextToken(cd.lexer);
					// if peek_token.token_type != #char ";" {
					// 	array_add(*cd.comp_errors.all_compiler_errors, MakeCompErr(.EVALUATION,
					// 		sprint("Error : statement does not end with \";\" : %", s_node.code_node,,context.allocator)));
					// 	break third_pass;
					// }
					if IsSemicolonError(cd) break third_pass;

					EatNextToken(*cd.lexer); //Eat ";"

					//Evaluate inline statement
					EvaluateDefaultStatement(inline_expr, cd);

					assert(cd.open_scope_stack.count > 1); //Sanity check, we add the scopes just above.
					// last_scope : *ScopeData = peek(cd.open_scope_stack);
					// last_scope : ScopeData = peek(cd.open_scope_stack);
	   			last_scope : ScopeData = GetCurrentScope(cd);
	   			last_scope_group : int = last_scope.inline_scope_group;
	   			while last_scope.inline_scope_group == last_scope_group {
	   				// pop(*cd.open_scope_stack);
		   			CloseControlScope(last_scope, cd, s_node);
	   				PopAndCloseScope(cd);
						if cd.comp_errors.all_compiler_errors.count > 0 break third_pass;
						// last_scope = peek(cd.open_scope_stack);
		   			last_scope = GetCurrentScope(cd);
					}
				}
			} else if IsStructDeclaration(s_node) {
				//TODO Should likely store this info somewhere else maybe referenced with token value for uniqueness
				//since it does not seem like we should store this in type_info
				//OR MAYBE when we do lazy lexing, we just skip tokens until we hit the close } bracket anyways for structs and enums.
				struct_info, found_struct_info := GetTypeInfoStructByName(s_node.left.value.token_string, cd.all_type_info_struct);
				assert(found_struct_info);
				//Skip passed the struct. We can also do something like FIRST_PASS_SKIP here on first_pass
				cd.lexer.next_index = struct_info.last_token_index;
			} else if IsEnumDeclaration(s_node) {
				//TODO Should likely store this info somewhere else maybe referenced with token value for uniqueness
				//since it does not seem like we should store this in type_info
				enum_info, found_enum_info := GetTypeInfoEnumByName(s_node.left.value.token_string, cd.all_type_info_enum);
				assert(found_enum_info);
				//Skip passed the enum. We can also do something like FIRST_PASS_SKIP here on first_pass
				cd.lexer.next_index = enum_info.last_token_index;
			} else if IsFunctionDeclaration(s_node) {
				fd, found_fd := ArrayFindFirstByNameId(cd.all_function_declarations, 
					s_node.value.total_char_index, "double_colon_char_index");
				assert(found_fd, "No function declaration : %.\n", s_node.left.value.token_string);

				//TODO REMINDER Need to set scp to the max_proc_offset_from_sbp here once we change and remove
				//.scp and .push from everywhere

				//Set the start_instr_index for this functions so we know where to jmp when we call it
				fd.start_instr_index = cd.all_music_instructions.count;
				//This is so we know that the code was evaluated so we can set where a function call needs to jmp to
				fd.function_code_evaluated = true;
				//We update any function calls that were already made here
				//TODO Technically we can do this all in one shot at the end.
				//All at the end is likely faster since then we don't have to remove them like here which is inefficient.
				//TODO Process this all at the end for each FunctionDeclaration.start_instr_index so we don't have to remove one by one
				for cd.all_out_of_order_instrs if it.function_id == fd.id {
					assert(it.op_index < MusicInstruction.operands.count); //sanity check
					cd.all_music_instructions[it.instr_index].operands[it.op_index].values[0].int_value = fd.start_instr_index;
					remove it;
				}

				//NOTE : Need to add this before creating scope since the scope will store it for later use.
				array_add(*cd.function_stack, fd.id);

				scope_data : *ScopeData = CreateScope(.FUNCTION_SCOPE, s_node, false, cd);
				//TODO We could set this inside CreateScope but since we already have the fd here, we just do it here.
				//If we could create function scopes in multiple places, then maybe better to set this in CreateScope.
				fd.scope_id = scope_data.id;
				//TODO Maybe if this is always true then we don't need the scope_id in the FunctionDeclaration anyways.
				assert(fd.start_instr_index == scope_data.start_instr_index);

				//Reset the offset from sbp and then we push arguments and return values on the stack
				cd.byte_offset_from_sbp = 0;
				//TODO Use CreateStackVarData and then don't we need to push these variables on the stack here?
				function_args : [] FunctionVariable = ArrayFindAllVarName(cd.all_function_arguments, fd.id, "function_id");
				for function_args {
					//TODO Can remove the below once we know this is working.
					//Pushing on the stack here instead of copying for consistency.
					#if 1 {
					#if 0 {
					arg_var_type : VariableType = ---;
					arg_t_info : *TypeInfo = it.t_info;
					if it.t_info.type_enum == .POINTER {
						arg_var_type = .DEFAULT;
					} else {
						//TODO Should we rename this to FUNCTION_INPUT or FUNCTION_RESTRICTED_INPUT
						arg_var_type = .RESTRICTED_INPUT;
						if arg_t_info.runtime_size > 8 {
							arg_t_info = GetOrCreateTypeInfoPointer(arg_t_info, cd);
						}
					}
					}
					//TODO Should we have a is_arg flag of the variable is a function argument so we don't have
					//to check the FunctionVariable every time?
					// var : *VariableData = CreateStackVarData(cd, it.name, arg_t_info, arg_var_type);
					var : *VariableData = CreateStackVarData(cd, it.name, it.t_info);
					assert(var.op.values[1].int_value == it.var_bytes_from_sbp);
					} else {
					var : *VariableData = array_add(*cd.variable_data_stack);
					var.id = cd.next_var_declaration_id;
					cd.next_var_declaration_id += 1;
					var.name = it.name;
					var.t_info = it.t_info;
					var.scope_index = cd.open_scope_stack.count-1;
					// var.function_id = fd.id;
					//TODO Need to update var_bytes_from_sbp here. Could probably put an op there instead
					//so we can just copy the op over directly isntead of this.
					var.op = RamMem(.sbp, it.var_bytes_from_sbp);
					var.var_type = VariableType.RESTRICTED_INPUT;
					}
				}

				//TODO FROM HERE Indeed if we remove return pointers, we can remove this but I think I want to
				//because it only allows for optimization in 1 case which is x := foo(); so we don't have an extra
				//copy but the value is on the stack on anyways, so 1 extra memcpy is not a big deal to avoid
				//all this extra complexity. In any case we would have to run the extra instructions for the pointer
				//dereference which is probably more expensive than the extra memcpy. 
				//I think I should write down my thoughts in "(" at some point once we update everything.
				//TODO SO maybe start with doing function debugging and then flesh it out a bit as adding
				//variables likely is wrong right now since we have the return pointers and then either do the ui first
				//so it's easier to check everything manually and then update function call logic or update function
				//call and then do the ui.
				//Need to keep track of max to set scp to max size for each stack frame
				//TODO We can remove this since return variables are not on the stack at all
				#if 0 {
				return_var : [] FunctionVariable = ArrayFindAllVarName(cd.all_function_return_variables, fd.id, "function_id");
				for return_var {
					#if 1 {
					//TODO Should this be restricted? It's a pointer... the pointer can't be updated but the data can
					var : *VariableData = CreateStackVarData(cd, it.name, it.t_info, .RESTRICTED_INPUT);
					assert(var.op.values[1].int_value == it.var_bytes_from_sbp);
					} else {
					var : *VariableData = array_add(*cd.variable_data_stack);
					var.id = cd.next_var_declaration_id;
					cd.next_var_declaration_id += 1;
					var.name = it.name;
					var.t_info = it.t_info;
					var.scope_index = cd.open_scope_stack.count-1;
					// var.function_id = fd.id;
					//TODO Need to update var_bytes_from_sbp here. Could probably put an op there instead
					//so we can just copy the op over directly isntead of this.
					var.op = RamMem(.sbp, it.var_bytes_from_sbp);
					var.var_type = VariableType.RESTRICTED_INPUT;
					}
				}
				}

				//NOTE : We check that this is valid on the second pass when we parse function declarations
				if fd.name == "main" {
					cd.main_function_instr_index = cd.all_music_instructions.count;
				}

				//Sanity check. We do this in the second pass so just double check assertion here.			
				assert(PeekNextToken(cd.lexer).token_type == #char "{");
				EatNextToken(*cd.lexer); //Eat "{"
				//TODO We could check here for "}" and if we have "}" then we don't create the function at all,
				//since it's an empty function and does not do anything.
				//OR We could put a .nop instruction if it's empty so that we can't have multiple empty instructions
				//start from the same place. OR we could have every instruction start with a nop or with a fstart
				//instruction which just starts the function and probably does nothing
			} else {
				//TODO Could make this ";" peek check a function so we can reuse for inline as well.
				//Just we have to break third_pass so iunno maybe not worth it for just 2 cases.
				//Normal statement case that should end with ";"
				// peek_token := PeekNextToken(cd.lexer);
				// if peek_token.token_type != #char ";" {
				// 	last_token := PeekLastToken(cd.lexer);
				// 	CreateCompErr(*cd.comp_errors, .EVALUATION, last_token, 
				// 	"Statement does not end with \";\".");
				// 	break third_pass;
				// }
				if IsSemicolonError(cd) break third_pass;
				EatNextToken(*cd.lexer); //Eat the ";"

				EvaluateDefaultStatement(s_node, cd);
			}

			/*TODO Should we allow empty lines for debugging.
			FOR EXAMPLE, function declarations have no instructions but technically we could stop there on a function call.
			This works in remedy, however here the function declaration itself has no code so it might be clearer
			overall to just jump to the first line since that is what the code actually does. 
			In the debugger, we can move the breakpoint to the next debug_line if the current line has no associated debug line.
			*/
			added_instructions : bool = cd.all_music_instructions.count > start_asm_instr_index;
			//We don't want to add debug_line if this is #asm since we already added it in the assembler for each instruction.
			//TODO Could make this a function if needed
			is_asm : bool = s_node.value.token_type == #char "#"	&&
				cast(CodeDirective) s_node.value.int_value == CodeDirective.asm;
			if added_instructions && !is_asm {
				//TODO I think we need to update the start and end in assembly. So maybe make a function to be consistent.
				//TODO Should be a function if we use similar logic elsewhere.
				//TODO We do something similar in the assembler. Should we make a function if they are mostly the same?
				//Only the start_asm_index is different so maybe we could just pass that in the function.
				debug_line, already_have_instr_on_line := ArrayFindFirstByNameId(cd.all_debug_lines, 
					s_node.value.line_number, "line_number");
				if already_have_instr_on_line {
					debug_line.end_asm_index = cd.all_music_instructions.count-1;
				} else {
					debug_line : *DebugLine = array_add(*cd.all_debug_lines);
					debug_line.line_number = s_node.value.line_number;
					debug_line.start_asm_index = start_asm_instr_index;
					debug_line.end_asm_index = cd.all_music_instructions.count-1;
					debug_line.absolute_path_name = loaded_file.absolute_path_name;
				}
			}


			array_reset_keeping_memory(*cd.all_node_values);
			array_reset_keeping_memory(*cd.all_code_ir_values);
			array_reset_keeping_memory(*cd.binary_tree.nodes);

			reset(*cd.expr_pool, true);


			/*I am putting this here now so we fail out on a statement that has errors BUT
			we can later pull it out of the statement evaluation loop to print out all errors at once.
			There might be some complications to that so it could also be a setting.
			ALSO we break out of third_pass now but this is here just in case.
			*/
			if cd.comp_errors.all_compiler_errors.count > 0 break third_pass;
		}
	}

	/*TODO Print out compiler errors here for convenience but we can change this to printing at the caller level
	or having some kind of more detailed error logging here... not sure yet.
	for example, right now we assume that the error is formatting itself but maybe that can be done afterwards...
	also we could add some text based on error type eg parser or evaluation error or internal
	*/
	if cs.print_errors_to_console {
		for cd.comp_errors.all_compiler_errors print("%\n", it.msg);
	}

	//TODO I am putting this in here now for convenience but we can pull it out later
	//if we want to do it somewhere else. A successful compilation is a good place to do it though
	//since we know we have a valid disassembly.
	if cd.comp_errors.all_compiler_errors.count == 0 {
		//Close the global scope here and make sure we only have that scope left
		//NOTE : We can only do this with no errors
		assert(cd.open_scope_stack.count == 1, "open scope count = % on compilation end", cd.open_scope_stack.count);
		cd.all_scope_data[global_scope.id].end_instr_index = cd.all_music_instructions.count-1;


		cd.disassembly = Disassembler(cd.all_music_instructions);
		cd.disassembly_loc = String.split(cd.disassembly, cast(u8) #char "\n");
		//We subtract 1 line here since the last line will be empty (we add \n to every line) and this keeps it consistent
		//with all_music_instructions.count so we can index/access them with the same value.
		if cd.disassembly_loc.count > 0 {
			cd.disassembly_loc.count -= 1;
		}
	}

	return cd;
}
//DOC : We grab the last token since the next token would be on the next line
//and the ; should be on the current line which is of the last token.
IsSemicolonError :: (cd : *CompilationData) -> is_error : bool {
	peek_token := PeekNextToken(cd.lexer);
	if peek_token.token_type != #char ";" {
		last_token := PeekLastToken(cd.lexer);
		CreateCompErr(cd, .EVALUATION, last_token, "Semicolon expected after expression.");
		return true;
	}
	return false;
}

IsFunctionDeclaration :: inline (node : *BinaryNode) -> bool {
	is_function_declaration : bool = node != null && node.value.token_type == .DOUBLE_COLON &&
		 node.right != null &&
		(node.right.value.token_type == .RIGHT_ARROW ||
		 node.right.value.token_type == #char ")" || //Empty function
		 node.right.value.token_type == #char "," || //Input list
		 node.right.value.token_type == #char ":") //Single value function
		&& 
	   (node.left != null && AllOrEquals(node.left.value.token_type, .[.IDENT, .KEYWORD_OPERATOR]));
   return is_function_declaration;
}

IsStructDeclaration :: inline (node : *BinaryNode) -> bool {
	is_struct_decl : bool = node != null && node.value.token_type == .DOUBLE_COLON &&
		node.right != null && node.right.value.token_type == .KEYWORD_STRUCT &&
		node.left != null && node.left.value.token_type == .IDENT;
	return is_struct_decl;
}

IsEnumDeclaration :: inline (node : *BinaryNode) -> bool {
	is_enum_decl : bool = node != null && node.value.token_type == .DOUBLE_COLON &&
		node.right != null && node.right.value.token_type == .KEYWORD_ENUM &&
		node.left != null && node.left.value.token_type == .IDENT;
	return is_enum_decl;
}

PopAndCloseScope :: inline (cd : *CompilationData) {
	//0 is the global scope so we never want to pop that.
	assert(cd.open_scope_stack.count > 1);
	last_scope_id : int = pop(*cd.open_scope_stack);

	found_scope : bool = false;
	for * cd.all_scope_data if it.id == last_scope_id {
		found_scope = true;
		//copy from the scope stack in case we updated something.
		// it.* = last_scope;
	   //Close the scope here so we can use for debugging later
	   it.end_instr_index = cd.all_music_instructions.count-1;
	   //NOTE : on final solo else, if we have no instructions in it, then we get start=2 and end=1 for example.
	   //so we do this check to avoid that.
	   /*WE REMOVE THE SCOPE IF THERE ARE NO INSTRUCTIONS IN IT BECAUSE otherwise we could have a case like
	   	if x == 0 {}
	   	else {}
	   	for 0..10 {}
		Then the else scope would overlap with the for loop scope if we leave the scope since 
		there are no instructions in the empty else and we do not want overlapping scopes.
		This could be avoided by making a compiler error with an empty else but I think
		allowing it and removing the scope makes more sense. If we have issues can update.
		I sometimes use empty if/else to write notes for that specific case so I think allowing it is ok.
		We have end < start instead of end <= start because end == start if we have a 0 to 1 line if/else.
		for example this will be 1 line scope so start == end (also inline if statements)
		if x == 0 { y = 5;}
	   */
	   if it.end_instr_index < it.start_instr_index {
	   	// it.end_instr_index = it.start_instr_index;
	   	array_ordered_remove_by_index(*cd.all_scope_data, it_index);
	   }
	   break;
	}
	//Sanity check to make sure we created the scope.
	assert(found_scope);
}

/*Note : We pass in the s_node here for error handling.
TODO We should likely store the closed scope somewhere so we can have access to it during debugging.
This will allow us to check which variables are available in the current scopes for example.
*/
CloseControlScope :: inline (last_scope : ScopeData, cd : *CompilationData, s_node : *BinaryNode) {
	if last_scope.scope_token.token_type == {
	//TODO Would having an ELSE_IF token be clearer? That may unnecessarily complicate things at the lexer/parser level though
	//ACTUALLY A BETTER OPTION is to just keep the scope nodes in a separate node array until we close the scope
	//and then to clear them like a stack. IF we need to check the nodes that is possible.
	//For now we store all nodes but that could be a good option later if needed.
	//So one array for general nodes thats gets cleared every expression 
	//and then another stack for control nodes / scopes that gets popped everytime we close a scope
	case .KEYWORD_ELSE; #through;
	case .KEYWORD_IF; {
		//TODO Removed this now that we don't use the .scp scope everywhere but leaving here for reference for now.
		//Close if scope before doing the jmp out
		// CreateMInstr(.add, RegMem(.scp), RegMem(.sbp), Imm(last_scope.start_byte_offset_from_sbp), d=cd);
		//Reset stack and remove all current scope variables
		cd.byte_offset_from_sbp = last_scope.start_byte_offset_from_sbp;
		cd.variable_data_stack.count = last_scope.variable_stack_start_index;

		//TODO We could also add these instructions during evaluation like we do for for loop
		next_check := PeekNextToken(cd.lexer);
		if next_check.token_type != .KEYWORD_ELSE {
			assert(cd.all_if_data.count > 0);
			//Each else associated with the original if has a jmp instruction that needs to be
			//updated to jmp to the current instruction which is after all the if/elses
			if_data : IfData = pop(*cd.all_if_data);
			while cd.all_else_data.count > 0 {
				else_data : *ElseData = peek_pointer(cd.all_else_data);
				if else_data.if_else_id != if_data.if_else_id {
					break;
				}
				cd.all_else_data.count -= 1;

				else_jmp : *MusicInstruction = *cd.all_music_instructions[else_data.jmp_instr_index];
				assert(else_jmp.op_code == OpCode.jmp);
				else_jmp.operands[0].values[0].int_value = cd.all_music_instructions.count;
			}
		} else {
			//Jump over the other elses if this if condition is true.
			//We add this .jmp to the outer scope and that should be ok since we should be checking
			//{} closing on the first pass so we should not have any other ctrl_fjmp until this else closes.
			CreateMInstr(.jmp, Imm(0), d=cd);
			else_data : *ElseData = array_add(*cd.all_else_data);
			else_data.if_else_id = peek(cd.all_if_data).if_else_id;
			else_data.jmp_instr_index = cd.all_music_instructions.count-1;
		}

		//We could check the node here directly if we keep the scope nodes until we clear them
		//If last scope is not a final else then we need to update the previous condition .fjmp
		if !last_scope.is_final_solo_else {
			//TODO make function for pushing and popping control fjmps to reuse
			//and then start on inline statements and consider scope before doing functions
			//(think about this when doing inline statements)
   		ctrl_fjmp : ControlFjmps = pop(*cd.all_control_fjmps);
   		//TODO Is this an internal error or a CompilerError?
   		assert(ctrl_fjmp.scope_index == cd.open_scope_stack.count-1);
   		fjmp_instr : *MusicInstruction = *cd.all_music_instructions[ctrl_fjmp.instr_index];
   		incomplete_jmp_index : *MusicOperand = *fjmp_instr.operands[0];
			incomplete_jmp_index.int_value = cd.all_music_instructions.count;	
		}
	}
	case .KEYWORD_WHILE; {
		/*NOTE THAT FOR WHILE AND FOR LOOP we reset the scp on every loop. This allows us to 
		  simply recreate variabel and such without wasting memory. Not the most efficient but it's
		  nice because it works in all cases and I prefer that to optimizing out the variables for example.
		  While loop only needs 1 reset since it does not create any variables for itself, while for loops
		  can create either 1 or 2 variables
		  NO NEED TO RESET SCP ANYMORE SINCE WE JUST USE byte_offset_from_sbp to keep track of where we are
		  on the stack.
		*/
		// CreateMInstr(.add, RegMem(.scp), RegMem(.sbp), Imm(last_scope.start_byte_offset_from_sbp), d=cd);
		//Reset stack and remove all current scope variables
		cd.byte_offset_from_sbp = last_scope.start_byte_offset_from_sbp;
		cd.variable_data_stack.count = last_scope.variable_stack_start_index;

		//TODO Can do the same as for if needed although while starts with condition so this works for now.
		//This works because we want to recheck the conditions which is how the scope starts
		CreateMInstr(.jmp, Imm(last_scope.start_instr_index), d=cd);

		//TODO Can this be a function to get the fjmp and then we set in here?
		ctrl_fjmp : ControlFjmps = pop(*cd.all_control_fjmps);
		//TODO Is this an internal error or a CompilerError?
		assert(ctrl_fjmp.scope_index == cd.open_scope_stack.count-1);
		fjmp_instr : *MusicInstruction = *cd.all_music_instructions[ctrl_fjmp.instr_index];
		incomplete_jmp_index : *MusicOperand = *fjmp_instr.operands[0];
		incomplete_jmp_index.int_value = cd.all_music_instructions.count;	
	}
	case .KEYWORD_FOR; {
		//I think this assertion is ok here since we should be failing beforehand on {} not closing
		//or an invalid for loop and then never reach here.
		assert(cd.all_for_loop_data.count > 0);
		fld : *ForLoopData = peek_pointer(cd.all_for_loop_data);
		//TODO Could do a memcpy here instead maybe
		for 0..fld.post_instr_count-1 {
			array_add(*cd.all_music_instructions, fld.post_loop_instrs[it]);
		}
		cd.all_for_loop_data.count -= 1;

		//TODO Can this be a function to get the fjmp and then we set in here?
		ctrl_fjmp : ControlFjmps = pop(*cd.all_control_fjmps);
		//TODO Is this an internal error or a CompilerError?
		assert(ctrl_fjmp.scope_index == cd.open_scope_stack.count-1);
		fjmp_instr : *MusicInstruction = *cd.all_music_instructions[ctrl_fjmp.instr_index];
		incomplete_jmp_index : *MusicOperand = *fjmp_instr.operands[0];
		//We want to jmp to the full scope reset
		incomplete_jmp_index.int_value = cd.all_music_instructions.count;

		//The for loop has 2 scope resets, one per loop which is passed in through post_loop_instrs above
		//and one to completely clear the scope here below.
		// CreateMInstr(.add, RegMem(.scp), RegMem(.sbp), Imm(last_scope.start_byte_offset_from_sbp), d=cd);
		//Reset stack and remove all current scope variables
		cd.byte_offset_from_sbp = last_scope.start_byte_offset_from_sbp;
		cd.variable_data_stack.count = last_scope.variable_stack_start_index;
	}
	case; {
		//TODO not sure we need this anymore since we check closed brackets in lexer now
		CreateCompErr(cd, .EVALUATION, s_node, "Found close } without open {.");
		return;
	}
	}
}

/*START OF ASSEMBLY
*/

// Assembly Intermediate Representation
AssemblyIR :: struct {
	//TODO This could be a SoA so we can operate mostly on the type and the int_value
	//OR remove altogether if not needed
	id : int;
	asm_ir_type : AssemblyIRType;
	union {
		int_value : int;
		float_value : float64;
	}
}

//TODO Can we put this in AssemblyIR now?
//It might make more sense to put 2 of these in AssemblyIR now for arrays and ram and variables
//and then we can keep it here and add more later if we need it
AssemblyIRValue :: struct {
	asm_ir_id : int;
	// int_value : int;
	union {
		int_value : int;
		float_value : float64;
	}
	//Only implemented int for now but this structure
	//allows us to do any type.
	// union {
	// 	int_value : int;
	// 	float_value : float;
	// 	bool_value : bool;
	// }
	asm_ir_value_type : AssemblyIRValueType;
}

//TODO Could add value types here and then set the
//value based on the type once we have other reg types.
MakeAssemblyIRValue :: inline (
	asm_ir_id : int,
	type : AssemblyIRValueType,
	int_value : int)
-> AssemblyIRValue 
{
	value : AssemblyIRValue = ---;
	value.asm_ir_id = asm_ir_id;
	value.asm_ir_value_type = type;
	value.int_value = int_value;
	return value;
}


//TODO Do we really need this anymore. I Guess it is more limited
//but we can remove expression stuff or reuse AssemblyIRType
//TODO Could likely make this into 1 type if they stay the same and then.
//So AssemblyIRValueType == OperandValueType and just have probably OperandValueType 
ir_value_type_enums : [] AssemblyIRValueType : #run enum_values_as_enum(AssemblyIRValueType);
AssemblyIRValueType :: enum {
	INT;
	FLOAT;
	SINGLE_REGISTER;
	// RAM_MEMORY;

	//TODO Could add logical operators here as well if needed
	BINARY_ADD_OP;
	BINARY_SUB_OP;
	BINARY_MULT_OP;
	BINARY_DIV_OP;
	UNARY_NEG_OP;
	UNARY_PLUS_OP;
	OPEN_CIRCLE_BRACKET;
	CLOSE_CIRCLE_BRACKET;

	EXPRESSION;
}

SINGLE_ASM_IR_TYPE :: AssemblyIRType.[.INT,.SINGLE_REGISTER,.RAM_MEMORY];
SINGLE_VALUE_TYPE :: AssemblyIRType.[.INT,.SINGLE_REGISTER,.EXPRESSION];
// INT_OR_SINGLE_REGISTER :: AssemblyIRType.[.INT,.SINGLE_REGISTER];
// asm_ir_type_enums : [] AssemblyIRType : #run enum_values_as_enum(AssemblyIRType);
AssemblyIRType :: enum {
	/*These are the types that are allowed at runtime
	right now. Other types are ultimately converted to
	integers and accessed appropriately.
	Adding a type system seems unnecessary atm overall because
	of higher level programming languages.
	*/
	INT;
	FLOAT;
	SINGLE_REGISTER;
	MEMORY_MPS;
	RAM_MEMORY;
	ARRAY;
	OP_CODE;
	//End of runtime types

	//For variables that are used which can be declared outside of the asm block and possibly also in the asm block
	//which would add them to the stack for us I guess... maybe best to allow the player to do that.
	ASM_VARIABLE;

	ADD;
	SUBTRACT;
	MULTIPLY;
	EXPRESSION;

	/*Below are convenience types to allow use to check
	other lexer tokens and things like op_space types
	on the second pass of the compiler.
	*/ 

	//TODO Replace this with VALUE_ARRAY 
	//since we can have registers in it
	COMMA;
	TWO_DOTS;

	//TODO Can likely remove this now
	OP_SPACE_INDEX;
	MACRO;
}

ASM_IR_ID : int = 0;
CreateAsmIR :: inline (type : AssemblyIRType, value : $T, data : *[..] AssemblyIR) -> *AssemblyIR {
#assert(T == int || T == float64);
	asm_ir : *AssemblyIR = array_add(data);
	asm_ir.id = ASM_IR_ID;
	asm_ir.asm_ir_type = type;
	#if T == {
	case int; asm_ir.int_value = value;
	case float64; asm_ir.float_value = value;
	}
	ASM_IR_ID += 1;
	return asm_ir;
}

//NOTE : The type is assumed to always be checked beforehand so we don't have to check in here.
CreateAsmIRValue :: inline (asm_ir_id : int, type : AssemblyIRType, value : $T, data : *[..] AssemblyIRValue) -> *AssemblyIRValue {
#assert(T == int || T == float64);
	asm_ir_v : *AssemblyIRValue = array_add(data);
	asm_ir_v.asm_ir_id = asm_ir_id;
	if type == {
	case .SINGLE_REGISTER; asm_ir_v.asm_ir_value_type = .SINGLE_REGISTER;
	case .OP_CODE; #through;
	case .INT; asm_ir_v.asm_ir_value_type = .INT;
	case .FLOAT; asm_ir_v.asm_ir_value_type = .FLOAT;
	}
	#if T == {
	case int; asm_ir_v.int_value = value;
	case float64; asm_ir_v.float_value = value;
	}
	return asm_ir_v;	
}

ValidateAssemblyIRTypes :: inline (
	current_asm_irs : [] AssemblyIR,
	input_valid_ir_types: .. [] AssemblyIRType)
-> bool
{
	//Input validation should validate each operand so current_asm_irs - 1 without
	//the op_code asm_ir.
	// assert(input_valid_ir_types.count == current_asm_irs.count);

	valid_ir_count : bool = current_asm_irs.count == input_valid_ir_types.count;
	if !valid_ir_count return false;

	all_valid_operands : bool = true;
	for valid_ir_types, valid_index : input_valid_ir_types {
		operand : AssemblyIR = current_asm_irs[valid_index];
		//TODO could validate things like valid single register in here
		valid_operand : bool = AllOrEquals(operand.asm_ir_type, valid_ir_types);
		if !valid_operand return false;
	}

	return true;
}

BracketAsm :: struct {
	c_index : int;
	asm_ir_index : int;
	asm_ir_value_index : int;
}

LabelSymbol :: struct {
	label_string : string;
	instr_index : int;
	//TODO This can be removed now with new asm without multiple files
	file_id : int;
}

/*TODO I THINK I DID A BUNCH OF THESE SO CAN REMOVE SOME OF THESE COMMENTS
-> muscall can get the value as a string from the enum and then store as int. Can also go from int to string in disassembly.
-> Right now we are testing Assembler from the compiler, which is good. Maybe can write some specific just for Assembler function eventually.
-> Could make the disassembler from MusicInstructon -> assembly string. Could make debugging easier
-> REMOVE ARRAYS AND "{" parsing. 
	-> THEN USE #asm {} and just search for "}" in assembler to close off asm block.
-> UPDATE ram and music memory "[" and "<" since it should be simpler now with only 2 values for sure
-> COULD REPLACE from <0,0> to [0,0] and then ram is [0] or [0+1] and so all music_memory must have ","
	Could also allow both <0,0> and [0,0] for now and see if there is a preference
-> ADD FLOAT TO ASSEMBLER so like "mov.f" for instruction to indicate float instruction and then later
we may possibly add single bytes so we would have mov.b and this would effect some instructions
so it depends on the instruction whether it wants to use the type or not otherwise we can just ignore it
-> ADD ABILITY TO ACCESS EXTERNAL VARIABLES FROM WITHIN #ASM SCOPE
-> POSSIBLY ALLOW PURE #ASM SCOPES SO THAT WE CAN HAVE LOOPS OR FUNCTION LIKE and we can use this for intrinsics
	- foo :: (x:int) -> int #asm {}
-> NOT SURE ABOUT THIS THE WAY WE PARSE IS ANALOGOUS TO THE TREE FOR THE COMPILER so I don't think we can
remove it as it is arbitrary size parsing and then checks it after. Likely just leave it and can
maybe optimize a bit if we force ";" at the end or "," in between but i like not as it is more flexible... hmmm
UPDATE ASSEMBLYIR AND ASSEMBLYIRVALUE (maybe collapse like we did for MusicInstruction) when we do floats.
Can maybe do that first depending and see how it effects, RAM and MUSIC_MEMORY. Should be doable and fail
in the loop and then we can just put everything into the AssemblyIR altogether.
-> Should we move MusicInstructon and MusicOperand and OpCode in here as well?
-> Generalize tests for lexer and for compiler. Specifically for compiler then use RamMEm and MusicMem with 
   MusicInstruction and MusicOperand directly (should we move those structs into this file?) and then use that
   for the compiler as well and then start again on compiler.
- LAZY LOADING TOKENS would likely need to change a bit the way we do first and second pass. If we force each
as instruction to end with ";" then we could just parse to there and then evaluate and then that would be
good for lazy loading as well. First pass is just labels and checks end of asm scope so that would likely stay the same

//TODO Should We move AssemblyIR and AssemblyIRValue in here? Probably, espcecially since well remove the other
//assembler and lexer from thegame_base once this is one can be used directly in the code.

Then look at generalizing tests with RamMem and MusicMem and use the functions to create it.
Then we can see if we can reuse these in the compiler as well. Start compiler after that and
reuse those and then do functions, if, loops since those are harder and then start on types
and move between asm and code with types.
AND See if we should GENERALIZE LEXER TESTS

*/
/*Reminders
	- LAZY LEXING : Maybe we can do lazy lexing directly in the assembler once we do that.
		That way we can also pass around errors more easily.
	- Move AssemblyIR and AssemblyIRValue in here
	- ERROR HANDLING. Should do a thorough pass when we do this with tests.
	- IF we remove arrays, then we can possibly compress the values into AssemblyIR and remove AssemblyIRValue completely.
	  Then we could optimize the assembler based on that rule.
  	- We could check for ',' to ensure we only have so many. This avoids issues with forgetting a ; for example although
  	that should not result in too much of a problem. Look into this when we test for errors.
  	- Should we move OpCode in here or leave it in thegame_data for now?
*/
/*Thoughts
	- Could replace music_mem from <0,0> to [0,0] and then ram is [0] or [0+1] and so all music_memory must have ","
	but the ram_memory is either single value or has a +/- for the offset
	- Could move this array_add for current_asm_irs altogether if we have a max value and remove the Array type
	since then we will have a max value we can use and so we just set those and we know it won't go over the max value.
	People could add more operators, but that can be verified beforehand and discarded.
	- If we lex one line at at time, we would still have to do a first pass in order to check for labels.
	We could do this by parsing the characters and checking for ":" and "#endasm", but then at that point we 
	would just create the tokens anyways in the first pass...
*/
//TODO We pass in all *CompilationData for convenience, but we only use all_compiler_errors and also 
//registers and variable_data_stack, so we could just pass those in but I will leave cd now
//for convenience in case we use it later. The problem is if we need to use the Assembler elsewhere
//then we need to pass in a full CompilationData but maybe that is also more consistent for now. 
//OVERALL I prefer passing in arrays I think so I can likely change that later.
//NOTE : total_asm_start_index i where we start from in the code. So it could default to 0
//We only use it for labels. Maybe I can put it in CompilationData eventually if that makes more sense.
Assembler :: (asm_tokens : [] LCodeToken, total_asm_start_index : int, cd : *CompilationData) {
	label_symbol_table : [..] LabelSymbol;
	label_symbol_table.allocator = context.allocator;

	fi : int = 0; //First pass index
	while fi < asm_tokens.count {
		//TODO There are no tests for labels. Should probably make some to make sure this actually works...
		//TODO Could have an identifier for labels so we don't confuse for outside variables if that's convenient.
		if asm_tokens[fi].token_type == CodeTokenType.IDENT &&
    	   asm_tokens[fi+1].token_type == #char ":"
	   {
	    	defer fi += 2;

			label_string : string = asm_tokens[fi].token_string;
			label_symbol, is_label_symbol := ArrayFindFirstByNameId(label_symbol_table,
				label_string, "label_string", StringEqual);

			if !is_label_symbol {
				new_label : *LabelSymbol = array_add(*label_symbol_table);
				new_label.label_string = label_string;
				new_label.instr_index = total_asm_start_index + fi;

				asm_tokens[fi].token_type = CodeTokenType.FIRST_PASS_SKIP;
				asm_tokens[fi+1].token_type = CodeTokenType.FIRST_PASS_SKIP;
			} else {
				CreateCompErr(cd, .ASSEMBLY_ERROR, asm_tokens[fi],
				sprint("Label already exists : %.", label_string,, context.allocator));
			}
	   } else {
			// Not processing on the first pass so we skip for now
			fi += 1;
		}
	}

	if cd.comp_errors.all_compiler_errors.count > 0 return;

	/*
		***IDEA : turn code into a linear equation 2 * code_0 + 1 * code_1 + 3 * code_2. That
		could be an interesting way to do levels later on where we can reuse what we did in a
		linear way. Can we perform other math operations on the code with this algebra?***
	*/

	/*TODO
	Overall we need to have 1 point where the OldMusicInstruction and OldMusicOperands are created and validated for consistency.
	Same place for asm and for code. Right now we validate in asm but this should also be validated for code for now
	so I reduce the number of mistakes. Then we can compile-time the check once its tested so that code generates faster
	but validating would still reduce bugs overall.
	Having multiple sources will increase the possibilty of bugs since I will have to make sure that the instructions
	are consistent across the multiple sources.
	*/
	ASM_IR_ID = 0;
	second_instr_index : int = 0;

	/*We can do this with 1 array with AssemblyIR followed by AssemblyIRValue and then just process in sequence.
	This would allow us to remove id and asm_ir_id from both structs which would make things faster.
	I guess asm_ir would still need a count in it though.
	We could do this with 2 arrays and 2 indices so then we just move up the number of values per IR.
	If we remove arrays, then the count could be a u8 or whatever type to make it smaller size.
	*/
	/*TODO Could we put AssemblyIRValue into AssemblyIR like with MusicInstructions?
	I guess one argument against it is what do we do for invalid input with lots of arguments.
	Because we don't really need this anymore for arrays if we only allow 2 values... but maybe we'll
	decide to add more later and then we should keep it.
	*/
	current_asm_irs : [..] AssemblyIR;
	current_asm_irs.allocator = context.allocator;
	current_asm_ir_values : [..] AssemblyIRValue;
	current_asm_ir_values.allocator = context.allocator;

	bracket_stack : [..] BracketAsm;
	bracket_stack.allocator = context.allocator;

	text_index : int = 0; //Second pass index
	while text_index < asm_tokens.count {
		start_index : int = text_index;
		while text_index < asm_tokens.count && asm_tokens[text_index].token_type != #char ";" {
	    	text_index += 1;
		}

		c_tokens : [] LCodeToken = array_view(asm_tokens, start_index, text_index - start_index);
		text_index += 1; // So we don't forget to move to the next lexer token on the next loop iteration.

		//Skip an empty line
		if c_tokens.count == 0 continue;

		//Default instruction type is integer. We could allow a setting which makes this float by default as well.
		instr_type := InstructionType.INTEGER;
		//TODO Could make a function that checks all the if statement conditions here
		//and returns the AssemblyIRType and how many tokens it is or something like that.
		c_index : int = 0;
		while c_index < c_tokens.count {
			if c_tokens[c_index].token_type == CodeTokenType.FIRST_PASS_SKIP {
       		c_index += 1;
	      } else if c_tokens[c_index].token_type == CodeTokenType.IDENT {
				//TODO We could do this in the OpCode lexer if we remove this first pass. Can just check for #asm
				//and then check for op_codes when we're in an asm_directive. Can also do this on the second pass
				//if we remove the first pass if we don't have labels. Only necessarily need first pass if we have labels.
				//This feels a lot cleaner overall though which is why I'm doing it this way.
				defer c_index += 1;

				//TODO Could do this check before this loop and create the OpCode at the beggining,
				//but we are also checking at the bottom when creating OldMusicInstruction so it would be a double check...
				//Leaving here for now in case we decide to allow instructions to start with something else... but
				//i doubt it as all other functionality should be passable from code to asm.
				if c_index == 0 {
					l_string : string = c_tokens[c_index].token_string;
					is_op_code, op_code_index := ArrayFindByValue(op_code_names, l_string);
					if is_op_code {
						CreateAsmIR(.OP_CODE, op_code_index, *current_asm_irs);
						if c_index + 1 < c_tokens.count && c_tokens[c_index+1].token_type == #char "." {
							if c_index + 2 < c_tokens.count {
								if c_tokens[c_index+2].token_string == {
								case "f"; instr_type = InstructionType.FLOAT;
								case "i"; instr_type = InstructionType.INTEGER;
								// case "b"; instr_type = InstructionType.BYTE;
								case;
				   				CreateCompErr(cd, .ASSEMBLY_ERROR, c_tokens[c_index+2],
									sprint("Invalid instruction type %. Use mov.i, mov.f", 
										c_tokens[c_index+2].token_string,,context.allocator));
								}
								c_index += 2;
							} else {
			   				CreateCompErr(cd, .ASSEMBLY_ERROR, c_tokens[c_index+1],
								sprint("Requires instruction type such as mov.i or mov.f", 
									c_tokens[c_index+1].token_type,,context.allocator));
							}
						} 
					} else {
	   				CreateCompErr(cd, .ASSEMBLY_ERROR, c_tokens[0],
						sprint("Invalid op code : %.", c_tokens[0].token_string,,context.allocator));
						break;
					}
				} else {
					l_string : string = c_tokens[c_index].token_string;
					reg_data, is_reg := ArrayFindFirstByNameId(cd.all_registers, l_string, "name");
					label_symbol, found_label_symbol := ArrayFindFirstByNameId(label_symbol_table,
						l_string, "label_string", StringEqual);
					if is_reg {
						CreateAsmIR(.SINGLE_REGISTER, reg_data.reg_index, *current_asm_irs);
					} else if found_label_symbol {
						//TODO Could have an identifier for labels so we don't confuse for outside variables if that's convenient.
						/*Documentation : Label declarations are replaced in the first pass with FIRST_PASS_SKIP.
							Here we store where we need to jump to based on the label_symbol name found.
						*/
						CreateAsmIR(.INT, label_symbol.instr_index, *current_asm_irs);
					} else {
						//Check for variable outside of the asm scope (may allow var declaration in asm scope later)
						var, found_var := FindVariableInNearestScope(l_string, cd.variable_data_stack);
						if found_var {
							//TODO IF the .op is RamMEm then we could also always make it valid
							//Let's try this if we found the var then it is valid and we just use the memory.
							//If it's an array then we convert it to RamArray since we use that type internally.
							valid_asm_var_type : bool = true;
							if var.t_info.type_enum == {
							// case .POINTER; #through;
							// case .FLOAT; #through;
							// case .INTEGER;
							// 	valid_asm_var_type = true;
							case .ARRAY;
								array_info := cast(*TypeInfoArray) var.t_info;
								element_type := array_info.element_type;
								//TODO Shouldn't this be if == to integer or float?
								if element_type.type_enum != .INTEGER || element_type.type_enum != .FLOAT {
									valid_asm_var_type = true;
								} else {
									valid_asm_var_type = false;
								}
							}
							if valid_asm_var_type {
								CreateAsmIR(.ASM_VARIABLE, var.id, *current_asm_irs);
							} else {
			   				CreateCompErr(cd, .ASSEMBLY_ERROR, c_tokens[c_index],
								sprint("Invalid asm variable type: %.", var.t_info.type_enum,,context.allocator));
							}
						} else {
		   				CreateCompErr(cd, .ASSEMBLY_ERROR, c_tokens[c_index],
							sprint("% is not a label, register or variable.", l_string,,context.allocator));
						}
					}
				} 
			}
			else if c_tokens[c_index].token_type == #char "+" {
				defer c_index += 1;
				CreateAsmIR(.ADD, 0, *current_asm_irs);
			} 
			else if c_tokens[c_index].token_type == #char "*" {
				defer c_index += 1;
				CreateAsmIR(.MULTIPLY, 0, *current_asm_irs);
			}
	    	//TODO Could do this in pre-pass with a first_pass skip and set the 
	    	//INT_LITERAL token to be negative which would maybe be more efficient...
			else if c_index + 1 < c_tokens.count &&
				     c_tokens[c_index].token_type == #char "-" &&
				     c_tokens[c_index+1].token_type == CodeTokenType.INTEGER
		   {
		    	//TODO Should we error before we find a dash that is not in front of a constant?
			   defer c_index += 2;
				CreateAsmIR(.INT, -c_tokens[c_index+1].int_value, *current_asm_irs);
			}
			else if c_tokens[c_index].token_type == CodeTokenType.INTEGER {
				defer c_index += 1;				
				CreateAsmIR(.INT, c_tokens[c_index].int_value, *current_asm_irs);
			}
			else if c_index + 1 < c_tokens.count &&
				     c_tokens[c_index].token_type == #char "-" &&
				     c_tokens[c_index+1].token_type == CodeTokenType.FLOAT
		   {
		    	//TODO Should we error before we find a dash that is not in front of a constant?
			   defer c_index += 2;
				CreateAsmIR(.FLOAT, -c_tokens[c_index+1].float_value, *current_asm_irs);
			}
			else if c_tokens[c_index].token_type == CodeTokenType.FLOAT {
				defer c_index += 1;				
				CreateAsmIR(.FLOAT, c_tokens[c_index].float_value, *current_asm_irs);
			}
			else if c_tokens[c_index].token_type == #char "]" {
				defer c_index += 1;
				if bracket_stack.count > 0 {
					bracket_asm : BracketAsm = pop(*bracket_stack);
					memory_asm_ir : *AssemblyIR = *current_asm_irs[bracket_asm.asm_ir_index];
					bracket_token : LCodeToken = c_tokens[bracket_asm.c_index];
					if bracket_token.token_type == #char "[" {
						bracket_index : int = bracket_asm.asm_ir_index + 1;
						asm_ir_in_brackets : [] AssemblyIR = array_view(current_asm_irs, bracket_index, current_asm_irs.count);
						is_valid_memory_access : bool = false;
						//TODO Should we make this into a function for clarity?
						//TODO We could create AssemblyIRValue directly here for each case since we know
						//how many are in each specific case but maybe we will compress even more eventually
						//and not have values at all eventually, especially if we remove arrays.
						// (asm_ir_in_brackets.count == 7 &&
						//    ValidateAssemblyIRTypes(asm_ir_in_brackets,
					   // 			SINGLE_VALUE_TYPE, .[.ADD], SINGLE_VALUE_TYPE, 
					   // 			.[.MULTIPLY], .[.INT], .[.ADD], .[.INT]))
						if asm_ir_in_brackets.count == 1 {
						   is_valid_memory_access = ValidateAssemblyIRTypes(asm_ir_in_brackets,
				   			SINGLE_VALUE_TYPE);
				   	} else if asm_ir_in_brackets.count == 3 {
						   is_valid_memory_access = ValidateAssemblyIRTypes(asm_ir_in_brackets,
				   			SINGLE_VALUE_TYPE, .[.ADD], SINGLE_VALUE_TYPE);
				   	}

				   	if is_valid_memory_access {
				   		//TODO Could make this into a function since we reuse it 3 times
				   		//We skip over commas and operators
				   		for asm_ir_in_brackets if it.asm_ir_type == {
				   			case .INT; #through;
				   			case .SINGLE_REGISTER;
								CreateAsmIRValue(memory_asm_ir.id, it.asm_ir_type, it.int_value, *current_asm_ir_values);
				   		}

							//Store count here so we know how many asm_ir_values to get.
							memory_asm_ir.int_value = asm_ir_in_brackets.count;
							// Remove all asm_irs after MEMORY_MPS between brackets []
							current_asm_irs.count -= asm_ir_in_brackets.count;
							ASM_IR_ID -= asm_ir_in_brackets.count;
				   	} else {
		   				CreateCompErr(cd, .ASSEMBLY_ERROR, c_tokens[c_index],
							"Invalid asm memory. Examples : [0], [ax], [sbp+8], [sbp+bx].");
				   	}
					}
					else {
						//TODO This is checked in the lexer. Will leave here for resilience.
	   				CreateCompErr(cd, .ASSEMBLY_ERROR, c_tokens[c_index],
						sprint("Invalid Opening Bracket : %, should be [\n", bracket_token.token_type,,context.allocator));
					}
				}
				else {
					//TODO This is checked in the lexer. Will leave here for resilience.
   				CreateCompErr(cd, .ASSEMBLY_ERROR, c_tokens[c_index],
					"Missing \"[\" opening bracket.");
				}
			}
			//TODO We could make this check very precise and only check until + and then * and the require 
			//brackets if the next ones are not ints.
			//r1 + r2 * i1 + i2 OR r1 + r2 * (e1) + (e2) where e1 and e2 are more complex constanct expressions
			//This would simplify parsing and only require a tree for the constants which could be computed immediately.
			//Could then also allow constant expressions for integer or float values in asm.
			else if c_tokens[c_index].token_type == #char "[" {
				defer c_index += 1;
				CreateAsmIR(.RAM_MEMORY, 0, *current_asm_irs);

				bracket_asm : *BracketAsm = array_add(*bracket_stack);
				bracket_asm.c_index = c_index;
				bracket_asm.asm_ir_index = current_asm_irs.count-1;
				bracket_asm.asm_ir_value_index = current_asm_ir_values.count;
			}
			else if c_tokens[c_index].token_type == #char ">" {
				defer c_index += 1;
				if bracket_stack.count > 0 {
					bracket_asm : BracketAsm = pop(*bracket_stack);
					memory_asm_ir : *AssemblyIR = *current_asm_irs[bracket_asm.asm_ir_index];
					bracket_token : LCodeToken = c_tokens[bracket_asm.c_index];
					if bracket_token.token_type == #char "<" {
						bracket_index : int = bracket_asm.asm_ir_index + 1;
						asm_ir_in_brackets : [] AssemblyIR = array_view(current_asm_irs, bracket_index, current_asm_irs.count);
						is_valid_music_access : bool = false;
						// number_of_commas : int = 0;
						//TODO These can be all one boolean expression if we keep it like this.
						//TODO could place them all in 1 function for 1 large check with ORs
						//TODO Leaving this here for remember but will likely only use the <x,y> case now.
						// if asm_ir_in_brackets.count == 1 {
						//    is_valid_music_access = ValidateAssemblyIRTypes(asm_ir_in_brackets,
				   	// 		SINGLE_VALUE_TYPE);
				   	// }
						// else if asm_ir_in_brackets.count == 5 &&
						//    ValidateAssemblyIRTypes(asm_ir_in_brackets,
				   	// 		SINGLE_VALUE_TYPE, .[.COMMA], SINGLE_VALUE_TYPE, .[.COMMA], SINGLE_VALUE_TYPE)
				   	// {
				   	// 	//TODO Can remove this case since we only want to allow row_index and mps_index
				   	// 	// where eventually we can say piano.pitch or piano.scale for row
				   	// 	// or just piano for first_row_index in lane
				   	// 	is_valid_music_access = true;
				   	// 	number_of_commas = 2;
				   	// }
						if asm_ir_in_brackets.count == 3 {
						   is_valid_music_access = ValidateAssemblyIRTypes(asm_ir_in_brackets,
				   			SINGLE_VALUE_TYPE, .[.COMMA], .[.INT,.SINGLE_REGISTER,.FLOAT]);
				   		// number_of_commas = 1;
				   	}

				   	if is_valid_music_access {	
				   		//We skip over the middle comma here, we could even be more precise here and
				   		//grab them directly and only allow 2 values or have separate case for 1 and 2.
				   		for asm_ir_in_brackets if it.asm_ir_type == {
				   			case .INT; #through;
				   			case .SINGLE_REGISTER;
									CreateAsmIRValue(memory_asm_ir.id, it.asm_ir_type, it.int_value, *current_asm_ir_values);
								case .FLOAT;
									CreateAsmIRValue(memory_asm_ir.id, it.asm_ir_type, it.float_value, *current_asm_ir_values);
				   		}

							memory_asm_ir.int_value = asm_ir_in_brackets.count;
			   			// assert(ir_values_in_bracket.count == asm_ir_in_brackets.count); //Sanity Check
							// current_asm_ir_values.count -= ir_values_in_bracket.count;
							// Remove all asm_irs after MEMORY_MPS between brackets []
							current_asm_irs.count -= asm_ir_in_brackets.count;
							ASM_IR_ID -= asm_ir_in_brackets.count;
				   	} else {
				   		CreateCompErr(cd, .ASSEMBLY_ERROR, c_tokens[bracket_asm.c_index],
							"Invalid asm music memory. Examples : <0,0>, <ax,1>, <cx,3.14159>, <1,bx>, <ax,bx>.");
				   	}
					} else {
						//TODO This checked in lexer now but can leave here just in case.
	   				CreateCompErr(cd, .ASSEMBLY_ERROR, c_tokens[c_index],
						sprint("Invalid Opening Bracket : %, should be <\n", bracket_token.token_type,,context.allocator));
					}
				}
				else {
					//TODO This is checked in the lexer. Will leave here for resilience.
   				CreateCompErr(cd, .ASSEMBLY_ERROR, c_tokens[c_index],
					"Missing \"<\" opening bracket.");
				}
			}
			else if c_tokens[c_index].token_type == #char "<" {
				defer c_index += 1;
				CreateAsmIR(.MEMORY_MPS, 0, *current_asm_irs);

				bracket_asm : *BracketAsm = array_add(*bracket_stack);
				bracket_asm.c_index = c_index;
				bracket_asm.asm_ir_index = current_asm_irs.count-1;
				bracket_asm.asm_ir_value_index = current_asm_ir_values.count;
			}
			else if c_tokens[c_index].token_type == #char "," {
				//Note: We skip over , so we can place commas between operands for now.
				//If we are in brackets then we add them so we can verify syntax.
				if bracket_stack.count > 0 {
					CreateAsmIR(.COMMA, 0, *current_asm_irs);
					c_index += 1;
				} else {
					c_index += 1;
					//We do nothing so we skip over incrementing ASM_IR_ID
					continue;
				}
			} else {
				//TODO Could have a more robust error if we have some AssemblyIRS
				//eg if we have op_code already, then we could state which operand is invalid
				print("Error at token %\n", c_tokens[c_index]);
	   		CreateCompErr(cd, .ASSEMBLY_ERROR, c_tokens[c_index], "Invalid asm.");
				break;
			}
		}


		//TODO Should we still do this for now or just return on first CompilerError. This way allows us
		//to accumulate multiple errors on 1 line which maybe is better long term
		if cd.comp_errors.all_compiler_errors.count > 0 {
			// print("Invalid asm_ir found on line %.\n", c_tokens[0].line_number);
			return;
		}

		/*Before we were processing these all at once but now we process 1 line at a time.
		If we need to do processing between lines, we can still do it by either pulling this out and
		doing it at the end or by going over the instructions again at the end and seeing what needs to interact.

		The current way however stores far less data because it only stores the current instruction and operands
		as asm_ir and then it creates an instruction and operand immediately after each instruction.
		Overall we would like to keep it like this unless necessary. 
		Remember asm is for linearly sequential instructions and code is for non-linear types of thinking.
		*/
		if current_asm_irs.count > 0 {
			is_valid_instruction : bool = true;
			ci : MusicInstruction = ---;
			op_code_asm_ir : AssemblyIR = current_asm_irs[0];
			if op_code_asm_ir.asm_ir_type == AssemblyIRType.OP_CODE {
				op_code : OpCode = op_code_enums[op_code_asm_ir.int_value];
				ci = MakeMusicInstruction(op_code,t=instr_type);
			} else {
				CreateCompErr(cd, .ASSEMBLY_ERROR, c_tokens[0],
				sprint("Instruction does not start with op_code : %\n", c_tokens[0],,context.allocator));
				break;
			}

			asm_ir_operands : [] AssemblyIR = array_view(current_asm_irs, 1, current_asm_irs.count-1);
			if asm_ir_operands.count > 3 {
				CreateCompErr(cd, .ASSEMBLY_ERROR, c_tokens[0],
				"Asm instructions have <= 3 operands.");
				break; //could also do a return here instead
			}
			for asm_ir_op, op_index : asm_ir_operands {
				c_op : *MusicOperand = *ci.operands[op_index];
				if asm_ir_op.asm_ir_type == {
				case AssemblyIRType.SINGLE_REGISTER; 
					c_op.* = RegMem(cast(RegDef) asm_ir_op.int_value);
				case AssemblyIRType.INT;
					c_op.* = Immediate(asm_ir_op.int_value);
				case AssemblyIRType.FLOAT;
					c_op.* = FImm(asm_ir_op.float_value);
				case AssemblyIRType.MEMORY_MPS; #through;
				case AssemblyIRType.RAM_MEMORY;
					asm_ir_values : [] AssemblyIRValue = ArrayFindAllVarName(current_asm_ir_values, asm_ir_op.id, "asm_ir_id", temp);
					if asm_ir_op.asm_ir_type == {
					case .MEMORY_MPS; c_op.operand_type = .MUSIC_MEMORY;
					case .RAM_MEMORY; c_op.operand_type = .RAM_MEMORY;
					}

					for ir_value, v_index : asm_ir_values {
						c_value : *MusicOperandValue = *c_op.values[v_index];
						if ir_value.asm_ir_value_type == {
						case .SINGLE_REGISTER; 
							c_value.type = .REGISTER;
							c_value.int_value = ir_value.int_value;
						case .INT; 
							c_value.type = .INTEGER;
							c_value.int_value = ir_value.int_value;
						case .FLOAT; 
							c_value.type = .FLOAT;
							c_value.float_value = ir_value.float_value;
						}
					}

					//This should not happen but leaving here as resilience. 
					//Everything is checked above so the actual operand should fail up there and return compiler errors there.
					//We do this in case we still have an error here that we forgot to catch above.
					//So we if we hit this then should update the code above and return the compiler error up there.
					err : CPUError = ValidateMusicOperandTypes(c_op, op_index);
					if err.is_error {
						//TODO Do we really need to print both of these now? Maybe even just returning
						//the error is best and then we can test and output it as well that way.
						print("Invalid operand values for %\n", asm_ir_values[err.error_index]);
						print(err.msg);
						CreateCompErr(cd, .ASSEMBLY_ERROR, c_tokens[0], err.msg);
					}
				case AssemblyIRType.ASM_VARIABLE;
					//TODO FROM HERE write tests for this and then do RamArray but could do RamArray later when needed
					//and then start on op spaces with asm instead.
					var, found_var := ArrayFindFirstByNameId(cd.variable_data_stack, asm_ir_op.int_value, "id");
					assert(found_var);

					//TODO If we have a pointer type then we can add a dereference instruction here
					//so we can grab from memory directly and also set directly at the pointer if we have to set an id for example
					if var.t_info.type_enum == .ARRAY {
						//TODO I think we're supposed to set a RAMArray or at least set the op so we can get it
					} else {
						c_op.* = var.op;
					}
				case;
					CreateCompErr(cd, .ASSEMBLY_ERROR, c_tokens[0],
					"Invalid asm instruction.");
					break;
				}
			}

			//TODO make error more precise here, which exact operand value and then which token is that.
			//There should be 1 to 1 correspondence here between asm_ir and operand_value.
			//TODO We should accumulate or return this error.
			err : CPUError = ValidateMusicInstruction(ci);
			if err.is_error {
				//TODO Do we really need both of these errors now or just 1 is enough?
				//Keeping both for now but when we test assembler errors we can see if we need both
				//or if just printing out the error msg is enough which would be better although
				//having a general index is fine.
				//TODO Should be adding ASSEMBLY_ERROR to all_compiler_errors and maybe some other types as well.
				// print("Invalid operand for %\n", asm_ir_operands[err.error_index]);
				// print(err.msg);
				// is_valid_instruction = false;
				CreateCompErr(cd, .ASSEMBLY_ERROR, c_tokens[0], err.msg);
				//TODO Could keep going and accumulate errors instead.
				break;
			} else {
				//TODO We could have an option that adds to a separate array here in case we just want to use the assembler
				//for something like that watch window editing variable names.
				array_add(*cd.all_music_instructions, ci);

				//TODO Should be a function if we use similar logic elsewhere.
				//TODO This could be optional
				debug_line, already_have_instr_on_line := ArrayFindFirstByNameId(cd.all_debug_lines, 
					c_tokens[0].line_number, "line_number");
				if already_have_instr_on_line {
					debug_line.end_asm_index = cd.all_music_instructions.count-1;
				} else {
					debug_line : *DebugLine = array_add(*cd.all_debug_lines);
					debug_line.line_number = c_tokens[0].line_number;
					debug_line.start_asm_index = cd.all_music_instructions.count-1;
					debug_line.end_asm_index = cd.all_music_instructions.count-1;
					debug_line.absolute_path_name = cd.all_directive_load_files[cd.load_index].absolute_path_name;
				}
			}
		}

		array_reset_keeping_memory(*current_asm_irs);
		array_reset_keeping_memory(*current_asm_ir_values);
	}

	/*TODO
	Eventually it may be a good idea to have a third pass here where we convert certain
	operands into multiple instructions. Eg arrays, expression and memory_units. This way
	we can remove those separate operand types and have a more consistent compilation and
	execution. Then we could remove those types and keep things to the simplest set of rules
	which seems both mathematically and programatically sound. We would also systematize the ability
	to convert some things into simpler asm instructions which may be akin to MACROS or functions
	and we could then use them as such through the language. For example, having a MACRO/function
	inside an expression. With a third pass, we could parse things recursively (iteratively) and so
	we could even nest variables and ensure they are output in proper order in the simpler asm instructions.
	I am waiting to add things like float and natural numbers before to see how that would affect things
	and then making a decision from there if this would be a good idea.
	Another thing to consider in general is what we can do with code later on in any case for creating
	higher level languages and also for processing asm in different ways and also the ability to add
	other instructions, although that would be less necessary if we were able to create MACROS.
	MACROS would then just become part of the system whereby we have an instruction which gets converted
	to multiple other instructions at a specific location. (REMOVE ALL THE OLD MACRO STUFF WHICH IS NOT USED)
	*/
	
	//TODO Could update all ParseError new lines here

	//TODO Leaving this here for now to remember how to STOP_ALL_MUSIC_PTS on recompilation when we implement it
	//with new code recompilation. Overall this should not be in the Assembler at all anymore.
	/*Note : We Stop all music_pts that were playing on compilation since everything gets cleared.
	  TODO We could also pause the audio since all_music_pts gets cleard on recompilation.
	*/
	//TODO But we could change this if compilation would not change anything until running later
	#if 0 {
	if all_data.game_audio_play.play_state == AudioPlayState.PLAY {
		array_add(*all_data.all_audio_events, MakeAudioEvent(.STOP_ALL_MUSIC_PTS));
	}
	}
}


OpValueToString :: inline (op_v : MusicOperandValue) -> string {
	rs : string;
	if op_v.type == {
	case .INTEGER;
		rs = tprint("%", op_v.int_value);	
	case .FLOAT;
		rs = tprint("%", op_v.float_value);
	case .REGISTER;
		reg_index : int = op_v.int_value;
		rs = reg_def_names[reg_index];
	}
	return rs;
}
//TODO Should we make a function that disassembles 1 instruction? Maybe not so that the string is all in 1 place.
/*TODO We could return errors from here as well if we have invalid input but for now we assume this comes from
the compiler and so it should all be valid. Could add assertions maybe but it will just look weird if it's wrong...
OR we do add assertions to help me out.
Instead of returning errors here, I think it is better to just validate the instructions first if needed and then disassemble.
I put some assertions just in case but I feel like the error handling would unecessarily complicate the disassembler code. 

FOR muscall, we should print the MusCallType here instead of an integer. Can implement that for assembly
in here and in the Assembler once we start coding muscalls. This will be easier to tell which muscall is what
just from looking at the disassembly.
*/
Disassembler :: (instrs : [] MusicInstruction) -> string {
 	sb : String_Builder;
 	sb.allocator = context.allocator; //TODO Maybe this should be temp or context.allocator?

	for mi : instrs {
		op_code_s : string = op_code_names[mi.op_code];
		append(*sb, op_code_s);
		if mi.instr_type == {
		case .FLOAT; append(*sb, ".f");
		//TODO We could put .i for integer but will leave empty as default for now.
		}

		append(*sb, " ");

		// print_to_builder(*sb,);
		for operand, op_index : mi.operands {
			if operand.operand_type == {
			case .INTEGER; {
				assert(operand.values[0].type == .INTEGER); //sanity check. can return or remove later
				int_string : string;	
				if mi.op_code == OpCode.muscall && op_index == 0 {
					int_string = muscall_type_names[operand.values[0].int_value];
				} else {
					int_string = tprint("%", operand.values[0].int_value);	
				}
				append(*sb, int_string);
			}
			case .FLOAT; {
				assert(operand.values[0].type == .FLOAT); //sanity check. can return or remove later
				float_string : string = tprint("%", formatFloat(operand.values[0].float_value, zero_removal=.ONE_ZERO_AFTER_DECIMAL));
				append(*sb, float_string);
			}
			case .REGISTER; {
				assert(operand.values[0].type == .REGISTER); //sanity check. can return or remove later
				reg_index : int = operand.values[0].int_value;
				reg_name : string = reg_def_names[reg_index];
				append(*sb, reg_name);
			}
			case .RAM_MEMORY; {
				append(*sb, "[");

				assert(AllOrEquals(operand.values[0].type, .[.REGISTER,.INTEGER])); //sanity check. can return or remove later
				op_v0 : string = OpValueToString(operand.values[0]);
				append(*sb, op_v0);

				if operand.values[1].type != .NONE {
					assert(operand.values[1].type != .FLOAT); //sanity check. can return or remove later
					if operand.values[1].int_value >= 0 {
						append(*sb, "+");
					}
					//NOTE : We already have a "-" if values[1] here is negative from tprint so we just don't put the "+";
					op_v1 : string = OpValueToString(operand.values[1]);
					append(*sb, op_v1);
				}

				append(*sb, "]");
			}
			case .MUSIC_MEMORY; {
				append(*sb, "<");

				assert(AllOrEquals(operand.values[0].type, .[.REGISTER,.INTEGER])); //sanity check. can return or remove later
				op_v0 : string = OpValueToString(operand.values[0]);
				append(*sb, op_v0);

				//TODO I think we want to always have both now. Although assembler still allows 1 but I don't
				//think that would actually work with the cpu execution anymore.
				// if operand.values[1].type != .NONE {
				append(*sb, ",");
				op_v1 : string = OpValueToString(operand.values[1]);
				append(*sb, op_v1);
				// }

				append(*sb, ">");
			}
			//TODO Not sure if we have a syntax for this one yet.
			//We don't but I can just do .[] for now and the type gets decided by the instruction type.
			//This is not implemented in the assembler yet though since we just use array variables.
			//Maybe I can leave it like that but maybe someone wants to use it eventually...
			case .RAM_ARRAY; {
				append(*sb, ".[");

				assert(AllOrEquals(operand.values[0].type, .[.REGISTER,.INTEGER])); //sanity check. can return or remove later
				op_v0 : string = OpValueToString(operand.values[0]);
				append(*sb, op_v0);

				append(*sb, ",");

				assert(AllOrEquals(operand.values[1].type, .[.REGISTER,.INTEGER])); //sanity check. can return or remove later
				op_v1 : string = OpValueToString(operand.values[1]);
				append(*sb, op_v1);

				append(*sb, "]");
			}
			}

			if op_index <= mi.operands.count-2 {
				next : int = op_index+1;
				if mi.operands[next].operand_type == .NONE {
					append(*sb, ";\n");
					break;
				} else {
					append(*sb, ", ");
				}
			} else if op_index == mi.operands.count-1 {
				append(*sb, ";\n");
			}
		}
	}

	return builder_to_string(*sb);
}

//TODO Keeping this test separate so that we can reuse it in Assembler without knowing
//the register count and ram size and row counts.
ValidateMusicOperandTypes :: inline (op : MusicOperand, op_index : int) -> CPUError {
	err : CPUError;
	if #complete op.operand_type == {
	case .NONE;
		err = ValidateOperandValueTypes(op, op_index, .[.[.NONE], .[.NONE]]);
	case .INTEGER;
		err = ValidateOperandValueTypes(op, op_index, .[.[.INTEGER], .[.NONE]]);
	case .FLOAT;
		err = ValidateOperandValueTypes(op, op_index, .[.[.FLOAT], .[.NONE]]);
	case .REGISTER;
		err = ValidateOperandValueTypes(op, op_index, .[.[.REGISTER], .[.NONE]]);
	case .RAM_MEMORY;
		err = ValidateOperandValueTypes(op, op_index, .[.[.REGISTER, .INTEGER], .[.NONE, .REGISTER, .INTEGER]]);
	case .RAM_ARRAY;
		err = ValidateOperandValueTypes(op, op_index, .[.[.REGISTER, .INTEGER], .[.REGISTER, .INTEGER]]);
	case .MUSIC_MEMORY;
		err = ValidateOperandValueTypes(op, op_index, .[.[.REGISTER, .INTEGER], .[.REGISTER, .INTEGER, .FLOAT]]);
	}
	return err;
}

//TODO We could pass in instr_type and then if it's .FLOAT we could check that certain parameters are floats
//but this might depend on per instruction, eg mov has some integers that are mov_size which cannot be floats.
ValidateMusicOperand :: inline (
	op : MusicOperand, op_index : int,
	all_register_memory : [] MemoryValue,
	ram : RAMMemory,
	row_size : int, row_count : int) 
-> CPUError 
{
	err : CPUError;
	//TODO Do we want to do these checks in ValidateMusicOperand or just combine them?
	err = ValidateMusicOperandTypes(op, op_index);
	if err.is_error return err;

	//TODO Should we put this in ValidateOperandValueTypes instead?
	for value, v_index : op.values if value.type == {
	case .REGISTER;
		if value.int_value < 0 || value.int_value >= all_register_memory.count {
			//TODO Should we use a different allocator. Can add the instruction info on 
			//error at the top level for things like instruction index and stack trace.
			//TODO Could make a general MakeOperandError with this starting string. OR Could just pull out string
			//and place that as first element for example "Error operand %" or whatever msg we decide on.
			err.is_error = true;
			err.msg = sprint("Error operand %, value %, invalid reg : %.\n", op_index, v_index, value.int_value,, context.allocator);
			return err;
		}
	}

	//TODO Can also check RAMLocation with mov_size here for some instructions depending on type
	//Or can just check that on the call itself.

	if op.operand_type == {
	case .RAM_MEMORY;
		ram_address : int = ComputeRAMLocation(op, all_register_memory, ram);
		//TODO Can check here if ram_address == 
		bounds_err : CPUError = MemoryInBounds(ram, ram_address);
		if bounds_err.is_error {
			return bounds_err;
			// err.is_error = true;
			// err.msg = sprint("Memory out of bounds : %.\n", ram_address,, context.allocator);
		} else if ram.has_null_address && ram_address == ram.null_address {
			err.is_error = true;
			err.msg = sprint("Null pointer exception on operand %.\n", op_index,, context.allocator);
		}
	case .MUSIC_MEMORY;
		//TODO Should we even allow 1 value music_memory? I guess we can for now but may be worth removing
		//entirey if we only ever use the 2 dimensional version. If we do remove it, then remove the .NONE
		//from here and the case below. I could also remove it and then add it later if needed.
		//TODO Asserting for now so I don't forget 
		//This no longer really works with x float. It does but I think it makes more sense to keep it consistent
		//with always getting row and x. I will leave for now just in case.
		// assert(op.values[1].type != .NONE, "Music memory operand requires 2 values : %\n", op_index);
		// if op.values[1].type == .NONE {
		// 	mem_index : int = MusicMemIndex(op, all_register_memory, row_size);
		// 	if mem_index < 0 || mem_index >= row_size * row_count {
		// 		err.is_error = true;
		// 		err.msg = sprint("Invalid music memory index : %.\n", mem_index,, context.allocator);
		// 	}
		// } else {
			row_index, x_index := MusicMemRowAndXIndex(op, all_register_memory, row_size);
			if x_index < 0 || x_index >= cast(float64) row_size {
				err.is_error = true;
				err.msg = sprint("Invalid music x : %.\n", x_index,, context.allocator);
			} else if row_index < 0 || row_index >= row_count {
				err.is_error = true;
				err.msg = sprint("Invalid music row : %.\n", row_index,, context.allocator);
			}
		// }
	}
	return err;
}

//TODO I think we can remove this one once we have all the validations with the new function.
ValidateOperandTypes :: inline (instr : MusicInstruction, valid_types : .. [] MusicOperandType) -> CPUError {
	return ValidateOperandTypes(instr, valid_types);
}
ValidateOperandTypes :: inline (
	instr : MusicInstruction,
	//TODO Could replace this with [3][] MusicOperandType for some compile-time checking.
	valid_types : [][] MusicOperandType)
-> CPUError
{
	err : CPUError;
	for op, op_index : instr.operands {
		is_valid : bool = AllOrEquals(op.operand_type, valid_types[op_index]);
		if !is_valid {
			err.is_error = true;
			err.error_index = op_index;
			err.msg = sprint("Error : invalid operand % : % - should be one of %.\n",
				op_index, op.operand_type, valid_types[op_index],, context.allocator);
			break;
		}		
	}
	return err;
}

//Switched valid_types so we don't have to put in the runtime assertion.
// assert(valid_types.count == MusicOperand.values.count);
// ValidateOperandValueTypes :: inline (operand : MusicOperand, op_index : int, valid_types: .. [] OperandValueType) -> CPUError {
ValidateOperandValueTypes :: inline (operand : MusicOperand, op_index : int, valid_types: [2][] OperandValueType) -> CPUError {
	err : CPUError;
	for value, v_index : operand.values {
		is_valid : bool = AllOrEquals(value.type, valid_types[v_index]);
		if !is_valid {
			err.is_error = true;
			err.msg = sprint("Error : operand %, invalid values %,% - should be %,%.\n",
				op_index, operand.values[0].type, operand.values[1].type,
				valid_types[0], valid_types[1],, context.allocator);
			break;
		}		
	}
	return err;
}

//TODO Can collapse these once we have RAM_ARRAY everywhere it needs to be
IGNORE :: ALL_OPERANDS_AND_ARRAY; //This is for when it does not matter if we pass something in or not.
ALL_OPERANDS_AND_ARRAY :: MusicOperandType.[.REGISTER, .RAM_MEMORY, .MUSIC_MEMORY, .INTEGER, .FLOAT, .RAM_ARRAY];
ALL_OPERANDS :: MusicOperandType.[.REGISTER, .RAM_MEMORY, .MUSIC_MEMORY, .INTEGER, .FLOAT];
ALL_MEMORY_OPERANDS :: MusicOperandType.[.REGISTER, .RAM_MEMORY, .MUSIC_MEMORY];
ALL_SINGLE_MEMORY_OPERANDS :: MusicOperandType.[.REGISTER, .RAM_MEMORY];
ALL_SINGLE_OPERANDS :: MusicOperandType.[.REGISTER, .RAM_MEMORY, .INTEGER, .FLOAT];
ALL_SINGLE_INT_OPERANDS :: MusicOperandType.[.REGISTER, .RAM_MEMORY, .INTEGER];

AsmInstructionManual :: struct {
	//TODO Can put all info for asm instruction manual in here so we can generate it the same way everywhere
	valid_instr_info : [] AsmValidInstructionInfo;
}
AsmValidOperands :: struct {
	//TODO Technically this can be [3][] MusicOperandType since we only have 3 operands.
	//We are creating at compile-time anyways so it does not really matter.
	//I leave it open for now in case we change the # of operands later which is very unlikely.
	//NOTE : first_array is operand_index and second is valid operand types for that index
	op_valid_types : [][] MusicOperandType;
}
AsmValidInstructionInfo :: struct {
	//TODO Can add valid instruction_type here as well although probably everything can be .f or .i
	//and we will ignore one if it doesn't matter but could still add here if needed.
	instr_valid_types : [] AsmValidOperands;
}
//TODO If we allow people to add their own instructions later, then this would need to be a resizable array
//which gets set at run-time. Then we could validate their instructions internally.
//UNLESS We just let them implement that afterwards in their own function. I guess either way works
//and we can see how we do it when/if we actually do it.
//It might be more worth separating custom from internal since they will likely run and be implemented differently.
//TODO Should we put this in all_data or just leave it as global for convenience?
//We could do this at compile-time for convenience but I had to call it at runtime for now, 
//otherwise I think all the nested arrays/structs stay on the stack by default at compile-time.
//Maybe could test when we update jai version or something but maybe this way is better overall.
//This way does allow us to pass it around if needed and choose where we put it in memory and add things to it at runtime.
ASM_INSTRUCTION_MANUAL : AsmInstructionManual;
GenerateAsmInstructionManual :: () -> AsmInstructionManual {
	aim : AsmInstructionManual;
	aim.valid_instr_info = NewArray(op_code_enums.count, AsmValidInstructionInfo);

	//TODO This should be #complete once we remove all the unused asm instructions.
	//There are only a few left create_circle, map_cs3, map_cs2, map_cs4, map_circle.
	//They are all unused, so remove them once we cleanup and then put #complete here for good measure.
	//free also needs to be added once we implement it. 
	// for op_code_enums if #complete it == {
	for op_code_enums if it == {
	case OpCode.mov; {
		aim.valid_instr_info[it] = .{.[
		//2 op single memory
		.{.[ALL_SINGLE_MEMORY_OPERANDS, 
			ALL_SINGLE_OPERANDS, 
			.[.NONE]]},
		//3 op single memory
		.{.[ALL_SINGLE_MEMORY_OPERANDS, 
			ALL_SINGLE_OPERANDS, 
			.[.INTEGER, .REGISTER]]},
		//2 op music memory
		.{.[.[.MUSIC_MEMORY], 
			ALL_OPERANDS_AND_ARRAY, 
			.[.NONE]]},
		//3 op music memory
		.{.[.[.MUSIC_MEMORY], 
			.[.MUSIC_MEMORY], 
			ALL_SINGLE_OPERANDS]},
		]};
	}
	case OpCode.const_mov; {
		aim.valid_instr_info[it] = .{.[
		.{.[.[.RAM_MEMORY], 
			ALL_SINGLE_INT_OPERANDS, 
			ALL_SINGLE_INT_OPERANDS]}
		]};
	}
	case OpCode.shl; #through;
	case OpCode.shr; #through;
	case OpCode.and; #through;
	case OpCode.xor; #through;
	case OpCode.or; {
		aim.valid_instr_info[it] = .{.[
		//2 op single memory
		.{.[ALL_SINGLE_MEMORY_OPERANDS,
			ALL_SINGLE_OPERANDS,
			.[.NONE]]},
		//3 op single memory
		.{.[ALL_SINGLE_MEMORY_OPERANDS, 
			ALL_SINGLE_OPERANDS, 
			ALL_SINGLE_OPERANDS]},
		//2 op music memory
		.{.[.[.MUSIC_MEMORY],
			ALL_OPERANDS_AND_ARRAY,
			.[.NONE]]},
		//3 op music memory
		.{.[.[.MUSIC_MEMORY], 
			ALL_OPERANDS_AND_ARRAY,
			ALL_OPERANDS_AND_ARRAY]},
		]};
	}
	case OpCode.rol; #through;
	case OpCode.ror; {
		aim.valid_instr_info[it] = .{.[
		//2 op single memory
		.{.[ALL_SINGLE_MEMORY_OPERANDS,
			ALL_SINGLE_OPERANDS,
			.[.NONE]]},
		//3 op single memory
		.{.[ALL_SINGLE_MEMORY_OPERANDS, 
			ALL_SINGLE_OPERANDS, 
			ALL_SINGLE_OPERANDS]},
		//2 op music memory
		.{.[.[.MUSIC_MEMORY],
			ALL_SINGLE_OPERANDS,
			.[.NONE]]},
		//3 op music memory
		.{.[.[.MUSIC_MEMORY], 
			ALL_OPERANDS,
			ALL_OPERANDS]},
		]};
	}
	case .abs; {
		aim.valid_instr_info[it] = .{.[
		.{.[ALL_SINGLE_MEMORY_OPERANDS,
			ALL_SINGLE_OPERANDS,
			.[.NONE]]},
		]};
	}
	case .not; {
		aim.valid_instr_info[it] = .{.[
		//1 op single memory
		.{.[ALL_SINGLE_MEMORY_OPERANDS,
			.[.NONE],
			.[.NONE]]},
		//2 op single memory
		.{.[ALL_SINGLE_MEMORY_OPERANDS,
			ALL_SINGLE_OPERANDS,
			.[.NONE]]},
		]};
	}
	case OpCode.mset; {
		aim.valid_instr_info[it] = .{.[
		.{.[.[.RAM_MEMORY],
			ALL_SINGLE_INT_OPERANDS,
			ALL_SINGLE_INT_OPERANDS]},
		]};
	}
	case OpCode.clear; {
		aim.valid_instr_info[it] = .{.[
		.{.[.[.MUSIC_MEMORY]]},
		]};
	}
	case OpCode.mspace_clear; {
		aim.valid_instr_info[it] = .{.[
		.{.[.[.NONE], 
			.[.NONE],
			.[.NONE]]},
		]};
	}
	case OpCode.mod; #through;
	case OpCode.div; #through;
	case OpCode.mul; #through;
	case OpCode.sub; #through;
	case OpCode.add; {
		aim.valid_instr_info[it] = .{.[
		//2 op single memory
		.{.[ALL_SINGLE_MEMORY_OPERANDS,
			ALL_SINGLE_OPERANDS,
			.[.NONE]]},
		//3 op single memory
		.{.[ALL_SINGLE_MEMORY_OPERANDS, 
			ALL_SINGLE_OPERANDS, 
			ALL_SINGLE_OPERANDS]},
		//2 op music memory
		.{.[.[.MUSIC_MEMORY],
			ALL_OPERANDS,
			.[.NONE]]},
		//3 op music memory
		.{.[.[.MUSIC_MEMORY], 
			ALL_OPERANDS,
			ALL_OPERANDS]},
		]};
		//TODO Could allow memory mps to memory mps here so we can have 
		//non-commutative operations like - and /
	}
	case OpCode.split; {
		//TODO VALIDAITON NOT DONE FOR SPLIT
		#if 0 {
		//TODO Maybe we should separate these into 2 instructions?
		err = ValidateOperandTypes(instr,
			.[.MUSIC_MEMORY],
			.[.SINGLE_REGISTER, .INT, .ARRAY]);
		if !err.is_error return err;

		err = ValidateOperandTypes(instr,
			.[.SINGLE_REGISTER],
			.[.MUSIC_MEMORY, .ARRAY]);
		if !err.is_error return err;
		}
	}
	case OpCode.dim; {
		//TODO ADD VALIDATION WHEN WE IMPLEMENT PROPERLY
		#if 0 {
		err = ValidateOperandTypes(operands,
			.[.SINGLE_REGISTER],
			.[.MUSIC_MEMORY]);
		if err.is_error return err;
		}
	}
	case OpCode.tmov; {
		aim.valid_instr_info[it] = .{.[
		.{.[.[.RAM_MEMORY], 
			.[.RAM_MEMORY,.RAM_ARRAY,.REGISTER,.INTEGER,.FLOAT], 
			.[.NONE, .INTEGER]]},
		//array = tano
		.{.[.[.RAM_ARRAY], 
			.[.RAM_MEMORY], 
			//Parameter used to specify return array address and type and any other info needed
			.[.RAM_MEMORY]]},
		]};
	}
	case OpCode.tclear; {
		aim.valid_instr_info[it] = .{.[
		.{.[.[.NONE, .INTEGER, .REGISTER, .RAM_MEMORY], 
			.[.NONE, .REGISTER],
			.[.NONE]]},
		]};
	}
	case OpCode.tmod; #through;
	case OpCode.tdiv; #through;
	case OpCode.tmul; #through;
	case OpCode.tsub; #through;
	case OpCode.tadd; {
		aim.valid_instr_info[it] = .{.[
		//2 op single memory
		.{.[.[.RAM_MEMORY],
			.[.REGISTER,.INTEGER,.FLOAT], 
			.[.NONE]]},
		.{.[.[.REGISTER,.INTEGER,.FLOAT], 
			.[.RAM_MEMORY],
			.[.NONE]]},
		//3 op single memory
		.{.[.[.RAM_MEMORY],
			.[.RAM_MEMORY], 
			.[.REGISTER,.INTEGER,.FLOAT]]},
		.{.[.[.RAM_MEMORY],
			.[.REGISTER,.INTEGER,.FLOAT], 
			.[.RAM_MEMORY]]},
		]};
	}
	case OpCode.trol; #through;
	case OpCode.tror; #through;
	case OpCode.tshl; #through;
	case OpCode.tshr; {
		aim.valid_instr_info[it] = .{.[
		//2 op single memory
		.{.[.[.RAM_MEMORY],
			.[.RAM_MEMORY, .REGISTER,.INTEGER,.FLOAT], 
			.[.NONE]]},
		]};
	}
	case OpCode.cgt;  #through;
	case OpCode.clt;  #through;
	case OpCode.cgte; #through;
	case OpCode.clte; #through;
	case OpCode.cneq; #through;
	case OpCode.ceq; {
		aim.valid_instr_info[it] = .{.[
		//2 op single memory
		.{.[ALL_SINGLE_MEMORY_OPERANDS,
			ALL_SINGLE_OPERANDS,
			.[.NONE]]},
		//3 op single memory
		.{.[ALL_SINGLE_MEMORY_OPERANDS,
			ALL_SINGLE_OPERANDS,
			ALL_SINGLE_OPERANDS]},
		]};
		//TODO Should we add default music memory comparisons?
	}
	case OpCode.push; {
		aim.valid_instr_info[it] = .{.[
		//1 op single memory
		.{.[ALL_SINGLE_OPERANDS,
			.[.NONE],
			.[.NONE]]},
		//2 op single memory
		.{.[ALL_SINGLE_OPERANDS,
			ALL_SINGLE_INT_OPERANDS,
			.[.NONE]]},
		]};
	}
	case OpCode.pop; {
		aim.valid_instr_info[it] = .{.[
		//1 op single memory
		.{.[ALL_SINGLE_MEMORY_OPERANDS,
			.[.NONE],
			.[.NONE]]},
		//2 op single memory
		.{.[ALL_SINGLE_MEMORY_OPERANDS,
			ALL_SINGLE_OPERANDS,
			.[.NONE]]},
		]};
	}
	case OpCode.tjmp; #through;
	case OpCode.fjmp; {
		aim.valid_instr_info[it] = .{.[
		//TODO Do we need the 2 op case, it assumes that we are jumping to .cr comparison register.
		//Can likely remove this and would need to update the instruction code as well.
		//2 op single memory
		.{.[ALL_SINGLE_INT_OPERANDS,
			ALL_SINGLE_INT_OPERANDS,
			.[.NONE]]},
		//3 op single memory
		.{.[ALL_SINGLE_INT_OPERANDS,
			ALL_SINGLE_INT_OPERANDS,
			ALL_SINGLE_INT_OPERANDS]},
		]};	
	}
	case OpCode.call; #through;
	case OpCode.jmp; {
		aim.valid_instr_info[it] = .{.[
		//1 op single memory
		.{.[ALL_SINGLE_INT_OPERANDS,
			.[.NONE],
			.[.NONE]]},
		]};
	}
	case OpCode.itof; #through;
	case OpCode.ftoi; {
		aim.valid_instr_info[it] = .{.[
		//2 op single memory
		.{.[ALL_SINGLE_MEMORY_OPERANDS,
			ALL_SINGLE_OPERANDS,
			.[.NONE]]},
		]};
	}
	case OpCode.s_print; {
		aim.valid_instr_info[it] = .{.[
		.{.[.[.RAM_MEMORY],
			.[.RAM_MEMORY],
			.[.RAM_MEMORY]]},
		]};
	}
	//TODO .tune and .mlen can be replace with .muscall altogether
	case OpCode.tune; #through;
	case OpCode.mlen; #through;
	case OpCode.muscall; {
		aim.valid_instr_info[it] = .{.[
		.{.[ALL_SINGLE_INT_OPERANDS,
			.[.NONE,.RAM_MEMORY],
			.[.NONE]]},
		]};
	}
	case OpCode.create_custom_geometry; #through;
	case OpCode.create_shape; #through;
	case OpCode.delete_shape; #through;
	case OpCode.create_text; #through;
	case OpCode.create_custom_3D; #through;
	case OpCode.create_shape_3D; #through;
	case OpCode.create_text_3D; #through;
	case OpCode.create_cs3; #through;
	case OpCode.map_cs3; #through;
	case OpCode.create_cs2; #through;
	case OpCode.map_cs2; #through;
	case OpCode.create_circle; #through;
	case OpCode.map_circle; #through;
	case OpCode.create_spiral; #through;
	case OpCode.map_spiral; #through;
	case OpCode.get_tuning_system; #through;
	case OpCode.create_tuning_system; #through;
	case OpCode.reset_default_tuning_systems; #through;
	case OpCode.get_or_create_simple_synth; #through;
	case OpCode.update_simple_synth; #through;
	case OpCode.delete_simple_synth; #through;
	case OpCode.create_row; #through;
	case OpCode.get_or_create_mspace; #through;
	case OpCode.update_mspace; #through;
	case OpCode.delete_mspace; #through;
	case OpCode.clear_mspace; #through;
	case OpCode.get_or_create_op_space; #through;
	case OpCode.clear_op_space; #through;
	case OpCode.setup_music; {
		aim.valid_instr_info[it] = .{.[
		.{.[.[.RAM_MEMORY],
			.[.NONE],
			.[.NONE]]},
		]};
	}
	//TODO Add free validation when we implement it
	// case OpCode.free;
	case OpCode.alloc; {
		aim.valid_instr_info[it] = .{.[
		.{.[ALL_SINGLE_INT_OPERANDS, 
			.[.REGISTER, .RAM_MEMORY, .NONE],
			.[.NONE]]},
		]};
	}
	case OpCode.push_all_stack_reg; #through;
	case OpCode.pop_all_stack_reg; {
		aim.valid_instr_info[it] = .{.[
		.{.[.[.NONE, .REGISTER, .RAM_MEMORY, .INTEGER],
			.[.NONE],
			.[.NONE]]},
		]};		
	}
	//TODO Should this be the default case?
	//Maybe not so it forces me to write down the validation for each instruction manually.
	case OpCode.delete_all_synths; #through;
	case OpCode.ret; #through;
	case OpCode.exit; #through;
	case OpCode.HALT; {
		aim.valid_instr_info[it] = .{.[
		.{.[.[.NONE],
			.[.NONE],
			.[.NONE]]},
		]};
	}
	}

	return aim;
}

/*TODO Need to finish the validation here for each instruction properly.
TODO We could split these up to validate based on # of operands, 1, 2, and 3
like we have with CreateMInstr and then it would be much clearer what failed for example.

The nice thing about this way is that we have it all in 1 place.

TODO HAVE TO REDO THIS A BIT BECAUSE THE ERRORS BEING RETURN ARE NOT ALWAYS RIGHT.
NEED TO CHECK IF IT IS IN FACT VALID MAYBE BASED ON OPERAND_0 and then return a correct error message
with all possible calls based on that instruction and operand combination.

TODO Need to pull out each array so we an reuse for user checking and maybe external files.
This will be all possible uses of the instructions in one place and then we just validate here
and if it does not hit any of the validations then we return a generic error with that op_code
and where to find the instructions (command to open file or something like that);
*/
//TODO Could pass in the AsmInstructionManual here and then we would store it in all data.
//But it won't change from one run to another so I guess may as well leave it global for now.
ValidateMusicInstruction :: inline (instr : MusicInstruction) -> CPUError {
	//TODO Could add float validation to check by InstructionType now.
	vii := ASM_INSTRUCTION_MANUAL.valid_instr_info[instr.op_code];
	for vii.instr_valid_types {
		err := ValidateOperandTypes(instr, it.op_valid_types);
		//We found one without error, so it is valid and we return it so this error is not an error.
		if !err.is_error return err;
	}

	//TODO Could generate that file string internally the AsmInstructionManual.
	//Could also generate a system file in a formatted way to use externally for all instructions.
	return CPUErr(
	sprint("Invalid % instruction. 'open asm_manual' to view valid asm instructions.", 
		instr.op_code,,context.allocator));
}

/*END OF ASSEMBLY
*/


/*Instruction Execution

TODO CAN MOVE IN MusicInstructon and othere data formats and also SetRAM functions since that is all part of 
the instruction execution code now in here.
https://en.wikipedia.org/wiki/Von_Neumann_architecture
*/
CPUState :: struct {
	comparison_register : bool;
	//TODO This should be replace with cip and nip 
	//(current and next instruction pointer)
	//once we implement the jmp instructions again.
	instr_increment : int;
	instr_index : int;
}

BreakpointType :: enum u8 {
	BP_CODE;
	BP_ASM;
}
DebugBreakpoint :: struct {
	//TODO Should we just use DebugLine here instead to more easily copy it over?
	//NOTE : BP_ASM ignores the line_number altogether
	line_number : int;
	//TODO Should we rename to start_asm_index or just reuse DebugLine?
	asm_index : int;
	end_asm_index : int;
	bp_type : BreakpointType;
}
DebugControl :: enum u8 {
	//TODO We could add this if needed, maybe could use for reset_watch_data
	//but right now it would be the same as running first time while NOT_RUNNING
	// START_DEBUGGING;
	CONTINUE;
	STEP_OVER;
	ASM_STEP_OVER;
	ASM_STEP_INTO;
	STEP_INTO;
	STEP_OUT;
	//TODO Could add pause if we need it
	// PAUSE;

	//These are added with TEXT_STOP and TEXT_RESTART
	// STOP_DEBUGGING;
	// RESTART;
}
//TODO Eventually comp_data will likely be stored within the text op space data.
//Could also possibly just pass in breakpoints array
PressCodeBreakpoint :: inline (line_number : int, text_op : *TextOpSpaceData, comp_data : *CompilationData) {
	//TODO We could pull this out as function and test it for convenience and also
	//then we can use it to set break_points from other places like tests or somewhere else in the code

	/*NOTE : It's ok to set a BP_CODE even if we have a BP_ASM because the BP_CODE is a range
	so it can stop anywhere in that range like with for array start loop code.
	BP_ASM is at a specific asm index so it does not interfere in any case.
	For convenience we render the BP_CODE for both asm and code panes but ultimately
	seeing code from asm to code or code to asm can have a separate action so we can see the ranges as well.
	*/
	found_breakpoint : bool = false;
	for text_op.exec_info.debug_info.break_points {
		if it.bp_type == .BP_CODE && it.line_number == line_number {
			//TODO Do a memcpy remove here once we implement it in general.
			array_ordered_remove_by_index(*text_op.exec_info.debug_info.break_points, it_index);
			found_breakpoint = true;
			break;
		}
	}

	if !found_breakpoint {
		//NOTE : We set a breakpoint in the editor no matter what. If we don't have asm_index
		//then this is set to -1 and should never get hit since we check asm_index in execution. 
		//NEED TO TEST THIS.
		//IF we have a line that has no asm_index (no debug_line), then we wont find it in all_debug_lines
		//and so it will still be -1.
		//TODO We can render this with the "?" or a different color like in remedy
		//Probably different color like grey is best, like a disabled breakpoint or maybe different color.
		//TODO We want to associate this to op_space data once we have that. for now it's just the default allocator.
		break_point : *DebugBreakpoint = array_add(*text_op.exec_info.debug_info.break_points);
		break_point.bp_type = BreakpointType.BP_CODE;
		break_point.line_number = line_number;
		break_point.asm_index = -1;
		break_point.end_asm_index = -1;
		//TODO Grab this instead once we have multiple compilation data possible
		if comp_data != null && comp_data.all_debug_lines.count > 0 {
			for comp_data.all_debug_lines {
				//TODO Could set this to >= so we take the next line that is available for debugging
				if it.line_number == break_point.line_number {
					break_point.asm_index = it.start_asm_index;
					break_point.end_asm_index = it.end_asm_index;
					break;
				}
			}
		}
	}
}
PressAsmBreakpoint :: inline (
	asm_break_index : int,	
	text_op : *TextOpSpaceData) 
{
	found_breakpoint : bool = false;
	for text_op.exec_info.debug_info.break_points {
		if it.asm_index == asm_break_index {
			//TODO Do a memcpy remove here once we implement it in general.
			array_ordered_remove_by_index(*text_op.exec_info.debug_info.break_points, it_index);
			found_breakpoint = true;
			break;
		}
	}

	if !found_breakpoint {
		//TODO We could make this CreateAsmBreakpoint to keep it consistent everywhere
		//and then also PressAsmBreakpoint so we remove it if there is already one there.
		//Then we could unit test that function as well.
		break_point : *DebugBreakpoint = array_add(*text_op.exec_info.debug_info.break_points);
		break_point.bp_type = BreakpointType.BP_ASM;
		break_point.asm_index = asm_break_index;
		break_point.end_asm_index = asm_break_index;
		//TODO We don't need to set line_number for BP_ASM anymore
		//TODO Choose the comp_data instead once we have multiple compilation data possible
		// if perm.all_data.comp_data != null && perm.all_data.comp_data.all_debug_lines.count > 0 {
		// 	debug_line := GetDebugLineAsm(text_op.highlighted_disasm_index, perm.all_data.comp_data);
		// 	break_point.line_number = debug_line.line_number;
		// }
	}
}
//TODO Should this be called DebugStackFrame?
DebugCallFrame :: struct {
	call_instr_index : int;
	//TODO Do we need this or just use it from the array since 
	//we will always have the function scope in there anyways.
	//NOTE I think we don't store the function_scope in all_scopes_in_function anymore
	// function_id : int;
	//TODO I am storing both of these here now for convenience,
	//but eventually we can just store the specific data that we need
	//like name and start/end_instr and function type.
	//Can make a separate struct and set the data in CreateDebugCallFrame
	// function_data : CallFrameFunctionData;
	function_scope : ScopeData;
	func_decl : FunctionDeclaration;

	//DOCU : Which scope we are at within all_scopes_in_function
	//which should be sequential since all_scope_data should be
	//sorted by function_id and start_instr_index
	s_index : int;
	all_scopes_in_function : [] ScopeData;

	//This should part of an allocator that we clear when not debugging/excuting
	//TODO These could be pointers to use less memory since Scopes will be fixed
	//after compilation.
	//TODO Should we make a StackPool and use it here
	//TODO Rename to open_scopes_in_function
	call_open_scopes : [..] ScopeData;

	//This keeps track of all the available variables currently in the call
	//based on the scope.
	frame_vars : [..] VariableData;
	stored_frame_registers : [] MemoryValue;
}

//TODO UTEST could write unit tests for this specific function once we know it is what we need to use.
CreateDebugCallFrame :: inline (
	func_start_index : int,
	exec_info : *ExecutionInfo,
	//NOTE : We are keeping this separate so maybe it is easier when we have multiple compilations later
	cd : *CompilationData,
	ad : *AllData)
{
	found_function_scope : bool = false;
	start_index : int;
	c_frame : *DebugCallFrame;
	for cd.all_scope_data {
		if it.start_instr_index == func_start_index && it.scope_type == .FUNCTION_SCOPE {
			found_function_scope = true;
			start_index = it_index;

			if exec_info.debug_info.debug_call_stack.count == exec_info.debug_info.c_frame_pool_count {
				//TODO Need to set the allocator for this to a generalized debug/execution allocator
				c_frame = array_add(*exec_info.debug_info.debug_call_stack);
				exec_info.debug_info.c_frame_pool_count += 1;
				//NOTE : Because we reuse the call frame, then we just create this once and reuse it 
				c_frame.stored_frame_registers = NewArray(ad.all_register_memory.count, MemoryValue, false);
			}
			else if exec_info.debug_info.debug_call_stack.count < exec_info.debug_info.c_frame_pool_count {
				exec_info.debug_info.debug_call_stack.count += 1;
				c_frame = peek_pointer(exec_info.debug_info.debug_call_stack);
			}
			else {
				assert(false, "c_frame_pool_count cannot be < debug_call_stack.count");
			}			
			c_frame.function_scope = it;
			//DOCUM : We reset the call frame here so we don't forget whenever we grab a new one
			//since the pool is stored in the same array as the actual call frames.
			c_frame.s_index = 0;
			array_reset_keeping_memory(*c_frame.call_open_scopes);
			array_reset_keeping_memory(*c_frame.frame_vars);
			//Set this to 0 just in case so things are not confusing when debugging.
			memset(c_frame.stored_frame_registers.data, 0, c_frame.stored_frame_registers.count * size_of(MemoryValue));

			//tODO I think maybe we don't need this and can just use the first scope since we always have 1 scope on a call frame
			// c_frame.function_id = it.function_id;
			// array_add(*c_frame.call_open_scopes, it);

			//TODO We set the whole FunctionDeclaration in here now but eventually we can just set the specific data
			//we need from here and function_scope to reduce call_frame memory.
			func_decl, found_func_decl := ArrayFindFirstByNameId(cd.all_function_declarations,
				c_frame.function_scope.function_id, "id");
			assert(found_func_decl);
			c_frame.func_decl = func_decl;

			break;
		}
	}
	//sanity check in case we don't have a function here which we should
	assert(found_function_scope, "no function found at instr %", func_start_index);

	//We start after the function_scope since we store that separately.
	//TODO if we include the function scope in call_open_scopes, then we would not + 1 here
	start_index += 1;
	end_index : int = start_index;
	while end_index < cd.all_scope_data.count &&
			cd.all_scope_data[end_index].function_id == c_frame.function_scope.function_id
	{
		end_index += 1;
	}
	scope_count : int = end_index - start_index;
	c_frame.all_scopes_in_function = array_view(cd.all_scope_data, start_index, scope_count);

	//DOCUM : We won't remove these variables, so we just add them here
	//and then reset them whenever we reust this call frame.
	for cd.all_variables if it.scope_id == c_frame.function_scope.id {
		array_add(*c_frame.frame_vars, it);
	}
}
HasCallInstrInRange :: inline (start_instr : int, end_instr : int, ami : [] MusicInstruction) -> bool {
	for start_instr..end_instr if ami[it].op_code == OpCode.call {
		return true;
	}
	return false;
}

//TODO Rename to DebuggerInfo and then CodeDebugData for code/asm data
DebugInfo :: struct {
	//TODO Maybe rename to code_stop_line for clarity from disasm
	//TODO Should we make this start_asm_index and get line from debug_line?
	//They are interchangeable so maybe it doesn't matter but how does that relate to asm debug point?
	//If so we could just put a breakpoint object here and set them
	//so if we hit a breakpoint we just copy it over directly.
	//CURRENTLY USE ip register to get that actually.
	//Maybe that is better in general and we can just remove this
	//REMOVED lets see how it works, can make GetDebugLineAsm more efficient
	//search alter which should remove complexity from this anyways.
	//Probably SoA with SIMD would be good here.
	// stop_line : int; 
	//TODO We could store both in here as current_hit_break_point
	//TODO We could store this somewhere if we have multiple debuggers open for example
	//OR maybe in this case an array is best for each text_op_space open and then just have
	//this as part of an allocator for the op_space and then free that allocator when we delete the op_space.
	break_points : [..] DebugBreakpoint;
	debug_control : DebugControl;

	//TODO This should be part of an allocator that we clear on execution.
	//TODO WE COULD REUSE call_frames since that will happen often
	//but then clear an entire allocator when we stop debugging.
	//We could also just use this as the pool directly and store
	//everything in here although maybe a pool makes more sense conceptually
	//and we just have a debug_alloc that gets cleared after debugging anyways.
	//THIS IS USING debug_call_stack as the pool directly.
	//TODO We can use a debug_call_frame_pool if this is too confusing
	//like we did with watch_data_rows. But this one is actually a stack so
	//it might be ok
	c_frame_pool_count : int;
	debug_call_stack : [..] DebugCallFrame;
	chose_other_call_frame : bool;
	/*DOC : This correspond directly to the debug_call_stack
	so we have to do debug_call_stack.count - 1- selected_call_frame_index
	to get the right rendering. 
	highlighted_call_stack_index is ui specific so we don't have to subtract
	*/
	selected_call_frame_index : int;
	debug_all_registers : [] MemoryValue;
	// call_stack_pool : [..] DebugCallFrame;
	//TODO We can store the call frames in here and anything else
	//we need while debugging and then clear it when we finish.
	//Could also use this for execution in general.
	//This would only need to account for the size of the call stack
	//although variable size could be larger
	// debug_pool : Flat_Pool;
	// debug_alloc : Allocator;

	//TODO We should put compilation in here for debugging which makes sense
	//since the debugger needs the *CompilationData to function.
	// comp_data : *CompilationData;

	//TODO I don't think we need this since we can just get it from ip register
	// disasm_stop_index : int;
	// disasm_breakpoints : [..] AsmBreakpoint;
}
//TODO Maybe rename this to TextOpMode or something and replace RUN with JUST_TEXT_EDITING
ExecutionMode :: enum u8 {
	RUN;
	DEBUG;
}
ExecutionState :: enum u8 {
	NOT_RUNNING;
	IS_EXEC_RUNNING;
	IS_DEBUG_STOP;
}
//TODO This should be separate like an exe. The DebugInfo would store file data if this was associated to
//some text files but we should be able to have execution info that does not require text files so we can
//just run some code easily, for example if some action creates some instructions that are run without any compile code.
ExecutionInfo :: struct {
	exec_state : ExecutionState;
	//TODO Maybe this can just be a separate ui thing...
	//It makes sense to have ui and this be the same though
	//since we should only do debug things while debugging
	exec_mode : ExecutionMode;
	//TODO We could probably separate this out eventually since execution
	//doesn't need it and we can just fetch it if we are in debug mode
	//Or also just store an id in here since we would only need it while it's running probably.
	debug_info : DebugInfo;
	//TODO Rename to exe_start_instr_index since this should be code independent
	main_instr_index : int;
	//TODO Could set here what exactly we want to execute OR
	//We could pass this ExecutionInfo into ExecuteManyInstructions
	// all_instructions : [..] MusicInstruction;
	//TODO Can also store what ram memory we are using here
	
	instructions_run_this_frame : int;
	continue_execution_next_frame : bool;
}
DebugStep :: struct {
	in_breakpoint_bounds_and_continue : bool;
	step_control : DebugControl;

	//TODO Should we rename these to start_bound_index and end_bound_index
	start_asm_index : int;
	end_asm_index : int;
	// start_function_index : int;
	// end_function_index : int;

	call_stack_count : int;
	//TODO Could use function_index instead but I think I prefer this for now.
	//TODO Can remove these if we just use call_stack_count now.
	has_call_instr : bool;
	call_index : int;
}

//TODO Could pass in a struct that has all the file info and stuff like that instead of just executing instructions.
//Or we just pass in instructions like this and then the instruction counter will tell us where to start.
HALT_INSTRUCTION :: MusicInstruction.{op_code=OpCode.HALT};
EndedExecution :: inline (mi : MusicInstruction) -> bool {
	if mi.op_code == .HALT || mi.op_code == .exit {
		return true;
	}
	return false;
}
//TODO Should we update *ExecutionInfo or have it return ExecutionInfo instead to be updated after...
//We could just return the stop_line_number as well or some info like that if that makes more sense than this.
//TODO Instead of passing in *ExecutionInfo, likely better to pass in an id and then fetch it in here
//so we can use it and update however we need.
//TODO ExecutionInfo should specify if we are using default music instructions or grabbing them from compilation.
//I think it's better to do that than to pass in an array of instructions. It is more general and if we add
//editable asm instructions later, then we would need the array so we could add/remove/update instructions with a specific asm instr.
/*LIKELY This will run async eventually so we don't freeze and also can have code running in a loop that way.
Then we have to pass in AllCodeData instead of AllData so we can have multiple code running at once.
*/
//TODO Need to pass in AllCodeData instead of AllData here.
ExecuteManyInstructions :: inline (exec : *ExecutionInfo, ad : *AllData) -> CPUError {
	assert(exec != null && ad != null);

	//TODO Use this from ad.comp_data now since we just use that.
	//OR WE COULD set this instructions in exec_info and do text and compilation stuff externally
	//IT would have to be a resizable array in any case so we can add this and so we can edit/add/remove instrs later
	//Then we can keep all_music_instructions for default loading and still set that as the default externally
	array_add(*ad.all_music_instructions, HALT_INSTRUCTION);
	//TODO Will likely need to fetch this from instruction pointer as the starting address.
	//Then can we move this into the loop?
	//ACTUALLY if .IS_DEBUG_STOP we already have this so we don't need to set it
	//BUT IF NOT_RUNNING then we would need to set this where we are starting.
	if exec.exec_state == .NOT_RUNNING {
		//TODO UTEST Maybe we should pull some of this out and only run it if we are running from a text_op
		//We would have to reset memory every time but otherwise everything else is dependent on running from a debugger.
		if exec.exec_mode == .DEBUG {
			//NOTE : Should reset all debug info in here. This way we keep the info if we hit an error.
			//MAYBE we can turn this into a function and also debugging could have it's own allocator while running.
			exec.debug_info.c_frame_pool_count = 0;
			array_reset_keeping_memory(*exec.debug_info.debug_call_stack);
			exec.debug_info.debug_all_registers = ad.all_register_memory;

			//TODO Could write a unit test to check this error.
			func_decl, found_main_func := ArrayFindFirstByAndOp(ad.comp_data.all_function_declarations, 
				"main", "name",
				exec.main_instr_index, "start_instr_index");
			//TODO This should be checked by the compiler. We could store this in the comp_data directly for easier fetching.
			//Just in case we do a double check here because we cannot debug without a main function anyways.
			//This is a case of resilience since this function could be called with code that was not compiled by our compiler 
			//eventually and this prevents that from ever happening.
			if !found_main_func return CPUErr(sprint("No main function found.\n"));

			//TODO We should be adding all the variables in the global scope here
			CreateDebugCallFrame(exec.main_instr_index, exec, ad.comp_data, ad);
		}
		//TODO Eventually we would just take an available memory pool I think once we have memory per execution.
		//Now we only have 1 so we reset it but once we can execute multiple code, then we would have multiple memorys
		//and we can reuse those whenever we run something new.
		ResetCodeMemory(ad);
		exec.exec_state = .IS_EXEC_RUNNING;
		//TODO Rename main_instr_index to exec_start_instr_index
		ad.all_register_memory[RegDef.pc].int_value = exec.main_instr_index;
	}
	//TODO Should make sure ip is in all_music_instructions. We could either not allow updating of the ip
	//address OR check to make sure ip address is in bounds.
	//COULD CHECK THAT IP is in bounds after every ExecMInstr and then return CPUError otherwise.
	// ci : MusicInstruction = ad.all_music_instructions[ad.all_register_memory[RegDef.pc].int_value];
	
	//TODO Could check an end_instr_index here in case we want to only run a ceratin number of instructions
	//at once, for instance per frame to avoid it taking too much time.
	//TODO Maybe we should run the HALT and return an exit error message instead
	//TODO Maybe we should have a .exit instruction and a .HALT where the exit is set at the end of main
	//and HALT is at the end of instructions to prevent going over the end and can be checked here.

	//TODO FROM HERE should we test some scopes here in different cases first (EG FOR, WHILE, IF AND ELSE)?
	//Maybe write 1 simple unit test for scopes for each type in general and then also a unit test
	//to make sure that scopes are working with the debugger.
	//check if we are in a new scope every new instruction and add to a stack if we are.
	//Then also add the variables so we know which scopes are available.
	//Then if we move out of a scope, we can remove that scope and close those variables.
	//This will be a stack in general for control scopes. 
	//For function scopes when we hit a .call instr, we add to the call stack and do the same thing
	//and probably start a new stack. So each call stack which have it's own stack for control scopes
	//and then we would have a DebugCall object which would have a stack for control scopes and what function were in.
	//TODO Should we write some new tests to check if the new CPU running is working or is that enough?
	err : CPUError;
	stop_execution : bool = false;
	//NOTE : This is for debugging step_over
	d_step : DebugStep;
	exec.continue_execution_next_frame = false;
	exec.instructions_run_this_frame = 0;
	while exec_loop := true {
		//TODO UTEST Could write unit tests to check this error.
		//IF next instruction index (pc reg) is out of bounds then we return an error.
		if ad.all_register_memory[RegDef.pc].int_value < 0 ||
			ad.all_register_memory[RegDef.pc].int_value >= ad.all_music_instructions.count
		{
			stop_execution = true;
			err = CPUErr(sprint("pc reg % out of bounds (0,%).\n", 
				ad.all_register_memory[RegDef.pc].int_value, ad.all_music_instructions.count-1,,context.allocator));
			break exec_loop;
		}

		//TODO should we make a separate debug function or is it better here in general?
		//Then we would not need to make this check every loop when just running the code.
		//TODO Maybe we could just pull this out into a ExecDebug function to clean up th CPU execution code.
		if exec.exec_mode == ExecutionMode.DEBUG {
			if exec.exec_state == .IS_DEBUG_STOP {
				exec.exec_state = .IS_EXEC_RUNNING;
				d_step.step_control = exec.debug_info.debug_control;
				d_step.call_stack_count = exec.debug_info.debug_call_stack.count;
				if exec.debug_info.debug_control == {
				case .CONTINUE; {
					/*NOTE : If we just stopped then we want to check within a range of code here
					and then continue until we are out of in_breakpoint_bounds_and_continue OR if we hit asm breakpoint.
					We check asm breakpoints down below always anyways so those will get hit no matter what.
					So we will stop here if we jmp to any of the lines below with those breakpoints set, which is all cases.
					BP_CODE 	instr 1
								instr 2
					BP_ASM	instr 3
								instr 4
					TODO We could also store last hit breakpoint but then we would always have to clear it
					so I kind of prefer this way.

					THIS ENSURES WE DONT STOP WITHIN THE SAME STATEMENT BOUNDS ON A CONTINUE. So we wait till we are out
					and then we stop if we hit a breakpoint (which could be on the same line on a next loop or something like that).
					SO this is STOP AT ANY BREAKPOINT AFTER THIS BREAKPOINT STATEMENT BOUNDS IS EXECUTED (including this breakpoint next time).
					*/
					//TODO Can remove this if this is fine. Leaving here just in case.
					// last_closest_bp : DebugBreakpoint;
					for exec.debug_info.break_points {
						if it.asm_index <= ad.all_register_memory[RegDef.pc].int_value &&
							it.end_asm_index >= ad.all_register_memory[RegDef.pc].int_value
							// it.asm_index > last_closest_bp.asm_index
						{
							// last_closest_bp = it;
							if it.bp_type == .BP_CODE {
								d_step.in_breakpoint_bounds_and_continue = true;
								d_step.start_asm_index = it.asm_index;
								d_step.end_asm_index = it.end_asm_index;
								break;
							}
						}
					}
					// if last_closest_bp.bp_type == .BP_CODE {
					// }
				}
				case .ASM_STEP_INTO; #through;
				case .ASM_STEP_OVER; {
					// d_step.step_control = exec.debug_info.debug_control;
					d_step.start_asm_index = ad.all_register_memory[RegDef.pc].int_value;
					d_step.end_asm_index = ad.all_register_memory[RegDef.pc].int_value;
				}
				case .STEP_INTO; #through;
				case .STEP_OVER; {
					// d_step.step_control = exec.debug_info.debug_control;
					d_line := GetDebugLineAsm(ad.all_register_memory[RegDef.pc].int_value, ad.comp_data);
					d_step.start_asm_index = d_line.start_asm_index;
					d_step.end_asm_index = d_line.end_asm_index;
				}
				case .STEP_OUT; {
					// d_step.step_control = exec.debug_info.debug_control;
					function_scope := peek(exec.debug_info.debug_call_stack).function_scope;
					d_step.start_asm_index = function_scope.start_instr_index;
					d_step.end_asm_index = function_scope.end_instr_index;
				}
				}

				//NOTE : This has been replaced with call_stack_count. Let's see if that keeps working
				//and I will leave this here now for reference just in case it is useful somehow.
				#if 0 {
				/*DOCU : If we have a step_over control, then we want to skip over call instructions. We do
				this by keeping the same range as step over but then also ensuring that we stay within
				the function scope.
				We could check and set the function instr range in here but we check later for now.
				*/
				//NOTE : Step into does not need to check since if we had a call we want to follow to the function
				//and so we just want to be outside the debug line.
				if AllOrEquals(exec.debug_info.debug_control, .[.STEP_OVER, .ASM_STEP_OVER]) {
					//TODO Could just always set this for convenience
					for d_step.start_asm_index..d_step.end_asm_index {
						if ad.all_music_instructions[it].op_code == OpCode.call {
							//NOTE : If we find a call with step over, then we want to be outside of debug line 
							//BUT inside the function scope.
							d_step.has_call_instr = true;
							d_step.call_index = exec.debug_info.debug_call_stack.count-1;
							break;
						} 
					}
				}
				}
			} else {
				//NOTE : We just executed some instructions and so we check if need to debug stop
				//If we are outside the original d_step then we stop
				last_instr := ad.all_music_instructions[ad.all_register_memory[RegDef.ir].int_value];
				//NOTE : We already checked that .pc is valid above so we can safely grab the instruction
				// next_instr := ad.all_music_instructions[ad.all_register_memory[RegDef.pc].int_value];
				if last_instr.op_code == .call {					
					//sanity check : should always have the main call frame in here
					assert(exec.debug_info.debug_call_stack.count > 0);
					//Set the previous frame call_instr_index so we know where we are calling from
					last_frame := peek_pointer(exec.debug_info.debug_call_stack);
					last_frame.call_instr_index = ad.all_register_memory[RegDef.ir].int_value;

					func_start_index : int = ComputeOperandInt(last_instr.operands[0], ad.all_register_memory, ad.ram_memory);
					//TODO Should this be returned as an error? It will be checked by the ExecMInstr anyways.
					//Also call should only be used by the compiler so this is more of a sanity check.
					assert(func_start_index >= 0 && func_start_index < ad.all_music_instructions.count);
					CreateDebugCallFrame(func_start_index, exec, ad.comp_data, ad);
				} 
				else if last_instr.op_code == .push_all_stack_reg {
					/*DOC : If we have a .push_all_stack_reg when we call a function, then we store the registers
					here for the stack frame so we can use in the watch window and avoid having to copy over updated
					sbp register and maybe anything else we add later.
					*/
    				for d_step.start_asm_index..d_step.end_asm_index {
    					if ad.all_music_instructions[it].op_code == OpCode.call {
							assert(exec.debug_info.debug_call_stack.count > 0);
							last_frame := peek_pointer(exec.debug_info.debug_call_stack);
		    				memcpy(last_frame.stored_frame_registers.data, ad.all_register_memory.data, ad.all_register_memory.count * size_of(MemoryValue));
							break;
						}
					}
				} 
				else if last_instr.op_code == .ret {
					//sanity check. The first one is main so that should be closed with exit
					assert(exec.debug_info.debug_call_stack.count > 1);
					//NOTE : To avoid issues we reset data when we create a new frame since we have the pool in the array.
					//The pool is store in the array but we could have a separate array for that as well.
					exec.debug_info.debug_call_stack.count -= 1;
					//TODO We could reset the data here if needed
					// pop(*exec.debug_info.debug_call_stack);
				}

				//Sanity check : should always have a value in here because of the main function
				assert(exec.debug_info.debug_call_stack.count > 0);
				c_frame : *DebugCallFrame = peek_pointer(exec.debug_info.debug_call_stack);
				//Pop all closed scopes off and remove variables
				while c_frame.call_open_scopes.count > 0 &&
						ad.all_register_memory[RegDef.pc].int_value > peek(c_frame.call_open_scopes).end_instr_index 
				{
					pop_scope := pop(*c_frame.call_open_scopes);
					while c_frame.frame_vars.count > 0 &&
							peek(c_frame.frame_vars).scope_id == pop_scope.id 
					{
						//TODO Use the frame_vars as a pool as well so just decrement count and the increment or
						pop(*c_frame.frame_vars);
					}
				}
				/*We go over the scopes that we skipped here, like with an else if we need skip over the
				  if or if-for-while inline in here.
				  x : int = 0;
				  if x == 1 for 0..10 { //SKIP OVER THESE SCOPES FOR EXAMPLE
				  } else if x == 0 {
				  }
				*/
				while c_frame.s_index < c_frame.all_scopes_in_function.count &&
						c_frame.all_scopes_in_function[c_frame.s_index].start_instr_index < ad.all_register_memory[RegDef.pc].int_value
				{
					c_frame.s_index += 1;
				}
				//Add any new scopes and variables that we have currently entered
				//TODO REMINDER We can add more than 1 scope for example if we have function scope and then asm/controle scope
				//since they would be on the same line. But if we add a .nop or .fstart instruction for all functions
				//then the function would start at a different instr index than anything that is in it.
				//ACTUALLY we no longer store all_scopes_in_function , so maybe this can be an if statement now.
				while c_frame.s_index < c_frame.all_scopes_in_function.count &&
						c_frame.all_scopes_in_function[c_frame.s_index].start_instr_index == ad.all_register_memory[RegDef.pc].int_value 
				{
					open_scope := c_frame.all_scopes_in_function[c_frame.s_index];
					array_add(*c_frame.call_open_scopes, open_scope);
					c_frame.s_index += 1;

					//TODO I think variables are also ordered by scope_id, although technically we could
					//have global variables, we could sort them and all_scope_data at the end of compilation to make sure.
					//SO WE COULD Keep track of the all_var_index and then start from there while scope_id == open_scope.id
					//instead of going through the entire array every time we add a scope.
					for ad.comp_data.all_variables if it.scope_id == open_scope.id {
						array_add(*c_frame.frame_vars, it);
					}
				}

				//TODO MAYBE STEP_INTO is run until we hit a call for the current line instruction range
				//and if we don't then it's just a STEP_OVER
				already_checked_breakpoints : bool = false;
				if d_step.step_control != .CONTINUE {
					//NOTE : STEP_INTO gets dealth with automatically by this range.
					out_of_step_bounds : bool = 
						ad.all_register_memory[RegDef.pc].int_value < d_step.start_asm_index || 
 		   			ad.all_register_memory[RegDef.pc].int_value > d_step.end_asm_index;

	   			hit_step_break : bool = out_of_step_bounds;

					if d_step.step_control == {
					case .ASM_STEP_OVER; #through;
					case .STEP_OVER; {
						#if 1 {
						/*DOC : This is not as explicit as if .ret then < call_stack count but we can only pop a call frame
						if we do a ret and therefore either we want to stack with the same call stack in all cases
						unless we step over a ret in which case it could be less. And it could be < call_stack_count - 1
						if we have a recursive function in which case we would want to skip over all the recursions.
						THEREFORE 
						if debug_call_stack.count == d_step.call_stack_count
							then we are back in the same function scope
						if debug_call_stack.count < d_step.call_stack_count;
							then we are back in a previously called function
						IN EITHER CASE we want to stop if we are out of the bounds of the d_step
						IF WE RECURSE this waits until we are out of the recursion completely and out of d_step bounds
						IF we have >= 1 function call on a line, it waits until we are back to the current call and out of d_step bounds
						*/
						valid_step_stack : bool = exec.debug_info.debug_call_stack.count <= d_step.call_stack_count;
						hit_step_break = out_of_step_bounds && valid_step_stack;
						//TODO Can remove this into deadcode if the above keeps working in all cases.
						// if last_instr.op_code == .ret {
						// 	//Since we returned, there should be 1 less stack frame from when we started.
						// 	//NOTE : If we hit another return we would have had to make a function call so then
						// 	//this would be > the d_step.call_stack_count
						// 	// step_stack_count -= 1;
						// 	valid_step_stack = exec.debug_info.debug_call_stack.count < d_step.call_stack_count;
						// } else {
						// 	valid_step_stack = exec.debug_info.debug_call_stack.count == d_step.call_stack_count;
						// } 
						} 
						else {
						//TODO WE CAN REMOVE THIS CASE IF THE ABOVE KEEPS WORKING IN GENERAL AND PUT IT IN DEAD CODE LATER
						//TODO I think for step over we just check if the last_instr == the last instr in the d_step
						//and if yes and we are out of the d_step bounds, then we hit step break. 
						//Just double check this with recursion since that should jump out of the entire recursion
						if d_step.has_call_instr {
							if last_instr.op_code == .ret && d_step.end_asm_index == ad.all_register_memory[RegDef.ir].int_value {
								/*DOC : Explicit case dealing with eg 'return foo(x);' where we have a call and ret
								on the same line so the call_stack gets popped above and then the call_index is > call_stack.count below.
								This case prevents that by only checking if we are out of step bounds in this specific case.
								I can't think of another case or reason to change anything else for now.
								So we leave this case explicit for documentation and if we find something else later
								(eg with loops or some other case I did not think of), then we can consider it altogether later.

								TECHNICALLY remedy skips over the call even if it's recursive but I am not sure which behavior I want
								so this goes through the recursion and if want to jump out we can just do step out or put a breakpoint outside.
								*/
								d_step.call_index -= 1;
								//REMINDER This did not work because of conditionals which don't necessarily end on the last condition
								// hit_last_step_instr : bool = d_step.end_asm_index == ad.all_register_memory[RegDef.ir].int_value;
								// hit_step_break = out_of_step_bounds && hit_last_step_instr;
							} 
							else {
								//DOC : OTHERWISE we deal with step over with out of step bounds AND in function scope.
								function_scope := exec.debug_info.debug_call_stack[d_step.call_index].function_scope;
								in_function_scope : bool = 
									ad.all_register_memory[RegDef.pc].int_value >= function_scope.start_instr_index &&
									ad.all_register_memory[RegDef.pc].int_value <= function_scope.end_instr_index;
								hit_step_break = out_of_step_bounds && in_function_scope;
							}	
						}
						}
					}
					}

					if hit_step_break {
						exec.exec_state = .IS_DEBUG_STOP;
						break exec_loop;					  	
					}
				} else if d_step.step_control == .CONTINUE {
					if d_step.in_breakpoint_bounds_and_continue {
						out_of_breakpoint_bounds : bool = 
							ad.all_register_memory[RegDef.pc].int_value < d_step.start_asm_index || 
	 		   			ad.all_register_memory[RegDef.pc].int_value > d_step.end_asm_index;
		   			if out_of_breakpoint_bounds {
		   				d_step.in_breakpoint_bounds_and_continue = false;
		   			}
					} 

					//NOTE : Need to check again here in case we switched it off just now
					if !d_step.in_breakpoint_bounds_and_continue {
						//We always check break_points so we stop on those if we find one for this instruction.
						for exec.debug_info.break_points {
							if it.asm_index <= ad.all_register_memory[RegDef.pc].int_value &&
								it.end_asm_index >= ad.all_register_memory[RegDef.pc].int_value
							{
								exec.exec_state = .IS_DEBUG_STOP;
								break exec_loop;
							}
						}
						//NOTE : don't need to check asm breakpoints again since we already checked all breakpoints here
						//IF WE EVERY DONT CHECK ALL BREAKPOINTS HERE then we need to remove this.
						already_checked_breakpoints = true;
					}
				}

				//TODO FROM HERE Should add a breakpoint test to check that if we hit a bp
				//and there is an asm_bp within the bounds, that it will stop there and then continue
				//after. Likely make a separate test for that case to not pollute this OR make
				//and integration test and add that test to check things are updated
				//but I think a blatant test is good in this case since it is a good specific case.
				//Then do for < {} and for * {} simple examples for unit test and integration test and then struct.
				//We only check asm breakpoint if we are not out of the previous breakpoint bounds yet.

				//NOTE : We always want to check asm breakpoints because we can stop there at any time inlcuding
				//during a step or if we are in_breakpoint_bounds_and_continue.
				if !already_checked_breakpoints {
					for exec.debug_info.break_points {
						if it.bp_type == .BP_ASM && 
							it.asm_index == ad.all_register_memory[RegDef.pc].int_value 
						{
							//TODO Could make this a ResetDStep function if needed
							d_step.in_breakpoint_bounds_and_continue = false;
							exec.exec_state = .IS_DEBUG_STOP;
							break exec_loop;
						}
					}
				}


				//TODO We could use this here instead for consistency when we debug stop
				// if exec.exec_state == .IS_DEBUG_STOP {
				// 	break exec_loop;
				// }
			}
		}

		//pc is next instruction. ir is the last executed instruction 
		//NOTE : We already checked that .pc is valid above so we can safely grab the instruction
		ad.all_register_memory[RegDef.ir] = ad.all_register_memory[RegDef.pc];
		//pc defaults next instruction to current instruction + 1 (ie .pc = .ir + 1)
		//then if it gets updated on a execution, we grab it on the next loop
		ad.all_register_memory[RegDef.pc].int_value = ad.all_register_memory[RegDef.ir].int_value + 1;
		ci := ad.all_music_instructions[ad.all_register_memory[RegDef.ir].int_value];
		err = ExecMInstr(ci, ad);
		//TODO Could make this more elaborate, for example grabbing stack trace.
		if err.is_error || ci.op_code == .exit {
			stop_execution = true;
			break exec_loop;
		}

		exec.instructions_run_this_frame += 1;
		if exec.instructions_run_this_frame >= ad.runtime_settings.asm_instructions_per_frame {
			exec.continue_execution_next_frame = true;
			break exec_loop;
		}
	}

	//Note : Remove the last HALT instruction efficiently.
	//This would need to change if we could add or change instructions for example.
	ad.all_music_instructions.count -= 1;
	// print("Executed All Instructions\n");

	if stop_execution {
		//This way we pause if we are in debug mode and hit an error so we can see the error. 
		//Otherwise we stop running.
		if exec.exec_mode == ExecutionMode.DEBUG && err.is_error {
			exec.exec_state = .IS_DEBUG_STOP;
			err.error_index = ad.all_register_memory[RegDef.ir].int_value;
			//We set the next instruction to .ir so we make sure to stop on it.
			ad.all_register_memory[RegDef.pc].int_value = ad.all_register_memory[RegDef.ir].int_value;
			//TODO This should be displayed somewhere obvious in the debugger to show that execution error
			//Maybe we could have the debugger console pop up automatically for example.
			log("DEBUGGER STOPPED ON ERROR : %.\n", err);
			//TODO We could do this at runtime but instead of fetching it every frame we get it once here.
			//Now doing it at runtime. Can remove this if we continue with it and it works well.
			// d_line : DebugLine = GetDebugLineAsm(ad.all_register_memory[RegDef.pc].int_value, ad.comp_data);
			// exec.debug_info.stop_line = d_line.line_number;
		} else {
			exec.exec_state = .NOT_RUNNING;
		}
		//TODO We could reset some of the registers here if needed.
		//TODO Should print out a file name here or something.
		//TODO Could print this to compiler console maybe but not pop up console
		// print("Ended execution.\n");
	}

	//NOTE : This will be no error if we don't return an error from the instruction execution.
	return err;
}

//TODO Can make instr_increment a struct for all things we want to change across several instructions
//OR BETTER YET just put it in all data and update it and then use it after.
//Can have a CPUState struct with instruction_counter in it
//TODO Can likely pass in less than AllData eventually and just what we need to update. Maybe not though
//with the .muscall since that can access anything.
/*We could possibly separate normal calls from muscall and then this would just take in CPUState
which would have registers and ram_memory

TODO Should pass in renderer_data and audio_data in here in case we need them.
TODO We could pass in ExecutionInfo so we would now how many instructions we have for example
Then we can also use thet for editable/add/remove instructions later
AND ALSO Check that a .jmp or .ret is not > the total # of instructions
*/
//TODO We could set 1 allocator per instruction and then clear right after so it could be small and then
//we remove everything temporary right away at the end of the instruction in every case.
ExecMInstr :: (ci : MusicInstruction, ad : *AllData) -> CPUError {

	//TODO Should this error checking all be in it's own function?
	err : CPUError = ValidateMusicInstruction(ci);
	if err.is_error return err;

	for op, op_index : ci.operands {
		err = ValidateMusicOperand(op, op_index,
			ad.all_register_memory, ad.ram_memory, ad.global_rules.row_size, ad.all_mspace_data[0].all_music_lane_rows.count);
		if err.is_error return err;
	}

	//Reminder : After this point, instruction and operands are assumed to be valid so we don't have to make
	//things messy and inefficient by passing around errors everywhere.

	if ci.op_code == {
	//TODO Should we change the name of this opcode to .copy. Depends if we want ppl to get used to this for computer assembly.
	case OpCode.mov; {
		err = ExecMov(ci, ad);
		if err.is_error return err;
	}
	/*.push and .pop are variations on mov, so we treat them as such. We have done this by separating out the
	mov code but maybe it is better to have 3 separate codes later. It depends how we will use them I think.
	So I will see what I want to do with code but this way seems to make the most sense for now.
	Could also have just one case in the switch and then adjust things but the problem there is that the
	MusicInstructon into this function is immutable so we cannot update it and then we have to copy it
	and so things get a bit messy.
	The current way is clear as to what the push and pop are doing relative to a mov and we don't have any duplicate
	code so all errors will only happen in 1 place and it was not too hard to change so that is why we chose
	to do it that way for now.
	NOTE: If we decide to only allow pushing and popping of single values then we should just rewrite the code
	simply in push and pop with single values like it was before. Could just copy/paste and alter from mov
	and basically we would have push and pop but without mov_size. It seems weird to allow a pop with a mov_size
	right now so maybe we just have mov with mov_size and use that if we need to do large moves.
	ALSO PUT MOV BACK INTO MOV above if we do that and remove the ExecMov function. Maybe we could keep the
	ComputeMovSize or ComputeByteMovSize since that maintains the 8 value default although we should likely
	set that somewhere so the player can set it wherever they want.
	I think switching to single value push and pop makes the most sense since we can just use movs for larger
	moves like return values and for structs, the values will have to be pushed 1 at a time anyways since we 
	need to set them and if its not initialized, then we just increment the scp instead of doing anything else.
	Strings will always be stored on the heap... so I see no reason to have push and pop with mov_size.
	I will leave it FOR NOW BUT CHANGE TO SINGLE after implementing functions and structs in code unless 
	we see something else.

	If we only use push/pop in function calling, then it may even be worth removing these instructions
	and just replacing them with mov/mset and add .scp. This would simplify things as we would have
	less instructions overall. Could leave them for single value case but what about inverse instructions
	to go backwards eventually?
	*/
	case OpCode.push; {
		copy_ci := ci;
		copy_ci.operands[2] = ci.operands[1];
		copy_ci.operands[1] = ci.operands[0];
		copy_ci.operands[0] = RamMem(.scp);	
		err = ExecMov(copy_ci, ad);
		if err.is_error return err;

		mov_size : int = ComputeMovSize(ci.operands[1], ad.all_register_memory, ad.ram_memory);
		ad.all_register_memory[RegDef.scp].int_value += mov_size;
	}
	case OpCode.pop; {
		mov_size : int = ComputeMovSize(ci.operands[1], ad.all_register_memory, ad.ram_memory);
		ad.all_register_memory[RegDef.scp].int_value -= mov_size;

		copy_ci := ci;
		//operands[0] is left the same since that is where we are popping/moving too
		copy_ci.operands[2] = ci.operands[1];
		copy_ci.operands[1] = RamMem(.scp);
		err = ExecMov(copy_ci, ad);
		if err.is_error return err;
	}
	case OpCode.mset; {
		//TODO WRITE UNIT TESTS FOR MSET
		mov_size : int = ComputeMovSize(ci.operands[2], ad.all_register_memory, ad.ram_memory);
		ram_address : int = ComputeRAMLocation(ci.operands[0], ad.all_register_memory, ad.ram_memory);
		ram_ptr : *u8 = GetMemory(ram_address, mov_size, ad.ram_memory);
		mv : MemoryValue = ComputeMemoryValue(ci.operands[1], ad.all_register_memory, ad.ram_memory);
		//TODO CompilerError
		assert(mv.int_value >= 0 && mv.int_value <= U8_MAX);
		memset(ram_ptr, cast(u8) mv.int_value, mov_size);
	}
	case OpCode.const_mov; {
		const_mem_address : int = ComputeOperandInt(ci.operands[1], ad.all_register_memory, ad.ram_memory);
		mov_size : int = ComputeOperandInt(ci.operands[2], ad.all_register_memory, ad.ram_memory);
		if const_mem_address < 0 || const_mem_address >= ad.comp_data.constant_memory.count ||
			const_mem_address + mov_size > ad.comp_data.constant_memory.count 
		{
			return CPUErr("Invalid const_mov memory is out of bounds.\n");
		}
		const_mem_data : *u8 = *ad.comp_data.constant_memory[const_mem_address];


		//This is checked for asm type RamMem in op code validation
		ram_address : int = ComputeRAMLocation(ci.operands[0], ad.all_register_memory, ad.ram_memory);
		ram_ptr, ram_err := GetMemory(ram_address, mov_size, ad.ram_memory);
		if ram_err.is_error return ram_err;

		memcpy(ram_ptr, const_mem_data, mov_size);
	}
	case OpCode.clear; {
		//TODO Can add a mov_size here so we can clear in a range as well.
		//That would be the reason to have clear so then we can optimize a clear in range.
		//Can also allow this for registers or memory although that can just be a mov 0.
		//TODO Could rename to clr or cler or not
		assert(ci.operands[0].operand_type != .NONE);
		row_index, x_index := MusicMemRowAndXIndex(ci.operands[0],
			ad.all_register_memory,
			ad.global_rules.row_size);
		//TODO Do this with a range
		//TODO This can be optimized by just memcpying over the old values instead in this function
		RemoveAllMusicPtsInMemory(row_index, x_index, *ad.all_mspace_data[0].all_music_pts);
	}
	//TODO Could have operand 1 and/or 2 be settings to filter clear based on row/tano and also svara
	case OpCode.tclear; {
		if ci.operands[0].operand_type == {
		case .NONE; {
			//Clear all music_pts if there is no input
			array_reset_keeping_memory(*ad.all_mspace_data[0].all_music_pts);
			array_reset_keeping_memory(*ad.tano_stack_music_pts);
		} 
		case .RAM_MEMORY; {
			//TODO Make a function that removes all neumes in a tano.
			//TODO Can pass ram_memory into assembler so we can do 
			//"tclear t;" for a specific tano
		} 
		//TODO If we pass in integer or register that could be clearing a specific mspace_index
		//so then we can just reset that specific array if we implements neumes with separate arrays.
		//TECHNICALLY We can do this with a tano and filter based on tano from start_row to max
		case .REGISTER; #through;
		case .INTEGER; {
			mspace_index : int = ComputeOperandInt(ci.operands[0], ad.all_register_memory, ad.ram_memory);
			mspace_neumes : *[..] MusicPoint = GetMSpaceNeumes(mspace_index, ad);
			//No need to do anything if we have no neumes in this mspace
			if mspace_neumes.count == 0 return NO_CPU_ERROR;

			if ci.operands[1].operand_type == .REGISTER && 
				ci.operands[1].values[0].int_value == cast(int) RegDef.tbp
			{
				tbp_row : int = ad.all_register_memory[ci.operands[1].values[0].int_value].int_value;
				/*DOC : For efficiency we sort the tano stack neumes by row and then we reset the count
				before that row and then default sort the neumes again.
				This is much more efficient than removing each neume 1 at a time.
				*/
				quick_sort(mspace_neumes.*, (m1,m2) => m1.row_index - m2.row_index);
				for mspace_neumes.* if it.row_index >= tbp_row {
					mspace_neumes.count = it_index;
					break;
				}
				//TODO Eventually we may not need to do this since we might have a separate array for audio neumes.
				DefaultSortNeumes(mspace_neumes.*);
			} 
			else {
				//Reset the entire mspace neume array
				array_reset_keeping_memory(mspace_neumes);
			}
		}
		}
	}
	//TODO Could also allow moving spaces to a specific index so people can cycle in any order they want.
	// case OpCode.create_mspace; {
	// 	/*TODO Although we have added these instructions AND put the mspace data as an array, I have not implemented
	// 	it visually or with audio yet because it involves some thought.
	// 	1) render the music rows depending on the mspace current mspace
	// 	2) have separate audio cursor for each mspace
	// 	3) add instructions to play a specific mspace (or several at once with an array)
	// 	4) add instructions to set the play cursor for each mspace 
	// 		(even if it's playing so we can programatically move where the audio is playing from)
	// 	*/
	// 	//TODO ALSO ADD VALIDATION FOR THIS AND SOME MINOR TESTS (unit and integration and check with intro)
	// 	new_mspace : *MusicSpaceData = InitMusicSpecData();
	// 	array_add(*ad.all_mspace_data, new_mspace);
	// }
	// case OpCode.delete_mspace; {
	// 	//TODO Remove an mspace from the list (put it in a free list so we can reuse it later)
	// }
	// case OpCode.mspace_clear; {
	// 	//NO arguments clears all mspaces by default.
	// 	//TODO Can pass an argument that clears a specific mspace once we implement that.
	// 	ClearMusicSpace(ad.all_mspace_data[0]);
	// 	//TODO I think using a pool to do this is cleaner since we would reset everything
	// 	//but maybe we add that once everything is cleaned up. It also lets us reuse the data if needed.
	// 	//Although we could just reset the mspaces and put them in a free_mspaces array and then grab those.
	// 	//If the data is just resizable arrays and values then maybe this is best but if we add other
	// 	//but i guess if we always grab with the allocator and then reset it for each mspace, that would be good too.
	// 	// reset(*ad.mspace_pool);
	// 	// ad.all_code_data = InitAllCodeData(,,ad.mspace_alloc);
	// }
	//TODO Should we rename to push_all_gpr or push_all_stack_reg?
	case OpCode.push_all_stack_reg; {
		//TODO We could have an option here to push ip and cr or not.
		//For functions we want to push .ip and .cr but maybe not if we call this in asm.
		//OR just pass that in as an operand with a default for .NONE.
		ram_location : int;
		if ci.operands[0].operand_type == .NONE {
			ram_location = ad.all_register_memory[RegDef.scp].int_value;
		} else {
			//NOTE : We treat the operand as RAM location and get the address and NOT the actual value.
			//Maybe there are some cases where this does not work and we could set 2 operators here instead.
			ram_location = ComputeRAMLocation(ci.operands[0], ad.all_register_memory, ad.ram_memory);
		}

		stack_reg_memory := array_view(ad.all_register_memory, push_pop_start_reg_index);
		reg_mem_pointer := cast(*u8) stack_reg_memory.data;
		SetRAMMem(ram_location, reg_mem_pointer, STACK_REG_SIZE, *ad.ram_memory);

		//TODO Can remove this once we no longer increment scp as we move along the function
		//TODO Remove this and do it in code so we can see it explicitly
		// ad.all_register_memory[RegDef.scp].int_value += STACK_REG_SIZE;
	}
	//TODO Should we rename to pop_all_stack_reg?
	case OpCode.pop_all_stack_reg; {
		stack_reg_memory := array_view(ad.all_register_memory, push_pop_start_reg_index);	
		reg_mem_pointer := cast(*u8) stack_reg_memory.data;

		//TODO Remove this with new way
		// ad.all_register_memory[RegDef.scp].int_value -= STACK_REG_SIZE;

		// ram_location : int = ad.all_register_memory[RegDef.scp].int_value;
		ram_location : int;
		if ci.operands[0].operand_type == .NONE {
			ram_location = ad.all_register_memory[RegDef.scp].int_value;
		} else {
			//NOTE : We treat the operand as RAM location and get the address and NOT the actual value.
			//Maybe there are some cases where this does not work and we could set 2 operators here instead.
			ram_location = ComputeRAMLocation(ci.operands[0], ad.all_register_memory, ad.ram_memory);
		}

		ram_pointer := cast(*MemoryValue) *ad.ram_memory.bytes[ram_location];
		memcpy(reg_mem_pointer, ram_pointer, STACK_REG_SIZE);
	}
	case OpCode.exit; {		
		//Explicitly do nothing. Eventually if we want to cleanup some data or registers or something
		//we can do it here and possibly split up exit and HALT if needed.
	}
	case OpCode.HALT; {
		return CPUErr("Halt and Catch Fire!");
	}
	case OpCode.mod; #through;
	case OpCode.div; #through;
	case OpCode.mul; #through;
	case OpCode.sub; #through;
	case OpCode.add; {
		assert(ci.operands[0].operand_type != .NONE && ci.operands[1].operand_type != .NONE);
		/*For float we can either use float type in operand but then we don't get all 64-bits on optimization.
		OR we have an fadd, fsub... instruction and then we can just assume float. But then what do we do
		if we add int or float to MEMORY_MPS? The type works better in that case. We could store it somewhere
		in there possibly. OpCodes tend to be a certain number of bits with some values so maybe we lose some
		bits for things like immediate.
		*/
		//TODO Should remove all these operand_0 and just call directly i think.
		operand_0 : MusicOperand = ci.operands[0];
		operand_1 : MusicOperand = ci.operands[1];
		if operand_0.operand_type == .REGISTER || operand_0.operand_type == .RAM_MEMORY {
			//TODO Can do 2 and 3 operands similar to how we do it for logic instructions
			mv : MemoryValue;
			v1 : MemoryValue;
			v2 : MemoryValue;
			if ci.operands[2].operand_type != .NONE {
				v1 = ComputeMemoryValue(ci.operands[1], ad.all_register_memory, ad.ram_memory);
				v2 = ComputeMemoryValue(ci.operands[2], ad.all_register_memory, ad.ram_memory);
			} else {
				v1 = ComputeMemoryValue(ci.operands[0], ad.all_register_memory, ad.ram_memory);
				v2 = ComputeMemoryValue(ci.operands[1], ad.all_register_memory, ad.ram_memory);
			}

			if ci.instr_type == .INTEGER {
				if ci.op_code == {
				case .add; mv.int_value = v1.int_value + v2.int_value;
				case .sub; mv.int_value = v1.int_value - v2.int_value;
				//TODO Should this be PosMod or %? Could have pmod and mod instruction separately.
				case .mod; mv.int_value = PosMod(v1.int_value, v2.int_value);
				case .div; mv.int_value = v1.int_value / v2.int_value;
				case .mul; mv.int_value = v1.int_value * v2.int_value;
		    	}
		   } else if ci.instr_type == .FLOAT {
				if ci.op_code == {
				case .add; mv.float_value = v1.float_value + v2.float_value;
				case .sub; mv.float_value = v1.float_value - v2.float_value;
				//TODO Should this be PosMod or %? Could have pmod and mod instruction separately.
				case .mod; mv.float_value = PosMod(v1.float_value, v2.float_value);
				case .div; mv.float_value = v1.float_value / v2.float_value;
				case .mul; mv.float_value = v1.float_value * v2.float_value;
		    	}		   	
		   }

			if operand_0.operand_type == .REGISTER {
		    	ad.all_register_memory[operand_0.int_value] = mv;
		   } else if operand_0.operand_type == .RAM_MEMORY {
		    	mem_address : int = ComputeRAMLocation(operand_0, ad.all_register_memory, ad.ram_memory);
		    	//TODO This is more clear and consistent than memcpy but maybe good to compare efficiency later.
		    	SetRAMValue(mem_address, mv, *ad.ram_memory);
				// memcpy(*ad.ram_memory.bytes[mem_address], *mv, size_of(MemoryValue));
		   }
		} else if operand_0.operand_type == .MUSIC_MEMORY {
			/*TODO If operand_1 is single value and operand_2 is RAM_ARRAY or MUSIC_MEMORY, then 
			*/
			to_row, to_start_x := MusicMemRowAndXIndex(operand_0, ad.all_register_memory, ad.global_rules.row_size);
			if operand_1.operand_type == .MUSIC_MEMORY {
				mv : MemoryValue = ComputeMemoryValue(ci.operands[2], ad.all_register_memory, ad.ram_memory);
				fv, iv := MVToFVAndIV(mv, ci.instr_type);
				from_row, from_x := MusicMemRowAndXIndex(ci.operands[1], ad.all_register_memory, ad.global_rules.row_size);
				//Reminder : using [..] *MusicPoint here did not work because the pointers will change
				//once we increase the size of the dynamic array of all_music_pts after array_count >= 8.
				to_music_pts : [] MusicPoint = GetAllMusicPtPosByPosition(from_row, from_x, ad.all_mspace_data[0].all_music_pts, MusicPoint);
				UpdateMusicPtsFromMinStart(to_music_pts, to_start_x, to_row, ad.global_rules.row_size);
				for * to_music_pts ArithmeticMusicOp(ci.op_code, iv, fv, it);
				CreateManyMusicPtsInMemory(to_music_pts, *ad.all_mspace_data[0].all_music_pts);
			} else {
				mv : MemoryValue = ComputeMemoryValue(ci.operands[1], ad.all_register_memory, ad.ram_memory);
				fv, iv := MVToFVAndIV(mv, ci.instr_type);
				from_music_pts : [] *MusicPoint;
				if ci.operands[2].operand_type != .NONE {
					/*IF RAM_ARRAY IS operands[2], then we could do the operation only on those specific values
					which would help with loops and also grabbing like munit[0,0,.[0,1,2]]
					*/
					//Music arithmetic by range. So we can mov by range and then apply arithmetic by range with 2 instructions.
					//TODO I am not sure if this is good or we should just be doing a loop. 
					//Also to consider inverse instruction consequences of range instructions.
					//I don't know if range_size really works because what about overlapping notes?
					operand_2 : MusicOperand = ci.operands[2];
					range_size : int = ComputeOperandInt(operand_2, ad.all_register_memory, ad.ram_memory);
					from_music_pts = GetAllMemoryMusicPtsInRange(to_start_x, to_start_x + range_size, to_row, ad.all_mspace_data[0].all_music_pts, *MusicPoint);
				} else {
					from_music_pts = GetAllMusicPtPosByPosition(to_row, to_start_x, ad.all_mspace_data[0].all_music_pts, *MusicPoint);
				}
				//TODO Do float properly here once we have float in asm.
				// op_float : float = cast(float) op_int;
				for from_music_pts ArithmeticMusicOp(ci.op_code, iv, fv, it);
			}
		}
	}
	//TODO diff as "\"
	case OpCode.rol; #through;
	case OpCode.ror; #through;
	case OpCode.shl; #through;
	case OpCode.shr; #through;
	case OpCode.or; #through;
	case OpCode.xor; #through;
	case OpCode.and; {
		if ci.operands[0].operand_type == {
		case .REGISTER; #through;
		case .RAM_MEMORY; {
			/*TODO Should we just grab .bytes[0] here and the store at .bytes[0]
			OR would we only do that for u8/BYTE type if we add that?
			for example, it would not work with "<<" and "<<<", so we would need a separate case for bytes.
			Maybe just implement bytes later if needed OR just use bytes for string in the language.
			*/
			//TODO Test for valid operand tests eg cannot have MUSIC_MEMORY here or FLOAT values
			//or cannot have a float instruction either, or we could just ignore that.
			int_v : int;
			i1 : int;
			i2 : int;
			if ci.operands[2].operand_type != .NONE {
				i1 = ComputeOperandInt(ci.operands[1], ad.all_register_memory, ad.ram_memory);
				i2 = ComputeOperandInt(ci.operands[2], ad.all_register_memory, ad.ram_memory);
			} else {
				i1 = ComputeOperandInt(ci.operands[0], ad.all_register_memory, ad.ram_memory);
				i2 = ComputeOperandInt(ci.operands[1], ad.all_register_memory, ad.ram_memory);
			}

			if ci.op_code == {
			//TODO Replace these with logical instructions. Can we reuse that for music memory?
			case OpCode.or;  int_v = cast(int) (i1 || i2);
			case OpCode.and; int_v = cast(int) (i1 && i2);
			//TODO Do these need to be converted to int though?
			case OpCode.xor; int_v = cast(int) (i1 ^ i2);
			case OpCode.rol; int_v = cast(int) (i1 <<< i2);
			case OpCode.ror; int_v = cast(int) (i1 >>> i2);
			case OpCode.shl; int_v = cast(int) (i1 << i2);
			case OpCode.shr; int_v = cast(int) (i1 >> i2);
	    	}

	    	//TODO This could be a function if we reuse it often
			if ci.operands[0].operand_type == .REGISTER {
		    	ad.all_register_memory[ci.operands[0].int_value].int_value = int_v;
		   } else if ci.operands[0].operand_type == .RAM_MEMORY {
		   	mem_address : int = ComputeRAMLocation(ci.operands[0], ad.all_register_memory, ad.ram_memory);
		   	SetRAMValue(mem_address, int_v, *ad.ram_memory);
				// memcpy(*ad.ram_memory.bytes[mem_address], *int_v, size_of(int));
		   }
		}
		case .MUSIC_MEMORY; {
			from_row, from_x := MusicMemRowAndXIndex(ci.operands[0], ad.all_register_memory, ad.global_rules.row_size);
			if ci.op_code == {
			case OpCode.rol; #through;
			case OpCode.ror; #through;
			case OpCode.shl; #through;
			case OpCode.shr; {
				/*TODO THESE INSTRUCTION NEED TO BE UPDATED TO HAVE X_FLOAT instead of int. Now they are int
				but the ror and rol would need fmod_cycling so we just want to make sure that is a precise.
				This could be a case where if its instr_type INTEGER then we still use int and for FLOAT
				we use float everywhere (for shift size and for bounds). So we could keep this way for instr_type INTEGER
				and then make a float way for instr_type FLOAT and write a separate test especially for bounds.
				*/
				assert(ci.operands[0].operand_type == .MUSIC_MEMORY, "Invalid operand_0 for shft : %.\n", ci.operands[0]);
				//TODO Could let operand_1 be an array and then we can grab or move along both x and y.
				//TODO this could be a float if we allow x axis to be float eventually...
				shft_dist : int = ComputeOperandInt(ci.operands[1], ad.all_register_memory, ad.ram_memory);
				//TODO Default to 1 but maybe it should be 0 once we have float.
				range_size : int = 1;
				lower_bound : int;
				upper_bound : int;
				norm_bound : int;
				if ci.op_code == {
				case OpCode.shr; #through;
				case OpCode.shl;
					if ci.operands[2].operand_type != .NONE {
						operand_2 : MusicOperand = ci.operands[2];
						range_size = ComputeOperandInt(operand_2, ad.all_register_memory, ad.ram_memory);
						assert(range_size > 0 && range_size <= ad.global_rules.row_size);
					}
				case OpCode.ror; #through;
				case OpCode.rol;
					assert(ci.operands[2].operand_type != .NONE);
					operand_2 : MusicOperand = ci.operands[2];
					mem_address : int = ComputeRAMLocation(operand_2, ad.all_register_memory, ad.ram_memory);
					lower_bound = GetMemValue(mem_address, int, ad.ram_memory);
					assert(lower_bound >= 0 && lower_bound <= ad.global_rules.row_size);

					upper_bound = GetMemValue(mem_address+8, int, ad.ram_memory);
					assert(upper_bound >= 0 && upper_bound <= ad.global_rules.row_size);

					assert(lower_bound < upper_bound);
					norm_bound = upper_bound - lower_bound;
				}

				//TODO Grabbing these values first and then updating is easier for debbuging but ultimately
				//just looping over the values is going to be more efficient unless we organize the data later for better search.
				from_music_pts : [] *MusicPoint = 
					GetAllMemoryMusicPtsInRange(from_x, from_x + range_size, from_row,
						ad.all_mspace_data[0].all_music_pts, *MusicPoint);

				//TODO Could have a version with RAM_ARRAY where each value is shifted by different distances
				//based on the RAM_ARRAY.
				for mp : from_music_pts {
					if ci.op_code == {
					//TODO Could pull this out into a function if we need to reuse the logic.
					//Already did with UpdateLogicMusicOp if needed.
					case OpCode.shr;
						//TODO What if we go over the row_size? Do we even want row_size or do we want it to just match
						//the max note count anyways and then we adjust that by checking before rendering or playing audio?
						mp.x_start += shft_dist;
						mp.x_end += shft_dist;
					case OpCode.shl;
						mp.x_start -= shft_dist;
						mp.x_end -= shft_dist;
					case OpCode.ror; #through;
					case OpCode.rol;
						norm_start : int = mp.x_start - lower_bound;
						mp_length : int = mp.x_end - mp.x_start;
						shifted_value : int;
						if ci.op_code == {
						//TODO Could have a version with RAM_ARRAY where each value is shifted by different distances
						//based on the RAM_ARRAY.
						case OpCode.ror; shifted_value = norm_start + shft_dist;
						case OpCode.rol; shifted_value = norm_start - shft_dist;
						}
						mp.x_start = lower_bound + PosMod(shifted_value, norm_bound);
						mp.x_end = mp.x_start + mp_length;
					}
					//TODO We should be doing this by default and round_to_int for x_start and x_end
					//Just doing this now for convenience until we update asm x values to float.
					mp.x_start_float = cast(float64) mp.x_start;
					mp.x_end_float = cast(float64) mp.x_end;					
				}
			}
			//TODO I think .not should be a separate case as it is substantially different.
			//We could do it separately and then if it is the same bring it back.
			case OpCode.and; #through;
			case OpCode.xor; #through;
			case OpCode.or; {
				/*For 3 operand logical music, we combine operand_1 and operand_2 and then we mov
				them to operand_0. So it is not applied on operand_0. This is a convenience to using
				3 operand instructions.
				This can be though of as a fresh operation with normalized 1 unit music points being
				placed in the new memory at operand_0. So it will only create and not do anything
				to the notes already at operand_0. This seems clear to me.

				***TODO IMPORTANT Should do the same with 2 operands and just clear operands[0]
				so do operands[0] OP operands[1] and then clear operands[0] and then move result to operands[0]***
				*/
				//TODO Should we treat all music_pt value like floats? This seems the most useful
				//musically but also may be more practical if we just have floats. The question is
				//will it be accurate? I think with 64-bit float it will be fine and bats can hear too!
				//Bats can hear up to 200khz which would start losing accuracy with 32-bit float.
				to_row_index, to_x_index := MusicMemRowAndXIndex(ci.operands[0], ad.all_register_memory, ad.global_rules.row_size);
				if ci.operands[2].operand_type != .NONE {
					op_1_values : [] float64 = ComputeMultiMemoryFloat(ci.instr_type, ci.operands[1], 
						ad.all_register_memory, ad.ram_memory, ad.all_mspace_data[0].all_music_pts, ad.global_rules.row_size);
					op_2_values : [] float64 = ComputeMultiMemoryFloat(ci.instr_type, ci.operands[2], 
						ad.all_register_memory, ad.ram_memory, ad.all_mspace_data[0].all_music_pts, ad.global_rules.row_size);

					new_values : [..] float64;
					new_values.allocator = context.allocator;
					if ci.op_code == {
					case OpCode.or; {
						for op_1_values {
							in_new_set := ArrayFindByValue(new_values, it, Float64Equal);
							if !in_new_set array_add(*new_values, it);
						}
						for op_2_values {
							in_new_set := ArrayFindByValue(new_values, it, Float64Equal);
							if !in_new_set array_add(*new_values, it);
						}
					}
					case OpCode.and; {
						for op_1_values {
							in_new_set := ArrayFindByValue(new_values, it, Float64Equal);
							in_other_set := ArrayFindByValue(op_2_values, it, Float64Equal);
							if !in_new_set && in_other_set array_add(*new_values, it);
						}
					}
					case OpCode.xor; {
						for op_1_values {
							in_new_set := ArrayFindByValue(new_values, it, Float64Equal);
							in_other_set := ArrayFindByValue(op_2_values, it, Float64Equal);
							if !in_new_set && !in_other_set array_add(*new_values, it);
						}
						for op_2_values {
							in_new_set := ArrayFindByValue(new_values, it, Float64Equal);
							in_other_set := ArrayFindByValue(op_1_values, it, Float64Equal);
							if !in_new_set && !in_other_set array_add(*new_values, it);
						}
					}
					}

					//We are setting the notes to 1 unit long as this sort of normalization seems to make
					//the most sense when considering all cases. Then if we want to lengthen notes after we can 
					//and if we want to set them to the previous note values we can with a bit of code.
					//TODO Can we make this more efficient by setting directly in memory since we don't
					//need a return value.
					CreateManyMusicPtsInMemory(new_values, to_row_index, to_x_index, to_x_index+1,
						*ad.all_mspace_data[0].all_music_pts);
				} else {
					from_values : [] float64 = ComputeMultiMemoryFloat(ci.instr_type, ci.operands[1], 
						ad.all_register_memory, ad.ram_memory, ad.all_mspace_data[0].all_music_pts, ad.global_rules.row_size);

					if ci.op_code == {
					case OpCode.or; {
						/*TODO If there are duplicates in to_music_pts, then we don't remove them here... I think
						we should because a set operation should always remove all duplicates
						What about with .and and .xor? I should test these a bit.
						Could just go over all_music_pts and keep track of pts and remove if we find duplicates
						otherwise add if we don't have it yet.
						Could also just remove all and then repeat the above code and then we wouldn't have code duplicate
						*/
						to_music_pts : [] MusicPoint = GetAllMusicPtPosByPosition(to_row_index, to_x_index,
							ad.all_mspace_data[0].all_music_pts, MusicPoint);
						for v : from_values {
							//TODO How do we change this for floats?
							set_value, already_in_set := ArrayFindFirstByNameId(to_music_pts, v, "music_pt_float", Float64Equal);
							if !already_in_set {
								CreateMusicPtInMemory(v, to_row_index, to_x_index, to_x_index+1, *ad.all_mspace_data[0].all_music_pts);
							}
						}
					}
					case OpCode.and; {
						/*This feels a bit weird to get the indices. I think this means we need to add
						order/index to the MusicPoint so we can differentiate if we have the same note.
						Right now I am considering music_mem an array but maybe it could be a set which is how
						it was before. I prefer array because it is more general which means we can do more with
						it and use as a set if we want. We could have an option which treats it like a set
						but I am not sure that is great for the code... At least this way the player can treat
						it like a set if they want or like something else if they want. The only difference
						is that we would need to use some kind of index for array whereas with set the 
						music_pt is unique by its actual music_pt_pos value. 
						Putting the indices however may also make it easier to keep the music_pt database properly
						ordered so general queries. Eg we can keep it sorted by x_value.
						One nice thing here is that the old music_pts that remain, stay in tact. Maybe this is
						not desired though. I guess it would depend on the case. The player can shrink each
						remaining note down after in any case.
						*/
						//TODO Can use this while loop if we need an ordered remove. Otherwise we can
						//also make a for expansion 
						mp_index : int = 0;
						while mp_index < ad.all_mspace_data[0].all_music_pts.count {
							mp : MusicPoint = ad.all_mspace_data[0].all_music_pts[mp_index];
						// for mp : ad.all_mspace_data[0].all_music_pts { //comment this line out if we use while loop with mp_index for custom removal
							if ValueInMusicPt(to_x_index, to_row_index, mp) {
								found_intersection : bool = false;
								for from_values if Float64Equal(it, mp.music_pt_float) {
									found_intersection = true;
									break;
								}
								//TODO could to ordered remove with the while loop here if that helps
								//leaving unordered remove for speed for now, likely will need some structure once data model is set
								//Currently we use ordered remove for debugging perception convenience.
								if !found_intersection {
									// remove mp; //unordered remove that deals with index
									// array_unordered_remove_by_index(*ad.all_mspace_data[0].all_music_pts, mp_index);
									array_ordered_remove_by_index(*ad.all_mspace_data[0].all_music_pts, mp_index);
									mp_index -= 1;
								}
							}
							mp_index += 1;
						}
					}
					case OpCode.xor; {
						//XOR logic : First we .or it normally and then we do if intersect then remove (inverse of and)

						//TODO This is just a straight copy of .or so maybe we can make function to reuse the or logic.
						//Code is short though so might be best to keep separate for now.
						to_music_pts : [] MusicPoint = GetAllMusicPtPosByPosition(to_row_index, to_x_index,
							ad.all_mspace_data[0].all_music_pts, MusicPoint);
						for v : from_values {
							//TODO How do we change this for floats?
							set_value, already_in_set := ArrayFindFirstByNameId(to_music_pts, v, "music_pt_float", Float64Equal);
							if !already_in_set {
								CreateMusicPtInMemory(v, to_row_index, to_x_index, to_x_index+1, *ad.all_mspace_data[0].all_music_pts);
							}
						}

						//Remove intersection points (similar to and but remove on intersection instead of !intersection)
						mp_index : int = 0;
						while mp_index < ad.all_mspace_data[0].all_music_pts.count {
							mp : MusicPoint = ad.all_mspace_data[0].all_music_pts[mp_index];
							if ValueInMusicPt(to_x_index, to_row_index, mp) {
								for from_values if Float64Equal(it, mp.music_pt_float) {
									array_ordered_remove_by_index(*ad.all_mspace_data[0].all_music_pts, mp_index);
									// array_unordered_remove_by_index(*ad.all_mspace_data[0].all_music_pts, mp_index);
									mp_index -= 1;
									break;
								}
							}
							mp_index += 1;
						}
					}
					}
				}
			}
			}
		}
		case;
			//TODO This error should be returned to the user either by terminal or in a debug or text window.
			assert(false, "Invalid operand_0 type for instruction % with operands.\n", ci, ci.operands[0]);
		}
	}
	case OpCode.abs; {
		mv_0 : MemoryValue;
		mv_1 : MemoryValue = ComputeMemoryValue(ci.operands[1], ad.all_register_memory, ad.ram_memory);
		if ci.instr_type == {
		case .INTEGER; mv_0.int_value = abs(mv_1.int_value);
 		case .FLOAT; mv_0.float_value = abs(mv_1.float_value);
    	}
    	//TODO We reuse this from compute binary ops, maybe we can have a generalized set mem_value
		if ci.operands[0].operand_type == .REGISTER {
	    	ad.all_register_memory[ci.operands[0].int_value] = mv_0;
	   } else if ci.operands[0].operand_type == .RAM_MEMORY {
	    	mem_address : int = ComputeRAMLocation(ci.operands[0], ad.all_register_memory, ad.ram_memory);
	    	//TODO This is more clear and consistent than memcpy but maybe good to compare efficiency later.
	    	SetRAMValue(mem_address, mv_0, *ad.ram_memory);
			// memcpy(*ad.ram_memory.bytes[mem_address], *mv, size_of(MemoryValue));
	   }
	   //NOTE : Any other type is checed by ValidateMusicInstruction and should return an error before running this.
	}
	//TODO Could have lnot and not for bitwise not
	case OpCode.not; {
		if ci.operands[0].operand_type == {
		case .REGISTER; #through;
		case .RAM_MEMORY; {
			ireg_value : int;
			value_1 : int = ComputeOperandInt(ci.operands[0], ad.all_register_memory, ad.ram_memory);
			value_2 : int;
			if ci.operands[1].operand_type != .NONE {
				value_2 : int = ComputeOperandInt(ci.operands[1], ad.all_register_memory, ad.ram_memory);
				ireg_value = cast(int) !value_2;
			} else {
				ireg_value = cast(int) !value_1;
			}

			if ci.operands[0].operand_type == .REGISTER {
		    	ad.all_register_memory[ci.operands[0].int_value].int_value = ireg_value;
		   } else if ci.operands[0].operand_type == .RAM_MEMORY {
		    	mem_address : int = ComputeRAMLocation(ci.operands[0], ad.all_register_memory, ad.ram_memory);
		    	SetRAMValue(mem_address, ireg_value, *ad.ram_memory);
				// memcpy(*ad.ram_memory.bytes[mem_address], *ireg_value, size_of(int));
		   }
		}
		case .MUSIC_MEMORY;
			assert(false, ".not MUSIC_MEMORY not implemented yet.\n");
			//TODO This likely needs to be limited to an octave or something
			//also it may be substantially different that i can be it's own case
			//and not here and done on the outer branch check.
			//TODO SO THIS SHOULD BE AN ABSOLUTE NOT ONLY IF WE CAN FOR MUSIC MEMORY, ALTHOUGH NOT SURE. 
			//OTHERWISE WE JUST HAVE LOGICAL AND BITWISE NOT HERE and the separate for set difference.
			//TODO SET DIFFERENCE SHOULD BE "\" like (x \ y)
		}
	}
	//TODO This could be a bitwise-and (band) replacement, like and gates letting things through
	case OpCode.split; {
		/*THIS CAN PROBABLY BE REPLACED BY MOV with RAM_ARRAY
		*/
		//TODO REMOVE ARRAY AND do this with RAM_MEMORY instead once we implement it
		#if 0 {
		//TODO With 3 operands this can be pulling notes out of memory units instructions
		assert(ci.operands.count == 2);

		operand_1 : MusicOperand = ci.operands[0];
		operand_2 : MusicOperand = ci.operands[1];

		/*TODO Maybe this should be for separate instructions, so SINGLE_REGISTER
		could be for SPLIT and MEMORY_MPS could be SUBSET
		*/
		if operand_1.operand_type == MusicOperandType.REGISTER 
		{
			split_from : [] int;
			if operand_2.operand_type == MusicOperandType.MUSIC_MEMORY {
				from_row_index, from_x_index := MusicMemRowAndXIndex(operand_2,
					ad.all_register_memory,
					ad.global_rules.row_size);
				split_from = GetAllMusicPtPosByPosition(from_row_index, from_x_index,
					ad.all_mspace_data[0].all_music_pts);

				//TODO Eventually these may be sorted by default in the MusicPoint table.
				// If so, then we can remove this extra sort.
				// quick_sort(split_from, (i1,i2) => i1 - i2);
			} else if operand_2.operand_type == MusicOperandType.ARRAY {
				#if 0 {
				split_from = GetMusicOperandArrayValues(operand_2.id,
					ad.all_music_operand_values,
					ad.all_register_memory,
					ad.all_music_operand_expressions);
				}
			}

			split_index : int = ad.all_register_memory[operand_1.values[0].int_value].int_value;
			if split_from.count > split_index {
				ad.all_register_memory[operand_1.values[0].int_value].int_value = split_from[split_index];
			} else {
				//TODO We print this warning right now but this should not fail so do we do
				//anything else. Maybe print the error to terminal?
				print("split_index = % but note count = %\n", split_index, split_from.count);
			}
		}
		else if operand_1.operand_type == MusicOperandType.MUSIC_MEMORY {
			from_row_index, from_x_index := MusicMemRowAndXIndex(operand_1. 
				ad.all_register_memory,
				ad.global_rules.row_size);
			array_music_pt_pos : [] int =
				GetAllMusicPtPosByPosition(from_row_index, from_x_index,
					ad.all_mspace_data[0].all_music_pts);

			//TODO Could possibly just allow ARRAY here if thats what we usually use anyways
			//TODO On the other hand do we even need an ARRAY for SPLIT?
			split_music_pt_poses : [..] int;
			split_music_pt_poses.allocator = temp;
			if operand_2.operand_type == MusicOperandType.INTEGER ||
			   operand_2.operand_type == MusicOperandType.REGISTER
			{
				//TODO Could probably optimize this case to only put 1 music_pt
				music_pt_index : int = operand_2.int_value;
			    if operand_2.operand_type == MusicOperandType.REGISTER {
					music_pt_index = ad.all_register_memory[operand_2.int_value].int_value;
			    }

				if music_pt_index < array_music_pt_pos.count {
					array_add(*split_music_pt_poses, array_music_pt_pos[music_pt_index]);
				}
				else {
					//TODO RUNTIME ERROR should stop execution
					//TODO Need to associate music instructions to loc to log line number
					print("RUNTIME ERROR : split % > % (# of points in set)\n",
						music_pt_index, array_music_pt_pos.count);
				}
			}
			// else if operand_2.operand_type == MusicOperandType.ARRAY
			// {
				//TODO REPLACE WITH RAM_MEMORY Once we re-implement split
				#if 0 {
				array_operand_values : [] MusicOperandValue =
					ArrayFindAllVarName(ad.all_music_operand_values,
						operand_2.id, "operand_id", temp);

				for op_value, op_index : array_operand_values
				{
					music_pt_index : int = op_value.int_value;
				    if op_value.asm_ir_value_type == AssemblyIRValueType.REGISTER {
						music_pt_index = ad.all_register_memory[op_value.int_value].int_value;
				    }

					if music_pt_index < array_music_pt_pos.count {
						array_add(*split_music_pt_poses, array_music_pt_pos[music_pt_index]);
					}
					else {
						//TODO Or we just dont evaluate it if that pos DNE
						//TODO RUNTIME ERROR should stop execution
						//TODO Need to associate music instructions to loc to log line number
						print("RUNTIME ERROR : split % > % (# of points in set)\n",
							music_pt_index, array_music_pt_pos.count);
					}
				}
				}
			// }

			ReplaceMusicPtsInMemory(split_music_pt_poses, from_x_index, from_row_index,
				*ad.all_mspace_data[0].all_music_pts);
		}
		}
	}
	//TODO Could make tdim which is dimension of a tano BUT we could also just to tmov to array and get count
	//but tdim would be overall more efficient if we just wanted the number of neumes.
	case OpCode.dim; {
		//TODO Write unit tests for this
		reg_operand : MusicOperand = ci.operands[0];
		memory_operand : MusicOperand = ci.operands[1];

		from_row_index, from_x_index := MusicMemRowAndXIndex(memory_operand, ad.all_register_memory, ad.global_rules.row_size);
		//TODO This would be more efficient as just a count function that returned the count.
		array_music_pt_pos : [] int = GetAllMusicPtPosByPosition(from_row_index, from_x_index, ad.all_mspace_data[0].all_music_pts);

		reg_index : int = reg_operand.int_value;
		ad.all_register_memory[reg_index].int_value = array_music_pt_pos.count;

		//TODO We could have a memory_mps here for convenience but we can also
		//just MOV or OR it from register to memory
	}
	/*DOC : By convention if we 
	"tmov tano, tano/neume" then we use the neume length of the RHS
	"tmov tano, int/float/array" then we use the length of the LHS tano for convenience


	TODO COULD allow a y/svara value filtering here too with a range so that is standardized
	and then can use that anywhere else along with tano stack for convenience.

	TODO Could make a .tlen instruction to adjust the notes of a tano all to a certain size maybe with some
	options as well eventually.
	*/
	case OpCode.tmov; {
		/*TODO IF operands[0] == RAM_ARRAY, then we could have an option where we return either 
		array view or resizable array, this way we simplify converting tano music_pts to array
		so then we can manipulate the array however we want after. ALSO we can specify
		the return type (MusicPoint, int or float) so then we can do whatever we want with it
		and then the other tano ops like .tadd and .tshr are there just for simplicity and optimization.
		*/
		if ci.operands[0].operand_type == {
		case MusicOperandType.RAM_MEMORY; {
			to_address : int = ComputeRAMLocation(ci.operands[0], ad.all_register_memory, ad.ram_memory);
			to_tano, err := GetMemValue(to_address, tano, ad.ram_memory);
			if err.is_error return err;

			to_t_norm : tano = NormalizeTano(to_tano);
			to_neumes : *[..] MusicPoint = GetMSpaceNeumes(to_tano.mspace_start, ad);
			// to_tano_lias : *[..] MusicPoint = GetMSpaceNeumes(to_tano.mspace_start, ad);
			// to_tano_liyas : *[..] MusicPoint = GetMSpaceNeumes(to_tano.mspace_start, ad);
			// to_tano_leyas : *[..] MusicPoint = GetMSpaceNeumes(to_tano.mspace_start, ad);
			// to_tano_leas : *[..] MusicPoint = GetMSpaceNeumes(to_tano.mspace_start, ad);
			// to_tano_leahs : *[..] MusicPoint = GetMSpaceNeumes(to_tano.mspace_start, ad);

			//TODO Can add a setting to specify that we are copying an entire row
			//OR we go from FLOAT64_NAN -> FLOAT64_NAN or FLOAT64_MIN -> FLOAT64_MAX OR FLOAT64_INFINITY
			//and if we have that as x_start and x_end then we ignore x and just check row and copy entire row.
			//Could even have a few settings like 0->FLOAT64_INFINITY for everything above 0 OR
			//FLOAT64_NAN -> FLOAT64_NAN for everything from -x_min to +x_max
			// tmov_settings : TMovSettings;
			// if ci.operands[2].operand_type != .NONE {
			// 	if ci.operands[2].values[0].int_value < 0 || 
			// 		ci.operands[2].values[0].int_value >= tmov_array_types.count 
			// 	{
			// 		return CPUErr("Invalid tmov_array_type needs to be 0 or 1.\n");
			// 	}
			// 	tmov_settings.tmov_array_type = cast(TMovArrayType) ci.operands[2].values[0].int_value;
			// }

			if ci.operands[1].operand_type == {
			case MusicOperandType.RAM_MEMORY; {
				//NOTE : These could be passed in as integer or registers.
				//TODO We could have RAM_MEMORY be a more elaborate setting if needed later.
				tmov_ram_type : TMovRamType = .TANO; //DEFAULT
				if ci.operands[2].operand_type == .INTEGER {
					if ci.operands[2].values[0].int_value < 0 || 
						ci.operands[2].values[0].int_value >= tmov_ram_types.count 
					{
						return CPUErr("Invalid tmov_array_type needs to be 0 or 1.\n");
					}
					tmov_ram_type = cast(TMovRamType) ci.operands[2].values[0].int_value;
				}

				//TODO Not using case statement here in case we have more complex settings later on.
				from_address : int = ComputeRAMLocation(ci.operands[1], ad.all_register_memory, ad.ram_memory);
				if tmov_ram_type == .TANO {
					from_tano, err := GetMemValue(from_address, tano, ad.ram_memory);
					if err.is_error return err;

					//TODO If we allow mspace ranges then we would copy from each mspace depending on the order.
					from_neumes : [] MusicPoint = GetMSpaceNeumes(from_tano.mspace_start, ad).*;
					for mp : TanoLoop.{from_tano,from_neumes} {
						new_mp : MusicPoint = TMovMusicPt(mp, from_tano, to_tano);
						//TOOD What should the default here be? Remove or leave or cut?
						//TODO We could have a register with a setting here OR ci.operands[2] which cuts or removes instead of leaving.
						//I think leaving by default is the most intuitive but we can see later.
						//I think we want to keep all the neumes in the from_tano in any case really unless we specify remove if not in to_tano.
						// new_mp_in_tano : bool = InTanoAssumeNorm(new_mp, to_t_norm);
						// if new_mp_in_tano {
							CreateMusicPtInMemory(new_mp, to_neumes);
						// }
					}
				} 
				else if tmov_ram_type == .NEUME {
					from_neume, err := GetMemValue(from_address, Neume, ad.ram_memory);
					if err.is_error return err;
					//TODO Eventually we can remove this conversion once we only have Neumes and remove MusicPoints.
					mp : MusicPoint = MakeMusicPoint(from_neume.svara, from_neume.row, from_neume.x_start, from_neume.x_end);
					//TODO should we be using normalized tano here?
					// new_mp : MusicPoint = TMovMusicPt(mp, CENTER_TANO, to_t_norm);
					new_mp : MusicPoint = TMovMusicPt(mp, CENTER_TANO, to_tano);
					CreateMusicPtInMemory(new_mp, to_neumes);
				} 
				//TODO Can remove this once everything is tested just reminder of how we used to set the MusicPoints.
				// from_music_pts : [] MusicPoint = 
				// 	GetAllMemoryMusicPtsInRange(from_x, from_x + mov_size_float, from_row, ad.all_mspace_data[0].all_music_pts);
				// //TODO Update this to fix a few bugs
				// UpdateMusicPtsFromMinStart(from_music_pts, to_start_x, to_row, ad.global_rules.row_size);
				// CreateManyMusicPtsInMemory(from_music_pts, *ad.all_mspace_data[0].all_music_pts);
			}
			case .FLOAT; #through;
			case .INTEGER; #through;
			case .REGISTER; {
				/*TODO Can use ci.operands[2] here to specify Neume type or any other type we want to allow
				SO we could have Neume in general but also have some types which assume the row or mspace
				and even that assume the note length so then we just take in the x value and place in all the other values.
				*/
				mv : MemoryValue = ComputeMemoryValue(ci.operands[1], ad.all_register_memory, ad.ram_memory);
				for row_index : to_t_norm.row_start..to_t_norm.row_end {
					//TODO Could override the type if we have immediate float or integer
					CreateMusicPtByIType(ci.instr_type, mv, to_t_norm.x_start, to_t_norm.x_end, row_index, to_neumes);
				}
			}
			case .RAM_ARRAY; {
				/*TODO IF RAM_ARRAY is 2nd operand, then we could do split here and move the values in the RAM_ARRAY
				over by index. This would help with for example munit[0][0][0] where the 3rd value could even be an array
				or something like that...
				*/
				/*TODO Can use ci.operands[2] here to specify Neume type or any other type we want to allow
				SO we could have Neume in general but also have some types which assume the row or mspace
				and even that assume the note length so then we just take in the x value and place in all the other values.
				maybe a type liek neume_x would just specify the start/end x and then neume_sx would just specify start x
				and add the rest as well and we can simplify adding notes to the easiest possible way.
				*/
				//TODO ACTUALLY use ci.operands[2] to specify array type here with settings for MusicPoint array
				//IF we have a [] MusicPoint, then we want to
				tmov_array_type : TMovArrayType;
				if ci.operands[2].operand_type != .NONE {
					if ci.operands[2].values[0].int_value < 0 || 
						ci.operands[2].values[0].int_value >= tmov_array_types.count 
					{
						return CPUErr("Invalid tmov_array_type needs to be 0 or 1.\n");
					}
					tmov_array_type = cast(TMovArrayType) ci.operands[2].values[0].int_value;
				}

				if tmov_array_type == .DEFAULT {
					from_values : [] float64 = ComputeMultiMemoryFloat(ci.instr_type, ci.operands[1],
						ad.all_register_memory, ad.ram_memory, ad.all_mspace_data[0].all_music_pts, ad.global_rules.row_size);
					for row_index : to_t_norm.row_start..to_t_norm.row_end {
						CreateManyMusicPtsInMemory(from_values, row_index, to_t_norm.x_start, to_t_norm.x_end, to_neumes);
					}
				} 
				else if tmov_array_type == .NEUME {
					array_count : int = ComputeMusicOperandValue(ci.operands[1].values[0], ad.all_register_memory);
					array_data : int = ComputeMusicOperandValue(ci.operands[1].values[1], ad.all_register_memory);
					neume_array, err := GetMemArray(array_data, array_count, Neume, ad.ram_memory);
					if err.is_error return err;
					for neume_array {
						//TODO Eventually we can remove this conversion once we only have Neumes and remove MusicPoints.
						mp : MusicPoint = MakeMusicPoint(it.svara, it.row, it.x_start, it.x_end);
						new_mp : MusicPoint = TMovMusicPt(mp, CENTER_TANO, to_tano);
						CreateMusicPtInMemory(new_mp.music_pt_float, new_mp.row_index, new_mp.x_start_float, new_mp.x_end_float, to_neumes);
						// CreateMusicPtInMemory(it.svara, it.row, it.x_start, it.x_end, to_neumes);
						// CreateManyMusicPtsInMemory(from_values, row_index, to_t_norm.x_start, to_t_norm.x_end, to_neumes);
					}					
				}
			}
			}
		}
		/*NOTE : We don't actually use the ram array here since we just store the
		return address in t2a_settings but I guess we could store it int
		one of the values of the ram array.
		Maybe that is more confusing or less confusing... not sure.
		For now we set the return address on the stack with t2a_settings.
		We could even set the settings AND array type in the RamArray.
		RamArray is supposed to be .[count,data] where the data is where
		the data is in memory whereas this would be where the array is
		and the count would be something else so I find that confusing right now
		but maybe there is a good reason to do it later.
		COULD also do both if the t2a_settings is set to .NONE then we we grab from RamArray

		Doc : This can only be set to an array view now since we don't know
		how many music_pts will be in the tano beforehand. Eventually we could also
		allow resizable arrays if needed.
		*/
		case MusicOperandType.RAM_ARRAY; {
			from_address : int = ComputeRAMLocation(ci.operands[1], ad.all_register_memory, ad.ram_memory);
			from_tano, err := GetMemValue(from_address, tano, ad.ram_memory);
			if err.is_error return err;

			//TODO get operands[2] to allow for different array return types like MusicPoint
			//CAN ALSO specify if we want to update an already given resizable array as RAM_ARRAY
			//instead of making a new array
 			t2a_address, t2a_error := ComputeRAMLocationCheck(ci.operands[2], ad.all_register_memory, ad.ram_memory, 
 				size_of(TanoToArraySettings));
			if t2a_error.is_error return err;
			t2a_settings : *TanoToArraySettings = GetMemPtr(t2a_address, TanoToArraySettings, ad.ram_memory);

			mem_size : int;
			array_count : int;
			array_data : *u8;
			if t2a_settings.return_array_type == {
			case .DEFAULT; {
				if ci.instr_type == {
				case .INTEGER; {
					//TODO If we have an allocator for each instruction then we should set this to that allocator eventually.
					tano_music_pts : [] int = GetTanoMusicPts(from_tano, ad.all_mspace_data[0].all_music_pts, type=int);
					array_count = tano_music_pts.count;
					array_data = cast(*u8) tano_music_pts.data;
					mem_size = size_of(int) * tano_music_pts.count;
				}
				case .FLOAT; {
					tano_music_pts : [] float64 = GetTanoMusicPts(from_tano, ad.all_mspace_data[0].all_music_pts, type=float64);
					array_count = tano_music_pts.count;
					array_data = cast(*u8) tano_music_pts.data;
					mem_size = size_of(float64) * tano_music_pts.count;
				}
				}
			}
			case .NEUME; {
				//TODO Need to cleanup MusicPoint and add it to code before we can use this properly.
				tano_neumes : [] Neume = GetTanoMusicPts(from_tano, ad.all_mspace_data[0].all_music_pts, type=Neume);
				array_count = tano_neumes.count;
				array_data = cast(*u8) tano_neumes.data;
				mem_size = size_of(Neume) * tano_neumes.count;
			}
			}

			//Check everything is in memory first and then set the values.
			alloc_heap_address, out_of_memory := AllocHeapMem(mem_size, ad);
			if out_of_memory.is_error return out_of_memory;

			// in_bounds := MemoryInBounds(ad.ram_memory, t2a_settings.return_address, mem_size);
			// if in_bounds.is_error return err;

			heap_ptr : *u8 = GetMemory(alloc_heap_address, mem_size, ad.ram_memory);
			// if mem_error.is_error return mem_error; //Already check this with AllocHeapMem above
			memcpy(heap_ptr, array_data, mem_size);

			//We set the return array info here directly from the pointer of the input t2a_settings
			t2a_settings.return_array_count = array_count;
			t2a_settings.return_array_data = alloc_heap_address;
		}
		}
	}
	//TODO Could use tpmod as PosMod and then tmod as fmod_cycling
	// case OpCode.tpmod; #through;
	case OpCode.tmod; #through;
	case OpCode.tdiv; #through;
	case OpCode.tmul; #through;
	case OpCode.tsub; #through;
	case OpCode.tadd; {
		if ci.operands[2].operand_type == .NONE {
			tano_operand : MusicOperand;
			value_operand : MusicOperand;
			/*DOC : RAM_MEMORY is always a tano. Values are assumed to be passed in by register or immediate.
			We could put a setting instead and specify what the types are at some point if that makes things clearer.
			But then we would need a setting for each combination so this seems simpler overall.
			*/
			if ci.operands[0].operand_type == .RAM_MEMORY {
				tano_operand = ci.operands[0];
				value_operand = ci.operands[1];
			} else if ci.operands[1].operand_type == .RAM_MEMORY {
				tano_operand = ci.operands[1];
				value_operand = ci.operands[0];
			}
			//Else should be validate by ValidateMusicInstruction

			to_address : int = ComputeRAMLocation(tano_operand, ad.all_register_memory, ad.ram_memory);
			to_tano, err := GetMemValue(to_address, tano, ad.ram_memory);
			if err.is_error return err;

			to_neumes : [] MusicPoint = GetMSpaceNeumes(to_tano.mspace_start, ad).*;

			mv : MemoryValue = ComputeMemoryValue(value_operand, ad.all_register_memory, ad.ram_memory);
			fv, iv := MVToFVAndIV(mv, ci.instr_type);
			if ci.operands[0].operand_type == .RAM_MEMORY {
				for * mp : TanoLoop.{to_tano,to_neumes} {
					DirectionArithmeticOp(ci.op_code, mp.music_pt_float, fv, mp);
				}				
			} else if ci.operands[1].operand_type == .RAM_MEMORY {
				for * mp : TanoLoop.{to_tano,to_neumes} {
					DirectionArithmeticOp(ci.op_code, fv, mp.music_pt_float, mp);
				}
			}
		} 
		else if ci.operands[2].operand_type != .NONE {
			/*TODO I am not sure I want to leave this case. Maybe we don't allow it and have to do operations
			  in place and we just mov to negative row first and then apply operation and then move wherever.

			  The problem here is we move the music_pts BUT we can't filter them or anything whereas we can with 
			  tmov so then this would remain 1 way unless we do a .t_mode instruction and then adjust from there.

			  FOR NOW THIS IS UNTESTED UNLESS WE END UP USING IT IN CODE. OTHERWISE CAN REMOVE IT LATER
			*/
			//ci.operands[0] == .RAM_MEMORY from ValidateMusicInstruction
			to_address : int = ComputeRAMLocation(ci.operands[0], ad.all_register_memory, ad.ram_memory);
			to_tano, err := GetMemValue(to_address, tano, ad.ram_memory);
			if err.is_error return err;

			to_t_norm : tano = NormalizeTano(to_tano);

			from_tano_operand : MusicOperand;
			value_operand : MusicOperand;
			if ci.operands[1].operand_type == .RAM_MEMORY {
				from_tano_operand = ci.operands[1];
				value_operand = ci.operands[2];
			} else if ci.operands[2].operand_type == .RAM_MEMORY {
				from_tano_operand = ci.operands[2];
				value_operand = ci.operands[1];
			}
			//Else should be validate by ValidateMusicInstruction

			from_address : int = ComputeRAMLocation(from_tano_operand, ad.all_register_memory, ad.ram_memory);
			from_tano, from_err := GetMemValue(from_address, tano, ad.ram_memory);
			if from_err.is_error return from_err;

			mv : MemoryValue = ComputeMemoryValue(value_operand, ad.all_register_memory, ad.ram_memory);
			fv, iv := MVToFVAndIV(mv, ci.instr_type);
			//TODO FROM HERE I think make 1 loop here and then implement "~=" and move assignment code
			//and then write unit tests for "~="
			for * mp : TanoLoop.{from_tano,ad.all_mspace_data[0].all_music_pts} {
				new_mp : MusicPoint = TMovMusicPt(mp, from_tano, to_tano);
				if ci.operands[1].operand_type == .RAM_MEMORY {
					DirectionArithmeticOp(ci.op_code, new_mp.music_pt_float, fv, *new_mp);
				} else if ci.operands[2].operand_type == .RAM_MEMORY {
					DirectionArithmeticOp(ci.op_code, fv, new_mp.music_pt_float, *new_mp);
				}
				CreateMusicPtInMemory(new_mp, *ad.all_mspace_data[0].all_music_pts);
			}				
		}
	}
	//TODO diff as "\"
	// case OpCode.or; #through;
	// case OpCode.xor; #through;
	// case OpCode.and; #through;
	//TODO Maybe we should separate tshr and trol?
	case OpCode.trol; #through;
	case OpCode.tror; #through;
	case OpCode.tshl; #through;
	case OpCode.tshr; {
		to_address : int = ComputeRAMLocation(ci.operands[0], ad.all_register_memory, ad.ram_memory);
		to_tano, err := GetMemValue(to_address, tano, ad.ram_memory);
		if err.is_error return err;

		to_t_norm : tano = NormalizeTano(to_tano);

		mv : MemoryValue = ComputeMemoryValue(ci.operands[1], ad.all_register_memory, ad.ram_memory);
		shft_dist, iv := MVToFVAndIV(mv, ci.instr_type);
		//TODO Could let operand_1 be an array and then we can grab or move along both x and y.
		//ACTUALLY we could make operand_1 music memr and then <row,x> would correspond to how we move along the row and x
		//and then we just have to add row shiftin and row rotating code here
		//OR have a separate instruction
		//ACTUALLY I think a separate instruction would be better so we can decide which order to want to shift
		//or rotate, meaning whether we want to do x and then row or row and then x.
		//TODO IMPORTANT MAKE A ROW SHIFT AND ROW ROTATING INSTRUCTION SO WE CAN DO THE SAME THING WITH ROW IN A TANO
		//TODO this could be a float if we allow x axis to be float eventually...
		lower_bound : float64 = to_t_norm.x_start;
		upper_bound : float64 = to_t_norm.x_end;
		//TODO I think this is correct now. Need to check with some rotate tests.
		//Upper and lower were already normalized from to_t_norm.
		norm_bound : float64 = upper_bound - lower_bound;
		// norm_bound : float64 = TanoXLength(to_t_norm);
		// range_size : float64 = TanoXLength(to_t_norm);
		for * mp : TanoLoop.{to_tano,ad.all_mspace_data[0].all_music_pts} {
			if ci.op_code == {
			//TODO Could pull this out into a function if we need to reuse the logic.
			case OpCode.tshr;
				//TODO What if we go over the row_size? Do we even want row_size or do we want it to just match
				//the max note count anyways and then we adjust that by checking before rendering or playing audio?
				//OR MAYBE we just allow it but we don't render or play it. This allows us to shift and have notes
				//appear and also resize the tano and have notes appear immediately which i like conceptually
				//but maybe in practice it does not work seamlessly.
				mp.x_start_float += shft_dist;
				mp.x_end_float += shft_dist;
			case OpCode.tshl;
				//TODO What should we do if this goes below 0? Should we allow it, clamp it or just remove it?
				//Could allow a setting that decides that.
				//I think leaving it and allowing negative is a good default BUT we need to make sure this
				//works properly for both audio and rendering when we have negative values.
				mp.x_start_float -= shft_dist;
				mp.x_end_float -= shft_dist;
			case OpCode.tror; #through;
			case OpCode.trol;
				norm_start : float64 = mp.x_start_float - lower_bound;
				shifted_value : float64;
				if ci.op_code == {
				//TODO Could have a version with RAM_ARRAY where each value is shifted by different distances
				//based on the RAM_ARRAY.
				case OpCode.tror; shifted_value = norm_start + shft_dist;
				case OpCode.trol; shifted_value = norm_start - shft_dist;
				}
				//NOTE : Compute the mp_length first before we update x_start
				mp_length : float64 = Length(mp);
				mp.x_start_float = lower_bound + PosMod(shifted_value, norm_bound);
				mp.x_end_float = mp.x_start_float + mp_length;
			}
			mp.x_start = round_to_int(mp.x_start_float);
			mp.x_end = round_to_int(mp.x_end_float);

			//TODO We could put a setting in operands[2] to cut notes on the boundaries or 
			//remove from outside of shift for example
		}
	}
	case OpCode.cgt;  #through;
	case OpCode.clt;  #through;
	case OpCode.cgte; #through;
	case OpCode.clte; #through;
	case OpCode.cneq; #through;
	case OpCode.ceq; {
		assert(ci.operands[0].operand_type != .NONE && ci.operands[1].operand_type != .NONE);
		if ci.operands[0].operand_type == {
		case .RAM_MEMORY; #through;
		case .REGISTER; {
			//TODO Verify valid types and return error for use. These error cases should also be tested for.
			//TODO This can only be register or ram. Need to validate and test
			v1 : MemoryValue;
			v2 : MemoryValue;
			if ci.operands[2].operand_type != .NONE {
				v1 = ComputeMemoryValue(ci.operands[1], ad.all_register_memory, ad.ram_memory);
				v2 = ComputeMemoryValue(ci.operands[2], ad.all_register_memory, ad.ram_memory);
			} else {
				v1 = ComputeMemoryValue(ci.operands[0], ad.all_register_memory, ad.ram_memory);
				v2 = ComputeMemoryValue(ci.operands[1], ad.all_register_memory, ad.ram_memory);
			}

			compare : bool;
			if ci.instr_type == .INTEGER {
				if ci.op_code == {
				case OpCode.cgt;  compare = v1.int_value > v2.int_value;
				case OpCode.clt;  compare = v1.int_value < v2.int_value;
				case OpCode.cgte; compare = v1.int_value >= v2.int_value;
				case OpCode.clte; compare = v1.int_value <= v2.int_value;
				case OpCode.ceq;  compare = v1.int_value == v2.int_value;
				case OpCode.cneq; compare = v1.int_value != v2.int_value;
			   }
			} else if ci.instr_type == .FLOAT {
				if ci.op_code == {
				case OpCode.cgt;  compare = v1.float_value > v2.float_value;
				case OpCode.clt;  compare = v1.float_value < v2.float_value;
				case OpCode.cgte; compare = v1.float_value >= v2.float_value;
				case OpCode.clte; compare = v1.float_value <= v2.float_value;
				//TODO Need to update these functions so it's not dependent on absolute epsilon
				case OpCode.ceq;  compare = Float64Equal(v1.float_value, v2.float_value);
				case OpCode.cneq; compare = !Float64Equal(v1.float_value, v2.float_value);
			   }
			}

		   //TODO Do we want to use this or only have the register we place it in?
		   //We are copying x86 and arm here but I don't know if it's useful.
		   //Maybe we will see why with language work. Doing both for now in case.
		   //TODO If we do this it should just be a regular register. BUT we store it in a register now so why have this at all?
		   ad.cpu_state.comparison_register = compare;

			/*TODO Could have 2 operand put it directly in the .cr comparison register if that is more convenient.
			  This is how they do it in x86 and arm, but im not sure if they do it for purely space efficiency
			  purposes or if there is another reason. It feels like have tjmp and fjmp to any register/memory
			  is clearer in general and also easier to debug.
			*/
		   int_compare : int = cast(int) compare;
			if ci.operands[0].operand_type == {
			case MusicOperandType.REGISTER;
				ad.all_register_memory[ci.operands[0].int_value].int_value = int_compare;
			case MusicOperandType.RAM_MEMORY;
		    	mem_address : int = ComputeRAMLocation(ci.operands[0], ad.all_register_memory, ad.ram_memory);
		    	SetRAMValue(mem_address, int_compare, *ad.ram_memory);
				// memcpy(*ad.ram_memory.bytes[mem_address], *int_compare, size_of(int));
			case;
				print("Invalid operand_0 on instruction : %\n", ci);
			}
		} 
		case .MUSIC_MEMORY;
			//TODO Should we do comparisons for MUSIC_MEMORY. Could have a default and then maybe
			//some options to switch. Best to check here as there are different comparison methods.

			//TODO Should we allow music_memory comparisons for ceq and cneq?
			//since we can compare all the notes directly or do we let the player
			//create a compare chord function? Maybe compare chord makes more 
			//sense since do we want them to be the same or modulo the same?
			//Or maybe some other criteria for sameness?
		case;
			//TODO Error we shuld not have this as operand_0 for comparison instructions
		}
	}
	/*TODO We should only allow these instructions to be valid within a single ASM_SCOPE
	this way we can check all labels and jmp range within the Assembler. Usually we would
	just jmp to a label, but we can also add relative jump instructions (jr, tjr, fjr)
	so that we can jmp variable amounts if desired. This would all remain within a single
	ASM_SCOPE. Allowing outside would get out of hand. Technically they could mov something
	into the .pc reg but maybe we prevent that or people can do it at their own risk.

	DOCUM : A branch instruction always has the jmp index at operands[0] and the conditional
	check at operands[1]. 
	This is used for example in the debugger to get the FunctionDeclaration from the call instruction so
	we can add it to the debug_call_stack.
	*/
	//TODO A .call for function calls is useful to store the stack trace.
	case OpCode.call; #through;
	case OpCode.tjmp; #through;
	case OpCode.fjmp; #through;
	case OpCode.jmp; {
		//.call and .jmp are unconditional jumps
		should_jump : bool = true;
		if ci.op_code == .tjmp || ci.op_code == .fjmp {
			cr_value : int;
			//TODO Can remove this case if we don't really use the .cr register overall.
			if ci.operands[1].operand_type == .NONE {
				cr_value = ad.all_register_memory[RegDef.cr].int_value;
			} else {
				cr_value = ComputeOperandInt(ci.operands[1], ad.all_register_memory, ad.ram_memory);
			}

			cr_bool : bool = cast(bool) cr_value;
			if ci.op_code == {
			case OpCode.tjmp; should_jump = cr_bool;
			case OpCode.fjmp; should_jump = !cr_bool;
			}
		}

		//TODO Not sure if we should do relative or absolute addressing. Relative seems better overall,
		//since then we can move asm code chunks around without having to change the jmp addresses.
		//Also technically it is better for linking for the same reason although it is likely that I
		//will just copy code over to one place and compile everything together.
		//Although asm will be jumping to labels and code will be generated anyways. We have to check
		//for negative values anyways here and return an error if it is negative.
		//Maybe absolute addressing would make things easier to debug overall. I could do absolute since
		//it seems easier but put it in a function in case we change to relative later for some reason...
		//TODO Could add a jmpr/jr/jrel instructon for relative address branch if needed.
		if should_jump {
			//TODO We could just do .ret in here so all the jmp code is in 1 place
			next_instr : int = ComputeOperandInt(ci.operands[0], ad.all_register_memory, ad.ram_memory);
			//TODO Should also check < all_music_instructions.count once we know where all instruction array is
			if next_instr < 0 || next_instr >= ad.all_music_instructions.count {
				err.is_error = true;
				err.msg = sprint("Branch address out of bounds : %. Max = %\n", 
					ci.operands[0], ad.all_music_instructions.count-1);
				return err;
			}
			ad.all_register_memory[RegDef.pc].int_value = next_instr;
			// ad.all_register_memory[RegDef.pc].int_value = ad.all_register_memory[RegDef.ir].int_value + next_instr;
		}
	}
	/*TODO Could make .tlen to adjust all neumes in a tano to a specific length 
	and can also allow all values above or below certain y or just do that in tmov
	*/
	case OpCode.mlen; {
		assert(ci.operands[0].operand_type != .NONE && ci.operands[1].operand_type != .NONE);

		//TODO We could have the 3rd operand specify a point but I guess it would be arbitrary vertical.
		//But that could still be useful.
		operand_1 : MusicOperand = ci.operands[0];
		operand_2 : MusicOperand = ci.operands[1];

		music_pt_length : int = operand_2.int_value;
		//TODO Should we delete the music_pts if length == 0?
		//or just not allow it at compile-time?
		assert(music_pt_length > 0);

		row_index, x_index := MusicMemRowAndXIndex(operand_1,
			ad.all_register_memory,
			ad.global_rules.row_size);

		//TODO Need to redo this with the new x_start_float
		#if 0 {
		array_x_start_music_pts : [] *MusicPoint =
			ArrayFindAllPointersByAndOp(ad.all_mspace_data[0].all_music_pts,
				x_index, "x_start",
				row_index, "row_index", temp);

		//TODO What should we do about overlapping notes? Could leave it and have the synthesizer
		//and audio output adjust it based on volume so we would still hear the new note play.
		if array_x_start_music_pts.count > 0 
		{
			new_x_end : int = array_x_start_music_pts[0].x_start + music_pt_length;
			// We check > and not >= because we go until the next memory_dspace to mark the end of the length
			if new_x_end > ad.global_rules.row_size {
				//TODO Make this error better once we have line_number and also should be able to show
				//error in the memory like highlight the memory_mps and the music_pt and debug stop.
				print("Runtime error : mlen % exceeds row_size %.\n", music_pt_length, ad.global_rules.row_size);
				// break; //TODO Should we break at runtime errors for now?
			} 
			else {
				//TODO Could SIMD this once we decide on x_end types
				for music_pt : array_x_start_music_pts {
					music_pt.x_end = new_x_end;
				}
			}
		}
		}
	}
	/*DOC : Ret is a jmp to PROC_RETURN_OP AND srp = sbp AND pop sbp from stack memory back to the register 
	We reset the sbp here so that after a return instruction, the stack is in the right
	place but we still pop all other registers after. We could pop everything here but then
	we don't have an instruction to go back to on returning from a function to be on the same line for the debugger.
	So this is all done for debugging simplicity. 
	Also seems like in jai, rsp is popped before ret and other registers after the call.
	IF WE UPDATE THIS, then we need to think about debugging and make sure we can jmp back to the same line
	on return from a function and that the sbp is properly set so all the data we see in the debugger is correct
	based on the function that we are currently in.

	ANOTHER OPTION is to pop all registers here on ret so then everything is reset when we get back. The problem
	there is that then we may not have an instruction on the same line to come back to. We could leaven an empty instruction
	there but this seems more consistent overall.
	*/
	case OpCode.ret; {
		//TODO WE could put this with .jmp instruction to avoid having differences in jmp code.
		//TODO WRITE TESTS FOR THIS AND ALSO push_all_stack_reg AND pop_all_stack_reg before using functions
		//TODO it can be used for debugging to pop from the function call stack as well.
		//ACTUALLY PROBABLY can just do the debugging through the debugger code when we see a .ret instructions.
		//.ret is just short for jmp [sbp,-8] 
		next_instr : int = ComputeOperandInt(PROC_RETURN_OP, ad.all_register_memory, ad.ram_memory);
		//TODO Should check if > all_music_instructions.count just don't know where all the instructions are coming from yet.
		//If from ExecutionInfo, then either pass that in or an id to it.
		if next_instr < 0 {
			err.is_error = true;
			err.msg = sprint("Branch address must be >= 0 : %.\n", ci.operands[0]);
			return err;
		}
		ad.all_register_memory[RegDef.pc].int_value = next_instr;

		/*TODO this currently only copies .sbp, but if we want to copy more then we just have to increase
		1 * size_of(MemoryValue) eg if we want to copy sbp, scp, ...
		maybe tpb (probably not tbp since we reset it after the call anyways, check tests for this in case we do) 

		LIKELY just leave it this way since now we reset all the other registers with srp instead
		so that we can reset the sbp on return and then see the correct values on return in the debugger.
		I left the old code lying around in case we watn to reset it later more easily this is also compile outable.
		the old PREVIOUS_SBP_OP is also next to the new one.
		*/
		#if 1 {
		//DOC : We set this first so then we use srp from here on to retrieve old registers on the stack.
		ad.all_register_memory[RegDef.srp].int_value = ad.all_register_memory[RegDef.sbp].int_value;

		//We just put the sbp back on here so that we can see the correct function values when returning from a function.
		//We do this again with pop_all_stack_reg but this way feels natural when using the debugger.
		stack_reg_memory := array_view(ad.all_register_memory, push_pop_start_reg_index);	
		reg_mem_pointer := cast(*u8) stack_reg_memory.data;
		ram_location : int = ComputeRAMLocation(PREVIOUS_SBP_OP, ad.all_register_memory, ad.ram_memory);
		ram_pointer, mem_error := GetMemPtr(ram_location, MemoryValue, ad.ram_memory);
		if mem_error.is_error return mem_error;
		memcpy(reg_mem_pointer, ram_pointer, 1 * size_of(MemoryValue));
		}
	}
	//TODO Should we rename this malloc to differentiate from jai alloc?
	case OpCode.alloc; {
		//TODO Need to add op checks to prevent the usage of float for operand[0] here
		mem_v : MemoryValue = ComputeMemoryValue(ci.operands[0], ad.all_register_memory, ad.ram_memory);
		//TODO Could do a free list for memory management.
		alloc_heap_address, out_of_memory := AllocHeapMem(mem_v.int_value, ad);
		if out_of_memory.is_error return out_of_memory;

		if ci.operands[1].operand_type == {
		case MusicOperandType.RAM_MEMORY;
	    	mem_address : int = ComputeRAMLocation(ci.operands[1], ad.all_register_memory, ad.ram_memory);
	    	SetRAMValue(mem_address, alloc_heap_address, *ad.ram_memory);
		case MusicOperandType.REGISTER; 
			reg_v : int = ci.operands[1].values[0].int_value;
			ad.all_register_memory[reg_v].int_value = alloc_heap_address;
		case;
			//Default to setting to .hrp register so we don't need to crash or something like that.
			ad.all_register_memory[RegDef.hrp].int_value = alloc_heap_address;
		}
	}
	case OpCode.free; {
		//TODO We could add this to a free list so we can reuse later if possible.
	}
	case OpCode.itof; #through;
	case OpCode.ftoi; {
		mem_v : MemoryValue = ComputeMemoryValue(ci.operands[1], ad.all_register_memory, ad.ram_memory);
		if ci.op_code == {
		case OpCode.itof; mem_v.float_value = cast(float64) mem_v.int_value;
		case OpCode.ftoi; mem_v.int_value = cast(int) mem_v.float_value;
		}

		//NOTE : Other cases are not valid and checked in ValidateMusicInstruction.
		if ci.operands[0].operand_type == {
		case MusicOperandType.RAM_MEMORY;
	    	mem_address : int = ComputeRAMLocation(ci.operands[0], ad.all_register_memory, ad.ram_memory);
	    	SetRAMValue(mem_address, mem_v, *ad.ram_memory);
		case MusicOperandType.REGISTER;
			ad.all_register_memory[ci.operands[0].int_value] = mem_v;
		}
	}
	case OpCode.s_print; {
		//TODO Can make a compiler sprint function for convenience if that's good.
		//But I kind of want to discourage using strings so people think more in terms of math and sound.
		//NOTE : These types are all checked in ValidateMusicInstruction
		//This is a string (count:int,data:*void/int)
		err : CPUError;
    	string_address : int = ComputeRAMLocation(ci.operands[0], ad.all_register_memory, ad.ram_memory);
		string_count := GetMemValue(string_address, int, ad.ram_memory);
		//NOTE: We only check second address since the first is checked in ValidateMusicOperand
		string_data, err= := GetMemValue(string_address+8, int, ad.ram_memory);
		if err.is_error return err;

		actual_string : string;
		actual_string.count = string_count;
		actual_string.data, err = GetMemory(string_data, string_count, ad.ram_memory);
		if err.is_error return err;

    	//This is an array of strings, args of s_print
    	args_array_address : int = ComputeRAMLocation(ci.operands[1], ad.all_register_memory, ad.ram_memory);
    	//TODO Could make a GetMemCountData if this is reused often but it is only 2 loc so maybe not.
    	args_array_count : int = GetMemValue(args_array_address, int, ad.ram_memory);
    	args_array_data, err= := GetMemValue(args_array_address+8, int, ad.ram_memory);
    	if err.is_error return err;

    	//TODO This should use the cpu allocator which we should reset after every instruction.
    	//Using temp for now since we want to clear it after the frame.
 		string_size :: 16;
    	actual_strings : [] string = NewArray(args_array_count, string,,temp);
    	for 0..args_array_count-1 {
    		next_arg : int = args_array_data + it * string_size;
    		bounds_err := MemoryInBounds(ad.ram_memory, next_arg, string_size);
    		if bounds_err.is_error return bounds_err;

    		actual_strings[it].count = GetMemValue(next_arg, int, ad.ram_memory);
			next_arg_data : int = GetMemValue(next_arg+8, int, ad.ram_memory);
    		actual_strings[it].data, err = GetMemory(next_arg_data, actual_strings[it].count, ad.ram_memory);
    		if err.is_error return err;
    	}

    	//NOTE:Since the string is stored on the stack, we have to store it in the heap and then copy it here
    	//so that then it can actually be used directly in sprint() as a [] Any since any contains a pointer.
    	actual_any_args := NewArray(args_array_count, Any,,temp);
    	for actual_strings actual_any_args[it_index] = it;
    	//TODO Should set this in cpu allocator once we use that instead
    	new_string := sprint(actual_string, ..actual_any_args,,temp);

		alloc_heap_address, out_of_memory := AllocHeapMem(new_string.count, ad);
		if out_of_memory.is_error return out_of_memory;

		//TODO We don't need both mem_checks but leaving here for resilience.
		heap_string_ptr := GetMemory(alloc_heap_address, new_string.count, ad.ram_memory);
		// if mem_error.is_error return mem_error;
		memcpy(heap_string_ptr, new_string.data, new_string.count);

    	return_address : int = ComputeRAMLocation(ci.operands[2], ad.all_register_memory, ad.ram_memory);
		in_bounds := MemoryInBounds(ad.ram_memory, return_address, new_string.count);
		if in_bounds.is_error return err;
    	SetRAMValue(return_address, new_string.count, *ad.ram_memory);
    	SetRAMValue(return_address+8, alloc_heap_address, *ad.ram_memory);
	}
	//TODO I think we can remove this now with creating mspaces and runtime settings
	// case OpCode.setup_music; {
	// 	mem_address : int = ComputeRAMLocation(ci.operands[0], ad.all_register_memory, ad.ram_memory);
	// 	setup_music_data, err := GetMemValue(mem_address, SetupMusicData, ad.ram_memory);
	// 	if err.is_error return err;

	// 	SetupMusic(ad, setup_music_data);
	// }
	/*DOC : If we eventually add other synth types, then we can grab by type here and then
	get the struct like AsmGetOrCreateSimpleSynthData or AsmGetOrCreateSubtractiveSynthData can have the same
	first 2 values like id and synth_type
	BUT this depends on how we structure it so I will till we do it.
	We can also get the old op codes temporarily so people can change the names and then update this to
	get_or_create_synth instead of this. But since we don't use the subtractive synth yet and maybe 
	we just add the custom synths with dynamic libraries eventually, maybe that is best.
	*/
	case OpCode.get_or_create_simple_synth; {
		mem_address : int = ComputeRAMLocation(ci.operands[0], ad.all_register_memory, ad.ram_memory);
		asm_data, err := GetMemPtr(mem_address, AsmGetOrCreateSimpleSynthData, ad.ram_memory);
		if err.is_error return err;

		gc_data : GetOrCreateSimpleSynthData;
		gc_data.synth_name, err = AsmStringToString(asm_data.synth_name, ad.ram_memory);
		if err.is_error return err;
		synth : *SimpleSynth = GetOrCreateSimpleSynth(gc_data, *ad.all_simple_synths, *ad.free_simple_synth_pool);
		asm_data.ret_synth_id = synth.synth_id;
	}
	case OpCode.update_simple_synth; {
		mem_address : int = ComputeRAMLocation(ci.operands[0], ad.all_register_memory, ad.ram_memory);
		asm_data, err := GetMemValue(mem_address, AsmUpdateSimpleSynthData, ad.ram_memory);
		if err.is_error return err;

		update : UpdateSimpleSynthData;
		update.synth_id = asm_data.synth_id;
		update.update_synth_name = AsmBoolToBool(asm_data.update_synth_name);
		update.synth_name, err = AsmStringToString(asm_data.synth_name, ad.ram_memory);
		if err.is_error return err;
		update.update_volume = AsmBoolToBool(asm_data.update_volume);
		update.volume = cast(float) asm_data.volume;
		update.update_wave_type = AsmBoolToBool(asm_data.update_wave_type);
		update.wave_type = asm_data.wave_type;
		update.update_attack_seconds = AsmBoolToBool(asm_data.update_attack_seconds);
		update.attack_seconds = cast(float) asm_data.attack_seconds;
		update.update_attack_curve = AsmBoolToBool(asm_data.update_attack_curve);
		update.attack_curve = cast(float) asm_data.attack_curve;
		update.update_release_seconds = AsmBoolToBool(asm_data.update_release_seconds);
		update.release_seconds = cast(float) asm_data.release_seconds;
		update.update_release_curve = AsmBoolToBool(asm_data.update_release_curve);
		update.release_curve = cast(float) asm_data.release_curve;

		synth, success, msg := UpdateSimpleSynth(update, ad.all_simple_synths);
		if !success return CPUErr(msg);
	}
	case OpCode.delete_simple_synth; {
		mem_address : int = ComputeRAMLocation(ci.operands[0], ad.all_register_memory, ad.ram_memory);
		asm_data, err := GetMemValue(mem_address, AsmDeleteSimpleSynthData, ad.ram_memory);
		if err.is_error return err;

		del : DeleteSimpleSynthData;
		del.synth_id = asm_data.synth_id;

		success, msg := DeleteSimpleSynth(del, *ad.all_simple_synths, *ad.free_simple_synth_pool);
		if !success return CPUErr(msg);
	}
	case OpCode.delete_all_synths; {
		DeleteAllSynths(*ad.all_simple_synths, *ad.free_simple_synth_pool);
	}
	case OpCode.get_tuning_system; {
		mem_address : int = ComputeRAMLocation(ci.operands[0], ad.all_register_memory, ad.ram_memory);
		asm_data, err := GetMemPtr(mem_address, AsmGetTuningSystemData, ad.ram_memory);

		short_name : string = AsmStringToString(asm_data.short_name, ad.ram_memory);

		tuning_system, found_tuning_system := ArrayFindFirstByNameId(ad.all_tuning_systems,	
			short_name, "short_name");
		if found_tuning_system {
			asm_data.ret_tuning_system_id = tuning_system.id;
		} else {
			return CPUErr(tprint("Tuning system % not found.", short_name));
		}
	}
	case OpCode.create_tuning_system; {
		//TODO FROM HERE Create equal temperament or ratio or linear from start tuning system
		//Make sure that data is consistent like music_pt_count and number of tuning pitches and anything else
		mem_address : int = ComputeRAMLocation(ci.operands[0], ad.all_register_memory, ad.ram_memory);
		asm_data, err := GetMemPtr(mem_address, AsmCreateTuningData, ad.ram_memory);
		if err.is_error return err;

		tuning_name, name_err := AsmStringToString(asm_data.name, ad.ram_memory);
		if name_err.is_error return name_err;
		short_name, short_err := AsmStringToString(asm_data.short_name, ad.ram_memory);
		if short_err.is_error return short_err;

		tuning_system, found_tuning_system := ArrayFindFirstConstByNameId(ad.all_tuning_systems,	
			short_name, "short_name");	
		if !found_tuning_system {
			create_t : CreateTuningData;
			create_t.name = tuning_name;
			create_t.short_name = short_name;
			create_t.compass_interval = asm_data.compass_interval;
			if asm_data.create_tuning_type != .EQUAL_TEMPERAMENT {
				tuning_values, err := GetAsmArray(asm_data.values, ad.ram_memory);
				if err.is_error return err;
				create_t.values = tuning_values;
			}

			if asm_data.create_tuning_type == {
			case .EQUAL_TEMPERAMENT; {
				tuning_system = CreateEqualTemperedTuningSystem(create_t.name, create_t.short_name,
					asm_data.point_count, create_t.compass_interval,
					*ad.all_tuning_systems, *ad.all_tuning_pitches);
			}
			case .RATIOS_FROM_START; {
				tuning_system = CreateTuningSystemFromStart(create_t, *ad.all_tuning_systems, *ad.all_tuning_pitches);
			}
			case .RATIOS_TO_NEXT; {
				tuning_system = CreateTuningSystemToNext(create_t, *ad.all_tuning_systems, *ad.all_tuning_pitches);
			}
			case .LINEAR_FROM_START; {
				tuning_system = CreateTuningSystemFromStart(create_t, *ad.all_tuning_systems, *ad.all_tuning_pitches, is_ratio=false);
			}
			case .LINEAR_TO_NEXT; {
				tuning_system = CreateTuningSystemToNext(create_t, *ad.all_tuning_systems, *ad.all_tuning_pitches, is_ratio=false);
			}
			}
		}
		asm_data.ret_tuning_system_id = tuning_system.id;
	}
	case OpCode.reset_default_tuning_systems; {
		//TODO Should this be an op code or just a terminal command or both?
		array_reset_keeping_memory(*ad.all_tuning_systems);
		array_reset_keeping_memory(*ad.all_tuning_pitches);
		CreateDefaultTuningSystems(*ad.all_tuning_systems, *ad.all_tuning_pitches);
	}
	//TODO FROM HERE check row audio types with synths and use that and then check midi data from here
	case OpCode.create_row; {
		mem_address : int = ComputeRAMLocation(ci.operands[0], ad.all_register_memory, ad.ram_memory);
		asm_data, err := GetMemPtr(mem_address, AsmCreateRowData, ad.ram_memory);
		if err.is_error return err;
		crd : CreateRowData;
		//TODO Should we make these float64 instead so we don't lose information?
		crd.octave_height = cast(float) asm_data.octave_height;
		crd.row_height = cast(float) asm_data.row_height;
		crd.row_base_pt = cast(float) asm_data.row_base_pt;
		crd.muted_row = AsmBoolToBool(asm_data.muted_row);
		crd.row_system_type = asm_data.row_system_type;
		crd.row_system_id = asm_data.row_system_id;
		crd.row_sub_system_id = asm_data.row_sub_system_id;
		crd.row_section_data, err = GetAsmArray(asm_data.row_sections, ad.ram_memory);
		if err.is_error return err;
		crd.row_midi_data.midi_channel = cast(u8) asm_data.row_midi_data.midi_channel;
		crd.row_midi_data.midi_velocity = cast(u8) asm_data.row_midi_data.midi_velocity;
		crd.row_midi_data.midi_control_change = cast(u8) asm_data.row_midi_data.midi_control_change;
		CreateMusicRow(crd, ad);
	}
	case OpCode.get_or_create_mspace; {
		mem_address : int = ComputeRAMLocation(ci.operands[0], ad.all_register_memory, ad.ram_memory);
		asm_data, err := GetMemValue(mem_address, AsmGetOrCreateMSpaceData, ad.ram_memory);
		if err.is_error return err;

		gcmd : GetOrCreateMSpaceData;
		gcmd.gc_type = asm_data.gc_type;
		gcmd.mspace_index = asm_data.mspace_index;
		gcmd.mspace_id = asm_data.mspace_id;
		gcmd.mspace_name, err = AsmStringToString(asm_data.mspace_name, ad.ram_memory);
		if err.is_error return err;

		//TODO Convert from asm to create here and do same for update below so we can update each invidivual mspace at runtime
		mspace_data : *MusicSpaceData = GetOrCreateMusicSpace(gcmd, ad.runtime_settings, *ad.all_mspace_data, *ad.free_mspace_data_pool);
		asm_data.ret_mspace_id = mspace_data.mspace_id;
	}
	case OpCode.update_mspace; {
		mem_address : int = ComputeRAMLocation(ci.operands[0], ad.all_register_memory, ad.ram_memory);
		asm_data, err := GetMemValue(mem_address, AsmUpdateMSpaceData, ad.ram_memory);
		if err.is_error return err;

		umd : UpdateMSpaceData;
		umd.mspace_id = asm_data.mspace_id;
		umd.update_mspace_index = AsmBoolToBool(asm_data.update_mspace_index);
		umd.mspace_index = asm_data.mspace_index;
		umd.update_mspace_name = AsmBoolToBool(asm_data.update_mspace_name);
		umd.mspace_name, err = AsmStringToString(asm_data.mspace_name, ad.ram_memory);
		if err.is_error return err;
		umd.update_tano_x_unit_width = AsmBoolToBool(asm_data.update_tano_x_unit_width);
		umd.tano_x_unit_width = asm_data.tano_x_unit_width;
		umd.update_mspace_audio_row_size = AsmBoolToBool(asm_data.update_mspace_audio_row_size);
		umd.set_fixed_audio_row_size = AsmBoolToBool(asm_data.set_fixed_audio_row_size);
		umd.mspace_audio_row_size = asm_data.mspace_audio_row_size;

		//TODO Pass in a execution allocator that gets reset after every execution
		//so we can store anything in there and then just reset
		//UNLESS we put cpu error in temp storage and copy it wherever we output it to afterwards.
		mspace, success, msg := UpdateMusicSpace(umd, ad.runtime_settings, *ad.all_mspace_data);
		if !success return CPUErr(msg);
	}
	case OpCode.delete_mspace; {
		mem_address : int = ComputeRAMLocation(ci.operands[0], ad.all_register_memory, ad.ram_memory);
		asm_data, err := GetMemValue(mem_address, AsmDeleteMSpaceData, ad.ram_memory);
		if err.is_error return err;

		dmd : DeleteMSpaceData;
		dmd.mspace_id = asm_data.mspace_id;

		success, msg := DeleteMusicSpace(dmd, *ad.all_mspace_data, *ad.free_mspace_data_pool);
		if !success return CPUErr(msg);
	}
	case OpCode.clear_mspace; {
		mem_address : int = ComputeRAMLocation(ci.operands[0], ad.all_register_memory, ad.ram_memory);
		asm_data, err := GetMemValue(mem_address, AsmClearMSpaceData, ad.ram_memory);
		if err.is_error return err;

		//TODO Should this be by index or ID? I guess we can do either or
		dmd : ClearMSpaceData;
		dmd.mspace_id = asm_data.mspace_id;

		success, msg := ClearMusicSpace(dmd, *ad.all_mspace_data);
		if !success return CPUErr(msg);
	}
	case OpCode.get_or_create_op_space; {
		//TODO We would have to validate the values here before pulling them since the player will be
		//placing them and could make errors.
		mem_address : int = ComputeRAMLocation(ci.operands[0], ad.all_register_memory, ad.ram_memory);

		//TODO Which one of these is better? GetMemValue does an out of ram bounds and null check.
		// space_data := cast(*AsmOpSpaceData) *ad.ram_memory.bytes[mem_address];
		asm_data, err := GetMemPtr(mem_address, AsmOpSpaceData, ad.ram_memory);
		if err.is_error return err;

		//TODO In order to store strings, we either want to set them in their own data with all the strings
		//or we reduce or data array to general u8 data and then store string directly in memory.
		//We could also have a separate general u8 memory where the strings are stored but which can
		//be used for anything else as well.
		#if 1 {
		name_string, name_err := AsmStringToString(asm_data.op_space_name, ad.ram_memory);
		if name_err.is_error return name_err;
		} else {
			name_string : string;
			name_string.count = asm_data.op_space_name.count;

			name_ptr, name_err := GetMemory(asm_data.op_space_name.data_address, name_string.count, ad.ram_memory);
			if name_err.is_error return name_err;
			name_string.data = name_ptr;
		}

		op_space, found_op_space := FindOpSpacePointerOpenOrClosed(name_string, 
			ad.all_open_op_spaces, ad.all_closed_op_spaces);
		if !found_op_space {
			cosd : CreateOpSpaceData;
			cosd.op_space_name = copy_string(name_string);
			cosd.op_space_external_type = AsmOpSpaceToExternalType(asm_data.op_space_type);
			//TODO We could allow setting offset here and also fixed to mspace so then the whole
			//music space can be setup in 1 shot. This would also be possible through dynamic libraries
			// cosd.world_offset = ;
			cosd.world_size = ad.runtime_settings.default_op_space_size;
			op_space = CreateClosedOpSpace(cosd, 
				*ad.all_closed_op_spaces, 
				*ad.all_op_space_spec_data, 
				*ad.all_op_spec_data_3D);
		}

		//Set the op space id here as a return value
		asm_data.ret_op_space_id = op_space.id;
	}
	case OpCode.clear_op_space; {
		mem_address : int = ComputeRAMLocation(ci.operands[0], ad.all_register_memory, ad.ram_memory);
		asm_clear_data, err := GetMemValue(mem_address, AsmClearOpData, ad.ram_memory);
		if err.is_error return err;

		clear_data : ClearOpSpaceData;
		clear_data.op_space_id = asm_clear_data.op_space_id;
		clear_data.clear_not_filter_3D = AsmBoolToBool(asm_clear_data.clear_not_filter_3D);

		//TODO FROM HERE pull this out to clear op space and then test its works as a function
		//with a test to clear and have a different filter or something
		//then maybe a test changing dims and then do it with asm and then make code
		//RESIZABLE 3d op spaces should update size properly with frustum and other 3d data
		ClearOpSpace(clear_data,
			ad.all_open_op_spaces,
			ad.all_closed_op_spaces,
			ad.all_op_space_spec_data,
			ad.all_op_spec_data_3D);
	}
	//TODO FROM HERE put circle data and shapes in op space specific data 
	case OpCode.create_circle; {
		mem_address : int = ComputeRAMLocation(ci.operands[0], ad.all_register_memory, ad.ram_memory);
		//TODO We could make adding it to an op_space optional. This way we can add the same circle to many op_space if needed.
		asm_data, err := GetMemPtr(mem_address, AsmCircleData, ad.ram_memory);
		if err.is_error return err;

		op_spec_data, found_op_spec_data := ArrayFindFirstByNameId(ad.all_op_space_spec_data,
			asm_data.op_space_id, "op_space_id");
		if !found_op_spec_data {
			return CPUErr(sprint("op_space_id % data not found.\n", asm_data.op_space_id));
		}

		tuning_system, found_tuning_system := 
			ArrayFindFirstByNameId(ad.all_tuning_systems, asm_data.tuning_system_id, "id");
		if !found_tuning_system {
			return CPUErr(sprint("tuning_system_id % not found.\n", asm_data.tuning_system_id,,context.allocator));
		}

		c_data : CreateCircleSpaceData;
		c_data.radius = cast(float) asm_data.radius;
		c_data.world_center = MakeV2FFrom64(asm_data.world_center);
		c_data.rotate_theta = cast(float)asm_data.rotate_theta;
		c_data.point_dim = MakeV2FFrom64(asm_data.point_dim);
		c_data.is_clockwise = AsmBoolToBool(asm_data.is_clockwise);
		c_data.repeating_interval_ratio = cast(float) asm_data.repeating_interval_ratio;
		c_data.tuning_system_id = asm_data.tuning_system_id;
		c_data.is_repeating = !AsmBoolToBool(asm_data.non_repeating);
		c_data.start_note = asm_data.start_note;
		c_data.is_sound_float = AsmBoolToBool(asm_data.is_sound_float);
		c_data.inner_circle_mute = cast(float) asm_data.inner_circle_mute;
		c_data.no_base_points = AsmBoolToBool(asm_data.no_base_points);
		c_data.show_text = AsmBoolToBool(asm_data.show_text);

		// circle : *CircleSpace = CreateCircleInOpSpace(asm_data.op_space_id, c_data, ad);
		circle : *CircleSpace = CreateCircleInOpSpace(c_data, op_spec_data, ad.all_tuning_systems, ad.all_tuning_pitches);

		//We set the return values back here.
		asm_data.ret_dspace_id = circle.dspace_id;
	}
	case OpCode.map_circle; {
		mem_address : int = ComputeRAMLocation(ci.operands[0], ad.all_register_memory, ad.ram_memory);
		map_data, err := GetMemPtr(mem_address, AsmMapCircle, ad.ram_memory);
		if err.is_error return err;

		op_spec_data, found_op_space_data := ArrayFindFirstByNameId(ad.all_op_space_spec_data,
			map_data.op_space_id, "op_space_id");
		assert(found_op_space_data);

		circle : CircleSpace = ArrayFindFirstConstByNameId(op_spec_data.all_op_circle_spaces,
			map_data.dspace_id, "dspace_id");
		#if 1 {
		map_points, map_err := GetAsmArray(map_data.pitches, ad.ram_memory);
		if map_err.is_error return map_err;
		} else {
		map_points : [] float64 = NewArray(map_data.point_count, float64,,temp);
		for p_index : 0..map_data.point_count-1 {
			next_address : int = map_data.point_data + size_of(float64) * p_index;
			next_vl, err := GetMemValue(next_address, float64, ad.ram_memory);
			if err.is_error return err;
			map_points[p_index] = next_vl;
		}
		}

		//TODO only need this for not repeating or to remove duplicates eventually if needed
		if !circle.is_repeating {
			filter_points : [..] float64;
			filter_points.allocator = temp;
			// filter_music_pts : [] float64 = NewArray(allmap_points.count, float64,, temp);
			circle_point_count := cast(float64) circle.inter_points.count;
			for map_points if it < circle_point_count {
				//TODO Can also remove duplicates here if needed.
				array_add(*filter_points, fmod_cycling(it, circle_point_count));
			}
			map_points = filter_points;
		}

		//TODO Does this even do anything if points are already sorted in music_pt table?
		//To make non-convex polygons, we can pass in the points however they want.
		//TODO REMOVE THIS USER CAN JUST SORT THEIR OWN POINTS HOW THEY WANT
		// if circle.sort_music_pts quick_sort(map_points, (f1,f2) => f1 - f2);

		//TODO Can remove this if we don't use the space shape value eventually and just use float
		tuning_system := ArrayFindFirstByNameId(ad.all_tuning_systems, circle.tuning_system_id, "id");
		tuning_pitches := ArrayFindAllVarName(ad.all_tuning_pitches, tuning_system.id, "tuning_system_id", temp);
		assert(tuning_system.music_pt_count == tuning_pitches.count);

		last_pt : float64 = peek(map_points);
		previous_op_pos : Vector2F = MusicPtToCirclePos(last_pt, circle);
		// world_pos : Vector2F = MusicPtToCirclePos(last_pt, circle, circle_points);
		// previous_point_cam_pos : Vector2F = OpSpaceToCameraSpace(world_pos, op_space, op_2D_cam.world_pos, default_base_cam);
		for map_points {
			op_pos : Vector2F = MusicPtToCirclePos(it, circle);
			// cam_pos : Vector2F = OpSpaceToCameraSpace(op_pos, op_space, op_2D_cam.world_pos, default_base_cam);
			// cam_rect : Rectangle2 = RectCenterDim(cam_pos, circle.point_dim);
			// PushRectangle(cam_rect, FGREEN_V, op_space.render_groups.scissor_group, order = 8);

			//TODO THIS Draw_line could be optional in circle. 
			//Likely will always draw them, but we can pull it out if it's optional and go over the points again.
			// PushQuadLineViewport(previous_point_cam_pos, cam_pos, GREY_DARKER_V, 0.05, op_space.render_groups.scissor_group, order = 6);

			rect : *SpaceRect = array_add(*op_spec_data.ass.all_space_rects);
			rect.shape_id = context.ALL_NEXT_IDS.NEXT_SHAPE_ID;
			context.ALL_NEXT_IDS.NEXT_SHAPE_ID += 1;
			rect.op_space_id = map_data.op_space_id;
			rect.dspace_id = map_data.dspace_id;
			rect.dspace_shape_group = map_data.dspace_shape_group;
			rect.render_order = circle.base_render_order+2; //TODO Should this be passed in?
			//TODO Pass this in through AsmMapCircle
			rect.color = FGREEN_V;
			//TODO Remove base_index from function input here since it is stored in spiral.
			// op_pos : Vector2F = ChordToSpiralPoint(notes, base_chord, spiral.base_index, spiral);
			rect.rect = RectCenterDim(op_pos, circle.point_dim);
			rect.pitch_set = NewArray(1, float64,,op_spec_data.spec_2D_alloc);
			rect.pitch_set[0] = it;
			rect.shape_text = sprint("%", it,,op_spec_data.spec_2D_alloc);

			//TODO This may be worth removing eventually and just have this be added manually by a general
			//space_arrow asm call to draw it directly between 2 given points.
			//YES I think it's better to just let the player draw the voice leadings since we don't
			//know how they'll want to draw it but we could simplify it for them as well.
			//TODO MAKE THIS A FUNCTION FOR NOW SO WE CAN REUSE HERE AND SPIRAL
			// if map_data.draw_vl_lines && it_index > 0 {
			//TODO Can have draw_vl_lines and draw_vl_arrows separately
			if map_data.draw_vl_type == {
			case .VL_LINE; {
				line : Quad2F = MakeQuadLine(previous_op_pos, op_pos, 0.05);
				quad : *SpaceQuad = array_add(*op_spec_data.ass.all_space_quads);
				quad.op_space_id = map_data.op_space_id;
				quad.dspace_id = map_data.dspace_id;
				quad.dspace_shape_group = map_data.dspace_shape_group;
				quad.render_order = circle.base_render_order+1; //TODO should we set this to something else?
				//TODO Pass this in through MapSpiralData
				quad.color = GREY_DARKER_V;
				quad.quad = line;
			} 
			case .VL_ARROW; {
				line, arrow := MakeQuadArrow(previous_op_pos, op_pos, 0.05);

				//TODO Maybe we should do this as triangles? Let's see if we use quads often
				//otherwise might be better to just have rects, triangles and circles
				quad : *SpaceQuad = array_add(*op_spec_data.ass.all_space_quads);
				quad.op_space_id = map_data.op_space_id;
				quad.dspace_id = map_data.dspace_id;
				quad.dspace_shape_group = map_data.dspace_shape_group;
				quad.render_order = circle.base_render_order+1; //TODO should we set this to something else?
				//TODO Pass this in through MapSpiralData
				quad.color = GREY_DARKER_V;
				quad.quad = line;

				tri : *SpaceTriangle = array_add(*op_spec_data.ass.all_space_triangles);
				tri.op_space_id = map_data.op_space_id;
				tri.dspace_id = map_data.dspace_id;
				tri.dspace_shape_group = map_data.dspace_shape_group;
				tri.render_order = circle.base_render_order+1; //TODO should we set this to something else?
				//TODO Pass this in through MapSpiralData (could have an array of colors)
				//Or 2 colors in this case, arrow color and point color
				tri.color = GREY_DARKER_V;
				tri.triangle = arrow;
			}
			}

			// previous_point_cam_pos = cam_pos;
			previous_op_pos = op_pos;
		}
	}
	//TODO Can make update_spiral which would also take in notes so we can remap SpaceShapes if needed.
	//Then can make efficient updates depending on which field is being updated.
	//Sure fire update is delete_spiral and then create_spiral with new params and then map_spiral with same notes.
	case OpCode.create_spiral; {
		mem_address : int = ComputeRAMLocation(ci.operands[0], ad.all_register_memory, ad.ram_memory);
		asm_data, err := GetMemPtr(mem_address, AsmCreateSpiral, ad.ram_memory);
		if err.is_error return err;

		op_spec_data, found_op_spec_data := ArrayFindFirstByNameId(ad.all_op_space_spec_data,
			asm_data.op_space_id, "op_space_id");
		if !found_op_spec_data {
			return CPUErr(sprint("op_space_id % data not found.\n", asm_data.op_space_id));
		}

		tuning_system, found_tuning_system := 
			ArrayFindFirstByNameId(ad.all_tuning_systems, asm_data.tuning_system_id, "id");
		if !found_tuning_system {
			return CPUErr(sprint("Tuning system id % not found.\n", asm_data.tuning_system_id,,context.allocator));
		} 

		sp : SpiralSpace;
		sp.spiral_type = asm_data.spiral_type;
		sp.world_center_pos = MakeV2F(cast(float)asm_data.world_pos.x, cast(float)asm_data.world_pos.x);
		sp.rotate = cast(float) asm_data.rotate;
		sp.is_clockwise = AsmBoolToBool(asm_data.is_clockwise);
		sp.radius_size = cast(float) asm_data.radius_size;
		sp.sr_factor = cast(float) asm_data.sr_factor;
		sp.pitch_zero_freq = asm_data.pitch_zero_freq;
		sp.tuning_system_id = asm_data.tuning_system_id;
		sp.tuning_count = asm_data.tuning_count;
		sp.chord_count = asm_data.chord_count;
		sp.is_in_out = AsmBoolToBool(asm_data.is_in_out);
		sp.is_loop = AsmBoolToBool(asm_data.is_loop);
		sp.sound_float = AsmBoolToBool(asm_data.sound_float);
		sp.show_values = AsmBoolToBool(asm_data.show_values);
		sp.point_dim = MakeV2F(cast(float)asm_data.point_dim.x, cast(float)asm_data.point_dim.x);
		sp.synth.wave_type = asm_data.osc_wave_type;

		base_chord, pitch_err := GetAsmArray(asm_data.base_chord, ad.ram_memory);
		if pitch_err.is_error return pitch_err;

		success, error_msg := ValidateSpiral(base_chord, sp);
		if !success return CPUErr(error_msg);

		// spiral : *SpiralSpace = CreateSpiralInSpace(asm_data.op_space_id, sp, ad);
		spiral : *SpiralSpace = CreateSpiralInSpace(sp, op_spec_data);
		asm_data.ret_dspace_id = spiral.dspace_id;

		//TODO We could do an update_spiral call which allows updating these points after creation
		//instead of just allowing them to be created on creation.
		//update_spiral can be used to set multiple point_bases and also to change the bases for sound_float.
		//We can also use it to add custom points or even to change the spiral entirely allowing for a possibly
		//morphing spiral although that may be slow... unless we just run 1 instruction per frame though it is possible
		#if 1 {
		if AsmBoolToBool(asm_data.set_spiral_base) {
			success = SetSpiralBase(base_chord, asm_data.base_index, spiral, op_spec_data);
			//Sanity check here since we need to check these errors before spiral creation
			assert(success, "Invalid SetSpiralBase not checked before creation.\n");
		}
		} else {
		if cast(bool) asm_data.set_base_points {
			base_chord : [] float64 = NewArray(spiral.chord_count, float64,,context.allocator);
			for 0..spiral.chord_count-1 {
				next_address : int = asm_data.base_chord_data + size_of(float64) * it;
				note, err := GetMemValue(next_address, float64, ad.ram_memory);
				if err.is_error return err;
				base_chord[it] = note;
			}
		}
		//TODO These can just be SpaceRects now instead of space_points
		//and then for the values we can just do an inverse operation OR still cache them for convenience
		//if the inverse operation WorldPosToSpaceIndex (like have for mouse_float sound code)
		//is too expensive to do all the time
		SetSpiralBase(base_chord, asm_data.base_index, spiral, 
			*ad.all_space_points, *ad.all_space_point_to_value,
			asm_data.op_space_id, *ad.all_space_shapes,, context.allocator);
		}

		//TODO This would be for spirals that have their own point structure not with our base point structure.
		#if 0 {
		if cast(bool) asm_data.set_custom_points {
			float_base := float64.[0,4,7];
			float_chord := float_base;
			for * float_chord it.* += 1.11111;
			CreateSpiralPointAndValues(float_chord, spiral,
				*perm.all_data.all_space_points,
				*perm.all_data.all_space_point_to_value,
				color = LIGHT_BROWN);
		}
		}
	}
	//TODO We can have a map_memory general function which maps memory units to specific dspaces
	//and then we can so those on hover or have them stored for convenience for example or
	//they can be played in order or something like that...
	//BUT it would essentially just be the SpaceShapes now being shown as memory units.
	//So it is up to the user to keep track of everything as they want which makes the most sense here.
	case OpCode.map_spiral; {
		//TODO FROM HERE cleanup spiral code and maybe test a bit more and then do the same for circles
		mem_address : int = ComputeRAMLocation(ci.operands[0], ad.all_register_memory, ad.ram_memory);
		asm_data, err := GetMemPtr(mem_address, AsmMapSpiral, ad.ram_memory);
		if err.is_error return err;

		op_spec_data, found_op_spec_data := ArrayFindFirstByNameId(ad.all_op_space_spec_data,
			asm_data.op_space_id, "op_space_id");
		if !found_op_spec_data {
			return CPUErr(sprint("op_space_id % data not found.\n", asm_data.op_space_id));
		}

		spiral, found_spiral := ArrayFindFirstConstByNameId(op_spec_data.all_op_spirals, 
			asm_data.dspace_id, "dspace_id");
		if !found_spiral {
			//TODO Should this be an error or just a warning? Other things could go wrong so maybe an error is best.
			return CPUErr(sprint("Spiral % not found.\n", asm_data.dspace_id,,context.allocator));
		}

		//Early out if we don't have any info in case we just drew a spiral without setting base points
		if spiral.base_chord.count == 0 || spiral.chord_count == 0 || spiral.tuning_count == 0 return NO_CPU_ERROR;

		map_values, map_err := GetAsmArray(asm_data.map_values, ad.ram_memory);
		if map_err.is_error return map_err;

		last_rect_pos : Vector2F;
		for map_v, map_index : map_values {
			rect : *SpaceRect = array_add(*op_spec_data.ass.all_space_rects);
			rect.shape_id = context.ALL_NEXT_IDS.NEXT_SHAPE_ID;
			context.ALL_NEXT_IDS.NEXT_SHAPE_ID += 1;
			rect.op_space_id = asm_data.op_space_id;
			rect.dspace_id = asm_data.dspace_id;
			rect.dspace_shape_group = asm_data.dspace_shape_group;
			rect.render_order = spiral.base_render_order + 1;
			//TODO Pass this in through MapSpiralData
			rect.color = FGREEN_V;
			//TODO We could return an error for out of bounds indices, but this avoids the error and still feels natural.
			point_index : float64 = SpiralMapToPointIndex(map_v, spiral);
			op_pos : Vector2F = FloatIndexToSpiralPos(point_index, spiral);
			rect.rect = RectCenterDim(op_pos, spiral.point_dim);

			notes := NewArray(spiral.base_chord.count, float64, false,,temp);
			for base_note, base_index : spiral.base_chord {
				notes[base_index] = base_note + fmod_cycling(map_v, cast(float64) spiral.tuning_count);
			}
			rect.pitch_set = array_copy(notes,, op_spec_data.spec_2D_alloc);
			rect.shape_text = sprint("%", notes,, op_spec_data.spec_2D_alloc);

			if AsmBoolToBool(asm_data.draw_vl_lines) && map_index > 0 {
				line, arrow := MakeQuadArrow(last_rect_pos, op_pos, 0.1);

				//TODO Maybe we should do this as triangles? Let's see if we use quads often
				//otherwise might be better to just have rects, triangles and circles
				quad : *SpaceQuad = array_add(*op_spec_data.ass.all_space_quads);
				quad.shape_id = context.ALL_NEXT_IDS.NEXT_SHAPE_ID;
				context.ALL_NEXT_IDS.NEXT_SHAPE_ID += 1;
				quad.op_space_id = asm_data.op_space_id;
				quad.dspace_id = asm_data.dspace_id;
				quad.dspace_shape_group = asm_data.dspace_shape_group;
				quad.render_order = spiral.base_render_order + 2; //TODO should we set this to something else?
				//TODO Pass this in through MapSpiralData
				quad.color = LBLUE_V;
				quad.quad = line;

				tri : *SpaceTriangle = array_add(*op_spec_data.ass.all_space_triangles);
				tri.shape_id = context.ALL_NEXT_IDS.NEXT_SHAPE_ID;
				context.ALL_NEXT_IDS.NEXT_SHAPE_ID += 1;
				tri.op_space_id = asm_data.op_space_id;
				tri.dspace_id = asm_data.dspace_id;
				tri.dspace_shape_group = asm_data.dspace_shape_group;
				tri.render_order = spiral.base_render_order + 2; //TODO should we set this to something else?
				//TODO Pass this in through MapSpiralData (could have an array of colors)
				//Or 2 colors in this case, arrow color and point color
				tri.color = LBLUE_V;
				tri.triangle = arrow;
			}

			last_rect_pos = op_pos;
		}
	}
	case OpCode.create_cs2; {
		mem_address : int = ComputeRAMLocation(ci.operands[0], ad.all_register_memory, ad.ram_memory);
		//TODO We could make adding it to an op_space optional. This way we can add the same circle to many op_space if needed.
		asm_cs2, err := GetMemPtr(mem_address, AsmChordS2Data, ad.ram_memory);
		if err.is_error return err;

		create_cs2 : CreateChordS2Data;
		create_cs2.world_pos = MakeV2FFrom64(asm_cs2.world_pos);
		create_cs2.point_dim = MakeV2FFrom64(asm_cs2.point_dim);
		// create_cs2.transform = MakeMatrix2FFrom64(asm_cs2.transform);
		create_cs2.scale_world_unit = cast(float) asm_cs2.scale_world_unit;
		create_cs2.lp_count = asm_cs2.lp_count;
		create_cs2.vl_order_text = AsmBoolToBool(asm_cs2.vl_order_text);
		create_cs2.vl_order_color = AsmBoolToBool(asm_cs2.vl_order_color);
		create_cs2.cs_filter_aggregate = asm_cs2.cs_filter_aggregate; 
		create_cs2.is_sound_float = AsmBoolToBool(asm_cs2.is_sound_float);
		create_cs2.osc_wave_type = asm_cs2.osc_wave_type;
		//Check if we have filters, otherwise we set the default in CreateChordS2Data which is all.
		if asm_cs2.asm_cs_filters.count > 0 {
			asm_cs_filters, err := GetAsmArray(asm_cs2.asm_cs_filters, ad.ram_memory); 
			if err.is_error return err;
			//TODO FROM HERE Make this into a function and test for chord_s3 and also
			//check that passing in a value_set through asm actually works in AsmChordS2 and 3d
			//THEN make the generate library code read from another file for non generated
			//and then copy the rest as generated so we just generate it and don't need to worry
			//about updating it although double checking is likely a good idea
			//DONT FORGET TO CLEAR OLD FILTER CODE STUFF ONCE WE UPDATE THIS
			//NOTE : These get copied again when creating the chords2 data
			create_cs2.new_cs_filters, err = AsmFiltersToTempFilters(asm_cs_filters, ad.ram_memory);
			// create_cs2.new_cs_filters = NewArray(asm_cs_filters.count, CSFilter,,temp);
			// for asm_cs_filters {
			// 	create_cs2.new_cs_filters[it_index].filter_index = it.filter_index;
			// 	create_cs2.new_cs_filters[it_index].filter_value = it.filter_value;
			// 	create_cs2.new_cs_filters[it_index].filter_type = it.filter_type;
			// 	create_cs2.new_cs_filters[it_index].value_set, err = GetAsmArray(it.value_set, ad.ram_memory);
			// 	if err.is_error return err;
			// }
		} else {
			//This is set by default in CreateChordS2Data but I am leaving here for clarity
			create_cs2.new_cs_filters = .[.{filter_type=.ALL}];
		}

		// print("create_cs2.is_sound_float=%\n", create_cs2.is_sound_float);
		//TODO Should have an option to fetch and log a warning if it does not work or maybe an error.
		//TODO We should limit this to only repeating tuning systems.
		tuning_system, found_tuning_system := 
			ArrayFindFirstByNameId(ad.all_tuning_systems, asm_cs2.tuning_system_id, "id");
		if !found_tuning_system {
			return CPUErr(sprint("Tuning system id % not found.\n", asm_cs2.tuning_system_id,,context.allocator));
		} 
		//tODO Do we need this here or is having tuning system with less just going to modulo over?
		else if tuning_system.music_pt_count < create_cs2.lp_count {
			return CPUErr(sprint("Tuning system count % < lp_count %.\n", tuning_system.music_pt_count, create_cs2.lp_count,,context.allocator));
		}
		create_cs2.tuning_system_id = tuning_system.id;

		op_spec_data, found_op_spec_data := ArrayFindFirstByNameId(ad.all_op_space_spec_data,
			asm_cs2.op_space_id, "op_space_id");
		if !found_op_spec_data {
			return CPUErr(sprint("op_space_id % data not found.\n", asm_cs2.op_space_id,,context.allocator));
		}
		chord_s2 : *ChordSpace2 = CreateChordSpace2(create_cs2, op_spec_data);
		asm_cs2.ret_dspace_id = chord_s2.dspace_id;

		//We only need to use the alloc for filtered points since the chord space points will be permanently stored in memory.
		cs2_points : *ChordS2Points2D = GetOrCreateCS2Points(create_cs2.lp_count, *ad.all_cs2_points_2D);
		FilterCS2D(chord_s2.*, cs2_points.*, *op_spec_data.ass, 
			chord_s2.cs_filters, chord_s2.cs_filter_aggregate,,op_spec_data.spec_2D_alloc);

		AddChordS2ToOpSpace(asm_cs2.op_space_id, chord_s2,
			*op_spec_data.all_op_collision_entities);
	}
	case OpCode.map_cs2; {
		mem_address : int = ComputeRAMLocation(ci.operands[0], ad.all_register_memory, ad.ram_memory);
		map_data, err := GetMemPtr(mem_address, MapChordS2Data, ad.ram_memory);
		if err.is_error return err;

		op_spec_data, found_op_spec_data := ArrayFindFirstByNameId(ad.all_op_space_spec_data,
			map_data.op_space_id, "op_space_id");
		if !found_op_spec_data {
			return CPUErr(sprint("op_space_id % data not found.\n", map_data.op_space_id,,context.allocator));
		}

		chord_s2, found_chord_s2 := ArrayFindFirstByNameId(op_spec_data.all_op_chord_s2,
			map_data.dspace_id, "dspace_id");
		if !found_chord_s2 {
			return CPUErr(sprint("chord_s2 % not found.\n", map_data.dspace_id,,context.allocator));
		}

		if map_data.vl_start_chord.count != 2 {
			return CPUErr(sprint("vl_start_chord count % != 2.\n", map_data.vl_start_chord.count));
		}
		start_chord, array_err := GetAsmArray(map_data.vl_start_chord, ad.ram_memory);
		if array_err.is_error return array_err;

		if map_data.vl_deltas.count % 2 != 0 {
			return CPUErr(sprint("vl_deltas count % should be a multiple of 2.\n", map_data.vl_deltas.count));
		}
		all_vl_deltas, delta_err := GetAsmArray(map_data.vl_deltas, ad.ram_memory);
		if delta_err.is_error return delta_err;

		total_deltas : int = map_data.vl_deltas.count / 2;
		new_vl_events : [] VLEvent = NewArray(total_deltas, VLEvent,,temp);
		for vl_index : 0..total_deltas-1 {
			next_address : int = map_data.vl_deltas.data_address + 2 * size_of(float64) * vl_index;
			next_delta_chord : [] float64 = GetMemArray(next_address, 2, float64, ad.ram_memory);
			new_vl_events[vl_index].voice_leading_sizes = array_copy(next_delta_chord,,temp);
		}

		vl_end_points, vl_points_no_dim := ProcessVoiceLeadingEventsNDim(chord_s2.dspace_id,
			start_chord, new_vl_events, chord_s2.music_pt_count,
			//TODO I am not sure we need to pass this in anymore...
			chord_s2.next_group_order,,temp);

		CreateVoiceLeadingShapes2D(map_data.op_space_id, chord_s2,
			vl_end_points, vl_points_no_dim, *op_spec_data.ass,,op_spec_data.spec_2D_alloc);
	}
	//TODO Rename this to create_s3
	case OpCode.create_cs3; {
		mem_address : int = ComputeRAMLocation(ci.operands[0], ad.all_register_memory, ad.ram_memory);
		//TODO We could make adding it to an op_space optional. This way we can add the same circle to many op_space if needed.
		asm_cs3, err := GetMemPtr(mem_address, AsmSpace3Data, ad.ram_memory);
		if err.is_error return err;

		create_cs3 : CreateChordS3Data;
		create_cs3.op_space_id = asm_cs3.op_space_id;
		create_cs3.higher_dim = asm_cs3.higher_dim;
		//TODO We should limit this to only repeating tuning systems.
		tuning_system, found_tuning_system := ArrayFindFirstByNameId(ad.all_tuning_systems, asm_cs3.tuning_system_id, "id");
		if !found_tuning_system {
			return CPUErr(sprint("Tuning system id % not found.\n", asm_cs3.tuning_system_id,,context.allocator));
		}
		//TODO I think this should be passed in so we can have different tuning systems for same counts
		create_cs3.lp_count = tuning_system.music_pt_count;
		create_cs3.tuning_system_id = tuning_system.id;
		if asm_cs3.asm_cs_filters.count > 0 {
			asm_cs_filters, err := GetAsmArray(asm_cs3.asm_cs_filters, ad.ram_memory); 
			if err.is_error return err;
			create_cs3.new_cs_filters, err = AsmFiltersToTempFilters(asm_cs_filters, ad.ram_memory);
			// create_cs3.new_cs_filters, err = GetAsmArray(asm_cs3.asm_cs_filters, ad.ram_memory); 
			if err.is_error return err;
		} else {
			//This is set by default in CreateChordS3Data but I am leaving here for clarity
			create_cs3.new_cs_filters = .[.{filter_type=.ALL}];
		}

		//We set some default values here which will be adjustable in dynamic lib but not here to simplify things in asm
		if create_cs3.higher_dim == 3 {
			create_cs3.mouse_rotate = DEFAULT_CHORD_S3_ROTATION;
			// create_cs3.s3_cam_start_type = S3CamStartType.USER_SET;
			// CHROMATIC_TRANSLATION := Vector3F.{0,0,2.0*(tuning_system.music_pt_count-12)};
			// UpdateTranslation(*create_cs3.cam_trans, CHROMATIC_TRANSLATION);
		} else {
			create_cs3.mouse_rotate = DEFAULT_CHORD_S4_ROTATION;
		}
		create_cs3.s3_cam_start_type = asm_cs3.s3_cam_start_type;
		//TODO Can also set 3d transform here if needed. Default is 3x3 identity matrix in CreateChordS3Data
		UpdateTranslation(*create_cs3.cam_trans, MakeV3FFrom64(asm_cs3.cam_start_pos));

		if AsmBoolToBool(asm_cs3.set_3d_perspective) {
			create_cs3.depth = cast(float) asm_cs3.depth;
			create_cs3.n = cast(float) asm_cs3.n;
			create_cs3.f = cast(float) asm_cs3.f;
		}

		op_space, found_op_space := FindOpSpaceOpenOrClosed(create_cs3.op_space_id, 
			ad.all_open_op_spaces, ad.all_closed_op_spaces);
		if !found_op_space {
			return CPUErr(sprint("op_space_id % not found.\n", asm_cs3.op_space_id,,context.allocator));
		}

		op_3D, found_op_3D := ArrayFindFirstByNameId(ad.all_op_spec_data_3D,
			asm_cs3.op_space_id, "op_space_id");
		if !found_op_3D {
			//TODO Should this be an error or just a warning? Other things could go wrong so maybe an error is best.
			return CPUErr(sprint("op_space_id % 3d data not found.\n", asm_cs3.op_space_id,,context.allocator));
		}

		//TODO Should we call this in here by default or just externally?
		// clear_data : ClearOpSpaceData;
		// clear_data.op_space_id = create_cs3.op_space_id;
		// ClearOpSpace(clear_data, ad);
		CreateSpace3D(op_space.world_size, create_cs3, op_3D);

		chord_space_points := GetOrCreateChordSpacePoints3D(op_3D.op_space_3D.higher_dim, op_3D.op_space_3D.lp_count, *ad.all_chord_space_points);
		FilterCS3D(chord_space_points, *op_3D.all_op_space_points_3D, op_3D.op_space_3D.new_cs_filters, .INTERSECTION);
		op_3D.op_space_3D.cam_trans = Space3DStartCamTrans(create_cs3.s3_cam_start_type, create_cs3.cam_focus_fun_region_pos, create_cs3.cam_trans, op_3D);

		// asm_cs3.dspace_id = op_3D.op_space_3D.dspace_id;
	}
	case OpCode.map_cs3; {
		mem_address : int = ComputeRAMLocation(ci.operands[0], ad.all_register_memory, ad.ram_memory);
		map_data, err := GetMemPtr(mem_address, MapChordS3Data, ad.ram_memory);
		if err.is_error return err;

		op_3D, found_op_3D := ArrayFindFirstByNameId(ad.all_op_spec_data_3D,
			map_data.op_space_id, "op_space_id");
		if !found_op_3D {
			//TODO Should this be an error or just a warning? Other things could go wrong so maybe an error is best.
			return CPUErr(sprint("op_space_id % not found.\n", map_data.op_space_id,,context.allocator));
		}

		if map_data.vl_start_chord.count != op_3D.op_space_3D.higher_dim {
			return CPUErr(sprint("vl_start_chord count % not equal to space dimension %.\n", 
				map_data.vl_start_chord.count, op_3D.op_space_3D.higher_dim,,context.allocator));
		}
		start_chord, array_err := GetAsmArray(map_data.vl_start_chord, ad.ram_memory);
		if array_err.is_error return array_err;

		if map_data.vl_deltas.count % op_3D.op_space_3D.higher_dim != 0 {
			return CPUErr(sprint("vl_deltas count % should be a multiple of space dimension %.\n", 
				map_data.vl_deltas.count, op_3D.op_space_3D.higher_dim,,context.allocator));
		}
		all_vl_deltas, delta_err := GetAsmArray(map_data.vl_deltas, ad.ram_memory);
		if delta_err.is_error return delta_err;

		//We checked mod above so this division will always be a precise integer.
		total_deltas : int = map_data.vl_deltas.count / op_3D.op_space_3D.higher_dim;
		new_vl_events : [] VLEvent = NewArray(total_deltas, VLEvent,,temp);
		for vl_index : 0..total_deltas-1 {
			next_address : int = map_data.vl_deltas.data_address + op_3D.op_space_3D.higher_dim * size_of(float64) * vl_index;
			next_delta_chord : [] float64 = GetMemArray(next_address, op_3D.op_space_3D.higher_dim, float64, ad.ram_memory);
			new_vl_events[vl_index].voice_leading_sizes = array_copy(next_delta_chord,,temp);
		}

		vl_end_points, vl_points_no_dim := ProcessVoiceLeadingEventsNDim(op_3D.op_space_3D.dspace_id,
			start_chord, new_vl_events, op_3D.op_space_3D.lp_count,
			//TODO We could pass vl_index through MapChordS3Data instead I think.
			map_data.vl_index_ref);

		//TODO Could pull this out and say draw vls or people can just do it themselves so they can set colors or sizes themselves
		for vl : vl_end_points {
			sp : *SpacePoint3D = array_add(*op_3D.all_op_space_points_3D);
			sp.draw_wire_mesh = true;
			sp.do_not_remove_with_filter = true;
			sp.color = RED_V;
			//DOC : We round the values here to stay consistent with the chord points but maybe that feels inconsistent anyways
			UpdateSpacePoint3D(sp, op_3D.op_space_3D.lp_count, vl.fun_region_float,
				round_pitches_below_octave=false,, op_3D.spec_3D_alloc);

			//TODO Can use spec_3D_alloc here and set any string size if needed and then clear on op clear
			//TODO Could make this optional like with 2d
			space_text : *SpaceText3D = array_add(*op_3D.all_op_text_3D);
			space_text.op_pos = sp.rel_pos;
			SetSpaceText3D(tprint("%", vl.order), space_text);
		}

		for vl : vl_points_no_dim {
			end_point : VLEndPoint = ArrayFindFirstByNameId(vl_end_points, vl.vl_id, "id");
			sp : *SpacePoint3D = array_add(*op_3D.all_op_space_points_3D);
			//TODO Could make this lerping optional like with 2d
			//TODO Can add lerp_vl_color here to the asm if we want to make this more explicit from blue to green or something else
			//OR we just do that in dynamic libraries later
	    	// sp.color = LBLUE_V;
			interp := cast(float) it_index / (0.9*end_point.vl_point_count);
			// interp := cast(float) it_index / (0.9*vl_points_no_dim.count);
			// interp := cast(float) it_index / cast(float) vl_points_no_dim.count;
			if interp > 1 interp = 1;
			sp.color.rgb = Lerp(GREY_DARKERM2_V.rgb, interp, WHITE_V.rgb);
			sp.color.a = 1.0;
	    	// sp.color = Lerp(ColorMultNoAlpha(0.6, LBLUE_V), cast(float)it_index/cast(float)vl_points_no_dim.count, LBLUE_V);
	    	// sp.color = Lerp(LBLUE_V, cast(float)it_index/cast(float)vl_points_no_dim.count, FGREEN_V);
			sp.scale_value = 0.3;
			sp.do_not_remove_with_filter = true;
			UpdateSpacePoint3D(sp, op_3D.op_space_3D.lp_count, vl.fun_region_float,, op_3D.spec_3D_alloc);
		}
	}
	case OpCode.create_custom_3D; {
		mem_address : int = ComputeRAMLocation(ci.operands[0], ad.all_register_memory, ad.ram_memory);
		asm_data, err := GetMemPtr(mem_address, AsmGeom3D, ad.ram_memory);
		if err.is_error return err;

		op_3D, found_op_3D := ArrayFindFirstByNameId(ad.all_op_spec_data_3D,
			asm_data.op_space_id, "op_space_id");
		if !found_op_3D {
			return CPUErr(sprint("op_space_id % 3d data not found.\n", asm_data.op_space_id,,context.allocator));
		}

		geom_3D, already_made_group := ArrayFindFirstByNameId(op_3D.all_custom_geom_3D, asm_data.group_id, "group_id");
		if already_made_group {
			return CPUErr(sprint("Already made group_id %.\n", asm_data.group_id,,context.allocator));
		}

		if asm_data.custom_audio_type == CustomAudioType.TUNING_SYSTEM {
			tuning_system, found_tuning_system := 
				ArrayFindFirstByNameId(ad.all_tuning_systems, asm_data.tuning_system_id, "id");
			if !found_tuning_system {
				return CPUErr(sprint("tuning_system_id % not found.\n", asm_data.tuning_system_id,,context.allocator));
			}
		}

		/*DOC : This geometry is optional. If we have it, then we use the data wherever needed but otherwise
		we use the default space 3d data which is what the default chord space 3 does anyways since I think in general
		we will use only 1 set of tuning system and points for a 3d space since having more complicates it BUT this
		allows it to be possible at least and so we can experiment to see how it is. Dynamic libraries allows us
		to do anything we need with the 3d ultimately since we can organize the points however we want then.
		*/
		custom_3D : *CustomGeom3D = array_add(*op_3D.all_custom_geom_3D);
		custom_3D.group_id = asm_data.group_id;
		custom_3D.tuning_system_id = asm_data.tuning_system_id;
		custom_3D.custom_audio_type = asm_data.custom_audio_type;
		custom_3D.osc_wave_type = asm_data.osc_wave_type;
	}
	case OpCode.create_shape_3D; {
		mem_address : int = ComputeRAMLocation(ci.operands[0], ad.all_register_memory, ad.ram_memory);
		asm_data, err := GetMemPtr(mem_address, AsmShape3D, ad.ram_memory);
		if err.is_error return err;

		op_3D, found_op_3D := ArrayFindFirstByNameId(ad.all_op_spec_data_3D,
			asm_data.op_space_id, "op_space_id");
		if !found_op_3D {
			return CPUErr(sprint("op_space_id % 3d data not found.\n", asm_data.op_space_id,,context.allocator));
		}

		geom_3D, geom_exists := ArrayFindFirstByNameId(op_3D.all_custom_geom_3D, asm_data.group_id, "group_id");
		if !geom_exists {
			return CPUErr(sprint("Geometry with group_id % not found.\n", asm_data.group_id,,context.allocator));
		}

		sp_3D : *SpacePoint3D = array_add(*op_3D.all_op_space_points_3D);
		sp_3D.id = context.ALL_NEXT_IDS.NEXT_SPACE_POINT_3D_ID;
		context.ALL_NEXT_IDS.NEXT_SPACE_POINT_3D_ID += 1;
		sp_3D.group_id = asm_data.group_id;
		sp_3D.rel_pos = MakeV3FFrom64(asm_data.rel_pos);
		if asm_data.fun_region.count > 0 {
			ram_fun, err := GetAsmArray(asm_data.fun_region, ad.ram_memory);
			if err.is_error return err;
			sp_3D.fun_region = array_copy(ram_fun,, op_3D.spec_3D_alloc);
		}
		if asm_data.pitch_set.count > 0 {
			ram_pitches, err := GetAsmArray(asm_data.pitch_set, ad.ram_memory);
			if err.is_error return err;
			sp_3D.pitch_set = array_copy(ram_pitches,, op_3D.spec_3D_alloc);
		}
		if asm_data.shape_text.count > 0 {
			name_string, name_err := AsmStringToString(asm_data.shape_text, ad.ram_memory);
			if name_err.is_error return name_err;
			sp_3D.shape_text = copy_string(name_string,, op_3D.spec_3D_alloc);
		}
		// sp_3D.do_not_remove_with_filter = AsmBoolToBool(asm_data.do_not_remove_with_filter);
		sp_3D.draw_wire_mesh = AsmBoolToBool(asm_data.draw_wire_mesh);
		sp_3D.is_selectable = !AsmBoolToBool(asm_data.not_selectable);
		sp_3D.scale_value = cast(float) asm_data.scale_value;
		sp_3D.color = MakeV4FFrom64(asm_data.color);
		if sp_3D.color == Vector4F.{0,0,0,0} sp_3D.color = DEFAULT_CUBE_MULTI_COLOR;
	}
	case OpCode.create_text_3D; {
		mem_address : int = ComputeRAMLocation(ci.operands[0], ad.all_register_memory, ad.ram_memory);
		asm_data, err := GetMemPtr(mem_address, AsmText3D, ad.ram_memory);
		if err.is_error return err;

		op_3D, found_op_3D := ArrayFindFirstByNameId(ad.all_op_spec_data_3D,
			asm_data.op_space_id, "op_space_id");
		if !found_op_3D {
			return CPUErr(sprint("op_space_id % 3d data not found.\n", asm_data.op_space_id,,context.allocator));
		}

		text_string, text_err := AsmStringToString(asm_data.text, ad.ram_memory);
		if text_err.is_error return text_err;

		//TODO Can use spec_3D_alloc here and set any string size if needed and then clear on op clear
		space_text : *SpaceText3D = array_add(*op_3D.all_op_text_3D);
		space_text.group_id = asm_data.group_id;
		space_text.op_pos = MakeV3FFrom64(asm_data.op_pos);
		SetSpaceText3D(text_string, space_text);
	}
	/*DOC : Create our own geometry where we can add shapes and shape values as frequencies.
	This allows players to create their own geometries without using pre-existing ones although
	shapes and values can be added to the pre-existing ones as well.
	*/
	//TODO FROM HERE continue updating this with tests and switching over to op spec data
	case OpCode.create_custom_geometry; {
		mem_address : int = ComputeRAMLocation(ci.operands[0], ad.all_register_memory, ad.ram_memory);
		asm_data, err := GetMemPtr(mem_address, AsmGeom2D, ad.ram_memory);
		if err.is_error return err;

		op_spec_data, found_op_spec_data := ArrayFindFirstByNameId(ad.all_op_space_spec_data,
			asm_data.op_space_id, "op_space_id");
		if !found_op_spec_data {
			return CPUErr(sprint("op_space_id % data not found.\n", asm_data.op_space_id));
		}

		//TODO These could be set per op space now since we have them uniquely by dspace_id and op_space_id
		asm_data.ret_dspace_id = context.ALL_NEXT_IDS.DSPACE_ID;
		context.ALL_NEXT_IDS.DSPACE_ID += 1;

		custom_g : *CustomGeometry = array_add(*op_spec_data.ass.all_custom_geometries);
		custom_g.dspace_id = asm_data.ret_dspace_id;
		custom_g.tuning_system_id = asm_data.tuning_system_id;
		custom_g.custom_audio_type = asm_data.custom_audio_type;
		custom_g.synth.wave_type = asm_data.osc_wave_type;
		//TODO Could pass this in through asm data as well if needed.
		custom_g.synth.envelope = MakeVolumeEnvelope();
		custom_g.collision_rect = RectCenterDim(MakeV2FFrom64(asm_data.collision_pos), MakeV2FFrom64(asm_data.collision_dim));
		custom_g.show_collision = AsmBoolToBool(asm_data.show_collision);

		//TODO Could allow other collision shapes later if needed
		coll : *CollisionEntity = array_add(*op_spec_data.all_op_collision_entities);
		coll.entity_id = custom_g.dspace_id;
		coll.entity_type = EntityType.CUSTOM_GEOMETRY;
		coll.shape = CollisionShape.RECTANGLE;
		coll.rect = custom_g.collision_rect;
	}
	case OpCode.create_shape; {
		mem_address : int = ComputeRAMLocation(ci.operands[0], ad.all_register_memory, ad.ram_memory);
		asm_data, err := GetMemPtr(mem_address, AsmShapeData, ad.ram_memory);
		if err.is_error return err;

		op_spec_data, found_op_spec_data := ArrayFindFirstByNameId(ad.all_op_space_spec_data,
			asm_data.op_space_id, "op_space_id");
		if !found_op_spec_data {
			return CPUErr(sprint("op_space_id % data not found.\n", asm_data.op_space_id));
		}

		asm_data.ret_shape_id = context.ALL_NEXT_IDS.NEXT_SHAPE_ID;
		context.ALL_NEXT_IDS.NEXT_SHAPE_ID += 1;

		if asm_data.type == AsmShapeType.RECTANGLE {
			rect : *SpaceRect = array_add(*op_spec_data.ass.all_space_rects);
			rect.shape_id = asm_data.ret_shape_id;
			rect.dspace_id = asm_data.dspace_id;
			rect.dspace_shape_group = asm_data.dspace_shape_group;
			rect.render_order = asm_data.render_order;
			rect.color = MakeV4FFrom64(asm_data.color);
			rect_pos : Vector2F = MakeV2FFrom64(asm_data.rect_pos);
			rect_dim : Vector2F = MakeV2FFrom64(asm_data.rect_dim);
			rect.rect = RectCenterDim(rect_pos, rect_dim);
			rect.not_selectable = AsmBoolToBool(asm_data.not_selectable);
			if asm_data.fun_region.count > 0 {
				ram_fun, err := GetAsmArray(asm_data.fun_region, ad.ram_memory);
				if err.is_error return err;
				rect.fun_region = array_copy(ram_fun,, op_spec_data.spec_2D_alloc);
			}
			if asm_data.pitch_set.count > 0 {
				ram_pitches, err := GetAsmArray(asm_data.pitch_set, ad.ram_memory);
				if err.is_error return err;
				rect.pitch_set = array_copy(ram_pitches,, op_spec_data.spec_2D_alloc);
			}
			if asm_data.shape_text.count > 0 {
				name_string, name_err := AsmStringToString(asm_data.shape_text, ad.ram_memory);
				if name_err.is_error return name_err;
				rect.shape_text = copy_string(name_string,, op_spec_data.spec_2D_alloc);
			}
		}
	}
	case OpCode.delete_shape; {
		mem_address : int = ComputeRAMLocation(ci.operands[0], ad.all_register_memory, ad.ram_memory);
		delete_data, err := GetMemValue(mem_address, DeleteShapeData, ad.ram_memory);
		if err.is_error return err;

		op_spec_data, found_op_spec_data := ArrayFindFirstByNameId(ad.all_op_space_spec_data,
			delete_data.op_space_id, "op_space_id");
		assert(found_op_spec_data);

		if delete_data.type == {
		case .RECTANGLE; {
			//TODO Can optimize these deletes if we index/sort these tables later.
			for * op_spec_data.ass.all_space_rects if it.shape_id == delete_data.shape_id {
				remove it;
				break;
			}
			for * op_spec_data.ass.all_space_shape_values if it.shape_id == delete_data.shape_id {
				remove it;
			}
		}
		}			
	}
	case OpCode.create_text; {
		mem_address : int = ComputeRAMLocation(ci.operands[0], ad.all_register_memory, ad.ram_memory);
		asm_data, err := GetMemPtr(mem_address, AsmText2D, ad.ram_memory);
		if err.is_error return err;

		op_spec_data, found_op_spec_data := ArrayFindFirstByNameId(ad.all_op_space_spec_data,
			asm_data.op_space_id, "op_space_id");
		if !found_op_spec_data {
			return CPUErr(sprint("op_space_id % data not found.\n", asm_data.op_space_id));
		}

		text_string, text_err := AsmStringToString(asm_data.text, ad.ram_memory);
		if text_err.is_error return text_err;

		//TODO Can use spec_2D_alloc here and set any string size if needed and then clear on op clear
		space_text : *SpaceText = array_add(*op_spec_data.ass.all_space_text);
		space_text.op_pos = MakeV2FFrom64(asm_data.op_pos);
		space_text.color = MakeV4FFrom64(asm_data.color);
		SetSpaceText(text_string, space_text);
	}
	//TODO Can add this if we want to allow custom colliders later
	// case OpCode.create_shape_collider; {
	// }
	/*TODO We could just have muscalls be in ram_memory and the first value tells us which call it is and then
	we know how to get the rest of the data.
	Could also allow 2 ops, so the first 1 would be the muscall type and the second would be its data which
	would depend on the muscall type.
	If we did it this way, then we could remove the muscall specific registers and just use ram_memory directly.
	But maybe the muscall registers simplifies certain things so let's see as we make them.
	*/
	case OpCode.muscall; {
		//TODO Depending on the call we would fetch from specific registers and memory appropriately.
		//Can start with create_space and then map_space by adding circles and then linear spaces.
		//Then we can add chord_s2 and then chord_s3 since chord_s3 cannot share another space.

		operand_value : int = ComputeOperandInt(ci.operands[0], ad.all_register_memory, ad.ram_memory);
		//TODO Could check operand type here
		muscall_type : MusCallType = muscall_type_enums[operand_value];

		//TODO All muscalls should be using this pattern now instead of the register patterns.
		//We can still specify a few registers I guess but this makes it much more general for each different call.
		mem_address : int = ComputeRAMLocation(ci.operands[1], ad.all_register_memory, ad.ram_memory);

		//TODO Start with creating new general op_spaces and then add geometries to it.
		//Start with circle and maybe linear and then can add chord_s2 and spirals and then
		//chord_s3/s4 should be similar to what we have now since they are alone in a space.
		//Then after circle/(maybe linear) we can continue with code a bit and dll to make sure
		//things are working and also write some simple tests to start creating a more solid baseline
		//for the instructions to work off of and the functions they are working from.
		if muscall_type == {
		// case MusCallType.setup_music; {
		// 	setup_music_data, err := GetMemValue(mem_address, SetupMusicData, ad.ram_memory);
		// 	if err.is_error return err;

		// 	SetupMusic(ad, setup_music_data);
		// }
		// case MusCallType.create_row; {
		// 	asm_data, err := GetMemPtr(mem_address, AsmCreateRowData, ad.ram_memory);
		// 	if err.is_error return err;
		// 	crd : CreateRowData;
		// 	//TODO Should we make these float64 instead so we don't lose information?
		// 	crd.octave_height = cast(float) asm_data.octave_height;
		// 	crd.row_height = cast(float) asm_data.row_height;
		// 	crd.muted_row = AsmBoolToBool(asm_data.muted_row);
		// 	crd.row_system_type = asm_data.row_system_type;
		// 	crd.row_section_data, err = GetAsmArray(asm_data.row_sections, ad.ram_memory);
		// 	if err.is_error return err;
		// 	CreateMusicRow(crd, ad);
		// }
		//TODO I think we should rename this to create_op_linear_row
		case MusCallType.create_op_row; {
			//TODO Should this asm data be different from MusicRow since it will likely have different values?
			//Maybe can do a subset here or just different altogether probably since we will have different
			//types of op rows, copy_music_row, single_system_row and multi_system_row
			asm_data, err := GetMemPtr(mem_address, AsmOpRowData, ad.ram_memory);
			if err.is_error return err;
			//TODO Should this be separate for CreateOpRowData as well? Maybe yes since the op will likely
			// have different options from the base. We could also just have MusicLaneRow in it with some added fields.
			crd : CreateRowData;
			//TODO Should we make these float64 instead so we don't lose information?
			crd.octave_height = cast(float) asm_data.octave_height;
			crd.row_height = cast(float) asm_data.row_height;
			crd.sound_on = cast(bool) asm_data.sound_on;
			crd.row_system_type = asm_data.row_system_type;
			crd.op_world_pos.x = cast(float) asm_data.x_op_pos;
			crd.op_world_pos.y = cast(float) asm_data.y_op_pos;
			crd.x_point_width = cast(float) asm_data.x_point_width;
			if asm_data.is_music_row_copy {
				//NOTE : No need to create the row sections here if it is copy_row
				crd.op_row_type = OpRowType.COPY_MUSIC_ROW;
				crd.copy_music_row_id = asm_data.copy_music_row_id;
			} else {
				//TODO I am not sure if we need this single_section but could be an optimization later
				// crd.op_row_type = OpRowType.SINGLE_SECTION;
				crd.op_row_type = OpRowType.MULTI_SECTION;
				crd.row_section_data = NewArray(asm_data.row_section_count, RowSectionData,,context.allocator);
				for 0..asm_data.row_section_count-1 {
					next_address : int = asm_data.row_section_memory_index + size_of(RowSectionData) * it;
					row_section, err := GetMemPtr(next_address, RowSectionData, ad.ram_memory);
					if err.is_error return err;
					crd.row_section_data[it] = row_section.*;
				}
			}

			row : MusicLaneRow = CreateOpLinearRow(crd, ad);

			//We set the row return values here
			asm_data.row_id = row.id;

			//TODO I think we should put this in the above so it remains consistent everywhere.
			dspace_to_op : *DSpaceToOpSpaceIndex = array_add(*ad.all_dspace_to_op_space_id);
			dspace_to_op.dspace_id = row.id;
			dspace_to_op.op_dspace_type = OpDSpaceType.LINEAR;
			dspace_to_op.op_space_id = asm_data.op_space_id;
		}
		case MusCallType.map_linear; {
			map_data, err := GetMemPtr(mem_address, MapLinearData, ad.ram_memory);
			if err.is_error return err;

			//TODO Should check that dspace_id, row_index and x_index exist, otherwise return error.
			//This also avoids invalid dspaces while running everything later as well.
			//SO WE COULD MAKe a generalized function to check and create so then we could
			//reuse that for function calls as well... hmmmm...
			//YES seems like we would reuse it in circle as well.

			//If this is a music copy row, then we don't want this.
			//TODO Should we separate row copy from linear? Because the rendering code is so similar
			//But also maybe it is different enough now with music_pts...
			op_linear_row := ArrayFindFirstByNameId(ad.all_op_linear_rows,
				map_data.dspace_id, "id");
			if op_linear_row.op_row_type == OpRowType.COPY_MUSIC_ROW {
				//TODO Should we return an error here or maybe just log something since this should likely not break everything.
				//Maybe we should allow this to overlap things? That seems pointless.
				print("Op Music row % is a copy_row and cannot be mapped.\n", op_linear_row);
			} else if map_data.map_linear_type == MapLinearType.POINT {
				//TODO I think we can remove both of these now and make map_linear just copy over
				//OR for linear we could do it automatically
				//OR We use this call to generate the notes on and can have a clear flag which clears the row
				//TODO Why don't we just make a new one of these with float64 and then work with that instead
				//of having to refactor everything?
				mem_to_dspace : *MemoryUnitToDSpace = array_add(*ad.all_memory_unit_to_dspace);
				//TODO This should be float64 everywhere now.
				mem_to_dspace.x_index = cast(int) map_data.x_index;
				mem_to_dspace.x_grid_pos = cast(int) map_data.op_x_row_pos;
				mem_to_dspace.row_index = map_data.row_index;
				mem_to_dspace.dspace_id = map_data.dspace_id;
				mem_to_dspace.op_dspace_type = OpDSpaceType.LINEAR;
				//TODO Could generate the rendering points or separate music_pt rects here for efficiency.
			} else if map_data.map_linear_type == MapLinearType.RANGE {
				//TODO We don't need this anymore with .map_memory
				mem_range : *MemoryRangeToDSpace = array_add(*ad.all_memory_range_to_dspace);
				mem_range.x_start = map_data.x_index;
				mem_range.x_end = map_data.x_end_index;
				mem_range.row_index = map_data.row_index;
				mem_range.dspace_id = map_data.dspace_id;
				mem_range.x_dspace_start = map_data.op_x_row_pos;
				mem_range.op_dspace_type = OpDSpaceType.LINEAR;
				//TODO Could generate the rendering points or separate music_pt rects here for efficiency.
			}
		}
		case MusCallType.map_memory; {
			//TODO Pass in dspace_shape_group as int so then we we can highlight specific sections or points if desired.
			//Should we pass in op_space_id also? Maybe not or maybe later yes?
			mem_range, err := GetMemPtr(mem_address, MemoryRangeToDSpace, ad.ram_memory);
			if err.is_error return err;
			//TODO Could add some checks here for dspace_id and x_index and row_index
			array_add(*ad.all_memory_range_to_dspace, mem_range);
		}
		//TODO THIS IS NO LONGER USED just because we have it in some tests. Remove it once we update the tests
		//to just use code and remove the asm inputs since those will break if we update any of the data
		case MusCallType.create_space; {
			//TODO We would have to validate the values here before pulling them since the player will be
			//placing them and could make errors.

			//TODO Which one of these is better? GetMemValue does an out of ram bounds and null check.
			// space_data := cast(*AsmOpSpaceData) *ad.ram_memory.bytes[mem_address];
			space_data, err := GetMemValue(mem_address, AsmOpSpaceData, ad.ram_memory);
			if err.is_error return err;

			//TODO In order to store strings, we either want to set them in their own data with all the strings
			//or we reduce or data array to general u8 data and then store string directly in memory.
			//We could also have a separate general u8 memory where the strings are stored but which can
			//be used for anything else as well.
			name_string : string;
			name_string.count = space_data.op_space_name.count;

			name_ptr, name_err := GetMemory(space_data.op_space_name.data_address, name_string.count, ad.ram_memory);
			if name_err.is_error return name_err;
			name_string.data = name_ptr;

			op_space, found_op_space := FindOpSpacePointerOpenOrClosed(name_string, 
				ad.all_open_op_spaces, ad.all_closed_op_spaces);
			if !found_op_space {
				cosd : CreateOpSpaceData;
				cosd.op_space_name = copy_string(name_string);
				cosd.op_space_external_type = AsmOpSpaceToExternalType(space_data.op_space_type);
				// cosd.op_space_name = alloc_string(space_data.op_space_name.count);
	 			// memcpy(cosd.op_space_name.data, name_string.data, name_string.count);
				// cosd.world_offset = ;
				// cosd.world_size = ;
				op_space = CreateClosedOpSpace(cosd, 
					*ad.all_closed_op_spaces, 
					*ad.all_op_space_spec_data, 
					*ad.all_op_spec_data_3D);
			}

			//Set the op space id here as a return value
			space_data.ret_op_space_id = op_space.id;
		}
		}
	}
	}
	//TODO Could check some generic errors here like making sure the .ip register is 0 < ip < instructions.count
	//OR also if the stack pointer is less than the heap. This would throw a CPUError every time like an interrupt.
	//YES we should check that .scp is < heap memory stack for stack overfloaw
	return .{};
}

tmov_ram_types : [] TMovRamType : #run enum_values_as_enum(TMovRamType);
TMovRamType :: enum u8 {
	TANO; //Default is that we go from_tano to to_tano
	NEUME;
}

tmov_array_types : [] TMovArrayType : #run enum_values_as_enum(TMovArrayType);
TMovArrayType :: enum {
	//int or float based on instruction type (although we could specify here)
	DEFAULT; 
	//TODO We use this to tmov music points into the tano so we can specify music point length 
	//This can be used relative to the tano being moved to
	NEUME;
}
//TODO Should we pull this out and grab it in any case?
// TMovType :: enum u8 {
// 	OP_1_RAM_TANO;
// 	OP_1_RAM_NOTE;
// }
//TODO We could remove this entirely and have a .tmov_mode instruction to change the behavior
//so we don't have to pollute this instruction, although maybe in this case it's ok because
//of the array type and other things.
TMovSettings :: struct {
	//TODO Remove this if we remove the RAM_NOTE case since we can just set it in a register
	// tmov_type : TMovType;
	//TODO add a setting that lets us specify TMovArrayType
	tmov_array_type : TMovArrayType;
}

//TODO get operands[2] to allow for different array return types like MusicPoint
//CAN ALSO specify if we want to update an already given resizable array as RAM_ARRAY
//instead of making a new array
//TODO Pull this out and reuse TMovArrayType
//TODO We could specify here no duplicates for int and float to simplify set operations
TanoToArraySettings :: struct {
	return_array_count : int;
	return_array_data : int;

	return_array_type : TMovArrayType;
	//TODO Could use this to remove duplicates in the asm instruction
	//but we would use the int as a bool to keep it 64-bit values
	// remove_duplicates : int;
}

TANO_STACK_MSPACE : int : -1;

TanoOpOffsets :: struct {
	row_start_op : MusicOperand;
	row_end_op : MusicOperand;
	x_start_op : MusicOperand;
	x_end_op : MusicOperand;
	mspace_op : MusicOperand;
}
GetTanoOpOffsets :: inline (op : MusicOperand) -> TanoOpOffsets {
	offsets : TanoOpOffsets = ---;
	offsets.row_start_op = op;
	offsets.row_end_op = AddOperandOffset(8, op);
	offsets.x_start_op = AddOperandOffset(16, op);
	offsets.x_end_op = AddOperandOffset(24, op);
	offsets.mspace_op = AddOperandOffset(32, op);
	return offsets;
}

/*TODO Move this back to .mov if we only allow single values for push and pop and then
have that be its own single value operand case without mov_size.
So far I am feeling like push with mov_size is confusing and prefer using only .mov with mov_size
whenever I need to copy over > 8 bytes of memory eg with a struct or array value.

TODO We could return an error or a warning. Error could end execution and a warning could just be printed somewhere.
Maybe automatically pause execution during debugging.
*/
ExecMov :: inline (ci : MusicInstruction, ad : *AllData) -> CPUError {
	mov_size : int = ComputeMovSize(ci.operands[2], ad.all_register_memory, ad.ram_memory);
	if ci.operands[0].operand_type == {
	case MusicOperandType.REGISTER;
		//TODO We could just ignore this but this makes it explicit for now in case theres a weird issue.
		if mov_size != 8 {
			return CPUErr(sprint("mov_size must == 8 for operand %.\n", ci.operands[1],, context.allocator));
		}
		ad.all_register_memory[ci.operands[0].int_value] = 
			ComputeMemoryValue(ci.operands[1], ad.all_register_memory, ad.ram_memory);
		//TODO If we allow mov_size <= 8 here, then we would just have to set reg = 0 and then do memcpy
		//They could be separate cases for mov_size == 8 and mov_size <= 8 or just the same case
		// ad.all_register_memory[ci.operands[0].int_value] = 0;
		// mv := ComputeMemoryValue(ci.operands[1], ad.all_register_memory, ad.ram_memory);
		// memcpy(*ad.all_register_memory[ci.operands[0].int_value], *mv, mov_size);
	case MusicOperandType.RAM_MEMORY; {
		ram_address : int = ComputeRAMLocation(ci.operands[0], ad.all_register_memory, ad.ram_memory);
		ram_ptr : *u8 = GetMemory(ram_address, mov_size, ad.ram_memory);
		/*I prefer this method to checking mov_size == 8 because then it works for strings and having a string
		of size 8 does not assume a memory_value although it would still work. This seems clearer for now
		but can reconsider later when we implement string or possibly (but unlikely) other types.
		*/
		value_ptr : *u8;
		if ci.operands[1].operand_type == {
		case .FLOAT; #through;
		case .INTEGER; #through;
		case .REGISTER;
			//TODO Can change to mov_size <= 8 later if we allow it for string or (unlikely) other types.
			if mov_size > 8 {
				return CPUErr(sprint("mov_size must <= 8 for operand %.\n", ci.operands[1],, context.allocator));
			}
			mv : MemoryValue = ComputeMemoryValue(ci.operands[1], ad.all_register_memory, ad.ram_memory);
			value_ptr = cast(*u8) *mv;
		case .RAM_MEMORY; 
			mem_address_1 : int = ComputeRAMLocation(ci.operands[1], ad.all_register_memory, ad.ram_memory);
			err : CPUError = ---;
			value_ptr, err = GetMemory(mem_address_1, mov_size, ad.ram_memory);
			if err.is_error return err;
		case .MUSIC_MEMORY;
			//TODO THIS WOULD LIKELY BE A SEPARATE CASE ENTIRELY SINCE WE WOULD COPY THEM DIFFERENTLY UNLESS
			//WE JUST STORE THE INTEGERS HERE BUT THEN IF WE HAVE FLOAT MUSIC_PTS ONLY WOULD HAVE TO CONSIDER THAT.
			//TODO We can use this to move all notes to ram and this can checked with the .dim instruction
			//TODO Technically we should be able to move 1 note to ram or register but should consider doing that 
			//with a different instruction since it is fundamentally different operation.
			//TODO We could do this to RAM_ARRAY instead now to mov music points from music memory to ram memory.
			assert(false, "Not Implemented : Cannot 'mov mem music'");
		}
		memcpy(ram_ptr, value_ptr, mov_size);
	}
	case MusicOperandType.RAM_ARRAY; {
		//TODO Can use this to create an array with a starting value in ram OR also just allow conversion
		//from music memory to ram memory directly.
	}
	case .MUSIC_MEMORY; {
		//TODO Implement this while testing mov since we should get a feel for all of them at the same time.
		if ci.operands[1].operand_type == {
		case .FLOAT; #through;
		case .INTEGER; #through;
		case .REGISTER; #through;
		case .RAM_MEMORY;
			//TODO operands[2] here should be music_point length
			//TODO Should make this error output more consistent with op and operands and error condition.
			//TODO Should we even allow mov_size here or just have it be 8.
			assert(mov_size == 8, "mov_size must == 8 for operand %.\n", ci.operands[1]);
			// if mov_size != 8 {
			// 	return CPUErr(sprint("mov_size must == 8 for operand %.\n", ci.operands[1],, context.allocator));
			// }
			//TODO This could be ComputeMultiMemoryFloat and then RAM can be used to load many values at once,
			//like with the set operators.
			mv : MemoryValue = ComputeMemoryValue(ci.operands[1], ad.all_register_memory, ad.ram_memory);
			row_index, x_index := MusicMemRowAndXIndex(ci.operands[0], ad.all_register_memory, ad.global_rules.row_size);
			//TODO Could override the type if we have immediate float or integer
			CreateMusicPtByIType(ci.instr_type, mv, x_index, x_index+1, row_index, *ad.all_mspace_data[0].all_music_pts);
		case .RAM_ARRAY;
			//TODO ci.operands[2] could be the size of the notes here instead.

			/*TODO IF RAM_ARRAY is 2nd operand, then we could do split here and move the values in the RAM_ARRAY
			over by index. This would help with for example munit[0][0][0] where the 3rd value could even be an array
			or something like that...
			*/
			to_row_index, to_x_index := MusicMemRowAndXIndex(ci.operands[0], ad.all_register_memory, ad.global_rules.row_size);
			from_values : [] float64 = ComputeMultiMemoryFloat(ci.instr_type, ci.operands[1], 
				ad.all_register_memory, ad.ram_memory, ad.all_mspace_data[0].all_music_pts, ad.global_rules.row_size);

			CreateManyMusicPtsInMemory(from_values, to_row_index, to_x_index, to_x_index+1,
				*ad.all_mspace_data[0].all_music_pts);

		case .MUSIC_MEMORY;
			//TODO These can be int or float now...
			from_row, from_x := MusicMemRowAndXIndex(ci.operands[1], ad.all_register_memory, ad.global_rules.row_size);
			to_row, to_start_x := MusicMemRowAndXIndex(ci.operands[0], ad.all_register_memory, ad.global_rules.row_size);

			//TODO Need to check if mov_size is negative so we start from behind the music_mem value
			//TODO This can be float here now so we should allow that.
			mov_size_float : float64 = 1;
			if ci.operands[2].operand_type != .NONE {
				//TODO Do we really want this range stuff or just make a loop? What about inverse operations?
				// mov_size = ComputeOperandInt(ci.operands[2], ad.all_register_memory, ad.ram_memory);
				mem_value := ComputeMemoryValue(ci.operands[2], ad.all_register_memory, ad.ram_memory);
				if ci.instr_type == {
				case .INTEGER;
					mov_size_float = cast(float64) mem_value.int_value;
					if ci.operands[2].operand_type == .FLOAT {
						mov_size_float = mem_value.float_value;
					}
				case .FLOAT;
					mov_size_float = mem_value.float_value;
					if ci.operands[2].operand_type == .INTEGER {
						mov_size_float = cast(float64) mem_value.int_value;
					}
				}
			}

			//TODO User error.
			//Technically this could wrap around to the next row
			assert(from_x + mov_size_float < cast(float64) ad.global_rules.row_size &&
				    to_start_x + mov_size_float < cast(float64) ad.global_rules.row_size);

			//TODO We should just be updating the points directly in the array and not making a new array here.
			//This is very inefficient since mov music memory is always going to be an update on music points.
			from_music_pts : [] MusicPoint = 
				GetAllMemoryMusicPtsInRange(from_x, from_x + mov_size_float, from_row, ad.all_mspace_data[0].all_music_pts);

			//TODO Update this to fix a few bugs
			UpdateMusicPtsFromMinStart(from_music_pts, to_start_x, to_row, ad.global_rules.row_size);
			CreateManyMusicPtsInMemory(from_music_pts, *ad.all_mspace_data[0].all_music_pts);
		}
	}
	}
	return .{};
}

/*TODO Implement a free list in here once we do that with free.
We use this function so we can allocate memory on the heap anywhere in asm.
*/
AllocHeapMem :: inline (size_in_bytes : int, ad : *AllData) -> alloc_heap_address : int, out_of_memory : CPUError {
	alloc_heap_address : int = ad.all_register_memory[RegDef.hcp].int_value;
	//TODO This is technically an OutOfMemoryException, but we might allow the size of the heap to increase later.
	bounds_err := MemoryInBounds(ad.ram_memory, alloc_heap_address, size_in_bytes);
	if bounds_err.is_error {
		err := CPUErr(sprint("Out of heap memory : %. RAM location is % and size is % bytes.\n", 
			ad.ram_memory.bytes.count, alloc_heap_address, size_in_bytes,,context.allocator));
		return -1, err;
	}
	//TODO Could also check if this is out of bounds at the end of every instruction and return an error if so.
	//OR that might be different when we use the free list for heap allocation.
	ad.all_register_memory[RegDef.hcp].int_value += size_in_bytes;
	return alloc_heap_address, NO_CPU_ERROR;
}

ComputeMovSize :: inline (operand : MusicOperand, all_registers : [] MemoryValue, ram : RAMMemory) -> int {
	mov_size : int = 8;
	if operand.operand_type != .NONE {
		mov_size = ComputeOperandInt(operand, all_registers, ram);
	}
	return mov_size;
}

//TODO We can remove this eventually if we only have float64 as the
//music_pt_pos which is likely.
MVToFVAndIV :: inline (mv : MemoryValue, t : InstructionType) -> float64, int {
	fv : float64;
	iv : int;
	if t == {
	case .INTEGER;
		iv = mv.int_value;
		fv = cast(float64) iv;
	case .FLOAT;
		fv = mv.float_value;
		iv = cast(int) fv;
	}
	return fv, iv;
}

/*TODO This should return some consistent and general errors which then get checked and added in the layer above.
*/
ComputeMemoryValue :: inline (
	operand : MusicOperand,
	all_register_memory : [] MemoryValue,
	ram_memory : RAMMemory)
-> MemoryValue
{
	mv : MemoryValue;
	if operand.operand_type == {
	case MusicOperandType.REGISTER;
		mv = all_register_memory[operand.values[0].int_value];
	case MusicOperandType.FLOAT; #through;
	case MusicOperandType.INTEGER;
		mv = operand.values[0].value;
	case MusicOperandType.RAM_MEMORY;
		mem_address : int = ComputeRAMLocation(operand, all_register_memory, ram_memory);
		//This seems to a be about 5 instructions shorter than memcpy and also clearer ram_memory);
		mv = GetMemValue(mem_address, MemoryValue, ram_memory);
		// memcpy(*int_value, *ad.ram_memory.bytes[mem_address], size_of(int));
	}
	return mv;
}

ComputeOperandInt :: inline (
	operand : MusicOperand, 
	all_register_memory : [] MemoryValue, 
	ram_memory : RAMMemory) 
-> int 
{
	mv := ComputeMemoryValue(operand, all_register_memory, ram_memory);
	return mv.int_value;
}

//I am compiling these out because I am not sure if they are generalized. I think it may depend
//on a case by case what we want to force or not. I will just leave here as a reminder for now but
//we can delete it if it's not used.
#if 0 {
MemValueForceFloat :: inline (
	instr_type : InstructionType,
	operand : MusicOperand,
	all_register_memory : [] MemoryValue,
	ram_memory : RAMMemory)
-> float64
{
	float_value : float64;
	mem_value := ComputeMemoryValue(operand, all_register_memory, ram_memory);
	if instr_type == {
	case .INTEGER;
		float_value = cast(float64) mem_value.int_value;
		if operand.operand_type == .FLOAT {
			float_value = mem_value.float_value;
		}
	case .FLOAT;
		float_value = mem_value.float_value;
		if operand.operand_type == .INTEGER {
			float_value = cast(float64) mem_value.int_value;
		}
	}
	return float_value;
}
}

/*TODO There is likely a consistent way of doing this that is only used for MUSIC_MEMORY and so that version
should be specific to MUSIC_MEMORY and probably only deal with floats.
Then we could have another one for other arrays in memory if needed but those may be specific to the instruction
like with muscall so then we should implement specifically for that instruction in ExecMInstr.

COULD RENAME THAT TO ComputeMusicValue or something like that

TODO Could pull out memory values for less input and separate from MUSIC_MEMORY
and combine if we need in some cases like set operators
*/
ComputeMultiMemoryFloat :: inline (
	instr_type : InstructionType,
	operand : MusicOperand,
	all_register_memory : [] MemoryValue,
	ram_memory : RAMMemory,
	all_music_pts : [] MusicPoint,
	row_size : int)
-> [] float64
{
	values : [] float64;
	if operand.operand_type == {
	case MusicOperandType.FLOAT; #through;
	case MusicOperandType.INTEGER; #through;
	case MusicOperandType.REGISTER; #through;
	case MusicOperandType.RAM_MEMORY;
		values = NewArray(1, float64, false,, context.allocator);
		mv : MemoryValue = ComputeMemoryValue(operand, all_register_memory, ram_memory);
		if instr_type == {
		case .INTEGER; values[0] = cast(float64) mv.int_value;
		case .FLOAT;   values[0] = mv.float_value;
		}
	case MusicOperandType.MUSIC_MEMORY;
		from_row_index, from_x_index := MusicMemRowAndXIndex(operand, all_register_memory, row_size);
		values = GetAllMusicPtFloat(from_row_index, from_x_index, all_music_pts);
	case MusicOperandType.RAM_ARRAY;
		/*TODO Separate this so we can grab only from RAM_ARRAY in .mov. I think operators can grab from
		anywhere so we can make another function with both ram memory and music memory.
		*/
		//TODO One way is to always assume .count and .data so we would have to store an array_view on the
		//stack if we find a fixed array for example. This would work in all cases and only add 128 bits
		//which we could remove after the instruction, although maybe not if we have added other things.
		//TODO This defaults to grabbing from an array but we could also have different options if needed.
		//ALSO what if we only want float? Maybe that would be a separate function that grabs only float
		//and makes sure that its all float.
		//TODO Should we have data first or count first, is there any difference or advantage?
		//Jai does (count,data) but it seems like we access the data more often in the compiler,
		//so it may be beneficial to put the data first.
		//TODO Could make a function here GetRamArrayValues
		array_count : int = ComputeMusicOperandValue(operand.values[0], all_register_memory);
		array_data : int = ComputeMusicOperandValue(operand.values[1], all_register_memory);

		#if 0 {
		mv : MemoryValue = ComputeMemoryValue(operand, all_register_memory, ram_memory);
		mem_address : int = ComputeRAMLocation(operand, all_register_memory, ram_memory);
		array_count : int = GetMemValue(mem_address, int, ram_memory);
		//TODO This is check in GetMemValue but if we check here then maybe we can return an error or check all array
		//values based on instruction types when we check errors at the beginning.
		// assert(mem_address+8 < ram_memory.bytes.count);
		data_address : int = GetMemValue(mem_address+8, int, ram_memory);
		//TODO likely pass in context.allocator here but we can see later.
		}
		values = NewArray(array_count, float64, false,, context.allocator);
		if instr_type == {
		case .INTEGER;
			for 0..array_count-1 {
				values[it] = cast(float64) GetMemValue(array_data + 8*it, int, ram_memory);
			}
		case .FLOAT;
			for 0..array_count-1 {
				values[it] = GetMemValue(array_data + 8*it, float64, ram_memory);
			}
		}
		//TODO We could allow a range here to grab an array of values but maybe that would depend on the instruction.
		//We could put the instruction specific fetch here or check for each instruction.
		//TODO Default case could be SIZE in memory and then grab 8 bytes of size. Unless we have a different instruction.
		//TODO Could also have types where the first value is the type so eg 0 would mean we have 1 value
		//but 1 would mean the next is count and then we grab all after. OR it could depend on the instruction
		//so some instructions will grab only 1 value and some will grab multi. One value would just be 1 though.
	}
	return values;
}


//TODO This could return OperandValue now in case we have float... now sure how were gonna do float yet though.
ComputeMusicOperandValue :: inline (op_value : MusicOperandValue, all_register_memory : [] MemoryValue) -> int {
	value : int = op_value.int_value;
	if op_value.type == .REGISTER {
		value = all_register_memory[op_value.int_value].int_value;
	}
	return value;
}

//TODO Can remove ram from here now since we validate the operand beforehand if it's ok.
ComputeRAMLocation :: inline (
	operand : MusicOperand,
	all_register_memory : [] MemoryValue,
	ram : RAMMemory)
-> int
{
	v0 : int = ComputeMusicOperandValue(operand.values[0], all_register_memory);
	v1 : int = ComputeMusicOperandValue(operand.values[1], all_register_memory);
	mem_location : int = v0 + v1;
	//TODO No longer need this check since we validate instruction before executing. Can put it back if needed.
	// assert(mem_location >= 0 && mem_location < ram.bytes.count);
	return mem_location;
}
ComputeRAMLocationCheck :: inline (
	operand : MusicOperand,
	all_register_memory : [] MemoryValue,
	ram : RAMMemory,
	mem_size_in_bytes : int)
-> int, CPUError
{
	ram_location : int = ComputeRAMLocation(operand, all_register_memory, ram);
	in_bounds : CPUError = MemoryInBounds(ram, ram_location, mem_size_in_bytes);
	return ram_location, in_bounds;
}


//TODO Can remove row_size from here since we can just check beforehand. We can put NoCheck in the function name
//too to explicitly show that you should validate the instructon beforehand. In any case, this could only be 
//used internally and so we don't validate to avoid passing errors around everywhere which would make the code
//both more complicated and slower.
/*TODO DOC : We don't use music memory anymore since we replace that with tano BUT we can still have it for completeness
but then we have to pass in the size of that specific row and we can either fetch that in here or pass it in externally
since the sizes of rows can be different NOW.
*/
MusicMemRowAndXIndex :: (
	operand : MusicOperand, 
	all_register_memory : [] MemoryValue,
	row_size : int) 
-> row_index : int, x_index : float64
{
	row_index : int = ComputeMusicOperandValue(operand.values[0], all_register_memory);
	#if 0 {
	x_index : int = ComputeMusicOperandValue(operand.values[1], all_register_memory);
	} else {
	//TODO Should this be a separate function or will we only use it here?
	//I think this is unique and we can leave it here since it is not affected by instruction type.
	/*TODO I see this as being a case where we could grab from float or int register depending on register type.
	It does mean things might be inconsistent and unclear though but this seems like a good case for it
	since passing in an int or float register does make sense either way.
	*/
	x_index : float64;
	if operand.values[1].type == {
	case .INTEGER; x_index = cast(float64) operand.values[1].int_value;
	case .FLOAT; x_index = operand.values[1].float_value;
	case .REGISTER; x_index = all_register_memory[operand.values[1].int_value].float_value;
	}
	}
	return row_index, x_index;
}

//TODO I think we can remove this since we wont compute it like this anymore
MusicMemIndex :: inline (
	operand : MusicOperand, 
	all_register_memory : [] MemoryValue,
	row_size : int) 
-> int 
{
	assert(operand.values[0].type != .NONE || operand.values[1].type != .NONE);

	x : int = ComputeMusicOperandValue(operand.values[0], all_register_memory);
	y : int = ComputeMusicOperandValue(operand.values[1], all_register_memory);
	music_mem_index : int = x + y * row_size;

	/*TODO Check memory_index or row_index < max. We need to pass this
	  message somewhere so for now we don't but once we have the debugger.
	*/

	return music_mem_index;
}
/*End of Instruction Execution
*/

/*An idea for generalized error message with language support.
*/

//TODO These can all be generated at compile-time.
ErrorMessageType :: enum {
	RAM_OUT_OF_BOUNDS;
}

ErrorMessage :: struct {
	msg : string;
}

ALL_ERROR_MESSAGES : AllErrorMessages;
AllErrorMessages :: struct {
	eng : [] ErrorMessage;
	fre : [] ErrorMessage;
	ita : [] ErrorMessage;
}
