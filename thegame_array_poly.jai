#import "Basic";
/*TODO
	should maybe eventually pull these out as thegame_data_query
	or maybe only when we begin optimizing the tables

	Should we just put this in thegame_shared_library to remove 1 import?
	I guess we usually use them but maybe in general i prefer encouraging loops?
	I don't know... What do you think?
*/

//TODO Update this with new ,, operator to have no allocator
CreateArray :: inline (
	//TODO maybe report this as we must add this here,
	//otherwise it does not compile with the ..$T
	$T : Type,
	allocator : Allocator,
	values : ..T)
-> [] T
{
	array : [] T = NewArray(values.count, T, false,, allocator);
	for values array[it_index] = it;
	return array;
}

TempArray :: inline (values : ..$T) -> [] T {
	array : [] T = NewArray(values.count, T, false,, temp);
	for values array[it_index] = it;
	return array;
}

ContextArray :: inline (values : ..$T) -> [] T {
	array : [] T = NewArray(values.count, T, false,, context.allocator);
	for values array[it_index] = it;
	return array;
}

CreateArray :: inline (values : ..$T) -> [] T {
	array : [] T = NewArray(values.count, T, false,, context.allocator);
	for values array[it_index] = it;
	return array;
}

#if 0 {
//Note : this does not work i believe because the stack frame 
//is destroyed once we step out of this function
CreateFixedArray :: inline (
	$array_count : int, 
	values : ..$T)
-> [] T
{
	array : [array_count] T;
	for values array[it_index] = it;
	return array;
}
}

//TODO Update this with new ,, operator to have no allocator
ArrayCopy :: (array: [] $T, allocator : Allocator = temp) -> [] T {
    dest := NewArray(array.count, T, false,, allocator);
    memcpy(dest.data, array.data, array.count * size_of(T));
    return dest;
}


ArraySubtract :: (a : [] $T, b : [] T) -> [] T {
	assert(a.count == b.count);

	result := NewArray(a.count, T);
	for 0..a.count-1 {
		result[it] = a[it] - b[it];
	}
	return result;
}

AddToAllArrays :: inline (
	element : $T,
	many_arrays : .. *[..] T)
{
	for array : many_arrays {
		array_add(array, element);
	}
}

ArrayUnorderedRemoveFirstByValue :: inline (array: *[] $T, item: T) -> is_removed : bool {
	is_removed : bool = false;
    for <<array  if it == item { 
        remove it;
        is_removed = true;
        break;
    }
    return is_removed;
}

//TODO with a memcpy generic remove and then memcpy everything over
// ArrayOrderedRemoveByIndex :: inline () {
// }

my_add_if_unique :: (array: *[..] $T, item: T) -> bool, s64 {   // Return true if newly added; also return index.
    found, index := ArrayFindByValue(<<array, item);
    if found return false, index;

    array_add(array, item);
    return true, array.count-1;
}

ArrayFindByValue :: (array: [] $T, item: T) -> bool, s64 {
    for array if it == item return true, it_index; 
    return false, -1;  // Not found.
}

ArrayFindByValue :: (array: [] $T, item: T, EqualsProc : (T,T) -> bool) -> bool, s64 {
    for array if EqualsProc(it, item) return true, it_index; 
    return false, -1;  // Not found.
}

ArrayFindByValueProc :: (
	array: [] $T, item: T,
	EqualsProc : (T, T) -> bool) 
-> bool, s64 
{
    for array if EqualsProc(it, item) return true, it_index; 
    return false, -1;  // Not found.
}

ArrayFindByValue :: (array: [] float64, item: float64) -> bool, s64 {
    for array if Float64Equal(it, item) return true, it_index; 
    return false, -1;  // Not found.
}

ArrayFindByValue :: (array: [] float, item: float) -> bool, s64 {
    for array if FloatEqual(it, item) return true, it_index; 
    return false, -1;  // Not found.
}

array_find_by_pointer :: (array: [] $T, item: T) -> bool, *T {
    for * array if <<it == item return true, it;
    return false, null;  // Not found.
}

//TODO could do a version where we pass in an increment function
//for non-numeric types
ArrayFindMaxByNameId :: inline (
	array: [] $T, 
	$name_id : string, min : $S) 
-> S 
{
	max : S = min;
    for array 
    {
    	is_greater : bool = #insert -> string {
    		return builder_string("it.% > max;", name_id);
    	}
    	if is_greater 
    	{
    		max = #insert -> string {
	    		return builder_string("it.%;", name_id);
	    	}
	    }
    }
    return max;
}

