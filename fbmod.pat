#include <std/io.pat>
#include <std/core.pat>

enum ResourceType : u8 {
    Invalid = -1,
    Embedded = 0,
    Ebx = 1,
    Res = 2,
    Chunk = 3,
    Bundle = 4,
    FsFile = 5
};

struct ModDetails {
    char title[];
    char author[];
    char category[];
    char version[];
    char description[];
    if (parent.file_structure_version >= 5)
        char modLink[];
};
    
struct BaseModResource {
    s32 index;
    
    u32 file_structure_version = parent.parent.parent.parent.file_structure_version;
    
    if ((file_structure_version <= 3 && index != -1) || file_structure_version > 3)
        char name[];

    if (index != -1) {
        u8 sha[20];
        s64 size;
        u8 flags;
        s32 handler_hash;
            
        if (file_structure_version >= 3) {
            char userData[];
        }
    }

    if (file_structure_version <= 3 && index != -1) {
        s32 skip_count;            
        if (skip_count > 0)
            s32 skip_bundles[skip_count];
        
        s32 bundle_count;            
        if (bundle_count > 0)
            s32 bundles[bundle_count];
    } else if (file_structure_version > 3) {
        s32 bundle_count;
        if (bundle_count > 0)
            s32 bundles[bundle_count];
    }
};
    
struct InvalidResource : BaseModResource {};    
struct EmbeddedResource : BaseModResource {};    
struct EbxResource : BaseModResource {};    
struct ResResource : BaseModResource {};    
struct ChunkResource : BaseModResource {};    
struct BundleResource : BaseModResource {};    
struct FsFileResource : BaseModResource {};
    
struct ModResource {
    ResourceType type;
        
    match (type) {
        (ResourceType::Embedded): EmbeddedResource resource;
        (ResourceType::Ebx): EbxResource resource;
        (ResourceType::Res): ResResource resource;
        (ResourceType::Chunk): ChunkResource resource;
        (ResourceType::Bundle): BundleResource resource;
        (ResourceType::FsFile): FsFileResource resource;
        (_): InvalidResource resource;
    }
};
    
struct ModResources {
    u32 count;
    ModResource resources[count];
};
    
struct ModDefinition {
    char magic[8];
    u32 file_structure_version;
    s64 data_offset;
    s32 data_count;
    u8 profile_string_length;
    char profile_string[profile_string_length];
    u32 game_version;        
    ModDetails details;        
    ModResources resources;
};
    
struct ResourceDataPosition {
    u64 offset;
    u64 size;
};
    
struct NonCompressedResourceData<auto size> {
    u8 data[size];
};
    
struct CompressedResourceData<auto size> {
    be u32 uncompressed_size;
    char compression_type[2];
    be u16 compressed_size;
    u8 data[size - sizeof(this)];
};
    
struct ResourceData {
    str name = parent.metadata.resources.resources[std::core::array_index()].resource.name;
    s32 resourceDataIndex = parent.metadata.resources.resources[std::core::array_index()].resource.index;
    
    if (resourceDataIndex == -1) {
        std::print("[MISSING] {}, skipping", name);
    } else {
        u32 resourceDataSize = parent.data_positions[resourceDataIndex].size;
        bool isCompressed = $[$ + sizeof(u32)] == 0x0F && $[$ + sizeof(u32) + 1] == 0x70;
        u32 start = $;
            
        if (isCompressed) {
            CompressedResourceData<resourceDataSize> resource_data;
        } else {
            NonCompressedResourceData<resourceDataSize> resource_data;
        }
            
        std::print((isCompressed ? "[COMPRESSED]" : "[RAW]") + " {} @ {:X}:{:X}", name, start, start + sizeof(resource_data) - 1);
    }
};
    
struct Mod {
    ModDefinition metadata;
    ResourceDataPosition data_positions[metadata.data_count];        
    ResourceData resource_data[metadata.resources.count];
};

Mod mod @ 0x00;
