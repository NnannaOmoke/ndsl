//! Implementation of a stack data structure. Due to the time and space complexities of the stack, this is just a wrapper
//! over an [ArrayList](src/array_list.zig)

const std = @import("std");
const testing = std.testing;
const array_list = @import("array_list.zig");
const ArrayList = array_list.ArrayList;
const Allocator = std.mem.Allocator;

/// Defines and returns a stack of type `T`
pub fn Stack(comptime T: type) type {
    return struct {
        const Self = @This();
        backing: ArrayList(T),
        /// Initialize an empty stack
        pub const empty = Self{ .backing = .empty };

        /// Initialize a stack with the provided capacity
        pub fn initWithCapacity(cap: usize, allocator: Allocator) Allocator.Error!Self {
            const backing = try ArrayList(T).initWithCapacity(cap, allocator);
            return Self{ .backing = backing };
        }

        /// Peek the top of the stack
        /// This returns the first element.
        /// If you need a reference, try `peekRef`
        pub fn peek(self: *Self) ?T {
            if (self.backing.occupied == 0) return null;
            return self.backing.getUnchecked(self.backing.occupied - 1);
        }

        /// Peek the top of the stack, returning a reference
        pub fn peekRef(self: *Self) ?*T {
            if (self.backing.occupied == 0) return null;
            return self.backing.getPointerUnchecked(self.backing.occupied - 1);
        }

        /// Push an element into the stack
        pub fn push(self: *Self, elem: T, allocator: Allocator) Allocator.Error!void {
            return self.backing.append(elem, allocator);
        }

        /// Push a slice with the LIFO strategy into the stack
        pub fn pushSlice(self: *Self, slice: []const T, allocator: Allocator) Allocator.Error!void {
            return self.backing.appendSlice(slice, allocator);
        }

        /// Pop an element from the top of the stack, which means deleting an returning it
        pub fn pop(self: *Self) ?T {
            if (self.backing.occupied == 0) return null;
            return self.backing.deleteAtUnchecked(self.backing.occupied - 1);
        }

        /// Return the length of the stack
        pub fn len(self: *Self) usize {
            return self.backing.len();
        }

        /// Deinit the stack and it's backing memory
        pub fn deinit(self: *Self, allocator: Allocator) void {
            self.backing.deinit(allocator);
        }
    };
}

// ============================================================================
// INITIALIZATION TESTS
// ============================================================================

test "empty stack initialization" {
    const IntStack = Stack(i32);
    var stack = IntStack.empty;

    try testing.expectEqual(@as(usize, 0), stack.len());
    try testing.expect(stack.peek() == null);
}

test "initWithCapacity creates correct capacity" {
    const IntStack = Stack(i32);
    const allocator = testing.allocator;

    var stack = try IntStack.initWithCapacity(10, allocator);
    defer stack.deinit(allocator);

    try testing.expectEqual(@as(usize, 0), stack.len());
    try testing.expectEqual(@as(usize, 10), stack.backing.backing.len);
}

// ============================================================================
// PUSH TESTS
// ============================================================================

test "push single element to empty stack" {
    const IntStack = Stack(i32);
    const allocator = testing.allocator;

    var stack = IntStack.empty;
    defer stack.deinit(allocator);

    try stack.push(42, allocator);

    try testing.expectEqual(@as(usize, 1), stack.len());
    try testing.expectEqual(@as(i32, 42), stack.peek().?);
}

test "push multiple elements" {
    const IntStack = Stack(i32);
    const allocator = testing.allocator;

    var stack = IntStack.empty;
    defer stack.deinit(allocator);

    try stack.push(1, allocator);
    try stack.push(2, allocator);
    try stack.push(3, allocator);

    try testing.expectEqual(@as(usize, 3), stack.len());
    try testing.expectEqual(@as(i32, 3), stack.peek().?);
}

test "push triggers reallocation" {
    const IntStack = Stack(i32);
    const allocator = testing.allocator;

    var stack = try IntStack.initWithCapacity(2, allocator);
    defer stack.deinit(allocator);

    try stack.push(1, allocator);
    try stack.push(2, allocator);
    const initial_cap = stack.backing.backing.len;

    try stack.push(3, allocator);

    try testing.expect(stack.backing.backing.len > initial_cap);
    try testing.expectEqual(@as(usize, 3), stack.len());
}

