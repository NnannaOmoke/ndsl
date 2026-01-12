//! This represents functionality for the operation of a simple array list

const std = @import("std");
const root = @import("root.zig");
const testing = std.testing;
const debug_print = std.debug.print;
const Allocator = std.mem.Allocator;
const look = std.ArrayList;
const RootError = root.NDSLError;

/// Returns an array list of type T
pub fn ArrayList(comptime T: type) type {
    return struct {
        const Self = @This();
        /// Factor by which we would increment the capacity on every new reallocation
        const MULTIPLIER_FACTOR = 2;
        backing: []T = &.{},
        occupied: usize = 0,

        /// Initialize an empty Arraylist
        pub const empty = Self{
            .backing = &.{},
            .occupied = 0,
        };

        /// Initialize an ArrayList with the provided capacity
        /// If you would like to do so with a buffer, pass in
        pub fn initWithCapacity(cap: usize, allocator: Allocator) Allocator.Error!Self {
            const slice = try allocator.alloc(T, cap);
            return Self{
                .backing = slice,
                .occupied = 0,
            };
        }

        /// Append an element to the back of the array list
        pub fn append(self: *Self, elem: T, allocator: Allocator) Allocator.Error!void {
            if (self.occupied + 1 > self.backing.len) {
                const new_len = (MULTIPLIER_FACTOR * self.backing.len) + 1;
                try self.resizeUp(new_len, allocator);
            }
            self.backing[self.occupied] = elem;
            self.occupied += 1;
            return;
        }

        /// Append a slice to the back of the array list
        pub fn appendSlice(self: *Self, slice: []const T, allocator: Allocator) Allocator.Error!void {
            const new_len = self.occupied + slice.len;
            if (new_len > self.backing.len) {
                try self.resizeUp(new_len, allocator);
            }
            @memcpy(self.backing[self.occupied..][0..slice.len], slice);
            self.occupied += slice.len;
            return;
        }

        /// Append an element at some point in the array list
        /// This operation is O(n)
        pub fn insertAt(
            self: *Self,
            elem: T,
            pos: usize,
            allocator: Allocator,
        ) RootError!void {
            if (self.checkOOB(pos)) return RootError.OutOfBounds;
            if (self.occupied + 1 >= self.backing.len) {
                const new_len = (MULTIPLIER_FACTOR * self.backing.len) + 1;
                try self.resizeUp(new_len, allocator);
            }
            @memmove(self.backing[pos..][1 .. self.occupied + 1], self.backing[pos..self.occupied]);
            self.backing[pos] = elem;
            self.occupied += 1;
            return;
        }

        /// Append a slice at some point in the array list
        /// This operation is O(n)
        pub fn insertSliceAt(
            self: *Self,
            slice: []const T,
            start: usize,
            allocator: Allocator,
        ) RootError!void {
            if (self.checkOOB(start)) return RootError.OutOfBounds;
            const new_len = slice.len + self.occupied;
            if (new_len > self.backing.len) {
                try self.resizeUp(new_len, allocator);
            }
            const tail_src = self.backing[start..self.occupied];
            const tail_dest = self.backing[start + slice.len .. slice.len + self.occupied];
            // move everything to from start to start+slice.len to start_slice.len + start
            @memmove(tail_dest, tail_src);
            @memcpy(self.backing[start..][0..slice.len], slice);
            self.occupied += slice.len;
            return;
        }

        /// Delete an element at some point in the array
        pub fn deleteAt(self: *Self, pos: usize) RootError!T {
            if (self.checkOOB(pos)) return RootError.OutOfBounds;
            return self.deleteAtUnchecked(pos);
        }

        /// Delete an element at some point in the array, while verifying that `pos` is in the array
        pub fn deleteAtUnchecked(self: *Self, pos: usize) T {
            const result = self.backing[pos];
            @memmove(self.backing[pos .. self.occupied - 1], self.backing[pos + 1 .. self.occupied]);
            self.occupied -= 1;
            return result;
        }

        /// Get an element situated at index `pos`
        pub fn get(self: *Self, pos: usize) ?T {
            if (self.checkOOB(pos)) return null;
            return self.getUnchecked(pos);
        }

        /// Get an element, having previously verified that `pos` is not out of bounds
        pub fn getUnchecked(self: *Self, pos: usize) T {
            return self.backing[pos];
        }

        /// Get a pointer to the element situated at index pos
        // NOTE: This operation is very unsafe -- some careless developer could free this pointer, leading to UB
        pub fn getPointer(self: *Self, pos: usize) ?*T {
            if (self.checkOOB(pos)) return null;
            return self.getPointerUnchecked(pos);
        }

        /// Get a reference to the element situtatued at index pos, having previously verified that `pos` is not out of bounds
        pub fn getPointerUnchecked(self: *Self, pos: usize) *T {
            return &self.backing[pos];
        }

        /// Deinitialize the `ArrayList`
        pub fn deinit(self: *Self, allocator: Allocator) void {
            allocator.free(self.backing);
            self.occupied = 0;
        }

        /// Return the number of elements in the array
        pub inline fn len(self: *Self) usize {
            return self.occupied;
        }

        /// Return the capacity of the array
        pub inline fn capacity(self: *Self) usize {
            return self.backing.len;
        }

        /// Check whether some index is out of bounds in the current array-list
        inline fn checkOOB(self: *Self, index: usize) bool {
            return index >= self.occupied;
        }

        /// In response to exceeding capacity, potentially reallocate or resize the memory
        fn resizeUp(self: *Self, new_len: usize, allocator: Allocator) Allocator.Error!void {
            // reallocation path
            if (allocator.remap(self.backing, new_len)) |slice| {
                self.backing = slice;
            } else {
                const new_slice = try allocator.alloc(T, new_len);
                // copy the data, then free the old slice by hand
                @memcpy(new_slice[0..self.backing.len], self.backing);
                allocator.free(self.backing);
                self.backing = new_slice;
            }
        }
    };
}

