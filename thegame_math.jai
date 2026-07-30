/*Note that this is currently used as a math module specifically for the game.
We have created our own structs for everything but ultimately this may be rather
impractical when it comes to using things externaly and may be better to use 
the common ones in the jai module/Math and only have extra functionality here.
*/
#import "Math";
#import "Basic";

EULER_N : float : 2.718281;
EULER_N64 : float64 : 2.7182818284590452353602874713527;
ROOT_2 : float : 1.414213;
ROOT_2_64 : float64 : 1.4142135623730950488;
ONE_OVER_ROOT_2 : float : 1.0 / ROOT_2;

//Note : log in cephes is ln == log base e
log_of_10 : float : #run log(10);
log10 :: inline (x : float) -> float
{
	x_log10 : float = log(x) / log_of_10;
	return x_log10;
}

log_of_2 : float : #run log(2);
log2 :: inline (x : float) -> float
{
	x_log2 : float = log(x) / log_of_2;
	return x_log2;
}

round :: inline (f : float) -> float {
    return cast(float) round_to_int(f);
}

//FRNDINT x86 asm instruction can be used here instead
round_to_int :: inline (x : float) -> int {
    if x < 0 return cast(int) (x - 0.5);
    else return cast(int) (x + 0.5);
}

round_to_int :: inline (x : float64) -> int {
    if x < 0 return cast(int) (x - 0.5);
    else return cast(int) (x + 0.5);
}

round_to_s32 :: inline (f : float) -> s32 {
    if f < 0 return cast(s32) (f - 0.5);
    return cast(s32) (f + 0.5);
}

round_to_u32 :: inline (f : float) -> u32 {
    if f < 0 return cast(u32) (f - 0.5);
    return cast(u32) (f + 0.5);
}

//Note : This is a redundant function for type checking in case we can have int and float for this function.
round_to_int :: inline (x : int) -> int {
	return x;
}

//TODO Could do a similar thing for floor_to_int
//Note : using 0.999 so that if we do ceil(2.0) we get 2.0 instead of 3.0
//TODO could also check if IsInt before procesing but this seems more efficient
//TODO and could also have a version that does not check for negative numbers
CEIL_CONST : float = 0.9999;
ceil_to_int :: inline (f : float) -> int {
    if f < 0 return cast(int) (f - CEIL_CONST);
    return cast(int) (f + CEIL_CONST);
}

ceil_to_u32 :: inline (f : float) -> u32 {
    assert(f >= 0);
    return cast(u32) (f + CEIL_CONST);
}

floor_to_int :: inline (f : float) -> int {
	return floor_to_int(cast(float64) f);
}
floor_to_int :: inline (f : float64) -> int {
	rf := cast(int) (f + VF_EPSILON_64);
	return rf;
}

IsInt :: (f : float) -> bool {
	if abs(round(f) - f) <= 0.00001 {
		return true;
	}
	return false;
}

squared :: inline (f : float) -> float {
    return f * f;
}

factorial :: inline (n : int) -> int {
	result : int = 1;
	n_copy := n;
	while n_copy > 1 {
		result *= n_copy;
		n_copy -= 1;
	}
	return result;
}

NChooseK :: inline (n : int, k : int) -> int {
	n_fact : int = factorial(n);
	k_fact : int = factorial(k);
	nk_fact : int = factorial(n-k);

	n_choose_k : int = n_fact / (k_fact * nk_fact);
	return n_choose_k;
}

//2s complement IsEven check
//TODO Could likely optimize with #asm as well.
IsEven2sC :: inline (n : int) -> bool {
	result : bool = n & 1 == 1;
	return result;
}

IsOdd2sC :: inline (n : int) -> bool {
	result : bool = n & 1 == 0;
	return result;
}

//Note : using % 2 instead of & 1 because
//% 2 works on all negative number system
//eg 1s complement, 2s complement, etc...
//whereas & 1 only works with 2s complement
IsEven :: inline (n : int) -> bool {
	result : bool = n % 2 == 0;
	return result;
}

IsOdd :: inline (n : int) -> bool {
	result : bool = n % 2 != 0;
	return result;
}

XOR_3 :: inline (a : bool, b : bool, c : bool) -> bool {
	result : bool = (a ^ b ^ c) && !(a && b && c);
	return result;
}

//TODO should this be in my own basics module
ArraysEqual :: (a1 : [] $T, a2 : [] T) -> bool {
	if a1.count != a2.count return false;
	for a1 if a2[it_index] != it return false;
	return true;
}

ArraysFloatEqual :: (a1 : [] $T, a2 : [] T) -> bool {
	if a1.count != a2.count return false;
	for a1 if !FloatBothEqual(a2[it_index], it) return false;
	return true;
}

ArraysFixedEqual :: (a1 : [$size] $T, a2 : [size] T) -> bool {
	for a1 if a2[it_index] != it return false;
	return true;
}

ArraysFloatFixedEqual :: (a1 : [$size] $T, a2 : [size] T) -> bool {
	for a1 if !FloatBothEqual(a2[it_index], it) return false;
	return true;
}

ArrayAllValuesEqual :: (a1 : [] $T) -> bool {
	//TODO what do we do on empty array?
	if a1.count == 0 return false;
	previous_value : T = a1[0];
	for a1 {
		if it != previous_value return false;
		previous_value = it;
	}
	return true;
}

/*TODO
	can extend these to have more flexible checks where we
	can input a variable amount of string bool checks
	eg !=, ==, &&, ||, EqualsProc(), etc...

	could make a version that takes a name_id as well
*/
AllOrEquals :: inline (value : $T, or_checks : [] T) -> bool {
	for or_checks if value == it return true;
	return false;
}

ArraySum :: inline (array : [] $T) -> T {
	sum : T;
	for array sum += it;
	return sum;
}

//Note : using ArrayMap implies that SIMD/multi-threading would work to optimize
//TODO does this work with compile-time map function?
//TODO pass in allocator
ArrayMap :: inline (
	array : [] $T, 
	$map : (T) -> $S,
	allocator : Allocator = temp) 
-> [] S 
{
	result := NewArray(array.count, S);
	for array result[it_index] = map(it);
	return result;
}

ArrayMap :: inline (array : *[] $T, $map : (p1 : T) -> T) {
	for array array[it_index] = map(it);
}

ArrayMap :: inline (array : [] $T, $map : (p1 : T, p2 : $R) -> $S, value : R) -> [] S {
	result := NewArray(array.count, S);
	for array result[it_index] = map(it, value);
	return result;
}

ArrayMap :: inline (array : *[] $T, $map : (p1 : T, p2 : $R) -> T, value : R) {
	for array array[it_index] = map(it, value);
}

ArrayMin :: inline (a : [] $T) -> T
#modify { return IsScalar(T), "Argument is not of a scalar type."; }
{
    m : T = a[0];
    for a if it < m m = it;
    return m;
}

ArrayMax :: inline (a : [] $T) -> T
#modify { return IsScalar(T), "Argument is not of a scalar type."; }
{
    m : T = a[0];
    for a if it > m m = it;
    return m;
}

ArrayReverse :: inline (a : [] $T) -> [] T {
	rev := array_copy(a);
	ArrayReverseInPlace(rev);
	return rev;
}

ArrayReverseInPlace :: inline (a : [] $T) {
	start : int = 0;
	end : int = a.count-1;
	while start < end {
		// a[start], a[end] = a[end], a[start];
		swap(*a[start], *a[end]);
		start += 1;
		end -= 1;
	}
}

ClampMin :: inline (min : $T, value : T) -> T {
	if value < min return min;
	return value;
}

ClampMax :: inline (value : $T, max : T) -> T {
	if value > max return max;
	return value;
}

//NOTE : This is an inclusive clamp - min <= value <= max
Clamp :: inline (min : $T, value : T, max : T) -> T {
	result : T = value;
	if value < min result = min;
	else if value > max result = max;
	return result;
}

Lerp :: inline (min : float, t : float, max : float) -> float {
    //result : float = (1.0 - t) * min + t * max;
    //Note : Below seems more efficient, only one multiplication
    result : float = min + t * (max - min);
    return result;
}

Lerp :: inline (min : $T, t : float, max : T) -> T {
	//TODO Does this require a cast or other proc for non-float types?
    result : T = min + t * (max - min);
    return result;
}

ClampComponents :: inline (min : $S, v : $T, max : S) -> T {
	result : T;
	for component, c_index : v.component {
		result.component[c_index] = Clamp(min, component, max);
	}
	return result;
}

ClampComponentsPointer :: inline (min : $S, v : *$T, max : S) {
	for *component : v.component {
		<<component = Clamp(min, <<component, max);
	}
}

InRange :: inline (min : $T, value : T, max : T) -> bool {
	result : bool = value >= min && value <= max;
	return result;
}

InRangeNoBounds :: inline (min : $T, value : T, max : T) -> bool {
	result : bool = value > min && value < max;
	return result;
}

LinearSystemCommonUnits :: struct {
	from_system_common_units : int;
	to_system_common_units : int;
}

ComputeLinearSystemCommonUnits :: inline (
	from_system_count : int,
	to_system_count : int)
-> LinearSystemCommonUnits
{
	lscu : LinearSystemCommonUnits;

	//TODO is there a more efficient GCD algorithm?
	//Maybe even having a table for most common GCD values
	//within u8
	gcd : int = GCDEuclidSubtract(from_system_count, to_system_count);

	lscu.to_system_common_units = from_system_count / gcd;
	lscu.from_system_common_units = to_system_count / gcd;

	#if 0 {
	common_value : int = from_system_count * lscu.from_system_common_unit;
	common_value_copy : int = to_system_count * lscu.to_system_common_unit;
	assert(common_value == common_value_copy);
	}

	return lscu;
}

//TODO could make 32 bit versions of snapping functions for efficiency
LinearSnapUp :: inline (
	from_point : int,
	from_system_count : int,
	to_system_count : int)
-> int
{
	//TODO can remove this once things are tested
	assert(from_system_count != 0 && to_system_count != 0);

	from_common_pos : float = from_point / cast(float) from_system_count;
	to_pos : float = from_common_pos * to_system_count;
	snap_pos : int = ceil_to_int(to_pos);

	// to_pos : float = from_common_pos / (cast(float) cu.to_system_common_units);
	// snap_up_pos : int = ceil_to_int(to_pos);
	// end_point : int = snap_up_common_pos / cu.to_system_common_units;
	//Note : we set the point to be zero based
	// end_point -= 1;

	return snap_pos;
}

LinearSnapDown :: inline (
	from_point : int,
	from_system_count : int,
	to_system_count : int)
-> int
{
	assert(from_system_count != 0 && to_system_count != 0);
	from_common_pos : float = from_point / cast(float) from_system_count;
	to_pos : float = from_common_pos * to_system_count;
	snap_pos : int = cast(int) to_pos;
	return snap_pos;
}

LinearSnapRound :: inline (
	from_point : int,
	from_system_count : int,
	to_system_count : int)
-> int
{
	assert(from_system_count != 0 && to_system_count != 0);
	from_common_pos : float = from_point / cast(float) from_system_count;
	to_pos : float = from_common_pos * to_system_count;
	snap_pos : int = round_to_int(to_pos);
	return snap_pos;
}

QuotientAndRemainder :: struct {
	quotient : int;
	remainder : int;
}
ComputeQuotientAndRemainder :: inline (dividend : int, divisor : int) 
-> QuotientAndRemainder
{
	q_and_r : QuotientAndRemainder = ---;
	q_and_r.quotient = dividend / divisor;
	q_and_r.remainder = dividend % divisor;
	return q_and_r;
}

ComputeQuotientAndRemainder2 :: inline (dividend : int, divisor : int) 
-> quotient : int, remainder : int
{
	qr : QuotientAndRemainder = ComputeQuotientAndRemainder(dividend, divisor);
	return qr.quotient, qr.remainder;
}

IntSequence :: inline (
	count : int,
	allocator : Allocator = temp) 
-> [] int 
{
	int_seq : [] int = NewArray(count, int, false,, allocator);
	for 0..count-1 int_seq[it] = it;
	return int_seq;
}

//This should work for all dimensions so can reuse everywhere
/*This check which axis were on like in 2d
3 3 3 3
2 2 2 3
1 1 2 3
0 1 2 3
So given 1 and 3 it would return true on 1 and 3 in above grid
and it should work in all dimensions based on size of a.count
*/
IsOnAxis :: inline (axes : [] float64, a : [] float64, mod : float64) -> bool {
	max_index : int = 0;
	max_v : float64 = FLOAT64_MIN;
	for a if it > max_v {
		max_v = it;
		max_index = it_index;
	}

	max_mod : float64 = PosMod(max_v, mod);
	found_axis : bool = false;
	for axes if Float64Equal(it, max_mod) {
		found_axis = true;
		break;
	}

	//TODO Would need to check for negative values here if we
	//want to add negative values.
	//OR I think we can just PosMod all the values and check like this
	//which i think is mentally simpler but maybe less efficient
	if found_axis {
		all_less : bool = true;
		for a {
			all_less &&= it < max_v || Float64Equal(it,max_v);
		}
		return all_less;
	}

	return false;
}

/*
	2D
*/

Lerp :: inline (min : Vector2F, t : float, max : Vector2F) -> Vector2F {
    result : Vector2F = min + t * (max - min);
    return result;
}

//TODO should quad just be 2 triangles?
//Note : assume clockwise a -> b -> c -> d
Quad2F :: struct {
	a, b, c, d : Vector2F;
}

MakeQuad2F :: inline (a : Vector2F, b : Vector2F, c : Vector2F, d : Vector2F) -> Quad2F {
	result : Quad2F = ---;
	result.a = a;
	result.b = b;
	result.c = c;
	result.d = d;
	return result;
}

operator + :: (quad : Quad2F, v : Vector2F) -> Quad2F #symmetric {
	result : Quad2F = quad;
	result.a += v;
	result.b += v;
	result.c += v;
	result.d += v;
	return result;
}

operator - :: (quad : Quad2F, v : Vector2F) -> Quad2F {
	result : Quad2F = quad;
	result.a -= v;
	result.b -= v;
	result.c -= v;
	result.d -= v;
	return result;
}

//TODO https://stackoverflow.com/questions/5922027/how-to-determine-if-a-point-is-within-a-quadrilateral
//Note : assume clockwise a -> b -> c -> d
PointInQuad :: inline (p : Vector2F, quad : Quad2F) -> bool {
	t0 := MakeTriangle2F(quad.a, quad.b, quad.c);
	t1 := MakeTriangle2F(quad.a, quad.c, quad.d);
	t0_in : bool = PointInTriangle(p, t0);
	t1_in : bool = PointInTriangle(p, t1);
	result : bool = t0_in || t1_in;
	return result;
}

QuadToTriangles :: (quad : Quad2F) -> [2] Triangle2F {
	tris : [2] Triangle2F;

	tris[0].a = quad.a;
	tris[0].b = quad.b;
	tris[0].c = quad.c;

	tris[1].a = quad.a;
	tris[1].b = quad.c;
	tris[1].c = quad.d;

	return tris;
}

