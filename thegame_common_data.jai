//TODO Gradually move any data that is used everywhere (include externally) here

#import "Basic";

//TODO should this be in a more general place or do we use jai allocators now
//homemade SimpleAllocator or FlatPool
MemoryData :: struct {
    base : *u8;
    size : s64;
    used : s64; //Using s64 since that is the return type of size_of function
}

PushSize :: inline (data : *MemoryData, size : s64) -> *void {
	assert(data.used + size < data.size);
    result : *void = data.base + data.used;
    data.used += size;
    return result;
}

PushStruct :: inline (data : *MemoryData, $type : Type) -> *type {
	result := cast(*type) PushSize(data, size_of(type));
	return result;
}

PushArray :: inline (data : *MemoryData, $type : Type, count : s64) -> *type {
    result := cast(*type) PushSize(data, size_of(type) * count);
    return result;
}