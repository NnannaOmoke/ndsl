//! This represents functionality for the implementation of queues and queue based data structures like ring buffers, etc

const std = @import("std");
const root = @import("root.zig");
const testing = std.testing;
const Allocator = std.mem.Allocator;
const NDSLError = root.NDSLError;

/// Returns a growable queue of type `T`
pub fn Queue(
    comptime T: type,
) type {
    return struct {
        const Self = @This();
        backing: []T = &.{},
        head: usize = 0,
        tail: usize = 0,

        /// Return an empty queue
        pub const empty = Self{};

        /// Initialize a queue with the provided capacity
        pub fn withInitCapacity(cap: usize, allocator: Allocator) Allocator.Error!Self {
            const backing = try allocator.alloc(T, cap);
            return Self{
                .backing = backing,
            };
        }

        /// Free the queue and its backing memory
        pub fn deinit(self: *Self, allocator: Allocator) void {
            allocator.free(self.backing);
            self.tail = 0;
            self.head = 0;
            return;
        }

        /// Peek the "head" of the queue
        pub fn peek(self: *Self) ?T {
            if (self.tail - self.head == 0) return null;
            return self.backing[self.head];
        }

        /// Peek the "head" of the queue, returning a reference
        pub fn peekRef(self: *Self) ?*T {
            if (self.tail - self.head == 0) return null;
            return &self.backing[self.head];
        }

        /// Push an element into the queue
        pub fn enqueue(self: *Self, elem: T, allocator: Allocator) Allocator.Error!void {
            if (self.tail >= self.backing.len) {
                const curr_len = self.tail - self.head;
                try self.resize(curr_len + 1, allocator);
            }
            self.backing[self.tail] = elem;
            self.tail += 1;
        }

        /// Push a slice into the queue. This obeys FIFO semantics
        pub fn enqueueSlice(self: *Self, slice: []const T, allocator: Allocator) Allocator.Error!void {
            const new_tail = (self.tail - self.head) + slice.len;
            if (new_tail >= self.backing.len) try self.resize(new_tail, allocator);
            @memcpy(self.backing[self.tail..][0..slice.len], slice);
            self.tail += slice.len;
        }

        /// Push a slice into the queue
        /// Remove the front of the queue
        pub fn dequeue(self: *Self) ?T {
            if (self.tail - self.head == 0) return null;
            const result = self.backing[self.head];
            self.head += 1;
            return result;
        }

        /// Compact the queue.
        /// This function is only viable if self.head != 0
        pub fn compact(self: *Self) void {
            if (self.head == 0) return;
            // no need to branch, just memmove and yeet the performance cost, might be CPU friendly
            const curr_len = self.tail - self.head;
            @memmove(self.backing[0..curr_len], self.backing[self.head..self.tail]);
            self.head = 0;
            self.tail = curr_len;
            return;
        }

        /// Resize the queue's backing memory
        fn resize(
            self: *Self,
            size_hint: usize,
            allocator: Allocator,
        ) Allocator.Error!void {
            // we have to check the wasted space currently in the queue
            // then, we if the wasted space is larger than or equal to the allocation request, we can just `@memcpy` and set head and tail to the appropriate indices
            const wasted_space = self.head;
            const curr_len = self.tail - self.head;
            const new_alloc = (size_hint * 2) + 1;
            if (wasted_space >= new_alloc) {
                // no need to reallocate with the allocator, just @memcpy
                @memcpy(self.backing[0..curr_len], self.backing[self.head..self.tail]);
            } else {
                // manually reallocate the memory
                if (allocator.remap(self.backing, new_alloc)) |slice| {
                    @memcpy(slice[0..curr_len], self.backing[self.head..self.tail]);
                    self.backing = slice;
                } else {
                    const new_slice = try allocator.alloc(T, new_alloc);
                    // copy the data, then free the old slice by hand
                    @memcpy(new_slice[0..curr_len], self.backing[self.head..self.tail]);
                    allocator.free(self.backing);
                    self.backing = new_slice;
                }
            }
            self.head = 0;
            self.tail = curr_len;
            return;
        }

        pub fn len(self: *Self) usize {
            return self.tail - self.head;
        }
    };
}