Rectangle2 :: struct {
    min : Vector2F;
    max : Vector2F;
}

Rect2Int :: struct {
    min : Vector2I;
    max : Vector2I;	
}

MoveRect :: inline (move : Vector2F, rect : *Rectangle2) {
	rect.min += move;
	rect.max += move;
}

RectMinMax :: inline (min : Vector2F, max : Vector2F) -> Rectangle2 {
    rect : Rectangle2 = ---;
    rect.min = min;
    rect.max = max;
    return rect;
}

RectMinDim :: inline (min : Vector2F, dim : Vector2F) -> Rectangle2 {
    rect : Rectangle2 = ---;
    rect.min = min;
    rect.max = min + dim;
    return rect;    
}

RectCenterHalfDim :: inline (center : Vector2F, half_dim : Vector2F) -> Rectangle2 {
    rect : Rectangle2 = ---;
    rect.min = center - half_dim;
    rect.max = center + half_dim;
    return rect;
}

RectCenterDim :: inline (center : Vector2F, dim : Vector2F) -> Rectangle2 {
    rect := RectCenterHalfDim(center, 0.5 * dim);
    return rect;
}

SquareCenterDim :: inline (center : Vector2F, dim : float) -> Rectangle2 {
    rect := RectCenterDim(center, MakeV2F(dim, dim));
    return rect;
}

RectMinCenterDim :: inline (min_center : Vector2F, dim : Vector2F) -> Rectangle2 {
	rect : Rectangle2 = ---;
	rect.min = min_center;
	rect.min.x -= 0.5*dim.x;
	rect.max = rect.min + dim;
	return rect;
}

RectLeftCenterDim :: inline (left_center : Vector2F, dim : Vector2F) -> Rectangle2 {
	rect : Rectangle2 = ---;
	rect.min = left_center;
	rect.min.y -= 0.5*dim.y;
	rect.max = rect.min + dim;
	return rect;
}

RectBottomRightDim :: inline (bottom_right : Vector2F, dim : Vector2F) -> Rectangle2 {
	rect : Rectangle2 = ---;
	rect.min.y = bottom_right.y;
	rect.max.y = bottom_right.y + dim.y;
	rect.max.x = bottom_right.x;
	rect.min.x = bottom_right.x - dim.x;
	return rect;
}

IsInRectangle :: inline (point : Vector2F, rect : Rectangle2) -> bool {
	result : bool = 
		point.x >= rect.min.x &&
		point.y >= rect.min.y &&
		point.x <= rect.max.x &&
		point.y <= rect.max.y;
	return result;
}

IsInRectangleSwap :: inline (rectangle : Rectangle2, point : Vector2F) -> bool {
	return IsInRectangle(point, rectangle);
}

RectanglesIntersect :: inline (r1 : Rectangle2, r2 : Rectangle2) -> bool {
	result : bool = 
		r1.max.x >= r2.min.x &&
		r1.max.y >= r2.min.y &&
		r1.min.x <= r2.max.x &&
		r1.min.y <= r2.max.y;
	return result;
}

//r1 contains r2
ContainsRectangle :: inline (r1 : Rectangle2, r2 : Rectangle2) -> bool {
	result : bool = 
		r1.min.x <= r2.min.x && 
		r1.min.y <= r2.min.y && 
		r1.max.x >= r2.max.x && 
		r1.max.y >= r2.max.y;
	return result;
}

//This assumes that the rectangles intersect so we can remove the 2 max checks.
//Therefore check if RectanglesIntersect before calling this.
ComputeRectIntersect :: (r1 : Rectangle2, r2 : Rectangle2) -> Rectangle2 {
	min_x := max(r1.min.x, r2.min.x);
	min_y := max(r1.min.y, r2.min.y);
	max_x := min(r1.max.x, r2.max.x);
   max_y := min(r1.max.y, r2.max.y);
   inter := RectMinMax(.{min_x, min_y}, .{max_x, max_y});
   return inter; 
   //Leave this here for reference to compute from width and height just in case
   //We assume the rectangles do intersect so we can remove this max check.
	// width := max(min(r1.max.x, r2.max.x) - min_x, 0);
   // height := max(min(r1.max.y, r2.max.y) - min_y, 0);
	// width := min(r1.max.x, r2.max.x) - min_x;
   // height := min(r1.max.y, r2.max.y) - min_y;
   // inter := RectMinDim(.{min_x, min_y}, .{width, height});
}

GetMinCorner :: inline (rect : Rectangle2) -> Vector2F {
    result := rect.min;
    return result;
}

GetMaxCorner :: inline (rect : Rectangle2) -> Vector2F {
    result := rect.max;
    return result;
}

GetCenter :: inline (rect : Rectangle2) -> Vector2F {
    result := 0.5 * (rect.min + rect.max);
    return result;
}

GetWidth :: inline (rect : Rectangle2) -> float {
	result := rect.max.x - rect.min.x;
	return result;
}

GetHeight :: inline (rect : Rectangle2) -> float {
	result := rect.max.y - rect.min.y;
	return result;
}

GetDim :: inline (rect : Rectangle2) -> Vector2F {
	result := rect.max - rect.min;
	return result;
}

GetBottomRight :: inline (rect : Rectangle2) -> Vector2F {
	v : Vector2F = ---;
	v.x = rect.max.x;
	v.y = rect.min.y;
	return v;
}
GetTopLeft :: inline (rect : Rectangle2) -> Vector2F {
	v : Vector2F = ---;
	v.x = rect.min.x;
	v.y = rect.max.y;
	return v;
}

GetSubRect :: inline (
	full_rect : Rectangle2, 
	subdivision : float, 
	sub_pos : float,
	margin : float = 0) 
-> Rectangle2
{
	rect_dim : Vector2F = GetDim(full_rect);
    sub_rect_pos : Vector2F = 
    	MakeV2F(full_rect.min.x + ((0.5 + sub_pos) * rect_dim.x / subdivision),
    			full_rect.min.y + 0.5 * rect_dim.y);
	sub_size_x : float = (rect_dim.x / subdivision) - 2*margin;
	sub_size_y : float = rect_dim.y - 2*margin;
	sub_rect : Rectangle2 = RectCenterDim(sub_rect_pos, MakeV2F(sub_size_x, sub_size_y));
	return sub_rect;
}

//TODO Could put a version in rendere that divides R / pixels_per_square
//from a render group for convenience
//DOC : R here is the width of the rect
RectLeftOutline :: inline (rect : Rectangle2, R : float) -> Rectangle2 {
	return RectMinMax(MakeV2F(rect.min.x - R/2.0, rect.min.y - R/2.0), MakeV2F(rect.min.x + R/2.0, rect.max.y + R/2.0));
}
RectBottomOutline :: inline (rect : Rectangle2, R : float) -> Rectangle2 {
	return RectMinMax(MakeV2F(rect.min.x - R/2.0, rect.min.y - R/2.0), MakeV2F(rect.max.x + R/2.0, rect.min.y + R/2.0));
}
RectRightOutline :: inline (rect : Rectangle2, R : float) -> Rectangle2 {
	return RectMinMax(MakeV2F(rect.max.x - R/2.0, rect.min.y - R/2.0), MakeV2F(rect.max.x + R/2.0, rect.max.y + R/2.0));
}
RectTopOutline :: inline (rect : Rectangle2, R : float) -> Rectangle2 {
	return RectMinMax(MakeV2F(rect.min.x - R/2.0, rect.max.y - R/2.0), MakeV2F(rect.max.x + R/2.0, rect.max.y + R/2.0));
}

Circle2 :: struct {
	pos : Vector2F;
	radius : float;
}

MakeCircle2 :: inline (pos : Vector2F, radius : float) -> Circle2 {
	c : Circle2 = ---;
	c.pos = pos;
	c.radius = radius;
	return c;
}

IsInCircle :: inline (pos : Vector2F, circle : Circle2) -> bool {
	return IsInCircle(pos, circle.pos, circle.radius);
}

IsInCircle :: inline (pos : Vector2F, c_pos : Vector2F, c_radius : float) -> bool {
	d_squared : float = LengthSquared(pos - c_pos);
	radius_squared : float = squared(c_radius);
	in_circle : bool = d_squared < radius_squared;
	return in_circle;
}

MakeMatrix2FFrom64 :: inline (m2f64 : Matrix2F64) -> Matrix2F {
	m : Matrix2F = ---;
	m.m11 = cast(float) m2f64.m11;
	m.m12 = cast(float) m2f64.m12;
	m.m21 = cast(float) m2f64.m21;
	m.m22 = cast(float) m2f64.m22;
	return m;
}

MakeMatrix2F64 :: inline (m2f : Matrix2F) -> Matrix2F64 {
	m : Matrix2F64 = ---;
	m.m11 = cast(float64) m2f.m11;
	m.m12 = cast(float64) m2f.m12;
	m.m21 = cast(float64) m2f.m21;
	m.m22 = cast(float64) m2f.m22;
	return m;
}

Matrix2F64 :: MyMatrix2(float64);
Matrix2F :: MyMatrix2(float);
MyMatrix2 :: struct($T : Type) {
	m11, m12 : T;
	m21, m22 : T;

	#if T == float { 
	#place m11; v_row : [2] Vector2F; //row vectors
	#place m11; floats : [4] float = ---;
	}
}

MakeMatrix2F :: inline (m11 : float, m12 : float,
				 		m21 : float, m22 : float) -> Matrix2F {
	result : Matrix2F = ---;
	result.m11 = m11; result.m12 = m12;
	result.m21 = m21; result.m22 = m22;
	return result;
}

MakeMatrix2FColumns :: inline (
	column_1 : Vector2F,
	column_2 : Vector2F)
-> Matrix2F 
{
	result : Matrix2F = ---;
	result.m11 = column_1.x; result.m12 = column_2.x;
	result.m21 = column_1.y; result.m22 = column_2.y;
	return result;
}

NewBasisToStandardBasisMatrix :: inline (
	x_axis : Vector2F,
	y_axis : Vector2F)
-> Matrix2F 
{
	return MakeMatrix2FColumns(x_axis, y_axis);
}

GetColumn1 :: inline (m : Matrix2F) -> Vector2F {
	result : Vector2F = ---;
	result.x = m.m11;
	result.y = m.m21;
	return result;
}

SetColumn1 :: inline (v : Vector2F, m : *Matrix2F) {
	m.m11 = v.x;
	m.m21 = v.y;
}

GetColumn2 :: inline (m : Matrix2F) -> Vector2F {
	result : Vector2F = ---;
	result.x = m.m12;
	result.y = m.m22;
	return result;
}

SetColumn2 :: inline (v : Vector2F, m : *Matrix2F) {
	m.m12 = v.x;
	m.m22 = v.y;
}

Matrix2F_IDENTITY :: Matrix2F.{1, 0,
							   0, 1};

//https://en.wikipedia.org/wiki/Rotations_and_reflections_in_two_dimensions
ROTATE_90 :: Matrix2F.{0,-1,
					   1, 0};
					   
ROTATE_NEG90 :: Matrix2F.{0, 1,
				   		 -1, 0};

ROTATE_180 :: Matrix2F.{-1, 0,
					     0,-1};

ROTATE_45 :: Matrix2F.{ONE_OVER_ROOT_2, -ONE_OVER_ROOT_2,
					   ONE_OVER_ROOT_2,  ONE_OVER_ROOT_2};

ROTATE_NEG45 :: Matrix2F.{ONE_OVER_ROOT_2, ONE_OVER_ROOT_2,
					   	 -ONE_OVER_ROOT_2, ONE_OVER_ROOT_2};

MakeRotationMatrix2F :: inline (theta : float) -> Matrix2F {
	cos_t : float = cos(theta);
	sin_t : float = sin(theta);
	result : Matrix2F = ---;
	result.m11 = cos_t; result.m12 = -sin_t;
	result.m21 = sin_t; result.m22 = cos_t;
	return result;
}

REFLECT_0 :: Matrix2F.{1, 0,
					   0,-1};

REFLECT_45 :: Matrix2F.{0, 1,
					    1, 0};

REFLECT_NEG45 :: Matrix2F.{0,-1,
						  -1, 0};

REFLECT_90 :: Matrix2F.{-1, 0,
					     0, 1};

MakeReflection2F :: inline (theta : float) -> Matrix2F {
	cos_t : float = cos(2.0*theta);
	sin_t : float = sin(2.0*theta);
	result : Matrix2F = ---;
	result.m11 = cos_t; result.m12 = sin_t;
	result.m21 = sin_t; result.m22 = -cos_t;
	return result;	
}

MakeScaleMatrix2F :: inline (x : float, y : float) -> Matrix2F {
	result := MakeMatrix2F(x, 0,
			       		   0, y);
	return result;
}

Y_POS_INVOLUTION :: Matrix2F.{-1, 0,
							   0, 1};

MakeInvolution2F :: inline (a : Vector2F) -> Matrix2F {
	x : float = a.x * 2.0;
	y : float = a.y * 2.0;
	axay : float = x * a.y;
	result := MakeMatrix2F(x * a.x - 1.0, axay,
						   axay, y * a.y - 1.0);
	return result;
}

//Notes m2 is row ordered matrix and vector is a column vector
operator * :: inline (m2 : Matrix2F, v : Vector2F) -> Vector2F {
	result : Vector2F = ---;
	result.x = m2.m11 * v.x + m2.m12 * v.y;
	result.y = m2.m21 * v.x + m2.m22 * v.y;
	return result;
}

operator * :: (m_0 : Matrix2F, m_1 : Matrix2F) -> Matrix2F {
	result : Matrix2F = ---;
	result.m11 = m_0.m11 * m_1.m11 + m_0.m12 * m_1.m21;
	result.m12 = m_0.m11 * m_1.m12 + m_0.m12 * m_1.m22;

	result.m21 = m_0.m21 * m_1.m11 + m_0.m22 * m_1.m21;
	result.m22 = m_0.m21 * m_1.m12 + m_0.m22 * m_1.m22;
	return result;
}

Determinant :: inline (m : Matrix2F) -> float {
	result : float = m.m11*m.m22-m.m12*m.m21;
	return result;
}

Inverse :: inline (m : Matrix2F, epsilon : float = 0.001) -> Matrix2F {
	det : float = Determinant(m);
    if (det < epsilon) && (det > -epsilon) return m;  // Failure... undefined!

	c : float = 1.0 / det;
	result : Matrix2F = ---;
	result.m11 = m.m22*c; result.m12 =-m.m12*c;
	result.m21 =-m.m21*c; result.m22 = m.m11*c;
	return result;
}

TransformAboutPoint :: inline (v : Vector2F, rot : Matrix2F, point : Vector2F) -> Vector2F {
	trans_pos : Vector2F = (rot * (v - point)) + point;
	return trans_pos;
}

