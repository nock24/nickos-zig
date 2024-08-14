const std = @import("std");
const mem = std.mem;
const drivers = @import("drivers");
const serial = drivers.serial;
const kernel = @import("kernel");
const Buffer = kernel.Buffer;

const Command = union(enum) {
    os_info,
    echo: []const u8,
};

const MAX_ARG_CNT: usize = 1;

const ArgParseError = error{
    TooLargeArgCnt,
    InsufficientArgs,
    TooManyArgs,
};

fn parseCmdArgs(str: []const u8, arg_buf: [][]const u8) ArgParseError!void {
    var arg_idx: usize = 0;
    var arg_start: usize = 0;

    for (str, 0..) |char, i| {
        if (char == ' ' or i == str.len - 1) { // end of argument
            if (arg_idx >= arg_buf.len) return ArgParseError.TooManyArgs;
            if (arg_idx < arg_buf.len - 1) return ArgParseError.InsufficientArgs;

            arg_buf[arg_idx] = str[arg_start..i];
            arg_idx += 1;
            arg_start = i + 1;
            continue;
        }
    }
}

const MAX_CMD_NAME_LEN: usize = 7;

const CmdParseError = error{
    IncorrectArgs,
    InvalidCmd,
};

fn parseCmd(str: []const u8) CmdParseError!Command {
    var cmd_name_buf = Buffer(MAX_CMD_NAME_LEN).zeroes();
    var cmd_name_len: usize = undefined;
    var no_args: bool = undefined;
    for (str, 0..) |char, i| {
        if (char == ' ') {
            no_args = false;
            cmd_name_len = i;
            break;
        }
        if (i == str.len - 1) { // end of command
            no_args = true;
            cmd_name_len = i;
            break;
        }

        if (i >= MAX_CMD_NAME_LEN) return CmdParseError.InvalidCmd;
        cmd_name_buf.bytes[i] = char;
    }

    const cmd_name = cmd_name_buf.bytes[0..cmd_name_len];
    const args_str = if (no_args)
        ""
    else
        str[cmd_name_len + 1 ..];

    return if (mem.eql(u8, cmd_name, "os-info")) blk: {
        if (args_str.len != 0) return CmdParseError.IncorrectArgs;
        break :blk .os_info;
    } else if (mem.eql(u8, cmd_name, "echo")) blk: {
        var args: [2][]const u8 = undefined;
        parseCmdArgs(args_str, &args) catch
            return CmdParseError.IncorrectArgs;
        break :blk .{ .echo = args[0] };
    } else return CmdParseError.InvalidCmd;
}

fn runCmd(cmd: Command) void {
    switch (cmd) {
        .os_info => serial.writeStr("OS: NickOS\n"),
        .echo => |str| serial.writeStr(str),
    }
}

pub fn start() noreturn {
    while (true) {
        serial.writeStr("[guest@nickos] -> ");

        var buf: [22]u8 = undefined;
        @memset(&buf, 0);
        const input = serial.readLine(&buf);
        const cmd = parseCmd(input) catch |e| {
            switch (e) {
                CmdParseError.InvalidCmd => serial.writeStr("Invalid command\n"),
                CmdParseError.IncorrectArgs => serial.writeStr("Incorrect arguments\n"),
            }
            continue;
        };

        runCmd(cmd);
    }
}
