#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>

#include "boot.h"

int main(int argc, char *argv[])
{
    if (argc == 1) {
        printf("bximage outputfile size\n");
        return 1;
    }

    int size = atoi(argv[2]);
    if (size < 1 || size > 1440) {
        printf("size must be in kb");
        return 1;
    }

    FILE *fp = fopen(argv[1], "wb");

    if (fp == NULL) {
        printf("cannot open %s\n", argv[1]);
    }

    
}