Matrix2I :: struct {
	m11, m12 : int;
	m21, m22 : int;

	#place m11; v_row : [2] Vector2I; //row vectors
	#place m11; ints : [4] int = ---;
}

MakeMatrix2I :: inline (m11 : int, m12 : int,
				 		m21 : int, m22 : int) -> Matrix2I {
	result : Matrix2I = ---;
	result.m11 = m11; result.m12 = m12;
	result.m21 = m21; result.m22 = m22;
	return result;
}

operator * :: (m2 : Matrix2I, v : Vector2I) -> Vector2I {
	result : Vector2I = ---;
	result.x = m2.m11 * v.x + m2.m12 * v.y;
	result.y = m2.m21 * v.x + m2.m22 * v.y;
	return result;
}


MakeV2F :: inline (x : float, y : float) -> Vector2F {
    v : Vector2F = ---;
    v.x = x;
    v.y = y;
    return v;
}

MakeV2F :: inline (x : int, y : int) -> Vector2F {
    v : Vector2F = ---;
    v.x = cast(float) x;
    v.y = cast(float) y;
    return v;
}

MakeV2F :: inline (v_i : Vector2I) -> Vector2F {
	v : Vector2F = ---;
	v.x = cast(float) v_i.x;
	v.y = cast(float) v_i.y;
	return v;
}

MakeV2F :: inline (components : [2] float) -> Vector2F {
	v : Vector2F = ---;
	v.component = components;
	return v;
}

MakeV2FFrom64 :: inline (v2f64 : Vector2F64) -> Vector2F {
	v : Vector2F = ---;
	v.x = cast(float) v2f64.x;
	v.y = cast(float) v2f64.y;
	return v;
}

MakeV2F64 :: inline (v2f : Vector2F) -> Vector2F64 {
	v : Vector2F64 = ---;
	v.x = cast(float64) v2f.x;
	v.y = cast(float64) v2f.y;
	return v;
}

Pointwise :: inline (v0 : Vector2F, v1 : Vector2F) 
	-> Vector2F #deprecated 
{
	return PointwiseProduct(v0, v1);
}

//TODO could rename ComponentwiseProduct
PointwiseProduct :: inline (v0 : Vector2F, v1 : Vector2F) -> Vector2F {
	result : Vector2F = ---;
	result.x = v0.x * v1.x;
	result.y = v0.y * v1.y;
	return result;
}

DotProduct :: inline (v0 : Vector2F, v1 : Vector2F) -> float {
    return v0.x * v1.x + v0.y * v1.y; 
}

LengthSquared :: inline (v : Vector2F) -> float {
    result := DotProduct(v, v);
    return result;
}

Length :: inline (v : Vector2F) -> float {
	result : float = sqrt(v.x * v.x + v.y * v.y);
	return result;
}

UnitVector :: inline (v : Vector2F) -> Vector2F {
	length : float = Length(v);
	if length == 0 return v;
	inv_length : float = 1.0 / length;

	result : Vector2F = ---;
	result.x = v.x * inv_length;
	result.y = v.y * inv_length;
	return result;
}

SwapRows :: inline (m : *Matrix2F) {
	swap(*m.v_row[0], *m.v_row[1]);
}

SwapRows :: inline (m : Matrix2F) -> Matrix2F {
	result : Matrix2F = ---;
	result.v_row[0] = m.v_row[1];
	result.v_row[1] = m.v_row[0];
	return result;
}

//TODO Could use polymorphic like with vector 2 if needed.
Vector4F64 :: struct { x, y, z, w : float64; }
MakeV4F64 :: inline (v4f : Vector4F) -> Vector4F64 {
	v : Vector4F64 = ---;
	v.x = cast(float64) v4f.x;
	v.y = cast(float64) v4f.y;
	v.z = cast(float64) v4f.z;
	v.w = cast(float64) v4f.w;
	return v;
}
MakeV4FFrom64 :: inline (v4f64 : Vector4F64) -> Vector4F {
	v : Vector4F = ---;
	v.x = cast(float) v4f64.x;
	v.y = cast(float) v4f64.y;
	v.z = cast(float) v4f64.z;
	v.w = cast(float) v4f64.w;
	return v;
}

Vector4F :: struct {
    x, y, z, w : float;
    #place x; component : [4] float = ---;
    #place x; xyz : Vector3F = ---;
    #place y; yzw : Vector3F = ---;
    #place x; xy : Vector2F = ---;
    #place x; rgb : Vector3F = ---;
    #place x; r, g, b, a : float;
    #place x; jai_v : Vector4 = ---;
}

MakeV4F :: inline (x : float, y : float, z : float, w : float) -> Vector4F {
    v : Vector4F = ---;
    v.x = x;
    v.y = y;
    v.z = z;
    v.w = w;
    return v;
}

MakeV4F :: inline (x : int, y : int, z : int, w : int) -> Vector4F {
    v : Vector4F = ---;
    v.x = cast(float) x;
    v.y = cast(float) y;
    v.z = cast(float) z;
    v.w = cast(float) w;
    return v;
}

MakeV4F :: inline (v3 : Vector3F, w : float) -> Vector4F {
    v : Vector4F = ---;
    v.xyz = v3;
    v.w = cast(float) w;
    return v;
}

operator + :: (v1 : Vector4F, v2 : Vector4F) -> Vector4F {
	result : Vector4F = ---;
	result.x = v1.x + v2.x;
	result.y = v1.y + v2.y;
	result.z = v1.z + v2.z;
	result.w = v1.w + v2.w;
	return result;
}

operator - :: (v1 : Vector4F, v2 : Vector4F) -> Vector4F {
	result : Vector4F = ---;
	result.x = v1.x - v2.x;
	result.y = v1.y - v2.y;
	result.z = v1.z - v2.z;
	result.w = v1.w - v2.w;
	return result;
}

operator * :: (v : Vector4F, f : float) -> Vector4F #symmetric {
	result : Vector4F = ---;
	result.x = v.x * f;
	result.y = v.y * f;
	result.z = v.z * f;
	result.w = v.w * f;
	return result;
}

Length :: inline (a : Vector4F) -> float {
    return sqrt(a.x*a.x + a.y*a.y + a.z*a.z + a.w*a.w);
}

/*TODO I think this works so we can update all operations
to use V2 and then reuse the for any vector type which is a lot
better than having different functions for all of them.
Especially float32 and float64

TODO I think we can leave Matrix2F as 32-bit because it seems to automatically cast up if we do
float64 = float32 * float64, it casts the float32 to float64 automatically and then this would simplify
everything greatly while keeping the world in 64 bit easily.
*/
Vector2F64 :: V2(float64);
Vector2F :: V2(float);
V2 :: struct($T : Type) {
    x, y : T;
    #place x; component : [2] T;
    #place x; r, i : T;
    #place x; theta, radius : T;
    #if T==float{
    	#place x; jai_v : Vector2;
    }
}

operator - :: (v0 : Vector2F, v1 : Vector2F) -> Vector2F {
    v : Vector2F = ---;
    v.x = v0.x - v1.x;
    v.y = v0.y - v1.y;
    return v;
}

operator + :: (v0 : Vector2F, v1 : Vector2F) -> Vector2F {
    v : Vector2F = ---;
    v.x = v0.x + v1.x;
    v.y = v0.y + v1.y;
    return v;
}

operator += :: (v0 : *Vector2F, v1 : Vector2F) {
    v0.x += v1.x;
    v0.y += v1.y;
}

operator * :: (v0 : Vector2F, f : float) -> Vector2F #symmetric {
    v : Vector2F = ---;
    v.x = v0.x * f;
    v.y = v0.y * f;
    return v;
}

operator / :: (v0 : Vector2F, f : float) -> Vector2F {
    v : Vector2F = ---;
    v.x = v0.x / f;
    v.y = v0.y / f;
    return v;
}

operator - :: (v0 : Vector2F) -> Vector2F {
    v : Vector2F = ---;
    v.x = -v0.x;
    v.y = -v0.y;
    return v;
}

PerpendicularClockwise :: inline (v : Vector2F) -> Vector2F {
	result := MakeV2F(v.y, -v.x);
	return result;
}

PerpendicularCounterClockwise :: inline (v : Vector2F) -> Vector2F {
	result := MakeV2F(-v.y, v.x);
	return result;
}

Vector2I :: struct {
    x, y : int;
    #place x; component : [2] int;
}

DotProduct :: inline (v0 : Vector2I, v1 : Vector2I) -> int {
    return v0.x * v1.x + v0.y * v1.y; 
}

MakeV2I :: inline (x : int, y : int) -> Vector2I {
	v : Vector2I = ---;
	v.x = x;
	v.y = y;
	return v;
}

MakeV2I :: inline (vf : Vector2F) -> Vector2I {
	vi : Vector2I = ---;
	vi.x = round_to_int(vf.x);
	vi.y = round_to_int(vf.y);
	return vi;
}

MakeV2I :: inline (array : [] int) -> Vector2I {
	assert(array.count == 2);
	v : Vector2I = ---;
	v.x = array[0];
	v.y = array[1];
	return v;
}

MakeV2I :: inline (components : [2] int) -> Vector2I {
	v : Vector2I = ---;
	v.x = components[0];
	v.y = components[1];
	return v;
}

MakeV2ICeil :: inline (vf : Vector2F) -> Vector2I {
	vi : Vector2I = ---;
	vi.x = ceil_to_int(vf.x);
	vi.y = ceil_to_int(vf.y);
	return vi;
}

//Intersection between (v2 - v1) and (v4 - v3)
LineSegmentsIntersect :: (v1 : Vector2F, v2 : Vector2F,
						  v3 : Vector2F, v4 : Vector2F) -> Vector2F, no_interect : bool
{
	t : float =  ((v1.x - v3.x) * (v3.y - v4.y) - (v1.y - v3.y) * (v3.x - v4.x)) /
				 ((v1.x - v2.x) * (v3.y - v4.y) - (v1.y - v2.y) * (v3.x - v4.x));
	if t > 1.0 || t < 0 {
		return Vector2F.{FLOAT32_MAX, FLOAT32_MAX}, true;
	}
	result : Vector2F = v1 + t * v2;
	return result, false;
}

operator == :: (v0 : Vector2I, v1 : Vector2I) -> bool {
	result : bool = v0.x == v1.x && v0.y == v1.y;
	return result;
}

operator - :: (v0 : Vector2I) -> Vector2I {
	v : Vector2I = ---;
	v.x = -v0.x;
	v.y = -v0.y;
	return v;
}

operator - :: (v0 : Vector2I, v1 : Vector2I) -> Vector2I {
    v : Vector2I = ---;
    v.x = v0.x - v1.x;
    v.y = v0.y - v1.y;
    return v;
}

operator + :: (v0 : Vector2I, v1 : Vector2I) -> Vector2I {
    v : Vector2I = ---;
    v.x = v0.x + v1.x;
    v.y = v0.y + v1.y;
    return v;
}

operator + :: (v0 : Vector2I, i : int) -> Vector2I #symmetric {
    v : Vector2I = ---;
    v.x = v0.x + i;
    v.y = v0.y + i;
    return v;
}

operator - :: (v0 : Vector2I, i : int) -> Vector2I {
    v : Vector2I = ---;
    v.x = v0.x - i;
    v.y = v0.y - i;
    return v;
}

operator * :: (v0 : Vector2I, f : float) -> Vector2F #symmetric {
	v : Vector2F = ---;
	v.x = v0.x * f;
	v.y = v0.y * f;
	return v;
}

moment :: inline (v0 : Vector2I, v1 : Vector2I) -> int {
    return v0.x * v1.y - v0.y * v1.x;
}

MyComplex_ZERO :: MyComplex.{0,0};
MyComplex :: struct {
    r, i : float;
    #place r; component : [2] float;
    #place r; vector : Vector2F;
}

operator + :: (c1 : MyComplex, c2 : MyComplex) -> MyComplex {
    result : MyComplex;
    result.r = c1.r + c2.r;
    result.i = c1.i + c2.i;
    return result;
}

operator - :: (c1 : MyComplex, c2 : MyComplex) -> MyComplex {
    result : MyComplex;
    result.r = c1.r - c2.r;
    result.i = c1.i - c2.i;
    return result;
}

operator * :: (c1 : MyComplex, c2 : MyComplex) -> MyComplex {
    result : MyComplex;
    result.r = (c1.r * c2.r) - (c1.i * c2.i);
    result.i = c1.r * c2.i + c1.i * c2.r;
    return result;
}

// operator * :: (a: MyComplex, b: MyComplex) -> MyComplex {
//     return .{a.x*b.y, -a.y*b.x};
// }

operator / :: (c1 : MyComplex, c2 : MyComplex) -> MyComplex {
    numerator : MyComplex = c1 * Conjugate(c2);
    denominator : float = MagnitudeSquared(c2);
    result : MyComplex = numerator / denominator;
    return result;
}

operator / :: (c : MyComplex, f : float) -> MyComplex {
    result : MyComplex;
    result.r = c.r / f;
    result.i = c.i / f;
    return result;
}

operator * :: (f : float, c : MyComplex) -> MyComplex #symmetric {
    result : MyComplex;
    result.r = f * c.r;
    result.i = f * c.i;
    return result;
}

Magnitude :: (c : MyComplex) -> float {
    result := sqrt(c.r * c.r + c.i * c.i);
    return result;
}

MagnitudeSquared :: (c : MyComplex) -> float {
    result := c.r * c.r + c.i * c.i;
    return result;
}

/*1 microsecond equivalent for now
 *Should be only used to check for equality or zero
 *since its not decimal point relative
*/
COMPLEX_EPSILON :: 0.00001;
operator == :: (c1 : MyComplex, c2 : MyComplex) -> bool {
    result := (c1.r - c2.r <= COMPLEX_EPSILON &&
                c1.r - c2.r >= -COMPLEX_EPSILON) &&
              (c1.i - c2.i <= COMPLEX_EPSILON &&
                c1.i - c2.i >= -COMPLEX_EPSILON);
    return result;
}

Conjugate :: (c : MyComplex) -> MyComplex {
    result : MyComplex;
    result.r = c.r;
    result.i = -1.0 * c.i;
    return result;
}

MakeMyComplex :: (r : float, i : float) -> MyComplex {
    c : MyComplex;
    c.r = r;
    c.i = i;
    return c;
}

//TODO could make one with all 4 variables plus amplitude if needed
MyComplexPolar :: struct {
    using c : MyComplex;
    using polar : PolarCoord;
}

PolarCoord :: struct {
	theta : float;
	radius : float = 1.0;
}

RotateMyComplexPolar :: inline (theta : float, cp : MyComplexPolar) -> MyComplexPolar {
	result := cp;
	RotateMyComplexPolar(theta, *result);
	return result;
}