// ============================================================================
// INITIALIZATION TESTS
// ============================================================================

test "empty queue initialization" {
    const IntQueue = Queue(i32);
    var queue = IntQueue.empty;

    try testing.expectEqual(@as(usize, 0), queue.len());
    try testing.expect(queue.peek() == null);
    try testing.expect(queue.dequeue() == null);
}

test "withInitCapacity creates correct capacity" {
    const IntQueue = Queue(i32);
    const allocator = testing.allocator;

    var queue = try IntQueue.withInitCapacity(10, allocator);
    defer queue.deinit(allocator);

    try testing.expectEqual(@as(usize, 0), queue.len());
    try testing.expectEqual(@as(usize, 10), queue.backing.len);
}

// ============================================================================
// ENQUEUE TESTS
// ============================================================================

test "enqueue single element to empty queue" {
    const IntQueue = Queue(i32);
    const allocator = testing.allocator;

    var queue = IntQueue.empty;
    defer queue.deinit(allocator);

    try queue.enqueue(42, allocator);

    try testing.expectEqual(@as(usize, 1), queue.len());
    try testing.expectEqual(@as(i32, 42), queue.peek().?);
}

test "enqueue multiple elements" {
    const IntQueue = Queue(i32);
    const allocator = testing.allocator;

    var queue = IntQueue.empty;
    defer queue.deinit(allocator);

    try queue.enqueue(1, allocator);
    try queue.enqueue(2, allocator);
    try queue.enqueue(3, allocator);

    try testing.expectEqual(@as(usize, 3), queue.len());
    try testing.expectEqual(@as(i32, 1), queue.peek().?); // Front should be 1
}

test "enqueue triggers reallocation" {
    const IntQueue = Queue(i32);
    const allocator = testing.allocator;

    var queue = try IntQueue.withInitCapacity(2, allocator);
    defer queue.deinit(allocator);

    try queue.enqueue(1, allocator);
    try queue.enqueue(2, allocator);
    const initial_cap = queue.backing.len;

    try queue.enqueue(3, allocator);

    try testing.expect(queue.backing.len > initial_cap);
    try testing.expectEqual(@as(usize, 3), queue.len());
}

test "enqueue many elements" {
    const IntQueue = Queue(i32);
    const allocator = testing.allocator;

    var queue = IntQueue.empty;
    defer queue.deinit(allocator);

    for (0..100) |i| {
        try queue.enqueue(@intCast(i), allocator);
    }

    try testing.expectEqual(@as(usize, 100), queue.len());
    try testing.expectEqual(@as(i32, 0), queue.peek().?); // Front is first enqueued
}

// ============================================================================
// ENQUEUE SLICE TESTS
// ============================================================================

test "enqueueSlice to empty queue" {
    const IntQueue = Queue(i32);
    const allocator = testing.allocator;

    var queue = IntQueue.empty;
    defer queue.deinit(allocator);

    const slice = [_]i32{ 1, 2, 3, 4, 5 };
    try queue.enqueueSlice(&slice, allocator);

    try testing.expectEqual(@as(usize, 5), queue.len());
    try testing.expectEqual(@as(i32, 1), queue.peek().?);
}

test "enqueueSlice to non-empty queue" {
    const IntQueue = Queue(i32);
    const allocator = testing.allocator;

    var queue = IntQueue.empty;
    defer queue.deinit(allocator);

    try queue.enqueue(10, allocator);
    try queue.enqueue(20, allocator);

    const slice = [_]i32{ 30, 40, 50 };
    try queue.enqueueSlice(&slice, allocator);

    try testing.expectEqual(@as(usize, 5), queue.len());
    try testing.expectEqual(@as(i32, 10), queue.peek().?);
}