ArrayFindMin :: inline (array: [] $T, max : T) -> T 
{
	min : T = ArrayFindByProc(array, max, (t1,t2) => t1 < t2);
	return min;
}

ArrayFindMax :: inline (array: [] $T, min : T) -> T 
{
	max : T = ArrayFindByProc(array, min, (t1,t2) => t1 > t2);
	return max;
}

default_builder : String_Builder;
builder_string :: (format_string : string, args : .. string) -> string {
	print_to_builder(*default_builder, format_string, args[0]);
	return builder_to_string(*default_builder);
}

builder_string_2 :: (format_string : string, args : .. string) -> string {
	print_to_builder(*default_builder, format_string, args[0], args[1]);
	return builder_to_string(*default_builder);
}
//TODO Maybe we can move all these into their own module, but in general I don't really like them
//and likely we will move them anyways once we access data specific to each array.
ArrayFindFirstByNameId :: (
	array: [] $T, 
	id: $S, $name_id : string)
-> *T, bool 
{
    for * array {
    	equal_ids := #insert -> string {
    		return builder_string("(<<it).% == id;", name_id);
    	}
    	if equal_ids return it, true;
    }
    return null, false;  // Not found.
    //TODO could assert in here and add a compiler flag
}
ArrayFindFirstConstByNameId :: (
	array: [] $T, 
	id: $S, $name_id : string) 
-> T, bool 
{
    for array {
    	equal_ids := #insert -> string {
    		return builder_string("it.% == id;", name_id);
    	}
    	if equal_ids return it, true;
    }
    return T.{}, false;  // Not found.
    //TODO could assert in here and add a compiler flag
}
//TODO Can replace with context allocator once we update jai
//TODO should we make temp the default allocator for these?
//TODO could make a version where allocator is passed in at compile-time
//TODO Should remove the allocator here and just use context allocator now
ArrayFindAllVarName :: (
	array: [] $T, 
	id: $S, 
	$name_id : string,
	allocator : Allocator = .{})
-> [] T 
{
    a := ifx allocator.proc then allocator else context.allocator;
	result : [..] T;
	result.allocator = a;
    for array {
    	equal_ids := #insert -> string {
    		return builder_string("it.% == id;", name_id);
    	}
    	if equal_ids {
    		array_add(*result, it);
    	}
    }
    return result;
}
//TODO should we separate this general data array code from the
//more game-specific data code
/*Probably can replace with an array_resize and memcpy
*/
ArrayAddAll :: inline (array : [] $T, add_to : *[..] T) {
	//TODO probably a faster way to do this with memcpy
	//if we have enough space in the resizable array,
	//otherwise we need to reserve more space
	//array_resize and then memcpy
	for array array_add(add_to, it);
}

ArrayFindByProc :: inline (
	array : [] $T, 
	initial_value : T, 
	proc : (x1:T,x2:T) -> bool)
-> T
{
	value : T = initial_value;
    for array if proc(it,value) value = it;
    return value;	
}

ArrayFindMinByNameId :: (
	array: [] $T, 
	$name_id : string, max : $S)
-> S 
{
	min : S = max;
    for array {
    	is_less : bool = #insert -> string {
    		return builder_string("it.% < min;", name_id);
    	}
    	if is_less {
    		min = #insert -> string {
	    		return builder_string("it.%;", name_id);
	    	}
	    }
    }
    return min;
}

ArrayFindMinValueByNameId :: (
	array: [] $T, 
	$name_id : string, max : $S)
-> T, bool
{
	value : T;
	found_value : bool = false;
	min : S = max;
    for array 
    {
    	is_less : bool = #insert -> string {
    		return builder_string("it.% < min;", name_id);
    	}
    	if is_less 
    	{
    		found_value = true;
    		value = it;
    		min = #insert -> string {
	    		return builder_string("it.%;", name_id);
	    	}
	    }
    }
    return value, found_value;
}

DSPACE_ID_NAME :: "dspace_id";

//TODO could have a query builder for &&, ||, ==, !=, multiple values, etc...
//TODO for multiple values .. string at the end and then loop add && == name
//TODO Should this return an index or just the value?

ArrayFindFirstIndexByNameId :: (
	array: [] $T, 
	id: $S, $name_id : string)