RotateMyComplexPolar :: inline (theta : float, cp : *MyComplexPolar) {
	cp.theta = fmod_cycling(cp.theta + theta, TAU);
	//TODO Can have an inverse rotation here as well if needed
	// cp.theta = fmod_cycling(theta - cp.theta, TAU);
	cp.r = cp.radius * cos(cp.theta);
	cp.i = cp.radius * sin(cp.theta);
}

MakeMyComplexPolar :: (theta : float, radius : float = 1.0, clockwise : bool = false) -> MyComplexPolar {
    c : MyComplex = EulersFormula(theta, clockwise);
    polar : MyComplexPolar;
    polar.c = c;
    polar.theta = theta;
    polar.radius = radius;
    return polar;
}

MyComplexToCPolar :: (c : MyComplex) -> MyComplexPolar {
    polar : MyComplexPolar;
    polar.c = c;
    polar.theta = atan2(c.i, c.r);
    polar.radius = sqrt(c.r * c.r + c.i * c.i); 
    return polar;
}

CPolarToMyComplex :: (p : MyComplexPolar) -> MyComplex {
    c : MyComplex;
    c.r = cos(p.theta);
    c.i = sin(p.theta);
    return c;
}

VectorToPolar :: inline (v : Vector2F) -> Vector2F {
	result : Vector2F;
    result.theta = atan2(v.y, v.x);
    result.radius = sqrt(v.x * v.x + v.y * v.y);
    return result;
}

/*Note that rotations are between -PI and PI.
This covers all rotations and will not function
properly outside of these bounds.

Given rotation is in counter-clockwise direction to
go with the base unit circle direction.
 PI/2 will rotate counter-clockwise by 1 quarter circle.
-PI/2 will rotate clockwise by 1 quarter circle.

TODO UNIT TEST THIS FUNCTION
*/
VectorToPolarZeroTo2PI :: inline (
	v : Vector2F,
	rotate : float = 0,
	clockwise : bool = true)
-> Vector2F
{
	p : Vector2F = VectorToPolar(v);
	p.theta -= rotate;
	if clockwise {
	//NOTE : adjusted this because circle was getting slightly less then 0 and given > TAU then which was an octave higher
	// if p.theta > 0 p.theta = TAU - p.theta;
	if p.theta > VF_EPSILON p.theta = TAU - p.theta;
	else p.theta = -p.theta;
	} else {
	// if p.theta < 0 p.theta += TAU;
	if p.theta < -VF_EPSILON p.theta += TAU;
	}
	return p;
}

VectorToPolar :: inline (v : Vector2I) -> Vector2F {
	result : Vector2F = VectorToPolar(MakeV2F(v));
    return result;
}

//TODO Pass this into pointer one below for consistency
PolarToVector :: (p : Vector2F) -> Vector2F {
	result : Vector2F;
	result.x = p.radius * cos(p.theta);
	result.y = p.radius * sin(p.theta);
	return result;
}

PolarToVector :: (p : *Vector2F) {
	theta : float = p.theta;
	radius : float = p.radius;
	p.x = radius * cos(theta);
	p.y = radius * sin(theta);
}

/*negative == false : e^(it) = cos(t) + isin(t)
 *negative == true : e^(-it) = cos(t) - isin(t)
*/
EulersFormula :: inline (theta : float, negative : bool = false) -> MyComplex {
    c : MyComplex;
    c.r = cos(theta);
    if negative c.i = -sin(theta);
    else c.i = sin(theta);
    return c;
}


/*
NOTE : rotate here is always counter-clockwise rotation for consistency.
TODO We can make a for_expansion for this to go through the circle points.
*/
RootsOfUnity :: (
	n : int, 
	clockwise : bool = false, 
	rotate : float = 0,
	$T : Type = Vector2F)
-> [] T 
{
#assert(T == MyComplexPolar || T == Vector2F || T == MyComplex);
    roots := NewArray(n, T,, context.allocator);
    if clockwise {
		// for < n..1 {
		// for #v2 < 1..n {
		for < 1..n {
			index := n - it;
			theta := TAU * it / n;
	    	if it == n theta = 0; //to be consistent with counter-clockwise loop
	    	theta += rotate;
	    	#if T == {
	    	case MyComplexPolar; roots[index] = MakeMyComplexPolar(theta);
	    	case Vector2F; roots[index] = EulersFormula(theta).vector;
	    	case MyComplex; roots[index] = EulersFormula(theta);
			}
		}
    } else {
		for 0..n-1 {
			theta := TAU * it / n;
			theta += rotate;
	    	#if T == {
	    	case MyComplexPolar; roots[it] = MakeMyComplexPolar(theta);
	    	case Vector2F; roots[it] = EulersFormula(theta).vector;
	    	case MyComplex; roots[it] = EulersFormula(theta);
			}
		}
    }
    return roots;    
}

//TODO Should do this with float64 and then cast on the way out to return
GetCirclePoint :: inline (
	//0.0 <= x <= 1.0
	x : float,
	clockwise : bool = false,
	$T : Type = Vector2F)
-> T 
{
#assert(T == MyComplexPolar || T == Vector2F || T == MyComplex);
 	#if T == {
 	case MyComplexPolar; return MakeMyComplexPolar(TAU*x, clockwise);
 	case Vector2F; 		return EulersFormula(TAU*x, clockwise).vector;
 	case MyComplex; 		return EulersFormula(TAU*x, clockwise);
	}  
}

Triangle2F :: struct {
	a, b, c : Vector2F;
	#place a; vertex : [3] Vector2F = ---;
}

MakeTriangle2F :: inline (a : Vector2F, b : Vector2F, c : Vector2F) -> Triangle2F {
	result : Triangle2F = ---;
	result.a = a;
	result.b = b;
	result.c = c;
	return result;
}

MakeTriangle2F :: inline (t : Triangle3F) -> Triangle2F {
	result : Triangle2F = ---;
	result.a = t.a.xy;
	result.b = t.b.xy;
	result.c = t.c.xy;
	return result;
}

//TODO this is just the wedge product of 2D triangle. replace with geometric algebra
OrientedArea :: inline (t : Triangle2F) -> float {
	result : float = 0.5 * ((t.c.x - t.a.x)*(t.b.y - t.a.y) - (t.b.x - t.a.x)*(t.c.y - t.a.y));
	return result; 
}

PointInTriangle :: inline (p : Vector2F, tri : Triangle2F) -> bool {
	area : float = 0.5 * (-tri.b.y*tri.c.x + tri.a.y*(-tri.b.x + tri.c.x) + tri.a.x*(tri.b.y - tri.c.y) + tri.b.x*tri.c.y);
	area_factor : float = 1.0 / (2.0 * area);
	s : float = area_factor*(tri.a.y*tri.c.x - tri.a.x*tri.c.y + (tri.c.y - tri.a.y)*p.x + (tri.a.x - tri.c.x)*p.y);
	t : float = area_factor*(tri.a.x*tri.b.y - tri.a.y*tri.b.x + (tri.a.y - tri.b.y)*p.x + (tri.b.x - tri.a.x)*p.y);
	if s >= 0 && t >= 0 && 1-s-t >= 0 return true;
	return false;
}

/*
	End of 2D
*/

/*
	3D
*/

Lerp :: inline (min : Vector3F, t : float, max : Vector3F) -> Vector3F {
    result : Vector3F = min + t * (max - min);
    return result;
}

Vector3F_MAX :: Vector3F.{10000,10000,10000};
Vector3F_MIN :: Vector3F.{-10000,-10000,-10000};

Vector3F :: struct {
    x, y, z : float;
    #place x; component : [3] float = ---;
    #place x; xy : Vector2F = ---;
    #place y; yz : Vector2F = ---;
    #place x; jai_v : Vector3 = ---;
}
//TODO Could make this polymorphic struct like with V2 if needed.
Vector3F64 :: struct { x, y, z : float64; }
MakeV3F64 :: inline (v3f : Vector3F) -> Vector3F64 {
	v : Vector3F64 = ---;
	v.x = cast(float64) v3f.x;
	v.y = cast(float64) v3f.y;
	v.z = cast(float64) v3f.z;
	return v;
}
MakeV3FFrom64 :: inline (v3f64 : Vector3F64) -> Vector3F {
	v : Vector3F = ---;
	v.x = cast(float) v3f64.x;
	v.y = cast(float) v3f64.y;
	v.z = cast(float) v3f64.z;
	return v;
}
//TODO https://randomascii.wordpress.com/2012/02/25/comparing-floating-point-numbers-2012-edition/
//TODO need to improve this to be relative epsilon and not absolute
//losing precision often due to small floating point rounding errors
VF_EPSILON :: 0.0001;
//TODO don't know if i like these struct == ops for vectors
//better to have a VectorEqual() function to remove ambiguity
//sometimes we don't want to generalize everything
operator == :: (v1 : Vector3F, v2 : Vector3F) -> bool {
    result := abs(v1.x - v2.x) <= VF_EPSILON &&
              abs(v1.y - v2.y) <= VF_EPSILON &&
              abs(v1.z - v2.z) <= VF_EPSILON;
    return result;
}

operator == :: (v1 : Vector2F, v2 : Vector2F) -> bool {
    result := abs(v1.x - v2.x) <= VF_EPSILON &&
              abs(v1.y - v2.y) <= VF_EPSILON;
    return result;
}
operator == :: (v1 : Vector4F, v2 : Vector4F) -> bool {
    result := abs(v1.x - v2.x) <= VF_EPSILON &&
              abs(v1.y - v2.y) <= VF_EPSILON &&
              abs(v1.z - v2.z) <= VF_EPSILON &&
              abs(v1.w - v2.w) <= VF_EPSILON;
    return result;
}

//TODO Need to make this not absolute value dependent like in 
//TODO https://randomascii.wordpress.com/2012/02/25/comparing-floating-point-numbers-2012-edition/
FloatBothEqual :: inline (f1 : $T, f2 : T) -> bool {
#assert(T == float || T == float64);
	#if T == float return FloatEqual(f1,f2);
	else #if T == float64 return Float64Equal(f1,f2);
}

FloatEqual :: inline (
	f1 : float, f2 : float, 
	bound : float = VF_EPSILON) 
-> bool 
{
	result : bool = abs(f1 - f2) <= bound;
	return result;
}

FEqual :: inline (f1 : float, f2 : float) 
-> bool 
{
	return FloatEqual(f1,f2);
}

FloatEqualInBound :: inline (
	f1 : float, f2 : float, 
	bound : float) 
-> bool
{
	return FloatEqual(f1, f2, bound);
}

FloatNotEqual :: inline (f1 : float, f2 : float) -> bool {
	result : bool = !FloatEqual(f1, f2);
	return result;
}

/*TODO Should we have operator == for float64 and float call this function? It might make total sense
since we are always using that as the default and then we can use a separate function if needed
*/
//TODO make this not dependent on absolute epsilon size
//TODO https://randomascii.wordpress.com/2012/02/25/comparing-floating-point-numbers-2012-edition/
VF_EPSILON_64 : float64 : 0.00001;
Float64Equal :: inline (f1 : float64, f2 : float64) -> bool {
	result : bool = abs(f1 - f2) <= VF_EPSILON_64;
	return result;
}

Float64NotEqual :: inline (f1 : float64, f2 : float64) -> bool {
	result : bool = !Float64Equal(f1, f2);
	return result;
}

IsFloat32 :: inline (f : float64) -> bool {
	result : bool = f < FLOAT32_MAX && f > FLOAT32_MIN;
	return result;
}

//All combinations of checking if float is in epsilon range.
//There are 4 as there are 2 operations each with 2 options.
//Left shifts range to left by epsilon so we would consider
//more start values and less end values.
//TODO Can rename InRangeLeft or InERangeLeft
InEpsilonRangeLeft :: inline (v : float64, start : float64, end : float64, EPSILON : float64 = VF_EPSILON_64) -> bool {
	if v >= start - EPSILON && v <= end - EPSILON {
    	return true;
   }	
   return false;
}
//Right shifts range to right by epsilon so we would consider
//more end values and less start values.
InEpsilonRangeRight :: inline (v : float64, start : float64, end : float64, EPSILON : float64 = VF_EPSILON_64) -> bool {
	if v >= start + EPSILON && v <= end + EPSILON {
    	return true;
   }	
   return false;
}
//Open open range by epsilon so we would consider
//more end values and more start values.
InEpsilonRangeOpen :: inline (v : float64, start : float64, end : float64, EPSILON : float64 = VF_EPSILON_64) -> bool {
	if v >= start - EPSILON && v <= end + EPSILON {
    	return true;
   }	
   return false;
}
//Close closes range by epsilon so we would consider
//less end values and less start values.
InEpsilonRangeClose :: inline (v : float64, start : float64, end : float64, EPSILON : float64 = VF_EPSILON_64) -> bool {
	if v >= start + EPSILON && v <= end - EPSILON {
    	return true;
   }	
   return false;
}

MakeV3F :: (x : float, y : float, z : float) -> Vector3F {
    v : Vector3F = ---;
    v.x = x;
    v.y = y;
    v.z = z;
    return v;
}

MakeV3F :: inline (components : [3] float) -> Vector3F {
    v : Vector3F = ---;
    v.x = components[0];
    v.y = components[1];
    v.z = components[2];
    return v;
}

MakeV3F :: (xy : Vector2F, z : float) -> Vector3F {
    v : Vector3F = ---;
    v.xy = xy;
    v.z = z;
    return v;
}

MakeV3F :: (v_i : Vector3I) -> Vector3F {
    v : Vector3F = ---;
    v.x = cast(float) v_i.x;
    v.y = cast(float) v_i.y;
    v.z = cast(float) v_i.z;
    return v;
}

operator - :: (v0 : Vector3F, v1 : Vector3F) -> Vector3F {
    v : Vector3F = ---;
    v.x = v0.x - v1.x;
    v.y = v0.y - v1.y;
    v.z = v0.z - v1.z;
    return v;
}

operator + :: (v0 : Vector3F, v1 : Vector3F) -> Vector3F {
    v : Vector3F = ---;
    v.x = v0.x + v1.x;
    v.y = v0.y + v1.y;
    v.z = v0.z + v1.z;
    return v;
}

operator += :: (v0 : *Vector3F, v1 : Vector3F) {
    v0.x += v1.x;
    v0.y += v1.y;
    v0.z += v1.z;
}

operator * :: (v0 : Vector3F, f : float) -> Vector3F #symmetric {
    v : Vector3F = ---;
    v.x = v0.x * f;
    v.y = v0.y * f;
    v.z = v0.z * f;
    return v;
}

operator - :: (v0 : Vector3F) -> Vector3F {
    v : Vector3F = ---;
    v.x = -v0.x;
    v.y = -v0.y;
    v.z = -v0.z;
    return v;
}

UnitVector :: (v : Vector3F) -> Vector3F {
	length : float = Length(v);
	if length == 0 return v;
	inv_length : float = 1.0 / length;

	result : Vector3F = ---;
	result.x = v.x * inv_length;
	result.y = v.y * inv_length;
	result.z = v.z * inv_length;
	return result;
}

