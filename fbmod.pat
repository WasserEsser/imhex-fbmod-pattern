#include <std/io.pat>
#include <std/core.pat>
#include <std/string.pat>

// BEGIN - ZSTD.hexpat
#pragma MIME application/zstd

#include <std/core.pat>
#include <std/io.pat>
#include <std/mem.pat>
#include <std/sys.pat>

using BitfieldOrder = std::core::BitfieldOrder;

#define ZSTD_MAGIC_NUMBER 0xFD2FB528

bitfield frame_header_descriptor_t {
    frame_content_size_flag : 2;
    single_segment_flag : 1;
    unused_bit : 1;
    reserved_bit : 1;
    content_checksum_flag : 1;
    dictionary_id_flag : 2;
} [[bitfield_order(BitfieldOrder::MostToLeastSignificant, 8)]];

bitfield window_descriptor_t {
    exponent : 5;
    mantissa : 3;
} [[bitfield_order(BitfieldOrder::MostToLeastSignificant, 8)]];

fn window_size(window_descriptor_t window_descriptor) {
    u64 window_log = 10 + window_descriptor.exponent;
    u64 window_base = 1 << window_log;
    u64 window_add = (window_base / 8) * window_descriptor.mantissa;
    u64 window_size = window_base + window_add;
    return window_size;
};

struct frame_header_t {
    frame_header_descriptor_t frame_header_descriptor;

    if (!frame_header_descriptor.single_segment_flag){
        window_descriptor_t window_descriptor;
    }

    if (frame_header_descriptor.dictionary_id_flag == 1) {
        le u8 dictionary_id;
    }
    else if (frame_header_descriptor.dictionary_id_flag == 2) {
        le u16 dictionary_id;
    }
    else if (frame_header_descriptor.dictionary_id_flag == 3) {
        le u32 dictionary_id;
    }

    if (frame_header_descriptor.frame_content_size_flag == 0) { // 0
        if (frame_header_descriptor.single_segment_flag) {
            le u8 content_size;
        }
    }
    else if (frame_header_descriptor.frame_content_size_flag == 1) {
        le u16 content_size;
    }
    else if (frame_header_descriptor.frame_content_size_flag == 2) {
        le u32 content_size;
    }
    else {
        le u64 content_size;
    }
};

bitfield block_header_t {
    last_block : 1;
    block_type : 2;
    block_size : 21;
};

enum block_type : u8 {
    raw_block = 0,
    rle_block = 1,
    compressed_block = 2,
    reserved = 3
};

struct data_block_t {
    block_header_t block_header;

    if (block_header.last_block) {
        last_block_flag = true;
    }

    if (block_header.block_type == block_type::raw_block) {
        le u8 block_content[block_header.block_size];
    }
    else if (block_header.block_type == block_type::rle_block) {
        le u8 block_content[1];
    }
    else if (block_header.block_type == block_type::compressed_block) {
        le u8 block_content[block_header.block_size];
    }
    else {
        std::error("The data block seems to be corrupted!");
    }
};

struct content_checksum_t {
    le u32 xxh64_hash;
};

struct zstd_frame_t {
    le u32 magic_number;
    std::assert(magic_number == ZSTD_MAGIC_NUMBER, "Invalid magic number!");
    frame_header_t frame_header;
    data_block_t data_block[while(!last_block_flag)];
    if (frame_header.frame_header_descriptor.content_checksum_flag) {
        content_checksum_t content_checksum;
    }
};

bool last_block_flag = false;
// END - ZSTD.hexpat

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
}[[static, name(std::format("[{}]: {}", std::core::array_index(), parent.resource_index[std::core::array_index()].resource.name))]];
    
struct NonCompressedResourceData<auto size> {
    u8 data[size];
}[[color("500000")]];
    
struct CompressedResourceData<auto size> {
    be u32 uncompressed_size;
    char compression_type[2];
    be u16 compressed_size;
    
    last_block_flag = false;
    zstd_frame_t zstd_frame;
    
    if ((size - sizeof(this)) > 0) {
        CompressedResourceData<size - sizeof(this)> additional_resource;
    }
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