-> int, bool 
{
    for array {
    	equal_ids := #insert -> string {
    		return builder_string("it.% == id;", name_id);
    	}
    	if equal_ids return it_index, true;
    }
    return -1, false;  // Not found.
    //TODO could assert in here and add a compiler flag
}

ArrayFindFirstByNameIdCheck :: inline (
	array: [] $T, 
	id: $S, $name_id : string) 
-> bool, *T 
{
	pointer, check := 
		ArrayFindFirstByNameId(array, id, name_id);
	return check, pointer;
}

ArrayFindFirstByAndOpCheck :: inline (array: [] $T,
	id_1: $S, $name_1 : string,
	id_2: $D, $name_2 : string) 
-> bool, *T
{
	result, check := ArrayFindFirstByAndOp(array, 
		id_1, name_1, id_2, name_2);
    return check, result;
}

ArrayFindFirstByAndOp :: (array: [] $T,
	id_1: $S, $name_1 : string,
	id_2: $D, $name_2 : string) 
-> *T, bool
{
    for * array {
    	equal_ids := #insert -> string {
    		return builder_string_2("it.% == id_1 && it.% == id_2;", name_1, name_2);
    	}
    	if equal_ids return it, true;
    }
    return null, false;
}

ArrayFindFirstConstByAndOp :: (array: [] $T,
	id_1: $S, $name_1 : string,
	id_2: $D, $name_2 : string) 
-> T, bool
{
    for * array {
    	equal_ids := #insert -> string {
    		return builder_string_2("it.% == id_1 && it.% == id_2;", name_1, name_2);
    	}
    	if equal_ids return it, true;
    }
    return T.{}, false;
}

ArrayFindFirstByAndOp :: (array: [] $T,
	EqualsProc1 : (S, S) -> bool, $name_1 : string, id_1: $S,
	EqualsProc2 : (D, D) -> bool, $name_2 : string, id_2: $D) 
-> *T, bool
{
    for * array {
    	equal_ids := #insert -> string {
    		return builder_string_2("EqualsProc1(it.%, id_1) && EqualsProc2(it.%, id_2);", name_1, name_2);
    	}
    	if equal_ids return it, true;
    }
    return null, false;
}

ArrayFindFirstByAndOp :: (array: [] $T,
	EqualsProc1 : (S, [] S) -> bool, $name_1 : string, id_1: [] $S,
	EqualsProc2 : (D, [] D) -> bool, $name_2 : string, id_2: [] $D) 
-> *T, bool
{
    for * array {
    	equal_ids := #insert -> string {
    		return builder_string_2("EqualsProc1(it.%, id_1) && EqualsProc2(it.%, id_2);", name_1, name_2);
    	}
    	if equal_ids return it, true;
    }
    return null, false;
}

ArrayFindFirstByAndOpCheck :: inline (array: [] $T,
	EqualsProc1 : (S, S) -> bool, $name_1 : string, id_1: [] $S,
	EqualsProc2 : (D, D) -> bool, $name_2 : string, id_2: [] $D) 
-> bool, *T
{
	pointer, check := ArrayFindFirstByAndOp(array,
		EqualsProc1, name_1, id_1, 
		EqualsProc2, name_2, id_2);
    return check, pointer;
}

ArrayFindFirstMultiArrayByNameId :: (id: $S, $name_id : string, $type : Type, arrays : .. $T) -> *type, bool {
	#assert type_info(T).type == Type_Info_Tag.ARRAY;
    for array_in_array : arrays {
    	for * array_in_array {
	    	equal_ids := #insert -> string {
	    		return builder_string("(<<it).% == id;", name_id);
	    	}
	    	if equal_ids return it, true;
	    }
    }
    return null, false;  // Not found.
}

//TODO i am not sure how a feel about camel case procedure as variable inputs
//should we use that or snake case?
ArrayFindFirstByNameId :: (
	array: [] $T, 
	id: $S, $name_id : string, 
	EqualsProc : (S, S) -> bool) 
-> *T, bool 
{
    for * array {
    	equal_ids := #insert -> string { 
    		return builder_string("EqualsProc((<<it).%, id);", name_id); 
    	}
    	if equal_ids return it, true;
    }
    return null, false;  // Not found.
}

ArrayFindAllVarNameByIndex :: (
	array: [] $T, 
	id: $S, 
	$name_id : string,
	allocator : Allocator = temp)