//TODO cross product and do clipping planes
CrossProduct :: inline (a : Vector3F, b : Vector3F) -> Vector3F {
    result: Vector3F = ---;
    result.x = a.y * b.z - a.z * b.y;
    result.y = a.z * b.x - a.x * b.z;
    result.z = a.x * b.y - a.y * b.x;
    return result;
}

DotProduct :: inline (a : Vector3F, b : Vector3F) -> float {
    return a.x*b.x + a.y*b.y + a.z*b.z;
}

Length :: inline (a : Vector3F) -> float {
    return sqrt(a.x*a.x + a.y*a.y + a.z*a.z);
}

Vector3I :: struct {
	x, y, z : int;
    #place x; component : [3] int = ---;
}

operator == :: (v0 : Vector3I, v1 : Vector3I) -> bool {
	result : bool = v0.x == v1.x && v0.y == v1.y && v0.z == v1.z;
	return result;
}

MakeV3I :: (x : int, y : int, z : int) -> Vector3I {
    v : Vector3I = ---;
    v.x = x;
    v.y = y;
    v.z = z;
    return v;
}

MakeV3I :: inline (vf : Vector3F) -> Vector3I {
	vi : Vector3I = ---;
	vi.x = round_to_int(vf.x);
	vi.y = round_to_int(vf.y);
	vi.z = round_to_int(vf.z);
	return vi;
}

MakeV3I :: inline (components : [3] int) -> Vector3I {
	v : Vector3I = ---;
	v.x = components[0];
	v.y = components[1];
	v.z = components[2];
	return v;
}

//If we use this for world transforms then we can use the polymorphic model like with vectors 
//and that might might make using all the current operations much simpler.
Matrix3F64 :: struct {
	m11, m12, m13 : float64;
	m21, m22, m23 : float64;
	m31, m32, m33 : float64;
	#place m11; coef  : [3][3] float64 = ---;
}
MakeMatrix3FFrom64 :: inline (m3f64 : Matrix3F64) -> Matrix3F {
	m3 : Matrix3F = ---;
	for x : 0..2 for y : 0..2 {
		m3.coef[x][y] = cast(float) m3f64.coef[x][y];
	}
	return m3;
}
MakeMatrix3F64 :: inline (m3 : Matrix3F) -> Matrix3F64 {
	m3f64 : Matrix3F64 = ---;
	for x : 0..2 for y : 0..2 {
		m3f64.coef[x][y] = cast(float64) m3.coef[x][y];
	}
	return m3f64;
}

Matrix3F :: struct {
	m11, m12, m13 : float;
	m21, m22, m23 : float;
	m31, m32, m33 : float;
	#place m11; jai_m : Matrix3 = ---;
	#place m11; coef  : [3][3] float = ---;
}

Matrix3F_Identity :: Matrix3F.{1,0,0,
							   0,1,0,
							   0,0,1};

EqualIdentity :: (m : Matrix3F) -> bool {
	result : bool = m.m11 == 1.0 && m.m22 == 1.0 && m.m33 == 1.0;
	return result;
}

MakeMatrix3F :: inline (m11 : float, m12 : float, m13 : float,
			     		m21 : float, m22 : float, m23 : float,
    			 		m31 : float, m32 : float, m33 : float) -> Matrix3F
{
	result : Matrix3F = ---;
    result.m11 = m11; result.m12 = m12; result.m13 = m13;
    result.m21 = m21; result.m22 = m22; result.m23 = m23;
    result.m31 = m31; result.m32 = m32; result.m33 = m33;
    return result;
}

operator * :: (m : Matrix3F, v : Vector3F) -> Vector3F {
	result : Vector3F = ---;
	result.x = m.m11 * v.x + m.m12 * v.y + m.m13 * v.z;
	result.y = m.m21 * v.x + m.m22 * v.y + m.m23 * v.z;
	result.z = m.m31 * v.x + m.m32 * v.y + m.m33 * v.z;
	return result;
}

operator * :: (v : Vector3F, m : Matrix3F) -> Vector3F {
	result : Vector3F = ---;
	result.x = v.x * m.m11 + v.y * m.m21 + v.z * m.m31;
	result.y = v.x * m.m12 + v.y * m.m22 + v.z * m.m32;
	result.z = v.x * m.m13 + v.y * m.m23 + v.z * m.m33;
	return result;	
}

operator * :: (f : float, m : Matrix3F) -> Matrix3F #symmetric {
	result : Matrix3F = ---;
    result.m11 = m.m11 * f; result.m12 = m.m12 * f; result.m13 = m.m13 * f;
    result.m21 = m.m21 * f; result.m22 = m.m22 * f; result.m23 = m.m23 * f;
    result.m31 = m.m31 * f; result.m32 = m.m32 * f; result.m33 = m.m33 * f;
    return result;
}

operator * :: (m: Matrix3F, n: Matrix3F) -> Matrix3F {
    result: Matrix3F = ---;
    
    result.m11 = m.m11 * n.m11 + m.m12 * n.m21 + m.m13 * n.m31;
    result.m21 = m.m21 * n.m11 + m.m22 * n.m21 + m.m23 * n.m31;
    result.m31 = m.m31 * n.m11 + m.m32 * n.m21 + m.m33 * n.m31;

    result.m12 = m.m11 * n.m12 + m.m12 * n.m22 + m.m13 * n.m32;
    result.m22 = m.m21 * n.m12 + m.m22 * n.m22 + m.m23 * n.m32;
    result.m32 = m.m31 * n.m12 + m.m32 * n.m22 + m.m33 * n.m32;

    result.m13 = m.m11 * n.m13 + m.m12 * n.m23 + m.m13 * n.m33;
    result.m23 = m.m21 * n.m13 + m.m22 * n.m23 + m.m23 * n.m33;
    result.m33 = m.m31 * n.m13 + m.m32 * n.m23 + m.m33 * n.m33;

    return result;
}

Inverse :: (a: Matrix3F, epsilon := 0.001) -> Matrix3F {
    r: Matrix3F = ---;

    c11 := a.m22*a.m33 - a.m32*a.m23;
    c12 := a.m21*a.m33 - a.m31*a.m23;
    c13 := a.m21*a.m32 - a.m31*a.m22;

    // Determinant.
    det := a.m11*c11 - a.m12*c12 + a.m13*c13;

    if (det < epsilon) && (det > -epsilon)  return a;  // Failure... undefined!

    idet := 1/det;
    
    r.m11 =  idet*c11;
    r.m12 = -idet*(a.m12*a.m33 - a.m13*a.m32);
    r.m13 =  idet*(a.m12*a.m23 - a.m13*a.m22);
    r.m21 = -idet*c12;
    r.m22 =  idet*(a.m11*a.m33 - a.m13*a.m31);
    r.m23 = -idet*(a.m11*a.m23 - a.m13*a.m21);
    r.m31 =  idet*c13;
    r.m32 = -idet*(a.m11*a.m32 - a.m12*a.m31);
    r.m33 =  idet*(a.m11*a.m22 - a.m12*a.m21);
    
    return r;
}

Determinant :: (a : Matrix3F) -> float {
	result : float = 
		(a.m11 * (a.m22 * a.m33 - a.m23 * a.m32)) +
		(a.m12 * (a.m23 * a.m31 - a.m21 * a.m33)) +
		(a.m13 * (a.m21 * a.m32 - a.m22 * a.m31));
	return result;
}


MakeScaleMatrix :: inline (x : float) -> Matrix3F {
	return MakeScaleMatrix(x,x,x);
}
MakeScaleMatrix :: inline (x : float, y : float, z : float) -> Matrix3F {
	result := MakeMatrix3F(x, 0, 0, 
  					       0, y, 0, 
				  	       0, 0, z);
	return result;
}

//TODO implement quaternions or better yet rotors!
MakeRotationX :: (theta : float) -> Matrix3F {
	c : float = cos(theta);
	s : float = sin(theta);

	result := MakeMatrix3F(1, 0, 0, 
						   0, c,-s, 
						   0, s, c);
	return result;
}

MakeRotationY :: (theta : float) -> Matrix3F {
	c : float = cos(theta);
	s : float = sin(theta);

	result := MakeMatrix3F(c, 0, s, 
						   0, 1, 0, 
						  -s, 0, c);
	return result;
}

MakeRotationZ :: (theta : float) -> Matrix3F {
	c : float = cos(theta);
	s : float = sin(theta);

	result := MakeMatrix3F(c,-s, 0, 
						   s, c, 0, 
						   0, 0, 1);
	return result;
}

MakeRotation :: (t : float, a : Vector3F) -> Matrix3F {
	c : float = cos(t);
	s : float = sin(t);
	d : float = 1.0 - c;

	x : float = a.x * d;
	y : float = a.y * d;
	z : float = a.z * d;
	axay : float = x * a.y;
	axaz : float = x * a.z;
	ayaz : float = y * a.z;

	result := MakeMatrix3F(c + x * a.x, axay - s * a.z, axaz + s * a.y, 
						   axay + s * a.z, c + y * a.y, ayaz - s * a.x, 
						   axaz - s * a.y, ayaz + s * a.x, c + z * a.z);
	return result;
}

MakeRotation :: (dir : Vector3F, a : Vector3F, b : Vector3F) -> Matrix3F {
	dir_unit : Vector3F = UnitVector(dir);
	delta : Vector3F = UnitVector(b - a);
	rot_normal : Vector3F = UnitVector(CrossProduct(dir_unit, delta));
	angle_normal : float = acos(DotProduct(dir_unit, delta));
	rot_matrix : Matrix3F = MakeRotation(angle_normal, rot_normal);
	return rot_matrix;
}

MakeRotationAssumeDirNormal :: (dir : Vector3F, a : Vector3F, b : Vector3F) -> Matrix3F {
	delta : Vector3F = UnitVector(b - a);
	rot_normal : Vector3F = UnitVector(CrossProduct(dir, delta));
	angle_normal : float = acos(DotProduct(dir, delta));
	rot_matrix : Matrix3F = MakeRotation(angle_normal, rot_normal);
	return rot_matrix;
}

//TODO these seem like they should be generated with meta-programming
MakeRotationXY :: (theta : float) -> Matrix4F {
	c : float = cos(theta);
	s : float = sin(theta);

	result := MakeMatrix4F(1, 0, 0, 0,
						   0, 1, 0, 0,
						   0, 0, c,-s,
						   0, 0, s, c);	
	return result;
}

MakeRotationXZ :: (theta : float) -> Matrix4F {
	c : float = cos(theta);
	s : float = sin(theta);

	result := MakeMatrix4F(1, 0, 0, 0,
						   0, c, 0,-s,
						   0, 0, 1, 0,
						   0, s, 0, c);	
	return result;
}

MakeRotationZW :: (theta : float) -> Matrix4F {
	c : float = cos(theta);
	s : float = sin(theta);

	result := MakeMatrix4F(c,-s, 0, 0,
						   s, c, 0, 0,
						   0, 0, 1, 0,
						   0, 0, 0, 1);	
	return result;
}

MakeRotationYZ :: (theta : float) -> Matrix4F {
	c : float = cos(theta);
	s : float = sin(theta);

	result := MakeMatrix4F(c, 0, 0,-s,
						   0, 1, 0, 0,
						   0, 0, 1, 0,
						   s, 0, 0, c);	
	return result;
}

MakeRotationXW :: (theta : float) -> Matrix4F {
	c : float = cos(theta);
	s : float = sin(theta);

	result := MakeMatrix4F(1, 0, 0, 0,
						   0, c,-s, 0,
						   0, s, c, 0,
						   0, 0, 0, 1);	
	return result;
}

MakeRotationYW :: (theta : float) -> Matrix4F {
	c : float = cos(theta);
	s : float = sin(theta);

	result := MakeMatrix4F(c, 0,-s, 0,
						   0, 1, 0, 0,
						   s, 0, c, 0,
						   0, 0, 0, 1);	
	return result;
}

MakeRotationXYAndZW :: (theta : float) -> Matrix4F {
	c : float = cos(theta);
	s : float = sin(theta);

	result := MakeMatrix4F(c,-s, 0, 0,
						   s, c, 0, 0,
						   0, 0, c,-s,
						   0, 0, s, c);	
	return result;
}

//TODO store as column vectors and retrieve with a Get(x,y) for efficiency
Matrix4x3F :: struct {
    m11, m12, m13, m14 : float;
    m21, m22, m23, m24 : float;
    m31, m32, m33, m34 : float;

    #place m11; v:      [3]    Vector4; // These are row vectors.
    #place m11; coef:   [3][4] float = ---;
} 

Matrix4x3F_Identity :: Matrix4x3F.{1,0,0,0,
								   0,1,0,0,
								   0,0,1,0};

MakeMatrix4x3F :: inline (m11 : float, m12 : float, m13 : float, m14 : float,
			     		  m21 : float, m22 : float, m23 : float, m24 : float,
    			 		  m31 : float, m32 : float, m33 : float, m34 : float) -> Matrix4x3F
{
	result : Matrix4x3F = ---;
    result.m11 = m11; result.m12 = m12; result.m13 = m13; result.m14 = m14;
    result.m21 = m21; result.m22 = m22; result.m23 = m23; result.m24 = m24;
    result.m31 = m31; result.m32 = m32; result.m33 = m33; result.m34 = m34;
    return result;
}

MakeMatrix4x3F :: inline (m : Matrix3F, v : Vector3F) -> Matrix4x3F {
	result : Matrix4x3F = ---;
	for i : 0..2 {
		for j : 0..2 {
			result.coef[i][j] = m.coef[i][j];
		}
	}
	result.coef[0][3] = v.x;
	result.coef[1][3] = v.y;
	result.coef[2][3] = v.z;
	return result;
}

operator * :: (m : Matrix4x3F, v : Vector4F) -> Vector3F {
    result: Vector3F = ---;
    result.x = m.m11 * v.x + m.m12 * v.y + m.m13 * v.z + m.m14 * v.w;
    result.y = m.m21 * v.x + m.m22 * v.y + m.m23 * v.z + m.m24 * v.w;
    result.z = m.m31 * v.x + m.m32 * v.y + m.m33 * v.z + m.m34 * v.w;
    return result;
}

//Note : we imply that w = 1 for vector v
TransformPoint :: inline (m : Matrix4x3F, v : Vector3F) -> Vector3F {
    result: Vector3F = ---;
    result.x = m.m11 * v.x + m.m12 * v.y + m.m13 * v.z + m.m14;
    result.y = m.m21 * v.x + m.m22 * v.y + m.m23 * v.z + m.m24;
    result.z = m.m31 * v.x + m.m32 * v.y + m.m33 * v.z + m.m34;
    return result;
}

//Note : we imply that w = 0 for vector v
TransformVector :: inline (m : Matrix4x3F, v : Vector3F) -> Vector3F {
    result: Vector3F = ---;
    result.x = m.m11 * v.x + m.m12 * v.y + m.m13 * v.z;
    result.y = m.m21 * v.x + m.m22 * v.y + m.m23 * v.z;
    result.z = m.m31 * v.x + m.m32 * v.y + m.m33 * v.z;
    return result;
}

