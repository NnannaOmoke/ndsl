## Array-Backed Data Structures in Zig

A collection of fundamental data structures and algorithms implemented using array-backed storage rather than pointer-based approaches. This project prioritizes cache-friendly, index-based implementations that offer predictable performance characteristics and easier reasoning about memory layout.

### Motivation

Most data structure implementations rely heavily on pointer-chasing through heap-allocated nodes. While conceptually simple, this approach suffers from poor cache locality, unpredictable memory fragmentation, and makes it difficult to reason about actual memory behavior.

Array-backed implementations offer several advantages:

- **Cache locality**: Sequential memory access patterns play well with modern CPU caches
- **Predictable performance**: No pointer indirection, clearer memory access patterns
- **Simpler memory management**: Bulk allocation and deallocation, reduced fragmentation
- **Easier debugging**: Indices are just integers, memory layout is explicit
- **Better for systems programming**: Direct control over memory layout and access patterns

This is both a learning project and an exploration of how far one can go implementing complex data structures with arrays and indices as the primary primitives.

### Why Zig

Zig provides the right level of control for this work:

- Manual memory management without fighting a borrow checker, or rust's safety semantics.
- Compile-time generics via `comptime` for zero-cost abstractions.
- Explicit allocator passing makes memory behavior clear.
- Direct mapping to hardware while maintaining reasonable abstractions.

### Structures to Implement

#### Foundation
- **Dynamic Array**: Growable array with amortized O(1) append, foundation for all other structures

#### Core Structures
- Stack (array + top index)
- Queue (circular buffer with wraparound)
- Binary Heap (implicit binary tree, parent/child via index arithmetic)
- Disjoint Set / Union-Find (parent and rank arrays)

#### Intermediate
- Hash Table (open addressing with linear probing, Robin Hood hashing)
- Sorted Array with binary search
- B-tree / B+ tree (array of nodes, each node contains key/child arrays)

#### Graph Structures
- Adjacency List (array of neighbor arrays)
- Edge List (single array of edge structures)
- Implicit Grid Graph (2D array with coordinate arithmetic)

#### Advanced
- Trie (prefix tree with array-based children)
- Segment Tree / Fenwick Tree (range query structures)
- Implicit Treap (combined BST and heap properties)

### Design Principles

1. **Indices over pointers**: Use integer indices instead of memory addresses when possible
2. **Explicit allocation**: All allocators are passed explicitly, no hidden allocations
3. **Generational indices**: Optional safety layer to catch use-after-free bugs
4. **Cache awareness**: Structure layout considers cache line sizes and access patterns
5. **Clear invariants**: Each structure documents what properties must hold

### Building and Testing

```bash
zig build
zig build test
```

### Resources

This implementation draws from:

- "Algorithms" by Sedgewick & Wayne
- "Programming Pearls" by Jon Bentley
- "Introduction to Algorithms" (CLRS)
- "Data Structures and Algorithm Analysis in C" by Weiss
- Various papers on cache-friendly data structures

### Contributing

This is primarily a learning project, but issues and discussions about implementation approaches are welcome.

### License

MIT
