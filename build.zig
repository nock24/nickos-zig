const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.resolveTargetQuery(.{
        .os_tag = .freestanding,
        .cpu_arch = .aarch64,
    });
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "kernel.elf",
        .root_source_file = b.path("src/kernel.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe.linker_script = b.path("linker.ld");
    exe.addAssemblyFile(b.path("src/asm/boot.S"));
    exe.addAssemblyFile(b.path("src/asm/utils.S"));
    b.installArtifact(exe);

    const run_objcopy = b.addSystemCommand(&.{
        "aarch64-linux-gnu-objcopy", "./zig-out/bin/kernel.elf",
        "-O",                        "binary",
        "./build/kernel.img",
    });
    run_objcopy.step.dependOn(&exe.step);
    b.default_step.dependOn(&run_objcopy.step);

    const qemu = b.step("qemu", "Run the OS in qemu");
    const run_qemu = b.addSystemCommand(&.{
        "qemu-system-aarch64",
        "-m",
        "1G",
        "-M",
        "raspi3b",
        "-drive",
        "file=./disk.img,format=raw,media=disk",
        "-kernel",
        "./build/kernel.img",
        "-serial",
        "null",
        "-serial",
        "stdio",
    });
    qemu.dependOn(&run_qemu.step);
    run_qemu.step.dependOn(b.getInstallStep());
}
