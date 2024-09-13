#define BOOT_SIGNATURE  0xAA55

#pragma pack(1)

struct boot_sector
{
    uint8_t jmp[3]; // jump
    uint8_t oem[8]; // oem name
    uint8_t bpb[19]; // bpb
    uint8_t drivenumber;
    uint8_t bootcode[479];
    uint16_t signature;
};

struct bios_parameter_block
{
    uint16_t    bytes_per_sector;
    uint8_t     sector_per_cluster;
    uint16_t    reserved_sectors;
    uint8_t     number_of_fats;
    uint16_t    entries_in_root;
    uint16_t    total_sects;
    uint8_t     media;
    uint16_t    sectors_per_fat;
    uint16_t    sectors_per_track;
    uint16_t    heads;
    uint32_t    hidden_sectors;
    uint32_t    total_sectors;
    uint16_t    reserved;
    uint8_t     bpb_signature_byte;
    uint32_t    volume_serial_number;
    uint8_t     label[11];
    uint8_t     file_system_id[8];
};

#pragma pack()