test "enqueueSlice empty slice" {
    const IntQueue = Queue(i32);
    const allocator = testing.allocator;

    var queue = IntQueue.empty;
    defer queue.deinit(allocator);

    try queue.enqueue(1, allocator);
    const empty_slice = [_]i32{};
    try queue.enqueueSlice(&empty_slice, allocator);

    try testing.expectEqual(@as(usize, 1), queue.len());
    try testing.expectEqual(@as(i32, 1), queue.peek().?);
}

test "enqueueSlice FIFO order verification" {
    const IntQueue = Queue(i32);
    const allocator = testing.allocator;

    var queue = IntQueue.empty;
    defer queue.deinit(allocator);

    const slice = [_]i32{ 1, 2, 3 };
    try queue.enqueueSlice(&slice, allocator);

    // Should dequeue in order: 1, 2, 3
    try testing.expectEqual(@as(i32, 1), queue.dequeue().?);
    try testing.expectEqual(@as(i32, 2), queue.dequeue().?);
    try testing.expectEqual(@as(i32, 3), queue.dequeue().?);
}

test "enqueueSlice triggers reallocation" {
    const IntQueue = Queue(i32);
    const allocator = testing.allocator;

    var queue = try IntQueue.withInitCapacity(3, allocator);
    defer queue.deinit(allocator);

    try queue.enqueue(1, allocator);

    const slice = [_]i32{ 2, 3, 4, 5, 6 };
    try queue.enqueueSlice(&slice, allocator);

    try testing.expectEqual(@as(usize, 6), queue.len());
    try testing.expect(queue.backing.len >= 6);
}

// ============================================================================
// DEQUEUE TESTS
// ============================================================================

test "dequeue from single element queue" {
    const IntQueue = Queue(i32);
    const allocator = testing.allocator;

    var queue = IntQueue.empty;
    defer queue.deinit(allocator);

    try queue.enqueue(42, allocator);

    const dequeued = queue.dequeue();

    try testing.expectEqual(@as(i32, 42), dequeued.?);
    try testing.expectEqual(@as(usize, 0), queue.len());
    try testing.expect(queue.peek() == null);
}

test "dequeue from multi-element queue" {
    const IntQueue = Queue(i32);
    const allocator = testing.allocator;

    var queue = IntQueue.empty;
    defer queue.deinit(allocator);

    try queue.enqueue(1, allocator);
    try queue.enqueue(2, allocator);
    try queue.enqueue(3, allocator);

    try testing.expectEqual(@as(i32, 1), queue.dequeue().?);
    try testing.expectEqual(@as(usize, 2), queue.len());

    try testing.expectEqual(@as(i32, 2), queue.dequeue().?);
    try testing.expectEqual(@as(usize, 1), queue.len());

    try testing.expectEqual(@as(i32, 3), queue.dequeue().?);
    try testing.expectEqual(@as(usize, 0), queue.len());
}

test "dequeue from empty queue returns null" {
    const IntQueue = Queue(i32);
    var queue = IntQueue.empty;

    const dequeued = queue.dequeue();
    try testing.expect(dequeued == null);
}

test "dequeue all then dequeue again returns null" {
    const IntQueue = Queue(i32);
    const allocator = testing.allocator;

    var queue = IntQueue.empty;
    defer queue.deinit(allocator);

    try queue.enqueue(1, allocator);
    _ = queue.dequeue();

    const dequeued = queue.dequeue();
    try testing.expect(dequeued == null);
}

test "dequeue respects FIFO order" {
    const IntQueue = Queue(i32);
    const allocator = testing.allocator;

    var queue = IntQueue.empty;
    defer queue.deinit(allocator);

    for (0..10) |i| {
        try queue.enqueue(@intCast(i), allocator);
    }

    // Should dequeue in same order as enqueued
    for (0..10) |i| {
        try testing.expectEqual(@as(i32, @intCast(i)), queue.dequeue().?);
    }
}

// ============================================================================
// PEEK TESTS
// ============================================================================