// test "test_memcpy_semantics" {
//     const src = &[_]u8{ 1, 2, 3, 4, 5, 6 };
//     var dst: [10]u8 = undefined;
//     @memcpy(dst[0..6], src);
//     for (dst) |e| {
//         debug_print("Current: {d}\n", .{e});
//     }
// }

// Assume ArrayList and Error are defined elsewhere
// const ArrayList = @import("arraylist.zig").ArrayList;
// const Error = @import("arraylist.zig").Error;

test "empty ArrayList initialization" {
    const IntList = ArrayList(i32);
    const list: IntList = .empty;

    try testing.expectEqual(@as(usize, 0), list.occupied);
    try testing.expectEqual(@as(usize, 0), list.backing.len);
}

test "initWithCapacity creates correct capacity" {
    const IntList = ArrayList(i32);
    const allocator = testing.allocator;

    var list = try IntList.initWithCapacity(10, allocator);
    defer list.deinit(allocator);

    try testing.expectEqual(@as(usize, 0), list.occupied);
    try testing.expectEqual(@as(usize, 10), list.backing.len);
}

// ============================================================================
// APPEND TESTS
// ============================================================================

test "append single element to empty list" {
    const IntList = ArrayList(i32);
    const allocator = testing.allocator;

    var list: IntList = .empty;
    defer list.deinit(allocator);

    try list.append(42, allocator);

    try testing.expectEqual(@as(usize, 1), list.occupied);
    try testing.expectEqual(@as(i32, 42), list.backing[0]);
}

test "append multiple elements triggers reallocation" {
    const IntList = ArrayList(i32);
    const allocator = testing.allocator;

    var list = IntList.empty;
    defer list.deinit(allocator);

    // Append several elements to force growth
    for (0..10) |i| {
        try list.append(@intCast(i), allocator);
    }

    try testing.expectEqual(@as(usize, 10), list.occupied);
    for (0..10) |i| {
        try testing.expectEqual(@as(i32, @intCast(i)), list.backing[i]);
    }
}