GetTranslation :: inline (transform : Matrix4x3F) -> Vector3F {
	result : Vector3F = ---;
	result.x = transform.m14;
	result.y = transform.m24;
	result.z = transform.m34;
	return result;
}

GetTransform :: inline (transform : Matrix4x3F) -> Matrix3F {
	result : Matrix3F = ---;
	result.m11 = transform.m11; result.m12 = transform.m12; result.m13 = transform.m13;
	result.m21 = transform.m21; result.m22 = transform.m22; result.m23 = transform.m23;
	result.m31 = transform.m31; result.m32 = transform.m32; result.m33 = transform.m33;
	return result;
}

UpdateTranslation :: inline (transform : *Matrix4x3F, v : Vector3F) {
	transform.m14 = v.x; 
	transform.m24 = v.y;
	transform.m34 = v.z;
}

AddToTranslation :: inline (transform : *Matrix4x3F, v : Vector3F) {
	transform.m14 += v.x; 
	transform.m24 += v.y;
	transform.m34 += v.z;
}

UpdateTransform :: inline (transform : *Matrix4x3F, m : Matrix3F) {
	for row : 0..2 for column : 0..2 {	
		transform.coef[row][column] = m.coef[row][column];
	}
}

MultiplyTransform :: inline (transform : *Matrix4x3F, new_t : Matrix3F) {
	old_t : Matrix3F = GetTransform(transform);
    rotate_mn : Matrix3F = old_t * new_t;
	UpdateTransform(transform, rotate_mn);
}

MultiplyTransform :: inline (transform : Matrix4x3F, new_t : Matrix3F) -> Matrix4x3F {
	result : Matrix4x3F = transform;
	MultiplyTransform(*result, new_t);
    return result;
}

MultiplyTransform :: inline (new_t : Matrix3F, transform : *Matrix4x3F) {
	old_t : Matrix3F = GetTransform(transform);
    rotate_mn : Matrix3F = new_t * old_t;
	UpdateTransform(transform, rotate_mn);
}

MultiplyTransform :: inline (new_t : Matrix3F, transform : Matrix4x3F) -> Matrix4x3F {
	result : Matrix4x3F = transform;
	MultiplyTransform(new_t, *result);
    return result;
}

//Note : 36 multiplys, 27 adds
operator * :: (m: Matrix4x3F, n: Matrix4x3F) -> Matrix4x3F {
    result: Matrix4x3F = ---;
    
    result.m11 = m.m11*n.m11 + m.m12*n.m21 + m.m13*n.m31;
    result.m21 = m.m21*n.m11 + m.m22*n.m21 + m.m23*n.m31;
    result.m31 = m.m31*n.m11 + m.m32*n.m21 + m.m33*n.m31;
    
    result.m12 = m.m11*n.m12 + m.m12*n.m22 + m.m13*n.m32;
    result.m22 = m.m21*n.m12 + m.m22*n.m22 + m.m23*n.m32;
    result.m32 = m.m31*n.m12 + m.m32*n.m22 + m.m33*n.m32;

    result.m13 = m.m11*n.m13 + m.m12*n.m23 + m.m13*n.m33;
    result.m23 = m.m21*n.m13 + m.m22*n.m23 + m.m23*n.m33;
    result.m33 = m.m31*n.m13 + m.m32*n.m23 + m.m33*n.m33;

    result.m14 = m.m11*n.m14 + m.m12*n.m24 + m.m13*n.m34 + m.m14;
    result.m24 = m.m21*n.m14 + m.m22*n.m24 + m.m23*n.m34 + m.m24;
    result.m34 = m.m31*n.m14 + m.m32*n.m24 + m.m33*n.m34 + m.m34;
        
    return result;
}

MultiplyTransforms :: (m: Matrix4x3F, n: Matrix4x3F) -> Matrix4F {
    result: Matrix4F = ---;

    result.mat4x3 = m * n;
    result.m41 = 0; result.m42 = 0; result.m43 = 0; result.m44 = 1.0;
        
    return result;
}

Triangle3F :: struct {
	a, b, c : Vector3F;
	#place a; vertex : [3] Vector3F = ---;
}

MakeTriangle3F :: inline (a : Vector3F, b : Vector3F, c : Vector3F) -> Triangle3F {
	result : Triangle3F = ---;
	result.a = a;
	result.b = b;
	result.c = c;
	return result;
}

MakeTriangle3F :: (tri : Triangle2F, z : float = 0) -> Triangle3F {
	result : Triangle3F = ---;
	result.a = MakeV3F(tri.a, z);
	result.b = MakeV3F(tri.b, z);
	result.c = MakeV3F(tri.c, z);
	return result;
}

operator * :: (t : Triangle3F, f : float) -> Triangle3F #symmetric {
	result : Triangle3F = t;
	result.a *= f;
	result.b *= f;
	result.c *= f;
	return result;
}

Triangle4F :: struct {
	a, b, c : Vector4F;
	#place a; vertex : [3] Vector4F = ---;
}

MakeTriangle4F :: inline (a : Vector4F, b : Vector4F, c : Vector4F) -> Triangle4F {
	result : Triangle4F = ---;
	result.a = a;
	result.b = b;
	result.c = c;
	return result;
}

MakeTriangle4F :: inline (t : Triangle3F) -> Triangle4F {
	result : Triangle4F = ---;
	result.a.xyz = t.a; result.a.w = 1.0; 
	result.b.xyz = t.b; result.b.w = 1.0;
	result.c.xyz = t.c; result.c.w = 1.0;
	return result;	
}

Line2F :: struct {
	point : Vector2F;
	direction : Vector2F;
}

MakeLine2F :: inline (p1 : Vector2F, p2 : Vector2F) -> Line2F {
	line : Line2F;
	line.point = p1;
	line.direction.x = p2.x - p1.x;
	line.direction.y = p2.y - p1.y;
	return line;
}

PointOnLine :: inline (point : Vector2F, line : Line2F) -> bool {
	dxc : float = point.x - line.point.x;
	dyc : float = point.y - line.point.y;

	cross : float = dxc * line.direction.y - dyc * line.direction.x;
	if FloatEqual(cross, 0) return true;
	return false;
}

Plane3F :: struct {
	a,b,c,d : float;
	#place a; n : Vector3F = ---;
	#place a; x,y,z,w : float = ---;
}

MakePlane :: (x : float, y : float, z : float, w : float) -> Plane3F {
	result : Plane3F = ---;
	result.a = x;
	result.b = y;
	result.c = z;
	result.d = w;
	return result;
}

MakePlane :: (normal : Vector3F, d : float) -> Plane3F {
	result : Plane3F = ---;
	result.n = normal;
	result.d = d;
	return result;
}

operator * :: (f : Plane3F, H : Matrix4x3F) -> Plane3F {
	result : Plane3F = MakePlane(
		f.x * H.m11 + f.y * H.m21 + f.z * H.m31, 
     	f.x * H.m12 + f.y * H.m22 + f.z * H.m32,
     	f.x * H.m13 + f.y * H.m23 + f.z * H.m33,
     	f.x * H.m14 + f.y * H.m24 + f.z * H.m34 + f.w);
	return result;
}

DotProduct :: (f : Plane3F, v : Vector3F) -> float {
	result : float = f.x * v.x + f.y * v.y + f.z * v.z;
	return result;
}

//Note : assumes p has a value of w = 1.0
DotProductPlanePoint :: (f : Plane3F, p : Vector3F) -> float {
	result : float = f.x * p.x + f.y * p.y + f.z * p.z + f.w;
	return result;
}

PlaneLineSegmentIntersect :: inline (plane : Plane3F, v0 : Vector3F, v1 : Vector3F) -> Vector3F, no_intersect : bool {
	if !LineSegmentIntersectsPlane(plane, v0, v1) return Vector3F.{FLOAT32_MAX, FLOAT32_MAX, FLOAT32_MAX}, true;
	return PlaneLineSegmentIntersectNoCheck(plane, v0, v1), false;
}

LineSegmentIntersectsPlane :: inline (plane : Plane3F, v0 : Vector3F, v1 : Vector3F) -> bool {
	v0_dist : float = DotPlane(plane, v0);
	v1_dist : float = DotPlane(plane, v1);
	result : bool = (v0_dist >= 0 && v1_dist <= 0) || (v0_dist <= 0 && v1_dist >= 0);
	return result;
}

PlaneLineSegmentIntersectNoCheck :: inline (plane : Plane3F, v0 : Vector3F, v1 : Vector3F) -> Vector3F {
	v_diff : Vector3F = v1 - v0;
	t : float = (-plane.d - DotProduct(plane.n, v0)) / DotProduct(plane.n, v_diff);
	intersect : Vector3F = v0 + t * v_diff;
	return intersect;
}

IntersectLinePlane :: (p : Vector3F, v : Vector3F, f : Plane3F) -> 
					   q : Vector3F, not_parallel : bool 
{
	fv : float = DotProduct(f, v);
	if abs(fv) > 0.0001 {
		q : Vector3F = p - v * (DotProductPlanePoint(f, p) / fv);
		return q, true;
	}
	return Vector3F.{FLOAT32_MIN+7.0, FLOAT32_MIN+1.0, FLOAT32_MIN+2.0}, false;
}

/*
	assumes cross product direction is (p0 - p1) -> (p2 - p1)
	so p1 is the pivot point
*/
MakeNormalizedPlane :: (p0 : Vector3F, p1 : Vector3F, p2 : Vector3F) -> Plane3F {
	v1 : Vector3F = p0 - p1;
	v2 : Vector3F = p2 - p1;
	normal : Vector3F = CrossProduct(v1, v2);
	unit_normal : Vector3F = UnitVector(normal);

	result : Plane3F = ---;
	result.a = unit_normal.x;
	result.b = unit_normal.y;
	result.c = unit_normal.z;
	result.d = -DotProduct(unit_normal, p0);
	return result;
}

#if 0 {
DotPlane :: (plane : Plane3F, v : Point3F) -> float #symmetric {
	result : float = plane.a * v.x + plane.b * v.y + plane.c * v.z + plane.d;
	return result;
}
}

DotPlane :: (plane : Plane3F, p : Vector3F) -> float #symmetric {
	result : float = plane.a * p.x + plane.b * p.y + plane.c * p.z + plane.d;
	return result;
}

Matrix4F :: struct {
    m11, m12, m13, m14 : float;
    m21, m22, m23, m24 : float;
    m31, m32, m33, m34 : float;
    m41, m42, m43, m44 : float;

    #place m11; mat4x3: Matrix4x3F = ---;
    
    #place m11; v:      [4]    Vector4F; // These are row vectors.
    #place m11; coef:   [4][4] float = ---;
    #place m11; floats: [16]   float = ---;
} 

Matrix4F_Identity :: Matrix4F.{1,0,0,0,
							   0,1,0,0,
							   0,0,1,0,
							   0,0,0,1};

MakeMatrix4F :: inline (m11 : float, m12 : float, m13 : float, m14 : float,
			     		m21 : float, m22 : float, m23 : float, m24 : float,
    			 		m31 : float, m32 : float, m33 : float, m34 : float,
    			 		m41 : float, m42 : float, m43 : float, m44 : float) -> Matrix4F
{
	result : Matrix4F = ---;
    result.m11 = m11; result.m12 = m12; result.m13 = m13; result.m14 = m14;
    result.m21 = m21; result.m22 = m22; result.m23 = m23; result.m24 = m24;
    result.m31 = m31; result.m32 = m32; result.m33 = m33; result.m34 = m34;
    result.m41 = m41; result.m42 = m42; result.m43 = m43; result.m44 = m44;
    return result;
}

//Note : assumes bottom row is [0,0,0,1]
MakeMatrix4F :: inline (m : Matrix3F, v : Vector3F) -> Matrix4F {
	result : Matrix4F;
	for i : 0..2 {
		for j : 0..2 {
			result.coef[i][j] = m.coef[i][j];
		}
	}
	result.coef[0][3] = v.x;
	result.coef[1][3] = v.y;
	result.coef[2][3] = v.z;
	result.coef[3][3] = 1.0;
	return result;
}

MakeMatrix4F :: inline (m : Matrix4x3F) -> Matrix4F {
	result : Matrix4F;
	for i : 0..2 {
		for j : 0..3 {
			result.coef[i][j] = m.coef[i][j];
		}
	}
	result.coef[3][0] = 0;
	result.coef[3][1] = 0;
	result.coef[3][2] = 0;
	result.coef[3][3] = 1.0;
	return result;
}

//TODO need to test if this works with clipping
//TODO could make a Matrix4x3F since bottom row = (0,0,0,1)
MakeOrthoProjection :: inline (l : float, r : float, t : float, b : float, 
							   n : float, f : float) -> Matrix4F 
{
	w_inv : float = 1.0 / (r - l);
	h_inv : float = 1.0 / (b - t);
	d_inv : float = 1.0 / (f - n);
	result := MakeMatrix4F(2.0*w_inv,         0,     0, -(r+l)*w_inv,
				                   0, 2.0*h_inv,     0, -(b+t)*h_inv,
				                   0,         0, d_inv,     -n*d_inv,
				                   0,         0,     0,          1.0);
	return result;
}

MakeFrustumProjectionDepthPrecisionWithG :: inline (g : float, s : float, n : float, 
								 	  				f : float) -> Matrix4F 
{
	k : float = n / (n - f);
	result := MakeMatrix4F(g/s, 0, 0, 0,
					         0, g, 0, 0,
				    	     0, 0, k,-f*k,
				    	     0, 0, 1, 0);
	return result;
}

MakeFrustumProjectionDepthPrecision :: inline (fovy : float, s : float, n : float,
							 	  			   f : float) -> Matrix4F 
{
	g : float = 1.0 / tan(fovy * 0.5);
	k : float = n / (n - f);
	result := MakeMatrix4F(g/s, 0, 0, 0,
					         0, g, 0, 0,
				    	     0, 0, k,-f*k,
				    	     0, 0, 1, 0);
	return result;
}

MakeFrustumProjectionWithG :: inline (g : float, s : float, n : float, 
								 	  f : float) -> Matrix4F 
{
	k : float = f / (f - n);
	result := MakeMatrix4F(g/s, 0, 0, 0,
					         0, g, 0, 0,
				    	     0, 0, k,-n*k,
				    	     0, 0, 1, 0);
	return result;
}

MakeFrustumProjection :: inline (fovy : float, s : float, n : float, 
								 f : float) -> Matrix4F 
{
	g : float = 1.0 / tan(fovy * 0.5);
	k : float = f / (f - n);
	result := MakeMatrix4F(g/s, 0, 0, 0,
					         0, g, 0, 0,
				    	     0, 0, k,-n*k,
				    	     0, 0, 1, 0);
	return result;
}

