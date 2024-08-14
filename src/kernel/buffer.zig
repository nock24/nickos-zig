pub fn Buffer(comptime length: usize) type {
    const len = if (length % 8 == 0)
        length
    else
        length + (8 - (length % 8));

    return extern struct {
        bytes: [len]u8,
        const Self = @This();

        pub fn zeroes() Self {
            var buffer = Self{
                .bytes = undefined,
            };
            @memset(&buffer.bytes, 0);
            return buffer;
        }

        pub fn slice(self: *Self) []u8 {
            return self.bytes[0..length];
        }
    };
}
