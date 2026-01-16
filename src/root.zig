const std = @import("std");
const builtin = @import("builtin");

comptime {
    _ = @import("array_list.zig");
    _ = @import("stack.zig");
    _ = @import("queue.zig");
    std.testing.refAllDeclsRecursive(@This());
}

// test {}

/// Define the possible error states of the library
pub const NDSLError = error{
    /// An out of bounds access was attempted
    OutOfBounds,
    /// The backing allocator returned a null pointer on some operation, or threw an error
    OutOfMemory,
};