test "append grows backing array correctly" {
    const IntList = ArrayList(i32);
    const allocator = testing.allocator;

    const initial_cap = 2;
    var list = try IntList.initWithCapacity(initial_cap, allocator);
    defer list.deinit(allocator);

    try list.append(1, allocator);
    try list.append(2, allocator);
    const curr_cap = list.backing.len;

    try list.append(3, allocator); // Should trigger resize

    try testing.expect(list.backing.len > curr_cap);
    try testing.expectEqual(@as(usize, 3), list.occupied);
}

// ============================================================================
// APPEND SLICE TESTS
// ============================================================================

test "appendSlice to empty list" {
    const IntList = ArrayList(i32);
    const allocator = testing.allocator;

    var list = IntList.empty;
    defer list.deinit(allocator);

    const slice = [_]i32{ 1, 2, 3, 4, 5 };
    try list.appendSlice(&slice, allocator);

    try testing.expectEqual(@as(usize, 5), list.occupied);
    for (slice, 0..) |val, i| {
        try testing.expectEqual(val, list.backing[i]);
    }
}

test "appendSlice to non-empty list" {
    const IntList = ArrayList(i32);
    const allocator = testing.allocator;

    var list = IntList.empty;
    defer list.deinit(allocator);

    try list.append(10, allocator);
    try list.append(20, allocator);

    const slice = [_]i32{ 30, 40, 50 };
    try list.appendSlice(&slice, allocator);

    try testing.expectEqual(@as(usize, 5), list.occupied);
    try testing.expectEqual(@as(i32, 10), list.backing[0]);
    try testing.expectEqual(@as(i32, 20), list.backing[1]);
    try testing.expectEqual(@as(i32, 30), list.backing[2]);
    try testing.expectEqual(@as(i32, 40), list.backing[3]);
    try testing.expectEqual(@as(i32, 50), list.backing[4]);
}

test "appendSlice empty slice" {
    const IntList = ArrayList(i32);
    const allocator = testing.allocator;

    var list = IntList.empty;
    defer list.deinit(allocator);

    try list.append(1, allocator);
    const empty_slice = [_]i32{};
    try list.appendSlice(&empty_slice, allocator);

    try testing.expectEqual(@as(usize, 1), list.occupied);
}

test "appendSlice triggers reallocation" {
    const IntList = ArrayList(i32);
    const allocator = testing.allocator;

    var list = try IntList.initWithCapacity(3, allocator);
    defer list.deinit(allocator);

    try list.append(1, allocator);

    const slice = [_]i32{ 2, 3, 4, 5, 6 };
    try list.appendSlice(&slice, allocator);

    try testing.expectEqual(@as(usize, 6), list.occupied);
    try testing.expect(list.backing.len >= 6);
}

// ============================================================================
// INSERT SLICE AT TESTS
// ============================================================================

test "insertSliceAt beginning" {
    const IntList = ArrayList(i32);
    const allocator = testing.allocator;

    var list = IntList.empty;
    defer list.deinit(allocator);

    try list.append(1, allocator);
    try list.append(2, allocator);
    try list.append(3, allocator);

    const slice = [_]i32{ 10, 20 };
    try list.insertSliceAt(&slice, 0, allocator);

    try testing.expectEqual(@as(usize, 5), list.occupied);
    try testing.expectEqual(@as(i32, 10), list.backing[0]);
    try testing.expectEqual(@as(i32, 20), list.backing[1]);
    try testing.expectEqual(@as(i32, 1), list.backing[2]);
    try testing.expectEqual(@as(i32, 2), list.backing[3]);
    try testing.expectEqual(@as(i32, 3), list.backing[4]);
}

test "insertSliceAt middle" {
    const IntList = ArrayList(i32);
    const allocator = testing.allocator;

    var list = IntList.empty;
    defer list.deinit(allocator);

    try list.append(1, allocator);
    try list.append(2, allocator);
    try list.append(5, allocator);

    const slice = [_]i32{ 3, 4 };
    try list.insertSliceAt(&slice, 2, allocator);

    try testing.expectEqual(@as(usize, 5), list.occupied);
    try testing.expectEqual(@as(i32, 1), list.backing[0]);
    try testing.expectEqual(@as(i32, 2), list.backing[1]);
    try testing.expectEqual(@as(i32, 3), list.backing[2]);
    try testing.expectEqual(@as(i32, 4), list.backing[3]);
    try testing.expectEqual(@as(i32, 5), list.backing[4]);
}