test "peek returns front element without removing" {
    const IntQueue = Queue(i32);
    const allocator = testing.allocator;

    var queue = IntQueue.empty;
    defer queue.deinit(allocator);

    try queue.enqueue(42, allocator);

    try testing.expectEqual(@as(i32, 42), queue.peek().?);
    try testing.expectEqual(@as(usize, 1), queue.len());

    // Peek again - should still be there
    try testing.expectEqual(@as(i32, 42), queue.peek().?);
    try testing.expectEqual(@as(usize, 1), queue.len());
}

test "peek on empty queue returns null" {
    const IntQueue = Queue(i32);
    var queue = IntQueue.empty;

    try testing.expect(queue.peek() == null);
}

test "peek after multiple enqueues shows front" {
    const IntQueue = Queue(i32);
    const allocator = testing.allocator;

    var queue = IntQueue.empty;
    defer queue.deinit(allocator);

    try queue.enqueue(1, allocator);
    try testing.expectEqual(@as(i32, 1), queue.peek().?);

    try queue.enqueue(2, allocator);
    try testing.expectEqual(@as(i32, 1), queue.peek().?); // Still first element

    try queue.enqueue(3, allocator);
    try testing.expectEqual(@as(i32, 1), queue.peek().?);
}

test "peek after dequeue shows new front" {
    const IntQueue = Queue(i32);
    const allocator = testing.allocator;

    var queue = IntQueue.empty;
    defer queue.deinit(allocator);

    try queue.enqueue(1, allocator);
    try queue.enqueue(2, allocator);

    _ = queue.dequeue();
    try testing.expectEqual(@as(i32, 2), queue.peek().?);
}

// ============================================================================
// PEEK REF TESTS
// ============================================================================

test "peekRef returns pointer to front element" {
    const IntQueue = Queue(i32);
    const allocator = testing.allocator;

    var queue = IntQueue.empty;
    defer queue.deinit(allocator);

    try queue.enqueue(42, allocator);

    const ptr = queue.peekRef();
    try testing.expect(ptr != null);
    try testing.expectEqual(@as(i32, 42), ptr.?.*);
}

test "peekRef allows modification of front element" {
    const IntQueue = Queue(i32);
    const allocator = testing.allocator;

    var queue = IntQueue.empty;
    defer queue.deinit(allocator);

    try queue.enqueue(42, allocator);

    const ptr = queue.peekRef();
    ptr.?.* = 100;

    try testing.expectEqual(@as(i32, 100), queue.peek().?);
    try testing.expectEqual(@as(i32, 100), queue.dequeue().?);
}

test "peekRef on empty queue returns null" {
    const IntQueue = Queue(i32);
    var queue = IntQueue.empty;

    try testing.expect(queue.peekRef() == null);
}

test "peekRef does not remove element" {
    const IntQueue = Queue(i32);
    const allocator = testing.allocator;

    var queue = IntQueue.empty;
    defer queue.deinit(allocator);

    try queue.enqueue(42, allocator);

    _ = queue.peekRef();
    try testing.expectEqual(@as(usize, 1), queue.len());
}

// ============================================================================
// COMPACT TESTS
// ============================================================================

test "compact moves elements to start" {
    const IntQueue = Queue(i32);
    const allocator = testing.allocator;

    var queue = IntQueue.empty;
    defer queue.deinit(allocator);

    // Enqueue and dequeue to create wasted space
    try queue.enqueue(1, allocator);
    try queue.enqueue(2, allocator);
    try queue.enqueue(3, allocator);

    _ = queue.dequeue();
    _ = queue.dequeue();

    // Now head != 0
    const head_before = queue.head;
    try testing.expect(head_before > 0);

    queue.compact();

    try testing.expectEqual(@as(usize, 0), queue.head);
    try testing.expectEqual(@as(usize, 1), queue.tail);
    try testing.expectEqual(@as(i32, 3), queue.peek().?);
}

