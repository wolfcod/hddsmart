#ifndef __FAT_H
#define __FAT_H

#pragma pack(1)
struct fat_datetime
{
    uint16_t time;
    uint16_t date;
};

struct fat_entry
{
    uint8_t filename[8];
    uint8_t extension[3];
    uint8_t attributes;
    uint16_t reserved;
    struct fat_datetime creation;
    struct fat_datetime last_access;
    struct fat_datetime last_write;
    uint16_t cluster;
    uint32_t size;
};

#pragma pack()
#endif
