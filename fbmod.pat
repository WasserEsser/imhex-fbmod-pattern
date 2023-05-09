#include <std/io.pat>
#include <std/core.pat>
#include <std/string.pat>

fn format_sha(auto sha) {
    return std::format(
        "{:02X}{:02X}{:02X}{:02X}{:02X}{:02X}{:02X}{:02X}{:02X}{:02X}{:02X}{:02X}{:02X}{:02X}{:02X}{:02X}{:02X}{:02X}{:02X}{:02X}", 
        sha[0], sha[1], sha[2], sha[3], sha[4], sha[5], sha[6], sha[7], sha[8], sha[9], 
        sha[10], sha[11], sha[12], sha[13], sha[14], sha[15], sha[16], sha[17], sha[18], sha[19]
    );
};

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
    char mod_title[] [[format("std::string::to_string")]];
    char mod_author[] [[format("std::string::to_string")]];
    char mod_category[] [[format("std::string::to_string")]];
    char mod_version[] [[format("std::string::to_string")]];
    char mod_description[] [[format("std::string::to_string")]];
    if (parent.file_structure_version >= 5)
        char mod_link[] [[format("std::string::to_string")]];
}[[inline]];
    
struct BaseModResource {
    s32 index;
    
    u32 file_structure_version = parent.parent.parent.metadata.file_structure_version;
    
    if ((file_structure_version <= 3 && index != -1) || file_structure_version > 3)
        char name[];

    if (index != -1) {
        u8 sha[20] [[format("format_sha")]];;
        s64 size;
        u8 flags;
        s32 handler_hash;
            
        if (file_structure_version >= 3) {
            char user_data[];
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
    
struct InvalidResource : BaseModResource {}[[inline]];    
struct EmbeddedResource : BaseModResource {}[[inline]];    
struct EbxResource : BaseModResource {}[[inline]];    
struct ResResource : BaseModResource {}[[inline]];    
struct ChunkResource : BaseModResource {}[[inline]];    
struct BundleResource : BaseModResource {}[[inline]];    
struct FsFileResource : BaseModResource {}[[inline]];
    
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
}[[name(std::format("[{}]: {}", resource.index, resource.name))]];
       
struct ModDefinition {
    char magic[8] [[format("std::string::to_string")]];
    u32 file_structure_version;
    s64 resource_data_offset;
    s32 resource_data_count;
    u8 game_string_length;
    char game_string[game_string_length] [[format("std::string::to_string")]];
    u32 game_version;        
    ModDetails details;
    u32 resource_index_count;
};
    
struct ResourceDataPosition {
    u64 offset;
    u64 size;
}[[name(std::format("[{}]: {}", std::core::array_index(), parent.resource_index[std::core::array_index()].resource.name))]];
    
struct NonCompressedResourceData<auto size> {
    u8 data[size];
}[[color("500000")]];
    
struct CompressedResourceData<auto size> {
    be u32 uncompressed_size;
    char compression_type[2];
    be u16 compressed_size;
    u8 data[size - sizeof(this)];
}[[color("80FFAA"), name(std::format("[{}]: {}", parent.resourceDataIndex, parent.name))]];
    
struct ResourceData {
    u32 arrayIndex = std::core::array_index();
    str name = parent.resource_index[arrayIndex].resource.name;
    s32 resourceDataIndex = parent.resource_index[arrayIndex].resource.index;
    
    if (resourceDataIndex == -1) {
        std::print("[MISSING] {}, skipping", name);
    } else {
        u32 resourceDataSize = parent.resource_data_positions[resourceDataIndex].size;
        bool isCompressed = $[$ + sizeof(u32)] == 0x0F && $[$ + sizeof(u32) + 1] == 0x70;
        u32 start = $;
            
        if (isCompressed) {
            CompressedResourceData<resourceDataSize> resource_data;
        } else {
            NonCompressedResourceData<resourceDataSize> resource_data;
        }
            
        std::print((isCompressed ? "[COMPRESSED]" : "[RAW]") + " {} @ {:X}:{:X}", name, start, start + sizeof(resource_data) - 1);
    }
}[[inline]];
    
struct Mod {
    ModDefinition metadata;            
    ModResource resource_index[metadata.resource_index_count];
    ResourceDataPosition resource_data_positions[metadata.resource_data_count];        
    ResourceData resource_data[metadata.resource_index_count];
};

Mod mod @ 0x00;