-> [] int 
{
	result : [..] int;
	result.allocator = allocator;
    for array {
    	equal_ids := #insert -> string {
    		return builder_string("it.% == id;", name_id);
    	}
    	if equal_ids array_add(*result, it_index);
    }
    return result;
}

/*Yes use new allocator with context allocator model, can and should update this everywhere
since this is the new convention and is more clear and consisten than the function parameter
passing method.
*/
ArrayFindAllMultiArrayByNameId :: (id: $S, $name_id : string, $type : Type, arrays : .. $T) -> [] type {
	#assert type_info(T).type == Type_Info_Tag.ARRAY;
	result : [..] type;
	for array_in_array : arrays {
	    for array_in_array {
	    	equal_ids := #insert -> string {
	    		return builder_string("it.% == id;", name_id);
	    	}
	    	if equal_ids array_add(*result, it);
	    }
	}
    return result;
}

//TODO this should just be part of the larger generated query 
ArrayCountAllVarName :: (
	array: [] $T, 
	id: $S, $name_id : string)
-> int 
{
	result_count : int = 0;
    for array {
    	equal_ids := #insert -> string {
    		return builder_string("it.% == id;", name_id);
    	}
    	if equal_ids result_count += 1;
    }
    return result_count;
}

ArrayAggregateMultiArrays :: ($type : Type, arrays : .. $T) -> [] type {
	#assert type_info(T).type == Type_Info_Tag.ARRAY;
	result : [..] type;
	for array_in_array : arrays {
	    for array_in_array {
	    	array_add(*result, it);
	    }
	}
    return result;
}

ArrayAggregatePointerMultiArrays :: ($type : Type, arrays : .. $T) -> [] *type {
	#assert type_info(T).type == Type_Info_Tag.ARRAY;
	result : [..] *type;
	for array_in_array : arrays {
	    for * array_in_array {
	    	array_add(*result, it);
	    }
	}
    return result;
}

ArrayFindAllVarName :: (
	array: [] $T, 
	id: $S, $name_id : string, 
	$EqualsProc : (S, S) -> bool,
	allocator : Allocator = .{}) 
-> [] T 
{
    a := ifx allocator.proc then allocator else context.allocator;
	result : [..] T;
	result.allocator = a;
    for array {
    	equal_ids := #insert -> string {
    		return builder_string("EqualsProc(it.%, id);", name_id);
    	}
    	if equal_ids array_add(*result, it);
    }
    return result;
}

/*TODO
	a version where both $name_id and id are are arrays
*/
ArrayFindAllArrayVarName :: (
	array : [] $T,
	all_ids : [] $S, $name_id : string,
	$EqualsProc : (S, [] S) -> bool,
	allocator : Allocator = .{})
-> [] T 
{
    a := ifx allocator.proc then allocator else context.allocator;
	result : [..] T;
	result.allocator = a;
    for array {
    	equal_ids := #insert -> string {
    		return builder_string("EqualsProc(it.%, all_ids);\n", name_id);
    	}
    	if equal_ids array_add(*result, it);
    }
    return result;
}

/*Note : this is like a join table
TODO rename to something with the word JOIN
*/
/*TODO Don't use this anymore instead just use a double loop, this is very unclear,
causes compiler issues on compiler updates and is generally difficult to maintain.
*/
ArrayFindAllByBothNames :: (
	array : [] $T, $array_var_name : string,
	all_ids : [] $S, 
	$EqualsProc : (v: int, a: [] S, $n: string) -> bool,
	$compare_var_name : string,
	allocator : Allocator = .{})
-> [] T 
{
    a := ifx allocator.proc then allocator else context.allocator;
	result : [..] T;
	result.allocator = a;
    for array {
    	equal_ids := #insert -> string {
    		return builder_string(
    		"EqualsProc(it.%, all_ids, compare_var_name);\n", array_var_name);
    	}
    	if equal_ids array_add(*result, it);
    }
    return result;
}

/*TODO Don't use this anymore instead just use a double loop, this is very unclear,
causes compiler issues on compiler updates and is generally difficult to maintain.
*/
ArrayFindAllByValueBothNames :: (
	array : [] $T, $array_var_name : string,
	all_ids : [] $S, 
	$EqualsProc : (v: int, a: [] S, $n: string) -> bool,
	$compare_var_name : string,
	$return_value_name : string, 
	$R : Type,
	allocator : Allocator = .{})
