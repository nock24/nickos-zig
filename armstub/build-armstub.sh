#!/bin/bash

rm -rf armstub/build
mkdir armstub/build

printf "Assembling armstub...\n"
aarch64-linux-gnu-gcc -MMD -c armstub/src/armstub.S -o armstub/build/armstub_s.o

printf "Linking armstub...\n"
aarch64-linux-gnu-ld --section-start=.text=0 -o armstub/build/armstub.elf armstub/build/armstub_s.o

printf "Converting elf to bin...\n"
aarch64-linux-gnu-objcopy armstub/build/armstub.elf -O binary armstub/build/armstub-custom.bin

printf "Build complete.\n\n"