test "push many elements" {
    const IntStack = Stack(i32);
    const allocator = testing.allocator;

    var stack = IntStack.empty;
    defer stack.deinit(allocator);

    for (0..100) |i| {
        try stack.push(@intCast(i), allocator);
    }

    try testing.expectEqual(@as(usize, 100), stack.len());
    try testing.expectEqual(@as(i32, 99), stack.peek().?);
}

// ============================================================================
// PUSH SLICE TESTS
// ============================================================================

test "pushSlice to empty stack" {
    const IntStack = Stack(i32);
    const allocator = testing.allocator;

    var stack = IntStack.empty;
    defer stack.deinit(allocator);

    const slice = [_]i32{ 1, 2, 3, 4, 5 };
    try stack.pushSlice(&slice, allocator);

    try testing.expectEqual(@as(usize, 5), stack.len());
    try testing.expectEqual(@as(i32, 5), stack.peek().?);
}

test "pushSlice to non-empty stack" {
    const IntStack = Stack(i32);
    const allocator = testing.allocator;

    var stack = IntStack.empty;
    defer stack.deinit(allocator);

    try stack.push(10, allocator);
    try stack.push(20, allocator);

    const slice = [_]i32{ 30, 40, 50 };
    try stack.pushSlice(&slice, allocator);

    try testing.expectEqual(@as(usize, 5), stack.len());
    try testing.expectEqual(@as(i32, 50), stack.peek().?);
}

test "pushSlice empty slice" {
    const IntStack = Stack(i32);
    const allocator = testing.allocator;

    var stack = IntStack.empty;
    defer stack.deinit(allocator);

    try stack.push(1, allocator);
    const empty_slice = [_]i32{};
    try stack.pushSlice(&empty_slice, allocator);

    try testing.expectEqual(@as(usize, 1), stack.len());
    try testing.expectEqual(@as(i32, 1), stack.peek().?);
}

test "pushSlice LIFO order verification" {
    const IntStack = Stack(i32);
    const allocator = testing.allocator;

    var stack = IntStack.empty;
    defer stack.deinit(allocator);

    const slice = [_]i32{ 1, 2, 3 };
    try stack.pushSlice(&slice, allocator);

    // Should pop in reverse order: 3, 2, 1
    try testing.expectEqual(@as(i32, 3), stack.pop().?);
    try testing.expectEqual(@as(i32, 2), stack.pop().?);
    try testing.expectEqual(@as(i32, 1), stack.pop().?);
}

// ============================================================================
// POP TESTS
// ============================================================================

test "pop from single element stack" {
    const IntStack = Stack(i32);
    const allocator = testing.allocator;

    var stack = IntStack.empty;
    defer stack.deinit(allocator);

    try stack.push(42, allocator);

    const popped = stack.pop();

    try testing.expectEqual(@as(i32, 42), popped.?);
    try testing.expectEqual(@as(usize, 0), stack.len());
    try testing.expect(stack.peek() == null);
}

test "pop from multi-element stack" {
    const IntStack = Stack(i32);
    const allocator = testing.allocator;

    var stack = IntStack.empty;
    defer stack.deinit(allocator);

    try stack.push(1, allocator);
    try stack.push(2, allocator);
    try stack.push(3, allocator);

    try testing.expectEqual(@as(i32, 3), stack.pop().?);
    try testing.expectEqual(@as(usize, 2), stack.len());

    try testing.expectEqual(@as(i32, 2), stack.pop().?);
    try testing.expectEqual(@as(usize, 1), stack.len());

    try testing.expectEqual(@as(i32, 1), stack.pop().?);
    try testing.expectEqual(@as(usize, 0), stack.len());
}

test "pop from empty stack returns null" {
    const IntStack = Stack(i32);
    var stack = IntStack.empty;

    const popped = stack.pop();
    try testing.expect(popped == null);
}

test "pop all then pop again returns null" {
    const IntStack = Stack(i32);
    const allocator = testing.allocator;

    var stack = IntStack.empty;
    defer stack.deinit(allocator);

    try stack.push(1, allocator);
    _ = stack.pop();

    const popped = stack.pop();
    try testing.expect(popped == null);
}