test "insertSliceAt end" {
    const IntList = ArrayList(i32);
    const allocator = testing.allocator;

    var list = IntList.empty;
    defer list.deinit(allocator);

    try list.append(1, allocator);
    try list.append(2, allocator);

    const slice = [_]i32{ 3, 4 };
    try list.appendSlice(&slice, allocator);

    try testing.expectEqual(@as(usize, 4), list.occupied);
    try testing.expectEqual(@as(i32, 1), list.backing[0]);
    try testing.expectEqual(@as(i32, 2), list.backing[1]);
    try testing.expectEqual(@as(i32, 3), list.backing[2]);
    try testing.expectEqual(@as(i32, 4), list.backing[3]);
}

test "insertSliceAt out of bounds" {
    const IntList = ArrayList(i32);
    const allocator = testing.allocator;

    var list = IntList.empty;
    defer list.deinit(allocator);

    try list.append(1, allocator);

    const slice = [_]i32{ 2, 3 };
    const result = list.insertSliceAt(&slice, 5, allocator);

    try testing.expectError(RootError.OutOfBounds, result);
}

test "insertSliceAt empty slice" {
    const IntList = ArrayList(i32);
    const allocator = testing.allocator;

    var list = IntList.empty;
    defer list.deinit(allocator);

    try list.append(1, allocator);
    try list.append(2, allocator);

    const empty_slice = [_]i32{};
    try list.insertSliceAt(&empty_slice, 1, allocator);

    try testing.expectEqual(@as(usize, 2), list.occupied);
    try testing.expectEqual(@as(i32, 1), list.backing[0]);
    try testing.expectEqual(@as(i32, 2), list.backing[1]);
}

test "insertSliceAt triggers reallocation" {
    const IntList = ArrayList(i32);
    const allocator = testing.allocator;

    var list = try IntList.initWithCapacity(3, allocator);
    defer list.deinit(allocator);

    try list.append(1, allocator);
    try list.append(2, allocator);

    const slice = [_]i32{ 10, 20, 30, 40 };
    try list.insertSliceAt(&slice, 1, allocator);

    try testing.expectEqual(@as(usize, 6), list.occupied);
    try testing.expect(list.backing.len >= 6);
    try testing.expectEqual(@as(i32, 1), list.backing[0]);
    try testing.expectEqual(@as(i32, 10), list.backing[1]);
    try testing.expectEqual(@as(i32, 20), list.backing[2]);
    try testing.expectEqual(@as(i32, 30), list.backing[3]);
    try testing.expectEqual(@as(i32, 40), list.backing[4]);
    try testing.expectEqual(@as(i32, 2), list.backing[5]);
}

// ============================================================================
// DELETE AT TESTS
// ============================================================================

test "deleteAt first element" {
    const IntList = ArrayList(i32);
    const allocator = testing.allocator;

    var list = IntList.empty;
    defer list.deinit(allocator);

    try list.append(1, allocator);
    try list.append(2, allocator);
    try list.append(3, allocator);

    const deleted = try list.deleteAt(0);

    try testing.expectEqual(@as(i32, 1), deleted);
    try testing.expectEqual(@as(usize, 2), list.occupied);
    try testing.expectEqual(@as(i32, 2), list.backing[0]);
    try testing.expectEqual(@as(i32, 3), list.backing[1]);
}

test "deleteAt middle element" {
    const IntList = ArrayList(i32);
    const allocator = testing.allocator;

    var list = IntList.empty;
    defer list.deinit(allocator);

    try list.append(1, allocator);
    try list.append(2, allocator);
    try list.append(3, allocator);

    const deleted = try list.deleteAt(1);

    try testing.expectEqual(@as(i32, 2), deleted);
    try testing.expectEqual(@as(usize, 2), list.occupied);
    try testing.expectEqual(@as(i32, 1), list.backing[0]);
    try testing.expectEqual(@as(i32, 3), list.backing[1]);
}

