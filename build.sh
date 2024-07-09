#!/bin/bash

rm -rf build
mkdir build

printf "Building kernel...\n"
zig build

printf "Converting elf to img...\n"
aarch64-linux-gnu-objcopy -O binary ./zig-out/bin/kernel8.elf ./build/kernel8.img

printf "Build complete\n\n"