test "pop respects LIFO order" {
    const IntStack = Stack(i32);
    const allocator = testing.allocator;

    var stack = IntStack.empty;
    defer stack.deinit(allocator);

    for (0..10) |i| {
        try stack.push(@intCast(i), allocator);
    }

    // Should pop in reverse order
    var i: i32 = 9;
    while (i >= 0) : (i -= 1) {
        try testing.expectEqual(i, stack.pop().?);
    }
}

// ============================================================================
// PEEK TESTS
// ============================================================================

test "peek returns top element without removing" {
    const IntStack = Stack(i32);
    const allocator = testing.allocator;

    var stack = IntStack.empty;
    defer stack.deinit(allocator);

    try stack.push(42, allocator);

    try testing.expectEqual(@as(i32, 42), stack.peek().?);
    try testing.expectEqual(@as(usize, 1), stack.len());

    // Peek again - should still be there
    try testing.expectEqual(@as(i32, 42), stack.peek().?);
    try testing.expectEqual(@as(usize, 1), stack.len());
}

test "peek on empty stack returns null" {
    const IntStack = Stack(i32);
    var stack = IntStack.empty;

    try testing.expect(stack.peek() == null);
}

test "peek after multiple pushes shows top" {
    const IntStack = Stack(i32);
    const allocator = testing.allocator;

    var stack = IntStack.empty;
    defer stack.deinit(allocator);

    try stack.push(1, allocator);
    try testing.expectEqual(@as(i32, 1), stack.peek().?);

    try stack.push(2, allocator);
    try testing.expectEqual(@as(i32, 2), stack.peek().?);

    try stack.push(3, allocator);
    try testing.expectEqual(@as(i32, 3), stack.peek().?);
}

test "peek after pop shows new top" {
    const IntStack = Stack(i32);
    const allocator = testing.allocator;

    var stack = IntStack.empty;
    defer stack.deinit(allocator);

    try stack.push(1, allocator);
    try stack.push(2, allocator);

    _ = stack.pop();
    try testing.expectEqual(@as(i32, 1), stack.peek().?);
}

// ============================================================================
// PEEK REF TESTS
// ============================================================================

test "peekRef returns pointer to top element" {
    const IntStack = Stack(i32);
    const allocator = testing.allocator;

    var stack = IntStack.empty;
    defer stack.deinit(allocator);

    try stack.push(42, allocator);

    const ptr = stack.peekRef();
    try testing.expect(ptr != null);
    try testing.expectEqual(@as(i32, 42), ptr.?.*);
}

test "peekRef allows modification of top element" {
    const IntStack = Stack(i32);
    const allocator = testing.allocator;

    var stack = IntStack.empty;
    defer stack.deinit(allocator);

    try stack.push(42, allocator);

    const ptr = stack.peekRef();
    ptr.?.* = 100;

    try testing.expectEqual(@as(i32, 100), stack.peek().?);
    try testing.expectEqual(@as(i32, 100), stack.pop().?);
}

test "peekRef on empty stack returns null" {
    const IntStack = Stack(i32);
    var stack = IntStack.empty;

    try testing.expect(stack.peekRef() == null);
}

test "peekRef does not remove element" {
    const IntStack = Stack(i32);
    const allocator = testing.allocator;

    var stack = IntStack.empty;
    defer stack.deinit(allocator);

    try stack.push(42, allocator);

    _ = stack.peekRef();
    try testing.expectEqual(@as(usize, 1), stack.len());
}

// ============================================================================
// LENGTH TESTS
// ============================================================================

test "len returns correct size" {
    const IntStack = Stack(i32);
    const allocator = testing.allocator;

    var stack = IntStack.empty;
    defer stack.deinit(allocator);

    try testing.expectEqual(@as(usize, 0), stack.len());

    try stack.push(1, allocator);
    try testing.expectEqual(@as(usize, 1), stack.len());

    try stack.push(2, allocator);
    try testing.expectEqual(@as(usize, 2), stack.len());

    _ = stack.pop();
    try testing.expectEqual(@as(usize, 1), stack.len());

    _ = stack.pop();
    try testing.expectEqual(@as(usize, 0), stack.len());
}

// ============================================================================
// INTEGRATION TESTS - STACK SEMANTICS
// ============================================================================