-> [] R
{
    a := ifx allocator.proc then allocator else context.allocator;
	result : [..] R;
	result.allocator = a;
    for array {
    	equal_ids := #insert -> string {
    		return builder_string(
    		"EqualsProc(it.%, all_ids, compare_var_name);\n", array_var_name);
    	}
    	if equal_ids {
    		value : R = #insert -> string {return builder_string(
    		"it.%;\n", return_value_name);
    		}
    		array_add(*result, value);
    	}
    }
    return result;
}

/*Note : In this case the order of array matters and 
we want the return value of all_ids. So we maintain
the order of array but grab the value of type of all_ids.
*/
/*TODO Don't use this anymore instead just use a double loop, this is very unclear,
causes compiler issues on compiler updates and is generally difficult to maintain.
*/
ArrayFindAllByBothNamesInOrder :: (
	array : [] $T, $array_var_name : string,
	all_ids : [] $S, 
	$EqualsProc : (v: int, a: [] T, $n: string) -> bool,
	$compare_var_name : string,
	allocator : Allocator = .{})
-> [] S
{
    a := ifx allocator.proc then allocator else context.allocator;
	result : [..] S;
	result.allocator = a;
    for all_ids {
    	equal_ids := #insert -> string {
    		return builder_string(
    		"EqualsProc(it.%, array, compare_var_name);\n", array_var_name);
    	}
    	if equal_ids array_add(*result, it);
    }
    return result;
}

/*TODO Don't use this anymore instead just use a double loop, this is very unclear,
causes compiler issues on compiler updates and is generally difficult to maintain.
*/
ArrayFindAllPointersByBothNames :: (
	array : [] $T, $array_var_name : string,
	all_ids : [] $S, 
	$EqualsProc : (v: int, a: [] S, $n: string) -> bool,
	$compare_var_name : string,
	allocator : Allocator = .{})
-> [] *T 
{
    a := ifx allocator.proc then allocator else context.allocator;
	result : [..] *T;
	result.allocator = a;
    for * array {
    	equal_ids := #insert -> string {
    		return builder_string(
    		"EqualsProc(it.%, all_ids, compare_var_name);\n", array_var_name);
    	}
    	if equal_ids array_add(*result, it);
    }
    return result;
}

ArrayFindAllPointersByNameId :: (
	array : [] $T,
	all_ids : [] $S,
	$name_id : string,
	EqualsProc : (S, [] S) -> bool,
	allocator : Allocator = .{}) 
-> [] *T 
{
    a := ifx allocator.proc then allocator else context.allocator;
	result : [..] *T;
	result.allocator = a;
    for * array {
    	equal_ids := #insert -> string {
    		return builder_string("EqualsProc(it.%, all_ids);\n", name_id);
    	}
    	if equal_ids array_add(*result, it);
    }
    return result;
}

ArrayFindAllPointersByNameId :: (
	array: [] $T, 
	id: $S, 
	$name_id : string,
	allocator : Allocator = .{}) 
-> [] *T 
{
    a := ifx allocator.proc then allocator else context.allocator;
	result : [..] *T;
	result.allocator = a;
    for * array {
		//TODO test if this is working when changing args accessing
    	equal_ids := #insert -> string {
    		return builder_string("it.% == id;", name_id);
    	}
    	if equal_ids array_add(*result, it);
    }
    return result;
}

ArrayFindAllPointersByNameId :: (
	array: [] $T, 
	id: $S, 
	$name_id : string, 
	EqualsProc : (S, S) -> bool,
	allocator : Allocator = .{})
-> [] *T 
{
    a := ifx allocator.proc then allocator else context.allocator;
	result : [..] *T;
	result.allocator = a;
    for * array {
		//TODO test if this is working when changing args accessing
    	equal_ids := #insert -> string {
    		return builder_string("EqualsProc(it.%, id);", name_id);
    	}
    	if equal_ids array_add(*result, it);
    }
    return result;
}

/*TODO SoA
	Can generalize an SoA by having a query with pointers
	to all the arrays and then search a subset of the arrays
	based on a value and then return by aggregating all the 
	arrays together into the struct automatically.
*/
/*TODO
	more robust version of this search function with array of :
	values (size n) 
	variable names (size n) 
	procedure validations (size n)
	logical operators between each sequential validation pair (size n-1)

	can have multiple chunks like the above for each query set
*/
ArrayFindAllByOp :: (array: [] $T, 
	id_1: $S, $name_1 : string, EqualsProc1 : (S,S) -> bool, 
	id_2: $D, $name_2 : string, EqualsProc2 : (D,D) -> bool,
	OpProc : (bool,bool) -> bool,
	allocator : Allocator = .{})