test "deleteAt last element" {
    const IntList = ArrayList(i32);
    const allocator = testing.allocator;

    var list = IntList.empty;
    defer list.deinit(allocator);

    try list.append(1, allocator);
    try list.append(2, allocator);
    try list.append(3, allocator);

    const deleted = try list.deleteAt(2);

    try testing.expectEqual(@as(i32, 3), deleted);
    try testing.expectEqual(@as(usize, 2), list.occupied);
    try testing.expectEqual(@as(i32, 1), list.backing[0]);
    try testing.expectEqual(@as(i32, 2), list.backing[1]);
}

test "deleteAt single element list" {
    const IntList = ArrayList(i32);
    const allocator = testing.allocator;

    var list = IntList.empty;
    defer list.deinit(allocator);

    try list.append(42, allocator);

    const deleted = try list.deleteAt(0);

    try testing.expectEqual(@as(i32, 42), deleted);
    try testing.expectEqual(@as(usize, 0), list.occupied);
}

test "deleteAt out of bounds" {
    const IntList = ArrayList(i32);
    const allocator = testing.allocator;

    var list = IntList.empty;
    defer list.deinit(allocator);

    try list.append(1, allocator);

    const result = list.deleteAt(5);
    try testing.expectError(RootError.OutOfBounds, result);
}

test "deleteAt empty list" {
    const IntList = ArrayList(i32);
    var list = IntList.empty;

    const result = list.deleteAt(0);
    try testing.expectError(RootError.OutOfBounds, result);
}

test "deleteAt all elements sequentially from front" {
    const IntList = ArrayList(i32);
    const allocator = testing.allocator;

    var list = IntList.empty;
    defer list.deinit(allocator);

    try list.append(1, allocator);
    try list.append(2, allocator);
    try list.append(3, allocator);

    _ = try list.deleteAt(0);
    try testing.expectEqual(@as(usize, 2), list.occupied);

    _ = try list.deleteAt(0);
    try testing.expectEqual(@as(usize, 1), list.occupied);

    _ = try list.deleteAt(0);
    try testing.expectEqual(@as(usize, 0), list.occupied);
}

test "deleteAt all elements sequentially from back" {
    const IntList = ArrayList(i32);
    const allocator = testing.allocator;

    var list = IntList.empty;
    defer list.deinit(allocator);

    try list.append(1, allocator);
    try list.append(2, allocator);
    try list.append(3, allocator);

    _ = try list.deleteAt(2);
    try testing.expectEqual(@as(usize, 2), list.occupied);

    _ = try list.deleteAt(1);
    try testing.expectEqual(@as(usize, 1), list.occupied);

    _ = try list.deleteAt(0);
    try testing.expectEqual(@as(usize, 0), list.occupied);
}

// ============================================================================
// GET TESTS
// ============================================================================

test "get valid index" {
    const IntList = ArrayList(i32);
    const allocator = testing.allocator;

    var list = IntList.empty;
    defer list.deinit(allocator);

    try list.append(42, allocator);
    try list.append(100, allocator);

    const val1 = list.get(0);
    const val2 = list.get(1);

    try testing.expect(val1 != null);
    try testing.expectEqual(@as(i32, 42), val1.?);
    try testing.expect(val2 != null);
    try testing.expectEqual(@as(i32, 100), val2.?);
}

test "get invalid index returns null" {
    const IntList = ArrayList(i32);
    const allocator = testing.allocator;

    var list = IntList.empty;
    defer list.deinit(allocator);

    try list.append(42, allocator);

    const val = list.get(5);
    try testing.expect(val == null);
}

test "get empty list returns null" {
    const IntList = ArrayList(i32);
    var list = IntList.empty;

    const val = list.get(0);
    try testing.expect(val == null);
}

// ============================================================================
// GET POINTER TESTS
// ============================================================================