MakeInverseFrustumProjection :: inline (fovy : float, s : float, n : float, 
				   					    f : float) -> Matrix4F 
{
	g : float = 1.0 / tan(fovy * 0.5);
	k : float = f / (f - n);
	result := MakeMatrix4F(s/g,  0, 		  0,   0,
					         0,1/g, 		  0,   0,
				    	     0,  0, 		  0,   1,
				    	     0,  0,-(f-n)/(n*f), 1/n);
	return result;
}

MakeRevFrustumProjection :: inline (fovy : float, s : float, n : float, 
									f : float) -> Matrix4F 
{
	g : float = 1.0 / tan(fovy * 0.5);
	k : float = n / (n - f);
	result := MakeMatrix4F(g/s, 0, 0, 0,
					         0, g, 0, 0,
				    	     0, 0, k,-f*k,
				    	     0, 0, 1, 0);
	return result;
}

TransformVertex :: inline (position : Vector3F, mvp : Matrix4F) -> Vector4F {
	result : Vector4F = ---;
	result.x = DotProduct(position, mvp.v[0].xyz) + mvp.v[0].w;
	result.y = DotProduct(position, mvp.v[1].xyz) + mvp.v[1].w;
	result.z = DotProduct(position, mvp.v[2].xyz) + mvp.v[2].w;
	result.w = DotProduct(position, mvp.v[3].xyz) + mvp.v[3].w;
	return result;
}

operator * :: (m : Matrix4F, v : Vector4F) -> Vector4F {
	result : Vector4F = ---;
	result.x = m.m11 * v.x + m.m12 * v.y + m.m13 * v.z + m.m14 * v.w;
	result.y = m.m21 * v.x + m.m22 * v.y + m.m23 * v.z + m.m24 * v.w;
	result.z = m.m31 * v.x + m.m32 * v.y + m.m33 * v.z + m.m34 * v.w;
	result.w = m.m41 * v.x + m.m42 * v.y + m.m43 * v.z + m.m44 * v.w;
	return result;
}

//Note : 64 multiplies, 48 adds
operator * :: (m : Matrix4F, n : Matrix4F) -> Matrix4F {
    // @Speed: Can have a specialized version if we know it's affine.
    result: Matrix4F = ---;
    
    result.m11 = m.m11*n.m11 + m.m12*n.m21 + m.m13*n.m31 + m.m14*n.m41;
    result.m21 = m.m21*n.m11 + m.m22*n.m21 + m.m23*n.m31 + m.m24*n.m41;
    result.m31 = m.m31*n.m11 + m.m32*n.m21 + m.m33*n.m31 + m.m34*n.m41;
    result.m41 = m.m41*n.m11 + m.m42*n.m21 + m.m43*n.m31 + m.m44*n.m41;
    
    result.m12 = m.m11*n.m12 + m.m12*n.m22 + m.m13*n.m32 + m.m14*n.m42;
    result.m22 = m.m21*n.m12 + m.m22*n.m22 + m.m23*n.m32 + m.m24*n.m42;
    result.m32 = m.m31*n.m12 + m.m32*n.m22 + m.m33*n.m32 + m.m34*n.m42;
    result.m42 = m.m41*n.m12 + m.m42*n.m22 + m.m43*n.m32 + m.m44*n.m42;

    result.m13 = m.m11*n.m13 + m.m12*n.m23 + m.m13*n.m33 + m.m14*n.m43;
    result.m23 = m.m21*n.m13 + m.m22*n.m23 + m.m23*n.m33 + m.m24*n.m43;
    result.m33 = m.m31*n.m13 + m.m32*n.m23 + m.m33*n.m33 + m.m34*n.m43;
    result.m43 = m.m41*n.m13 + m.m42*n.m23 + m.m43*n.m33 + m.m44*n.m43;
        
    result.m14 = m.m11*n.m14 + m.m12*n.m24 + m.m13*n.m34 + m.m14*n.m44;
    result.m24 = m.m21*n.m14 + m.m22*n.m24 + m.m23*n.m34 + m.m24*n.m44;
    result.m34 = m.m31*n.m14 + m.m32*n.m24 + m.m33*n.m34 + m.m34*n.m44;
    result.m44 = m.m41*n.m14 + m.m42*n.m24 + m.m43*n.m34 + m.m44*n.m44;
        
    return result;
}

operator * :: (m : Matrix4F, n : Matrix4x3F) -> Matrix4F {
    result: Matrix4F = ---;
    
    result.m11 = m.m11*n.m11 + m.m12*n.m21 + m.m13*n.m31;
    result.m21 = m.m21*n.m11 + m.m22*n.m21 + m.m23*n.m31;
    result.m31 = m.m31*n.m11 + m.m32*n.m21 + m.m33*n.m31;
    result.m41 = m.m41*n.m11 + m.m42*n.m21 + m.m43*n.m31;
    
    result.m12 = m.m11*n.m12 + m.m12*n.m22 + m.m13*n.m32;
    result.m22 = m.m21*n.m12 + m.m22*n.m22 + m.m23*n.m32;
    result.m32 = m.m31*n.m12 + m.m32*n.m22 + m.m33*n.m32;
    result.m42 = m.m41*n.m12 + m.m42*n.m22 + m.m43*n.m32;

    result.m13 = m.m11*n.m13 + m.m12*n.m23 + m.m13*n.m33;
    result.m23 = m.m21*n.m13 + m.m22*n.m23 + m.m23*n.m33;
    result.m33 = m.m31*n.m13 + m.m32*n.m23 + m.m33*n.m33;
    result.m43 = m.m41*n.m13 + m.m42*n.m23 + m.m43*n.m33;
        
    result.m14 = m.m11*n.m14 + m.m12*n.m24 + m.m13*n.m34 + m.m14;
    result.m24 = m.m21*n.m14 + m.m22*n.m24 + m.m23*n.m34 + m.m24;
    result.m34 = m.m31*n.m14 + m.m32*n.m24 + m.m33*n.m34 + m.m34;
    result.m44 = m.m41*n.m14 + m.m42*n.m24 + m.m43*n.m34 + m.m44;
        
    return result;
}

InverseLengyel :: (m: Matrix4x3F) -> Matrix4x3F {
    a := MakeV3F(m.m11, m.m21, m.m31);
    b := MakeV3F(m.m12, m.m22, m.m32);
    c := MakeV3F(m.m13, m.m23, m.m33);
    d := MakeV3F(m.m14, m.m24, m.m34);

    s := CrossProduct(a, b);
    t := CrossProduct(c, d);

    invmdet := 1.0 / DotProduct(s, c);
    s *= invmdet;
    t *= invmdet;
    v := c * invmdet;

    r0 := CrossProduct(b, v);
    r1 := CrossProduct(v, a);

    return MakeMatrix4x3F(
            r0.x, r0.y, r0.z, -DotProduct(b, t),
            r1.x, r1.y, r1.z,  DotProduct(a, t),
            s.x,   s.y,  s.z, -DotProduct(d, s));
}


InverseLengyel :: (m: Matrix4F, epsilon := 0.0001) -> Matrix4F, bool {
    a := MakeV3F(m.m11, m.m21, m.m31);
    b := MakeV3F(m.m12, m.m22, m.m32);
    c := MakeV3F(m.m13, m.m23, m.m33);
    d := MakeV3F(m.m14, m.m24, m.m34);

    x := m.m41;
    y := m.m42;
    z := m.m43;
    w := m.m44;

    s := CrossProduct(a, b);
    t := CrossProduct(c, d);
    u := a * y - b * x;
    v := c * w - d * z;

    det := DotProduct(s, v) + DotProduct(t, u);
    invmdet := 1.0 / det;
    s *= invmdet;
    t *= invmdet;
    u *= invmdet;
    v *= invmdet;

    r0 := CrossProduct(b, v) + t * y;
    r1 := CrossProduct(v, a) - t * x;
    r2 := CrossProduct(d, u) + s * w;
    r3 := CrossProduct(u, c) - s * z;

    return MakeMatrix4F(
            r0.x, r0.y, r0.z, -DotProduct(b, t),
            r1.x, r1.y, r1.z,  DotProduct(a, t),
            r2.x, r2.y, r2.z, -DotProduct(d, s),
            r3.x, r3.y, r3.z,  DotProduct(c, s)),
        abs(det) < epsilon;
}

AdjugateLengyel :: (m: Matrix4F) -> Matrix4F {

    // @Cleanup: Use Vector3.{} or m.v[n].xyz.
    a := MakeV3F(m.m11, m.m21, m.m31);
    b := MakeV3F(m.m12, m.m22, m.m32);
    c := MakeV3F(m.m13, m.m23, m.m33);
    d := MakeV3F(m.m14, m.m24, m.m34);

    x := m.m41;
    y := m.m42;
    z := m.m43;
    w := m.m44;

    s := CrossProduct(a, b);
    t := CrossProduct(c, d);
    u := a * y - b * x;
    v := c * w - d * z;

    r0 := CrossProduct(b, v) + t * y;
    r1 := CrossProduct(v, a) - t * x;
    r2 := CrossProduct(d, u) + s * w;
    r3 := CrossProduct(u, c) - s * z;

    return MakeMatrix4F(
            r0.x, r0.y, r0.z, -DotProduct(b, t),
            r1.x, r1.y, r1.z,  DotProduct(a, t),
            r2.x, r2.y, r2.z, -DotProduct(d, s),
            r3.x, r3.y, r3.z,  DotProduct(c, s));
}

/*
	End of 3D
*/

/*TODO Another simple sorting algorithm in-place without recursion is HeapSort
https://en.wikipedia.org/wiki/Heapsort
standard implementation seems simple enough. Could also use in language possibly
maybe also quicksort also a test for recursion and function pointers
*/
/*TODO make this work for variable/constant type T
  maybe pass in max value for different types?
*/
MergeSort :: (arr : [] int) {
	if arr.count <= 1 return;

	power_count : int = arr.count;
	merge_arr : [] int;
	if arr.count & (arr.count - 1) == 0 {
		//We already have a power of 2
		merge_arr = arr;
	} else { //We do not have a power of 2 so we round up to nearest power of 2
		//TODO check hacker's delight or other bit twiddling for an interesting
		//way to get next power of 2
		//This one is interesting, don't really understand it yet though
		power_count -= 1;
		power_count |= power_count >> 1;
		power_count |= power_count >> 2;
		power_count |= power_count >> 4;
		power_count |= power_count >> 8;
		power_count |= power_count >> 16;
		power_count |= power_count >> 32; //Note : this is s64 so only works until power_count = 2^64 - 1
		power_count += 1;
		
		merge_arr = NewArray(power_count, int);
		for 0..arr.count-1 {
			merge_arr[it] = arr[it];
		}
		for arr.count..merge_arr.count-1 {
			merge_arr[it] = S64_MAX; //TODO max value for different types here maybe passed in?
		}
	}

	size := 2;
	while size <= merge_arr.count {
		defer size <<= 1;
		start : int = 0;
		arr_index : int;
		while start < merge_arr.count {
			defer start += size;
			//TODO make this more efficient by reusing arrays here instead of allocating each time
			//for example could pass arrays into SplitArray and use size here instead of count
			//TODO instead of creating new arrays can just return arrays
			//pointing to the 1 array
			//TODO or just use temporary allocator
			split_1, split_2 := SplitArray(merge_arr, start, start + (size >> 1), start+size);
			defer free(split_1.data);
			defer free(split_2.data);
			s_1 : int;
			s_2 : int;
			while s_1 < split_1.count && s_2 < split_2.count {
				if split_1[s_1] < split_2[s_2] {
					merge_arr[arr_index] = split_1[s_1];
					s_1 += 1;
				} else {
					merge_arr[arr_index] = split_2[s_2];
					s_2 += 1;
				}
				arr_index += 1;
			}

			if s_2 > s_1 {
				for s_1..split_1.count-1 {
					merge_arr[arr_index] = split_1[s_1];
					s_1 += 1;
					arr_index += 1;
				}
			} else {
				for s_2..split_2.count-1 {
					merge_arr[arr_index] = split_2[s_2];
					s_2 += 1;
					arr_index += 1;
				}
			}
		}		
	} 	

	if merge_arr.count != arr.count {
		for 0..arr.count-1 {
			arr[it] = merge_arr[it];
		}
		free(merge_arr.data);
	}
}

MergeSortRecursive :: (arr : [] int) {
	if arr.count == 1 return;
	split_1, split_2 := SplitArray(arr, 0, arr.count / 2, arr.count);
	MergeSortRecursive(split_1);
	defer free(split_1.data);
	MergeSortRecursive(split_2);
	defer free(split_2.data);

	s_1 : int;
	s_2 : int;
	arr_index : int;
	for 0..arr.count-1 {
		if s_1 >= split_1.count || s_2 >= split_2.count break;
		if split_1[s_1] < split_2[s_2] {
			arr[arr_index] = split_1[s_1];
			s_1 += 1;
		} else {
			arr[arr_index] = split_2[s_2];
			s_2 += 1;
		}
		arr_index += 1;
	}

	if s_2 > s_1 {
		for s_1..split_1.count-1 {
			arr[arr_index] = split_1[s_1];
			s_1 += 1;
			arr_index += 1;
		}
	} else {
		for s_2..split_2.count-1 {
			arr[arr_index] = split_2[s_2];
			s_2 += 1;
			arr_index += 1;
		}
	}
}

/*Note : middle and end DO NOT include themselves as indices in the split arrays
  so we only go until middle-1 for split_1 and end-1 for split_2
*/
SplitArray :: (arr : [] int, start : int, middle : int, end : int) -> [] int, [] int {
	split_1 := NewArray(middle - start, int);
	for 0..middle-start-1 {
		split_1[it] = arr[it + start];
	}

	split_2 := NewArray(end - middle, int);
	for 0..end-middle-1 {
		split_2[it] = arr[it + middle];
	}
	return split_1, split_2;
}

/*Note value can be positive or negative
  eg value = 5-13, mod = 7 => modulo = 6
*/
WrappedMod :: inline (value : int, mod : int) -> int {
	modulo : int = value;
	if value >= mod {
		modulo = value % mod;
	} else if value < 0 {
		modulo = ((value % mod) + mod) % mod;
	}
	return modulo;
}

abs :: inline (x: $T) -> T {
    if x < 0 return -x;
    return x;
}

//TODO use asm for optimization
//https://stackoverflow.com/questions/8021772/assembly-language-how-to-do-modulo
PosMod :: inline (b : $T, m : T) -> T {
	if m == 0 return cast(T) abs(b);
	modulo : T = b;
	while modulo >= m {
		modulo -= m;
	}
	while modulo < 0 {
		modulo += m;
	}
	return modulo;
}

//TODO I think we can collapse FloatBothEqual and have just 1 PosMod float function
//TODO Should we make float == operator and float64 == operator
//since we usually want that to be the default... Then we would not need 
//these extra functions as well and in general for float.
PosMod :: inline (b : float, m : float) -> float {
	if m == 0 return abs(b);
	modulo : float = b;
	while modulo > m || FloatEqual(modulo, m) {
		modulo -= m;
	}
	while modulo < 0 {
		modulo += m;
	}
	return modulo;
}