-> [] T 
{
    a := ifx allocator.proc then allocator else context.allocator;
	result : [..] T;
	result.allocator = a;
    for array {
    	equal_ids := #insert -> string {
    		return builder_string_2(
    			"OpProc(EqualsProc1(it.%, id_1), EqualsProc2(it.%, id_2));", 
    			name_1, name_2);
    	}
    	if equal_ids array_add(*result, it);
    }
    return result;
}

ArrayFindAllByArrayOp :: (array: [] $T, 
	id_1: [] $S, $name_1 : string, EqualsProc1 : (S, [] S) -> bool, 
	id_2: [] $D, $name_2 : string, EqualsProc2 : (D, [] D) -> bool,
	OpProc : (bool,bool) -> bool,
	allocator : Allocator = .{})
-> [] T 
{
    a := ifx allocator.proc then allocator else context.allocator;
	result : [..] T;
	result.allocator = a;
    for array {
    	equal_ids := #insert -> string {
    		return builder_string_2(
    			"OpProc(EqualsProc1(it.%, id_1), EqualsProc2(it.%, id_2));", 
    			name_1, name_2);
    	}
    	if equal_ids array_add(*result, it);
    }
    return result;
}

//TODO should also maybe change the order for name and id
//i seem to make the mistake of order quite often
ArrayFindAllByAndOp :: (array: [] $T,
	id_1: $S, $name_1 : string,
	id_2: $D, $name_2 : string,
	allocator : Allocator = .{})
-> [] T 
{
    a := ifx allocator.proc then allocator else context.allocator;
	result : [..] T;
	result.allocator = a;
    for array {
    	equal_ids := #insert -> string {
    		return builder_string_2("it.% == id_1 && it.% == id_2;", name_1, name_2);
    	}
    	if equal_ids array_add(*result, it);
    }
    return result;
}

ArrayFindAllByValueAndOp :: (array: [] $T,
	id_1: $S, $name_1 : string,
	id_2: $D, $name_2 : string,
	$return_value_name : string,
	$R : Type,
	allocator : Allocator = .{})
-> [] R
{
    a := ifx allocator.proc then allocator else context.allocator;
	result : [..] T;
	result.allocator = a;
    for array {
    	equal_ids := #insert -> string {
    		return builder_string_2("it.% == id_1 && it.% == id_2;", name_1, name_2);
    	}
    	if equal_ids {
    		value : R = #insert -> string {return builder_string(
    		"it.%;\n", return_value_name);
    		}
    		array_add(*result, value);
    	}
    }
    return result;
}

ArrayFindAllPointersByAndOp :: (array: [] $T, 
	id_1: $S, $name_1 : string, 
	id_2: $D, $name_2 : string,
	allocator : Allocator = .{}) 
-> [] *T 
{
    a := ifx allocator.proc then allocator else context.allocator;
	result : [..] *T;
	result.allocator = a;
    for * array {
    	equal_ids := #insert -> string {
    		return builder_string_2("it.% == id_1 && it.% == id_2;", name_1, name_2);
    	}
    	if equal_ids array_add(*result, it);
    }
    return result;
}

ArrayFindAllByAndOp :: (array: [] $T, 
	id_1: $S, $name_1 : string, EqualsProc1 : (S, S) -> bool, 
	id_2: $D, $name_2 : string, EqualsProc2 : (D, D) -> bool,
	allocator : Allocator = .{})
-> [] T 
{
    a := ifx allocator.proc then allocator else context.allocator;
	result : [..] T;
	result.allocator = a;
    for array {
    	equal_ids := #insert -> string {
    		return builder_string_2(
    			"EqualsProc1(it.%, id_1) && EqualsProc2(it.%, id_2);",
    			name_1, name_2);
    	}
    	if equal_ids array_add(*result, it);
    }
    return result;
}

ArrayFindAllByArrayAndOp :: (array: [] $T, 
	id_1: [] $S, $name_1 : string, EqualsProc1 : (S, [] S) -> bool, 
	id_2: [] $D, $name_2 : string, EqualsProc2 : (D, [] D) -> bool,
	allocator : Allocator = .{})