test "compact on already compacted queue does nothing" {
    const IntQueue = Queue(i32);
    const allocator = testing.allocator;

    var queue = IntQueue.empty;
    defer queue.deinit(allocator);

    try queue.enqueue(1, allocator);

    queue.compact();

    try testing.expectEqual(@as(usize, 0), queue.head);
    try testing.expectEqual(@as(usize, 1), queue.tail);
}

test "compact preserves FIFO order" {
    const IntQueue = Queue(i32);
    const allocator = testing.allocator;

    var queue = IntQueue.empty;
    defer queue.deinit(allocator);

    try queue.enqueue(10, allocator);
    try queue.enqueue(20, allocator);
    try queue.enqueue(30, allocator);
    try queue.enqueue(40, allocator);

    _ = queue.dequeue();
    _ = queue.dequeue();

    queue.compact();

    try testing.expectEqual(@as(i32, 30), queue.dequeue().?);
    try testing.expectEqual(@as(i32, 40), queue.dequeue().?);
}

test "compact empty queue is safe" {
    const IntQueue = Queue(i32);
    var queue = IntQueue.empty;

    queue.compact(); // Should not crash

    try testing.expectEqual(@as(usize, 0), queue.head);
    try testing.expectEqual(@as(usize, 0), queue.tail);
}

// ============================================================================
// LENGTH TESTS
// ============================================================================

test "len returns correct size" {
    const IntQueue = Queue(i32);
    const allocator = testing.allocator;

    var queue = IntQueue.empty;
    defer queue.deinit(allocator);

    try testing.expectEqual(@as(usize, 0), queue.len());

    try queue.enqueue(1, allocator);
    try testing.expectEqual(@as(usize, 1), queue.len());

    try queue.enqueue(2, allocator);
    try testing.expectEqual(@as(usize, 2), queue.len());

    _ = queue.dequeue();
    try testing.expectEqual(@as(usize, 1), queue.len());

    _ = queue.dequeue();
    try testing.expectEqual(@as(usize, 0), queue.len());
}

// ============================================================================
// INTEGRATION TESTS - QUEUE SEMANTICS
// ============================================================================

test "classic queue operations sequence" {
    const IntQueue = Queue(i32);
    const allocator = testing.allocator;

    var queue = IntQueue.empty;
    defer queue.deinit(allocator);

    // Enqueue 1, 2, 3
    try queue.enqueue(1, allocator);
    try queue.enqueue(2, allocator);
    try queue.enqueue(3, allocator);

    // Peek should be 1 (front)
    try testing.expectEqual(@as(i32, 1), queue.peek().?);

    // Dequeue should give 1, 2, 3
    try testing.expectEqual(@as(i32, 1), queue.dequeue().?);
    try testing.expectEqual(@as(i32, 2), queue.dequeue().?);
    try testing.expectEqual(@as(i32, 3), queue.dequeue().?);

    // Queue should be empty
    try testing.expect(queue.peek() == null);
    try testing.expect(queue.dequeue() == null);
}

test "enqueue and dequeue interleaved" {
    const IntQueue = Queue(i32);
    const allocator = testing.allocator;

    var queue = IntQueue.empty;
    defer queue.deinit(allocator);

    try queue.enqueue(1, allocator);
    try queue.enqueue(2, allocator);
    try testing.expectEqual(@as(i32, 1), queue.dequeue().?);

    try queue.enqueue(3, allocator);
    try testing.expectEqual(@as(i32, 2), queue.dequeue().?);
    try testing.expectEqual(@as(i32, 3), queue.dequeue().?);

    try testing.expect(queue.dequeue() == null);
}

test "stress test - many enqueue and dequeue operations" {
    const IntQueue = Queue(i32);
    const allocator = testing.allocator;

    var queue = IntQueue.empty;
    defer queue.deinit(allocator);

    // Enqueue 1000 elements
    for (0..1000) |i| {
        try queue.enqueue(@intCast(i), allocator);
    }

    try testing.expectEqual(@as(usize, 1000), queue.len());

    // Dequeue all 1000 elements in order
    for (0..1000) |i| {
        try testing.expectEqual(@as(i32, @intCast(i)), queue.dequeue().?);
    }

    try testing.expectEqual(@as(usize, 0), queue.len());
}

