#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <ctype.h>

#include "argp.h"
#include "boot.h"
#include "fat.h"

const char* getoptvalue(struct argp_option* args, const char* key)
{
	for (; args->name != NULL; args++)
	{
		if (strcmp(key, args->name) == 0)
			return args->value;
	}
	return NULL;
}

struct argp_option* find_args(struct argp_option* args, const char* cmd)
{
	for (; args->name != NULL; args++)
	{
		if (cmd[0] == '-' && cmd[1] == '-')
			if (strcmp(args->name, &cmd[2]) == 0)
				return args;
		
		if (cmd[0] == '-' && cmd[1] != '-')
			if (strcmp(args->arg, &cmd[1]) == 0)
				return args;
	}

	return NULL;
}

static int parse_args(int argc, char** argv, struct argp_option* options)
{
	for (int i = 1; i < argc; i++) {
		struct argp_option* opt = find_args(options, argv[i]);

		if (opt == NULL) {
			printf("Invalid argument %s\n", argv[i]);
			return -1;
		}

		if (opt->flags & OPTION_ARG_SWITCH) {
			opt->value = (char*)1;	// switch enabled
		}
		else {
			if (i + 1 == argc) {
				printf("missing value for %s\n", argv[i]);
				return -1;
			}
			else {
				opt->value = argv[i+1];
				i++;	// consumed argument
			}
		}
	}

	for (struct argp_option* check = options; check->name != NULL; check++)
		if ((check->flags & OPTION_ARG_OPTIONAL) == 0 && check->value == NULL) {
			printf("Argument %s not provided.\n", check->name);
			return -1;
		}
	return 0;
}

struct argp_option options[] =
{
    { "image", 0, NULL, 0, "image disk", 0},
    { "extract", 0, NULL, OPTION_ARG_OPTIONAL, "extract the file from the image", 0 },
    { "add", 0, NULL, OPTION_ARG_OPTIONAL, "add the file into the image", 0 },
    { "input", 0, NULL, OPTION_ARG_OPTIONAL, "input file", 0 },
    { "output", 0, NULL, OPTION_ARG_OPTIONAL, "output file", 0 },
	{ "dump", 0, NULL,  OPTION_ARG_SWITCH | OPTION_ARG_OPTIONAL, "dump fat info", 0 },
	{ NULL }
};

void *load_image(const char *filename, size_t *size)
{
	*size = 0;
    FILE *fp = fopen(filename, "rb");

	if (fp == NULL)
    {
        printf("Cannot open %s as flat disk\n", filename);
        return NULL;
    }

    fseek(fp, 0, SEEK_END);
	size_t image_size = ftell(fp);
    if (image_size == 0 || (image_size % 512) != 0)
    {
        printf("image size not aligned to sector size. Value %zu\n", image_size);
        fclose(fp);
        return NULL;
    }

    void *image_buffer = malloc(image_size);
    if (image_buffer == NULL)
    {
        printf("Error. Cannot allocate %zu\n", image_size);
        fclose(fp);
        return NULL;
    }
    fseek(fp, 0, SEEK_SET);
    fread(image_buffer, 1, image_size, fp);
    fclose(fp);

	*size = image_size;
	return image_buffer;
}

int save_image(const char *filename, void *buffer, size_t size)
{
    FILE *fp = fopen(filename, "wb");

	if (fp == NULL)
    {
        printf("Cannot open %s as flat disk\n", filename);
        return -1;
    }

    fwrite(buffer, 1, size, fp);
    fclose(fp);

	return 0;
}

int fat_type(struct bios_parameter_block *bpb)
{
	const char *fs = bpb->file_system_id;
	
	if (fs[0] == 'F' && fs[1] == 'A' && fs[2] == 'T' && fs[3] == '1')
	{
		if (fs[4] == '2')
			return 12;
		else if (fs[5] == '6')
			return 16;
	}
	return 0;
}

uint16_t get_cluster_no(uint8_t *fat, int fat_type, uint16_t cluster)
{
	uint16_t no = 0;
	uint8_t b0, b1;
	uint16_t idx;

	switch(fat_type) {
		case 12:
			idx = (cluster / 2) * 3;
			if ((cluster % 2) != 0) {
				b0 = fat[idx+1]; b1 = fat[idx+2];
				no = (b1 << 8) | b0;
				no = no >> 4;
			}
			else {
				b0 = fat[idx]; b1 = fat[idx+1];
				no = (b1 & 0x0f) << 8 | b0;
			}
			break;
		case 16:
			no = fat[cluster * 2] | fat[(cluster * 2) + 1] << 8;
			break;
	}

	return no;
}

