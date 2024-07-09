const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.resolveTargetQuery(.{
        .os_tag = .freestanding,
        .cpu_arch = .aarch64,
    });

    const optimize = b.standardOptimizeOption(.{});
    const exe = b.addExecutable(.{
        .name = "kernel8.elf",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe.linker_script = b.path("linker.ld");

    exe.addAssemblyFile(b.path("src/boot.S"));
    exe.addAssemblyFile(b.path("src/utils.S"));

    b.installArtifact(exe);
}
