const std = @import("std");

pub fn build(b: *std.Build) void {
    const rpi_target = b.resolveTargetQuery(.{
        .os_tag = .freestanding,
        .cpu_arch = .aarch64,
    });
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "kernel.elf",
        .root_source_file = b.path("src/kernel.zig"),
        .target = rpi_target,
        .optimize = optimize,
    });
    exe.linker_script = b.path("linker.ld");
    exe.addAssemblyFile(b.path("src/boot.S"));
    exe.addAssemblyFile(b.path("src/utils.S"));
    b.installArtifact(exe);

    const run_objcopy = b.addSystemCommand(&.{
        "aarch64-linux-gnu-objcopy", "./zig-out/bin/kernel.elf",
        "-O",                        "binary",
        "./build/kernel.img",
    });
    run_objcopy.step.dependOn(&exe.step);
    b.default_step.dependOn(&run_objcopy.step);

    const unit_tests = b.addTest(.{
        .root_source_file = b.path("src/test.zig"),
        .target = target,
        .optimize = optimize,
    });
    const run_unit_tests = b.addRunArtifact(unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);

    const qemu = b.step("qemu", "Run the OS in qemu");
    const run_qemu = b.addSystemCommand(&.{
        "qemu-system-aarch64",
        "-M",
        "raspi3b",
        "-kernel",
        "./build/kernel.img",
        "-serial",
        "null",
        "-serial",
        "stdio",
    });
    qemu.dependOn(&run_qemu.step);
    run_qemu.step.dependOn(&exe.step);
}