test "getPointer valid index" {
    const IntList = ArrayList(i32);
    const allocator = testing.allocator;

    var list = IntList.empty;
    defer list.deinit(allocator);

    try list.append(42, allocator);

    const ptr = list.getPointer(0);
    try testing.expect(ptr != null);
    try testing.expectEqual(@as(i32, 42), ptr.?.*);

    // Modify through pointer
    ptr.?.* = 100;
    try testing.expectEqual(@as(i32, 100), list.backing[0]);
}

test "getPointer invalid index returns null" {
    const IntList = ArrayList(i32);
    const allocator = testing.allocator;

    var list = IntList.empty;
    defer list.deinit(allocator);

    try list.append(42, allocator);

    const ptr = list.getPointer(5);
    try testing.expect(ptr == null);
}

// ============================================================================
// COMPLEX INTEGRATION TESTS
// ============================================================================

test "mixed operations sequence" {
    const IntList = ArrayList(i32);
    const allocator = testing.allocator;

    var list = IntList.empty;
    defer list.deinit(allocator);

    // Append some elements
    try list.append(1, allocator);
    try list.append(2, allocator);
    try list.append(3, allocator);

    // Insert slice in middle
    const slice = [_]i32{ 10, 20 };
    try list.insertSliceAt(&slice, 1, allocator);

    // Should be: [1, 10, 20, 2, 3]
    try testing.expectEqual(@as(usize, 5), list.occupied);

    // Delete middle element
    _ = try list.deleteAt(2);

    // Should be: [1, 10, 2, 3]
    try testing.expectEqual(@as(usize, 4), list.occupied);
    try testing.expectEqual(@as(i32, 1), list.backing[0]);
    try testing.expectEqual(@as(i32, 10), list.backing[1]);
    try testing.expectEqual(@as(i32, 2), list.backing[2]);
    try testing.expectEqual(@as(i32, 3), list.backing[3]);
}

test "stress test with many operations" {
    const IntList = ArrayList(i32);
    const allocator = testing.allocator;

    var list = IntList.empty;
    defer list.deinit(allocator);

    for (0..100) |i| {
        try list.append(@intCast(i), allocator);
    }
    try testing.expectEqual(@as(usize, 100), list.occupied);

    for (0..50) |_| {
        _ = try list.deleteAt(0);
    }
    try testing.expectEqual(@as(usize, 50), list.occupied);

    for (0..50) |i| {
        try testing.expectEqual(@as(i32, @intCast(i + 50)), list.backing[i]);
    }
}

test "reallocation preserves data integrity" {
    const IntList = ArrayList(i32);
    const allocator = testing.allocator;

    var list = try IntList.initWithCapacity(2, allocator);
    defer list.deinit(allocator);

    for (0..20) |i| {
        try list.append(@intCast(i), allocator);
    }

    for (0..20) |i| {
        try testing.expectEqual(@as(i32, @intCast(i)), list.backing[i]);
    }
}

test "works with different types" {
    const StringList = ArrayList([]const u8);
    const allocator = testing.allocator;

    var list = StringList.empty;
    defer list.deinit(allocator);

    try list.append("hello", allocator);
    try list.append("world", allocator);

    try testing.expectEqual(@as(usize, 2), list.occupied);
    try testing.expectEqualStrings("hello", list.backing[0]);
    try testing.expectEqualStrings("world", list.backing[1]);
}

test "works with structs" {
    const Point = struct {
        x: i32,
        y: i32,
    };

    const PointList = ArrayList(Point);
    const allocator = testing.allocator;

    var list = PointList.empty;
    defer list.deinit(allocator);

    try list.append(.{ .x = 1, .y = 2 }, allocator);
    try list.append(.{ .x = 3, .y = 4 }, allocator);

    try testing.expectEqual(@as(usize, 2), list.occupied);
    try testing.expectEqual(@as(i32, 1), list.backing[0].x);
    try testing.expectEqual(@as(i32, 2), list.backing[0].y);
    try testing.expectEqual(@as(i32, 3), list.backing[1].x);
    try testing.expectEqual(@as(i32, 4), list.backing[1].y);
}