-> [] T 
{
    a := ifx allocator.proc then allocator else context.allocator;
	result : [..] T;
	result.allocator = a;
    for array {
    	equal_ids := #insert -> string {
    		return builder_string_2(
    			"EqualsProc1(it.%, id_1) && EqualsProc2(it.%, id_2);", 
    			name_1, name_2);
    	}
    	if equal_ids array_add(*result, it);
    }
    return result;
}

ArrayFindAllByAndOpArrayEquals :: (array: [] $T, 
	id_1: [] $S, $name_1 : string, 
		EqualsProcArray1 : (S, [] S, (S,S) -> bool) -> bool, 
		EqualsProc1 : (S, S) -> bool, 
	id_2: [] $D, $name_2 : string, 
		EqualsProcArray2 : (D, [] D, (D,D) -> bool) -> bool, 
		EqualsProc2 : (D, D) -> bool)
-> [] T 
{
	result : [..] T;
    for array {
    	equal_ids := #insert -> string {
    		return builder_string_2(
    			"EqualsProcArray1(it.%, id_1, EqualsProc1) && EqualsProcArray2(it.%, id_2, EqualsProc2);", 
    			name_1, name_2);
    	}
    	if equal_ids array_add(*result, it);
    }
    return result;
}

ArrayFindAllPointersByAndOp :: (array: [] $T,
	id_1: $S, $name_1 : string, EqualsProc1 : (S, S) -> bool,
	id_2: $D, $name_2 : string, EqualsProc2 : (D, D) -> bool)
-> [] *T
{
	result : [..] *T;
    for * array {
    	equal_ids := #insert -> string {
    		return builder_string_2(
    			"EqualsProc1(it.%, id_1) && EqualsProc2(it.%, id_2);",
    			name_1, name_2);
    	}
    	if equal_ids array_add(*result, it);
    }
    return result;
}

ArrayRemoveAllByAndOp :: (array: *[] $T, 
	id_1: $S, $name_1 : string, 
	id_2: $D, $name_2 : string) 
{
    for <<array {
    	equal_ids := #insert -> string {
    		return builder_string_2("it.% == id_1 && it.% == id_2;", name_1, name_2);
    	}
    	if equal_ids remove it;
    }
}

ArrayRemoveAllByAndOpAndReturn :: (
	array: *[] $T, 
	id_1: $S, $name_1 : string, 
	id_2: $D, $name_2 : string) 
-> [] T 
{
	result : [..] T;
    for <<array {
    	equal_ids := #insert -> string {
    		return builder_string_2("it.% == id_1 && it.% == id_2;", name_1, name_2);
    	}
    	if equal_ids {
    		array_add(*result, it);
    		remove it;
    	}
    }
    return result;
}

ArrayRemoveFirstByAndOp :: (
	array: *[] $T, 
	id_1: $S, $name_1 : string, 
	id_2: $D, $name_2 : string) 
-> found : bool 
{
    for <<array {
    	equal_ids := #insert -> string {
    		return builder_string_2("it.% == id_1 && it.% == id_2;", name_1, name_2);
    	}
    	if equal_ids {
    		remove it;
    		return true;
    	}
    }
    return false;
}

ArrayRemoveFirstByNameId :: (
	array: *[] $T, 
	id: $S, $name_id : string) 
-> found : bool
{
    for <<array {
    	equal_ids := #insert -> string {
    		return builder_string("it.% == id;", name_id);
    	}
    	if equal_ids {
    		remove it;
    		return true;
    	}
    }
    return false;
}

ArrayRemoveFirstByNameIdAndReturn :: (
	array: *[] $T, id: $S, $name_id : string) 
-> found : bool, result : T 
{
    for <<array {
    	equal_ids := #insert -> string {
    		return builder_string("it.% == id;", name_id);
    	}
    	if equal_ids {
    		result := it;
    		remove it;
    		return true, result;
    	}
    }
    return false, .{};
}

ArrayRemoveAllByNameId :: (
	array: *[] $T, 
	id: $S, 
	$name_id : string) 
{
    for <<array {
    	equal_ids := #insert -> string {
    		return builder_string("it.% == id;", name_id);
    	}
    	if equal_ids remove it;
    }
}

ArrayRemoveAllByNameIdAndReturn :: (
	array: *[] $T, 
	id: $S, $name_id : string,
	allocator : Allocator = .{}) 
-> [] T 
{
    a := ifx allocator.proc then allocator else context.allocator;
	result : [..] T;
	result.allocator = a;
    for <<array {
    	equal_ids := #insert -> string {
    		return builder_string("it.% == id;", name_id);
    	}
    	if equal_ids {
    		array_add(*result, it);
    		remove it;
    	}
    }
    return result;
}