/** this function parse all entries in fat and dump information about it */
void parse_fat(void *image, size_t size, struct bios_parameter_block *bpb, int fat_type)
{
	uint8_t *fat = (uint8_t *)image + (bpb->bytes_per_sector * bpb->reserved_sectors);

	uint16_t clusterNo = (
		bpb->total_sects - bpb->reserved_sectors - 
		(bpb->number_of_fats * bpb->sectors_per_fat)
	) / bpb->sector_per_cluster;

	for(uint16_t i = 0; i < clusterNo; i++)
	{
		uint16_t next = get_cluster_no(fat, fat_type, i);
		printf("next cluster %d\n", next);
	}
}

static void truncate(char *src)
{
	while(*src != 0 && *src != 0x20)
	{
		*src = tolower(*src);
		src++;
	}
	*src = 0;

}
void parse_root(void *image, size_t size, struct bios_parameter_block *bpb, int fat_type)
{
	uint8_t *fat = (uint8_t *)image + (bpb->bytes_per_sector * bpb->reserved_sectors);

	size_t root_cluster = 0;
	int clusterNo = 0;
	
	do
	{
		uint16_t next = get_cluster_no(fat, fat_type, clusterNo++);
		if (next == 0x0fff && fat_type == 12)
			break;
		if (next == 0xffff && fat_type == 16)
			break;
	} while (1);
	
	printf("Root Directory: (allocated clusters %d)\n", clusterNo);

	struct fat_entry *dir = (struct fat_entry *)
		((uint8_t *)image + (bpb->bytes_per_sector * bpb->reserved_sectors) + 
		(bpb->number_of_fats * bpb->sectors_per_fat) * bpb->bytes_per_sector);
	
	while(dir->filename[0] != 0)
	{
		char name[9]; char ext[4];
		memset(name, 0, sizeof(name));
		memset(ext, 0, sizeof(ext));
		
		memcpy(ext, dir->extension, 3);
		memcpy(name, dir->filename, 8);
		truncate(name); truncate(ext);

		printf("%s.%s | %d\n", name, ext, dir->size);

		dir++;
	}
}
/** dump BPB */
void dump(struct bios_parameter_block *bpb)
{
	char fs[9];
	memset(fs, 0, sizeof(fs));
	memcpy(fs, bpb->file_system_id, 8);

	printf("Bytes per sector: %d\n", bpb->bytes_per_sector);
	printf("Sectors per cluster: %d\n", bpb->sector_per_cluster);
	printf("Number of FATs: %d\n", bpb->number_of_fats);
	printf("Entries in root: %d\n", bpb->entries_in_root);
    printf("Total sectors: %d\n", bpb->total_sectors);
	printf("Type of media: %s\n", bpb->media == 0x80 ? "disk" : "floppy");
	printf("Sectors per FAT: %d\n", bpb->sectors_per_fat);
    printf("Sectors per track: %d\n", bpb->sectors_per_track);
    printf("heads: %d\n", bpb->heads);
    if (fs[0] == 'F' && fs[1] == 'A' && fs[2] == 'T' && fs[3] == '1')
	{
		if (fs[4] == '2')
			printf("FAT12 FOUND!");
		else if (fs[5] == '4')
			printf("FAT16 FOUND");
		else
			printf("unknown FAT format");
	}
	else
	printf("File System: %s", fs);

}
int main(int argc, char *argv[])
{
    printf("bxwriter\n");

    if (parse_args(argc, argv, options) != 0)
    {
        return -1;
    }

    const char *flat = getoptvalue(options, "image");

    int extract = getoptvalue(options, "extract") != NULL ? 1 : 0;
    int add = getoptvalue(options, "add") != NULL ? 1 : 0;
    const char *input = getoptvalue(options, "input");
    const char *output = getoptvalue(options, "output");
    
	size_t image_size = 0;
	void *image = load_image(flat, &image_size);

	if (image == NULL)
	{
		return -1;
	}


	struct boot_sector *bs = (struct boot_sector *)image;
	struct bios_parameter_block *bpb = (struct bios_parameter_block *)(&bs->bpb);
	int fat = 0;

	do
	{
		if (bpb->bpb_signature_byte != 0x29)
		{
			printf("BPB signature byte not valid.\n");
			break;
		}

		fat = fat_type(bpb);
		if (fat == 0)
		{
			printf("FAT not supported\n");
			break;
		}

		if (getoptvalue(options, "dump") != NULL)
		{
			dump(bpb);
			parse_fat(image, image_size, bpb, fat);
			parse_root(image, image_size, bpb, fat);
		}

		if (extract)
		{

		}
		if (add)
		{
			save_image(flat, image, image_size);
		}

	} while (0);

	return 0;
}