PosMod :: inline (b : float64, m : float64) -> float64 {
	if m == 0 return abs(b);
	modulo : float64 = b;
	while modulo > m || Float64Equal(modulo, m) {
		modulo -= m;
	}
	while modulo < 0 {
		modulo += m;
	}
	return modulo;
}

PowerInt :: inline (n : int, p : int) -> int {
	result : int = n;
	for 1..p result *= n;
	return result;
}

//TODO should we move fourier to audio?
/*Fourier
*/
//Notes assume constant input for now, eg input = f(k) = 1
//Also M could be a constant power of 2 window size < some max M
DFT :: (input : [] float) -> [] MyComplex {
	N := input.count;
	/*Compute e^(-2 * PI * k/N) constants 
	 *as theta = 2 * PI * k / N
	 *consts[k] = cos(theta) - i * sin(theta)
	*/
	//TODO can cache these at compile-time or load_time
	consts := NewArray(N, MyComplex);
	for k : 0..N-1 {
		theta : float = 2 * PI * k / N;
		consts[k] = EulersFormula(theta, true);
	}

	transforms := NewArray(N, MyComplex);
	for k : 0..N-1 {
		for n : 0..N-1 {
			// print("n is % : ", n);
			// print("input[n] is % : ", input[n]);
			const_index : int = (k * n) % N;
			// print("exp is %", const_index);
			value : MyComplex = input[n] * consts[const_index];
			// value : MyComplex = input[n] * EulersFormula(-TAU*n*k/N);
			// print("input*exp is %\n", value);
			transforms[k] += value;
		}
		transforms[k] /= cast(float) N;
		// print("k is % with magnitude %\n", k, Magnitude(transforms[k]));
		// print("k is % with value %\n", k, transforms[k]);
	}
	return transforms;
}

InverseDFT :: (input : [] MyComplex) -> [] MyComplex {
	N := input.count;
	/*Compute e^(-2 * PI * k/N) constants 
	 *as theta = 2 * PI * k / N
	 *consts[k] = cos(theta) - i * sin(theta)
	*/
	//TODO can cache these at compile-time or load_time
	consts := NewArray(N, MyComplex);
	for k : 0..N-1 {
		theta : float = 2 * PI * k / N;
		consts[k] = EulersFormula(theta);
	}

	transforms := NewArray(N, MyComplex);
	for k : 0..N-1 {
		for n : 0..N-1 {
			const_index : int = (k * n) % N;
			value : MyComplex = input[n] * consts[const_index];
			transforms[k] += value;
		}
	}
	return transforms;
}

HAMMING_A :: 0.54;
//Hanning window by default
//TODO pass in allocator? complex signals and FFT?
HanWindow :: (signal : [] float, a : float = 0.5) -> [] float {
	N := cast(float) signal.count;
	windowed_signal := NewArray(signal.count, float);
	for s, n : signal {
		windowed_sample : float = (((1-a)*cos(TAU*(n/N) + PI))+a) * s;
		windowed_signal[n] = windowed_sample;
	}
	return windowed_signal;	
}

HanWindowMyComplex :: (signal : [] float, a : float = 0.5) -> [] MyComplex {
	N := cast(float) signal.count;
	windowed_signal := NewArray(signal.count, MyComplex, false,, temp);
	for s, n : signal {
		windowed_sample : float = (((1-a)*cos(TAU*(n/N) + PI))+a) * s;
		windowed_signal[n] = MakeMyComplex(windowed_sample, 0);
	}
	return windowed_signal;	
}

/* Fast Fourier Transform
	- This only works for input signals that have length that is a multiple of 2
	//TODO a version that takes in real values
	//TODO version that pads for arbitrary sized input signal
*/
FFT :: (input : [] MyComplex, normalize : bool = false) -> [] MyComplex {
	output := NewArray(input.count, MyComplex);
	for 0..input.count-1 {
		output[it] = input[it];
	}
	BreakDownFourier(output);
	N : int = 2;
	while N <= output.count {
		defer N <<= 1;
		i := 0;
		while i < output.count {
			defer i += N;
			for k : 0..(N/2)-1 {
				even_index : int = i + k;
				odd_index : int = i + k + (N/2);
				even : MyComplex = output[even_index];
				odd : MyComplex = output[odd_index];

				//TODO cache these at startup
				theta : float = TAU * k / N;
				e_const := EulersFormula(theta, true);
				odd_with_const : MyComplex = e_const * odd;

				output[even_index] = (even + odd_with_const);
				output[odd_index] = (even - odd_with_const);
			}
		}
	}
	if normalize {
		N_float := cast(float) input.count;
		for * output {
			<<it /= N_float;
		}
	}
	return output;
}

log2 :: inline (x: int) -> int {
    // @@ Use BSR/CTZ/CLZ intrinsic for this?
    assert(x != 0);
    r := 0;
    x = x >> 1  ;
    while x {
        r += 1;
        x = x >> 1;
    }
    return r;
}

BreakDownFourier :: inline (input : [] MyComplex) {
	bits := log2(input.count);
	for 1..input.count-1 {
		swap_pos := BitReverse(it, bits);
		if swap_pos <= it continue;
		temp := input[it];
		input[it] = input[swap_pos];
		input[swap_pos] = temp;
	}
}

InverseFFT :: (input : [] MyComplex, already_normalized : bool = false) -> [] MyComplex {
	//Take input conjugate
	input_conjugate := NewArray(input.count, MyComplex);
	defer free(input_conjugate.data);
	for 0..input.count-1 {
		input_conjugate[it] = Conjugate(input[it]);	
	}

	//Forward FFT
	output := FFT(input_conjugate);

	//Take output conjugate and divide by N
	const := 1.0 / cast(float) output.count;
	if already_normalized const = 1.0; //TODO is this correct?
	for 0..output.count-1 {
		output[it] = Conjugate(output[it]) * const;	
	}	
	return output;
}

BitReverse :: (n : int, bits : int) -> int {
	reversed_n : int = n;
	count : int = bits - 1;

	n >>= 1;
	while n > 0 {
		reversed_n = (reversed_n << 1) | (n & 1);
		count -= 1;
		n >>= 1;
	}
	return ((reversed_n << count) & ((1 << bits) - 1));
}

//TODO make this more generic to parse integer number by number
//Should this be in here or in my own Basics module?
IntToString :: (i : int, allocator : Allocator = temp) -> string {
	if i == 0 return "0";

	i_abs := abs(i);
	i_array : [..] int;
	i_array.allocator = temp;
	while i_abs > 0 {
		next_int : int = i_abs % 10;
		array_add(*i_array, next_int);
		i_abs /= 10;
	}

	s_builder : String_Builder;
	s_builder.allocator = temp;
	//TODO can compile-time remove this for positive integers
	if i < 0 append(*s_builder, "-");
	for < i_array {
		next_string : string = BaseDigitToString(it);
		append(*s_builder, next_string);
	}
	return builder_to_string(*s_builder,, allocator);
}

BaseDigitToString :: (i : int) -> string {
	if i == 0 return "0";
	if i == 1 return "1";
	if i == 2 return "2";
	if i == 3 return "3";
	if i == 4 return "4";
	if i == 5 return "5";
	if i == 6 return "6";
	if i == 7 return "7";
	if i == 8 return "8";
	if i == 9 return "9";
	return "";
}

/*TODO we could store some the lower values of m and n
in a table for fast GCD lookup. something like
from 0-255 and have it be u8 passing in

a faster algorithm implementation would be
https://stackoverflow.com/questions/63604914/how-can-i-speed-up-the-binary-gcd-algorithm-using-builtin-ctz
https://stackoverflow.com/questions/9353973/implementation-of-builtin-clz
*/
GCDEuclidMod :: inline (i1 : int, i2 : int) -> int {
	if i1 == 0 || i2 == 0 return 1;

	m : int = i1;
	n : int = i2;

	r : int = m % n;
	while r != 0 {
		m = n;
		n = r;
		r = m % n;
	}
	return n;
}

GCDEuclidSubtract :: inline (m : int, n : int) -> int {
	if m == 0 || n == 0 return 1;

	a : int = m;
	b : int = n;

	while a != b {
		if a > b {
			a = a - b;
		} else {
			b = b - a;
		}
	}
	return a;
}

//TODO permutation on generators for prime numbers
//TODO should we separate out group theory in computational algebra file?
FindGenerators :: inline (n : int, allocator : Allocator = temp) 
-> [] int 
{
	generators : [..] int;
	generators.allocator = allocator;
	for 1..n-1 {
		gcd : int = GCDEuclidSubtract(it, n);
		if gcd == 1 array_add(*generators, it);
	}
	return generators;
}

HeapsAlgorithm :: inline (A : [] $T) -> [][] T {
    // c is an encoding of the stack state. c[k] encodes the for-loop counter for when generate(k - 1, A) is called
    all_perms : [][] T = NewArray(factorial(A.count), [] T);
    all_perms_index : int = 0;

    A_copy := array_copy(A);
    c : [] int = NewArray(A_copy.count, int);

    all_perms[all_perms_index] = array_copy(A_copy);
    all_perms_index += 1;
    // print("%\n", A_copy);
    
    // i acts similarly to a stack pointer
    i := 1;
    while i < A_copy.count {
        if c[i] < i {
            if IsEven(i) {
                swap(*A_copy[0], *A_copy[i]);
            }
            else {
                swap(*A_copy[c[i]], *A_copy[i]);
            }

            all_perms[all_perms_index] = array_copy(A_copy);
    		all_perms_index += 1;
            // print("%\n", A_copy);

            // Swap has occurred ending the for-loop. Simulate the increment of the for-loop counter
            c[i] += 1;
            // Simulate recursive call reaching the base case by bringing the pointer to the base case analog in the array
            i = 1;
        }
        else {
            // Calling generate(i+1, A) has ended as the for-loop terminated. Reset the state and simulate popping the stack by incrementing the pointer.
            c[i] = 0;
            i += 1;
        }
    }
    return all_perms;
}

//TODO Could implement this with a for_expansion
//TODO A version where we pass in function to write to
HeapsAlgorithmPermIndex :: inline (A : [] $T, return_perm_index : int) -> [] T {
	//TODO do we really need this assertion?
	assert(return_perm_index < factorial(A.count));

    if return_perm_index == 0 return A;
    // print("%\n", A_copy);

    // c is an encoding of the stack state. c[k] encodes the for-loop counter for when generate(k - 1, A) is called
    all_perms_index : int = 0;
    A_copy := array_copy(A);
    c : [] int = NewArray(A_copy.count, int);
    
    // i acts similarly to a stack pointer
    i := 1;
    while i < A_copy.count {
        if c[i] < i {
            if IsEven(i) {
                swap(*A_copy[0], *A_copy[i]);
            }
            else {
                swap(*A_copy[c[i]], *A_copy[i]);
            }

            all_perms_index += 1;
    		if all_perms_index == return_perm_index {
    			//TODO Could place a for_expansion here to return each permutation
    			return A_copy;
    		}
            // print("%\n", A_copy);

            // Swap has occurred ending the for-loop. Simulate the increment of the for-loop counter
            c[i] += 1;
            // Simulate recursive call reaching the base case by bringing the pointer to the base case analog in the array
            i = 1;
        }
        else {
            // Calling generate(i+1, A) has ended as the for-loop terminated. Reset the state and simulate popping the stack by incrementing the pointer.
            c[i] = 0;
            i += 1;
        }
    }
    return A_copy;
}

/*Generalized permutation loops that permutes between a range [start_value..end_value]
for loop_count number of loops.
loop_count defines # of for loops as in if loop_count == 3 is the same as
for x1 : start_value..end_value for x2 : start_value..end_value for x3 : start_value..end_value
*/
PermutationLoops :: struct {
	loop_count : int;
	start_value : int;
	end_value : int;
	//TODO Could have an array of size loop_count for each array
	//if we want different values for each loop
	// start_values : [] int;
	// end_values : [] int;
}

//TODO Should do a reverse and forward version as well. Currently this is reverse i think
//since we start from pl.loop_count and then move backwards.
for_expansion :: (pl : *PermutationLoops, body : Code, flags : For_Flags) #expand {
	o_index : int = pl.loop_count-1;
	loop_values : [] int = NewArray(pl.loop_count, int,, temp);
	for 0..pl.loop_count-1 loop_values[it] = pl.start_value;
	i : int = 0;
	while loop_values[0] <= pl.end_value {
		`it := loop_values;
		`it_index := i;

		#insert body;
		
		o_index = loop_values.count-1;
		loop_values[o_index] += 1;
		while o_index > 0 && loop_values[o_index] > pl.end_value {
			loop_values[o_index] = pl.start_value;
			o_index -= 1;
			loop_values[o_index] += 1;
		}
		i += 1;
	}
}

/*Prime number close to U32_MAX
  Random/module uses 64-bit could do that too 

  b = 0 is MCG (multiplicative congruential generator)
  b > 0 is LCG (linear congruential generator)
*/
LCRandomData :: struct {
	a : u32 = 16807;
	b : u32 = 0;
	// rand_max : u32 = 17;
	rand_max : u32 = 2_147_483_647;
	// rand_max : u32 = 4_294_967_117;
	seed : u32 = 177177;
}


LCRandom :: inline (using lc : *LCRandomData) -> u32
{
	seed = (a * seed + b) % rand_max;
	return seed;
	//Can use this if we have signed integer
	// r : u32 = seed;
	// if r < 0 r = -r;
	// return r;
}

//TODO Remove this if we use jai version
#add_context lc_rand := LCRandomData.{};
Random :: inline (l : $T, u : T) -> T {
	return Random(l,u,*context.lc_rand);
}

Random :: inline (l : $T, u : T, lc : *LCRandomData) -> T {
	//Add 1.0 so we have equal distribution for each value
	//and then we truncate instead of rounding otherwise
	//l and u will only have half of the chance of being hit
	//relative to each other value.
	rand_float : float = Random(cast(float)l,u+1.0,lc);
	rand_int : T = cast(T) rand_float;
	return rand_int;
}

Random :: inline (l : float, u : float, lc : *LCRandomData) -> float
{
	rand_int : int = LCRandom(lc);
	rand_float : float = cast(float) rand_int;
	rand_float = rand_float / lc.rand_max;
	rand_float = rand_float * (u - l) + l;
	return rand_float;
}

//TODO Could use jai random here but they seem to have similar distributions
// #import "Random";
Brownian :: inline (x : float, range : float, bound : float) -> float {
	b : float = x + Random(-range,range);
	#if 1 {
	while b > bound || b < -bound {
		b = x + Random(-range,range);
	}
	} else {
	//Another way to do bounds
	if b > bound b = bound;
	else if b < -bound b = -bound;
	}
	return b;
}