ArrayRemoveAllByNameIdAndReturn :: (
	array: *[] $T, 
	id: $S, $name_id : string,
	EqualsProc : (S, S) -> bool,
	allocator : Allocator = .{}) 
-> [] T 
{
    a := ifx allocator.proc then allocator else context.allocator;
	result : [..] T;
	result.allocator = a;
    for <<array {
    	equal_ids := #insert -> string {
    		return builder_string("EqualsProc(it.%, id);\n", name_id);
    	}
    	if equal_ids {
    		array_add(*result, it);
    		remove it;
    	}
    }
    return result;
}

ArrayRemoveAllByNameId :: (
	array: *[] $T, 
	id: $S, $name_id : string, 
	EqualsProc : (S, S) -> bool) 
{
    for <<array {
    	equal_ids := #insert -> string {
    		return builder_string("EqualsProc(it.%, id);\n", name_id);
    	}
    	if equal_ids remove it;
    }
}

ArrayRemoveAllByArrayNameId :: (
	array : *[] $T,
	all_ids : [] $S, $name_id : string,
	EqualsProc : (S, [] S) -> bool)
{
    for <<array {
    	equal_ids := #insert -> string {
    		return builder_string("EqualsProc(it.%, all_ids);\n", name_id);
    	}
    	if equal_ids remove it;
    }
}

ArrayRemoveAllByArrayBothNames :: (
	array : *[] $T, $array_var_name : string,
	all_ids : [] $S, 
	$EqualsProc : (v: int, a: [] S, $n: string) -> bool,
	$compare_var_name : string)
{
    for <<array {
    	equal_ids := #insert -> string {
    		return builder_string(
    		"EqualsProc(it.%, all_ids, compare_var_name);\n", array_var_name);
    	}
    	if equal_ids remove it;
    }
}

ArrayRemoveAllByArrayNameIdAndReturn :: (
	array : *[] $T,
	all_ids : [] $S, $name_id : string,
	EqualsProc : (S, [] S) -> bool,
	allocator : Allocator = .{})
-> [] T 
{
    a := ifx allocator.proc then allocator else context.allocator;
	result : [..] T;
	result.allocator = a;
    for <<array {
    	equal_ids := #insert -> string {
    		return builder_string("EqualsProc(it.%, all_ids);\n", name_id);
    	}
    	if equal_ids {
    		array_add(*result, it);
    		remove it;
    	}
    }
    return result;
}

ArrayRemoveAllByArrayBothNamesAndReturn :: (
	array : *[] $T, $array_var_name : string,
	all_ids : [] $S, 
	$EqualsProc : (v: S, a: [] S, $n: string) -> bool,
	$compare_var_name : string,
	allocator : Allocator = .{})
-> [] T 
{
    a := ifx allocator.proc then allocator else context.allocator;
	result : [..] T;
	result.allocator = a;
    for <<array {
    	equal_ids := #insert -> string {
    		return builder_string(
    		"EqualsProc(it.%, all_ids, compare_var_name);\n", array_var_name);
    	}
    	if equal_ids {
    		array_add(*result, it);
    		remove it;
    	}
    }
    return result;
}


AllOrEqualsVarName :: inline (
	value : $T, or_checks : [] $S,
	$var_name : string)
-> bool
{
	for or_checks {
    	equal_ids := #insert -> string {
    		return builder_string("it.% == value;\n", var_name);
    	}
		if equal_ids return true;
	}
	return false;
}

AllOrEqualsProc :: inline (
	value : $T, 
	or_checks : [] T,
	EqualsProc : (T,T) -> bool) 
-> bool 
{
	for or_checks if EqualsProc(value, it) return true;
	return false;
}

//TODO Could have a version where we pass in the whole string with and then it will set both
SetResizableArrays :: ($t : Type, $code : string) -> string #expand {
	sb : String_Builder;
	comp_data_type_info := cast(*Type_Info_Struct) type_info(t);
	for ti_member : comp_data_type_info.members {
		if ti_member.type.type == Type_Info_Tag.ARRAY {
			ti_array := cast(*Type_Info_Array) ti_member.type;
			if ti_array.array_type == .RESIZABLE {
				print_to_builder(*sb, code, ti_member.name);
			}
		}
	}
	return builder_to_string(*sb);
}