test "wasted space triggers in-place compaction" {
    const IntQueue = Queue(i32);
    const allocator = testing.allocator;

    var queue = try IntQueue.withInitCapacity(10, allocator);
    defer queue.deinit(allocator);

    // Fill queue
    for (0..5) |i| {
        try queue.enqueue(@intCast(i), allocator);
    }

    // Dequeue to create wasted space
    for (0..4) |_| {
        _ = queue.dequeue();
    }

    // head should be at 4 now (wasted space)
    try testing.expect(queue.head > 0);

    // Enqueue more - should trigger compaction if wasted space is sufficient
    try queue.enqueue(100, allocator);

    // Verify FIFO order still intact
    try testing.expectEqual(@as(i32, 4), queue.dequeue().?);
    try testing.expectEqual(@as(i32, 100), queue.dequeue().?);
}

test "works with different types - strings" {
    const StringQueue = Queue([]const u8);
    const allocator = testing.allocator;

    var queue = StringQueue.empty;
    defer queue.deinit(allocator);

    try queue.enqueue("first", allocator);
    try queue.enqueue("second", allocator);
    try queue.enqueue("third", allocator);

    try testing.expectEqualStrings("first", queue.dequeue().?);
    try testing.expectEqualStrings("second", queue.dequeue().?);
    try testing.expectEqualStrings("third", queue.dequeue().?);
}

test "works with structs" {
    const Point = struct {
        x: i32,
        y: i32,
    };

    const PointQueue = Queue(Point);
    const allocator = testing.allocator;

    var queue = PointQueue.empty;
    defer queue.deinit(allocator);

    try queue.enqueue(.{ .x = 1, .y = 2 }, allocator);
    try queue.enqueue(.{ .x = 3, .y = 4 }, allocator);

    const p1 = queue.dequeue().?;
    try testing.expectEqual(@as(i32, 1), p1.x);
    try testing.expectEqual(@as(i32, 2), p1.y);

    const p2 = queue.dequeue().?;
    try testing.expectEqual(@as(i32, 3), p2.x);
    try testing.expectEqual(@as(i32, 4), p2.y);
}

test "peek and peekRef consistency" {
    const IntQueue = Queue(i32);
    const allocator = testing.allocator;

    var queue = IntQueue.empty;
    defer queue.deinit(allocator);

    try queue.enqueue(42, allocator);

    const val = queue.peek().?;
    const ptr = queue.peekRef().?;

    try testing.expectEqual(val, ptr.*);
}

test "empty queue all operations return null/correct values" {
    const IntQueue = Queue(i32);
    var queue = IntQueue.empty;

    try testing.expect(queue.peek() == null);
    try testing.expect(queue.peekRef() == null);
    try testing.expect(queue.dequeue() == null);
    try testing.expectEqual(@as(usize, 0), queue.len());
}

test "resize with sufficient wasted space avoids allocation" {
    const IntQueue = Queue(i32);
    const allocator = testing.allocator;

    var queue = try IntQueue.withInitCapacity(20, allocator);
    defer queue.deinit(allocator);

    // Create significant wasted space
    for (0..15) |i| {
        try queue.enqueue(@intCast(i), allocator);
    }

    for (0..14) |_| {
        _ = queue.dequeue();
    }

    // Now head=14, only 1 element left
    const backing_ptr = queue.backing.ptr;

    // Enqueue more - should compact in place, not reallocate
    try queue.enqueue(100, allocator);

    // Backing pointer should be same (no reallocation)
    try testing.expectEqual(backing_ptr, queue.backing.ptr);
}