test "classic stack operations sequence" {
    const IntStack = Stack(i32);
    const allocator = testing.allocator;

    var stack = IntStack.empty;
    defer stack.deinit(allocator);

    // Push 1, 2, 3
    try stack.push(1, allocator);
    try stack.push(2, allocator);
    try stack.push(3, allocator);

    // Peek should be 3
    try testing.expectEqual(@as(i32, 3), stack.peek().?);

    // Pop should give 3, 2, 1
    try testing.expectEqual(@as(i32, 3), stack.pop().?);
    try testing.expectEqual(@as(i32, 2), stack.pop().?);
    try testing.expectEqual(@as(i32, 1), stack.pop().?);

    // Stack should be empty
    try testing.expect(stack.peek() == null);
    try testing.expect(stack.pop() == null);
}

test "push and pop interleaved" {
    const IntStack = Stack(i32);
    const allocator = testing.allocator;

    var stack = IntStack.empty;
    defer stack.deinit(allocator);

    try stack.push(1, allocator);
    try stack.push(2, allocator);
    try testing.expectEqual(@as(i32, 2), stack.pop().?);

    try stack.push(3, allocator);
    try testing.expectEqual(@as(i32, 3), stack.pop().?);
    try testing.expectEqual(@as(i32, 1), stack.pop().?);

    try testing.expect(stack.pop() == null);
}

test "stress test - many push and pop operations" {
    const IntStack = Stack(i32);
    const allocator = testing.allocator;

    var stack = IntStack.empty;
    defer stack.deinit(allocator);

    // Push 1000 elements
    for (0..1000) |i| {
        try stack.push(@intCast(i), allocator);
    }

    try testing.expectEqual(@as(usize, 1000), stack.len());

    // Pop all 1000 elements in reverse order
    var i: i32 = 999;
    while (i >= 0) : (i -= 1) {
        try testing.expectEqual(i, stack.pop().?);
    }

    try testing.expectEqual(@as(usize, 0), stack.len());
}

test "balanced parentheses checker pattern" {
    const CharStack = Stack(u8);
    const allocator = testing.allocator;

    var stack = CharStack.empty;
    defer stack.deinit(allocator);

    const expr = "((()))";

    for (expr) |char| {
        if (char == '(') {
            try stack.push(char, allocator);
        } else if (char == ')') {
            if (stack.pop() == null) {
                try testing.expect(false); // Unbalanced
            }
        }
    }

    try testing.expectEqual(@as(usize, 0), stack.len()); // Balanced
}

test "works with different types - strings" {
    const StringStack = Stack([]const u8);
    const allocator = testing.allocator;

    var stack = StringStack.empty;
    defer stack.deinit(allocator);

    try stack.push("first", allocator);
    try stack.push("second", allocator);
    try stack.push("third", allocator);

    try testing.expectEqualStrings("third", stack.pop().?);
    try testing.expectEqualStrings("second", stack.pop().?);
    try testing.expectEqualStrings("first", stack.pop().?);
}

test "works with structs" {
    const Point = struct {
        x: i32,
        y: i32,
    };

    const PointStack = Stack(Point);
    const allocator = testing.allocator;

    var stack = PointStack.empty;
    defer stack.deinit(allocator);

    try stack.push(.{ .x = 1, .y = 2 }, allocator);
    try stack.push(.{ .x = 3, .y = 4 }, allocator);

    const p2 = stack.pop().?;
    try testing.expectEqual(@as(i32, 3), p2.x);
    try testing.expectEqual(@as(i32, 4), p2.y);

    const p1 = stack.pop().?;
    try testing.expectEqual(@as(i32, 1), p1.x);
    try testing.expectEqual(@as(i32, 2), p1.y);
}

test "peek and peekRef consistency" {
    const IntStack = Stack(i32);
    const allocator = testing.allocator;

    var stack = IntStack.empty;
    defer stack.deinit(allocator);

    try stack.push(42, allocator);

    const val = stack.peek().?;
    const ptr = stack.peekRef().?;

    try testing.expectEqual(val, ptr.*);
}

test "empty stack all operations return null/correct values" {
    const IntStack = Stack(i32);
    var stack = IntStack.empty;

    try testing.expect(stack.peek() == null);
    try testing.expect(stack.peekRef() == null);
    try testing.expect(stack.pop() == null);
    try testing.expectEqual(@as(usize, 0), stack.len());
}
