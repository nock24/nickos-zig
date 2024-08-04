const std = @import("std");
const mem = std.mem;
const drivers = @import("drivers");
const serial = drivers.serial;

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

fn parseCmdArgs(str: []const u8, arg_cnt: usize) ArgParseError![]const []const u8 {
    if (arg_cnt > MAX_ARG_CNT) return ArgParseError.TooLargeArgCnt;

    var args: [MAX_ARG_CNT][]const u8 = undefined;
    for (&args) |*arg| {
        arg.* = "";
    }
    var arg_idx: usize = 0;
    var arg_start: usize = 0;

    for (str, 0..) |char, i| {
        if (char == ' ' or i == str.len - 1) { // end of argument
            if (arg_idx >= arg_cnt) return ArgParseError.TooManyArgs;
            if (arg_idx < arg_cnt - 1) return ArgParseError.InsufficientArgs;

            args[arg_idx] = str[arg_start..i];
            arg_idx += 1;
            arg_start = i + 1;
            continue;
        }
    }

    return args[0..arg_cnt];
}

const MAX_CMD_NAME_LEN: usize = 7;

const CmdParseError = error{
    IncorrectArgs,
    InvalidCmd,
};

fn parseCmd(str: []const u8) CmdParseError!Command {
    var cmd_name_buf: [MAX_CMD_NAME_LEN]u8 = undefined;
    @memset(&cmd_name_buf, 0);
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
        cmd_name_buf[i] = char;
    }

    const cmd_name = cmd_name_buf[0..cmd_name_len];
    const args_str = if (no_args)
        ""
    else
        str[cmd_name_len + 1 ..];

    return if (mem.eql(u8, cmd_name, "os-info")) blk: {
        if (args_str.len != 0) return CmdParseError.IncorrectArgs;
        break :blk .os_info;
    } else if (mem.eql(u8, cmd_name, "echo")) blk: {
        const args = parseCmdArgs(args_str, 1) catch
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

        const input = serial.readLine();
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