// TODO: add extension struct called `VecDeque` that allows to pop from head and push to front
/// Returns a growable ring buffer of type `T`
/// This is analogous to rust's `vecdeque`
pub fn RingBuffer(
    comptime T: type,
) type {
    return struct {
        const Self = @This();
        backing: []T = &.{},
        head: usize = 0,
        len: usize = 0,

        const empty = Self{};

        /// Initialize a ring buffer with the provided capacity
        pub fn withInitCapacity(cap: usize, allocator: Allocator) Allocator.Error!Self {
            const backing = try allocator.alloc(T, cap);
            return Self{ .backing = backing };
        }

        /// Free the ring buffer and its backing memory
        pub fn deinit(self: *Self, allocator: Allocator) void {
            allocator.free(self.backing);
            self.head = 0;
            self.len = 0;
        }

        /// Push an element into the front of the ring buffer
        pub fn enqueue(self: *Self, elem: T, allocator: Allocator) Allocator.Error!void {
            if (self.len + 1 > self.backing.len) try self.resize(self.len + 1, allocator);
            const index = self.head + self.len;
            const pos = self.mask_or_mod_enqueue(index);
            self.backing[pos] = elem;
            self.len += 1;
            return;
        }

        /// Push a slice into the front of the ring buffer
        pub fn enqueueSlice(self: *Self, slice: []const T, allocator: Allocator) Allocator.Error!void {
            if (self.len + slice.len > self.backing.len) try self.resize(self.len + slice.len, allocator);
            // our issue is simple -- we must batch the copies into two
            const start_pos = self.mask_or_mod_enqueue(self.head + self.len);
            const diff = self.backing.len - start_pos;
            if (slice.len > diff) {
                const rem = slice.len - diff;
                @memcpy(self.backing[start_pos..], slice[0..diff]);
                @memcpy(self.backing[0..rem], slice[diff..][0..rem]);
            } else {
                @memcpy(self.backing[start_pos..][0..slice.len], slice);
            }
            self.len += slice.len;
        }

        /// Dequeue an element. This follows FIFO semantics
        pub fn dequeue(self: *Self) ?T {
            if (self.len == 0) return null;
            const res = self.backing[self.head];
            self.head += 1;
            return res;
        }

        /// Peek the "head" of the ring buffer
        pub fn peek(self: *Self) ?T {
            if (self.len == 0) return null;
            return self.backing[self.head];
        }

        /// Peek the "head" of the ring buffer, returning a reference
        pub fn peekRef(self: *Self) ?*T {
            if (self.len == 0) return null;
            return &self.backing[self.head];
        }

        /// Resize the backing array for the allocator
        /// The size hint is usually aligned forward to the next power of eight to make `mask_or_mod_enqueue` cheaper
        fn resize(self: *Self, size_hint: usize, allocator: Allocator) Allocator.Error!void {
            // all size hints are multiplied by 2 and aligned forward or backward to the next power of eight.
            const mul_two = size_hint * 2;
            const forward = (mul_two + 7) & ~(7); //hopefull aligns forward to the next power of eight
            // TODO: Make this safe for overflow semantics. On most platforms, the process will die before overflow needs to be a problem
            if (allocator.remap(self.backing, forward)) |new_slice| {
                const tail = self.backing.len - self.head;
                const wrap_around_len = self.len -| tail;
                @memcpy(new_slice[0..tail], self.backing[self.head..]);
                @memcpy(new_slice[tail..][0..wrap_around_len], self.backing[0..wrap_around_len]);
                self.backing = new_slice;
            } else {
                const new_slice = try allocator.alloc(T, forward);
                const tail = self.backing.len - self.head;
                const wrap_around_len = self.len -| tail;
                @memcpy(new_slice[0..tail], self.backing[self.head..]);
                @memcpy(new_slice[tail..][0..wrap_around_len], self.backing[0..wrap_around_len]);
                allocator.free(self.backing);
                self.backing = new_slice;
            }
            self.head = 0;
            return;
        }

        /// Function provides the index for the next insert
        inline fn mask_or_mod_enqueue(self: *Self, index: usize) usize {
            const cap = self.backing.len;
            if (cap & (cap - 1) == 0) {
                @branchHint(.likely);
                return index & (cap - 1);
            } else {
                @branchHint(.unlikely);
                return index % cap;
            }
        }
    };
}
