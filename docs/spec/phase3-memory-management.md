# Phase 3: Memory Management Enhancement

**Duration**: 4-5 weeks
**Prerequisites**: Phase 2 complete (advanced schedulers implemented)
**Next Phase**: Phase 4 (File System Enhancement)

## Overview

Phase 3 transforms xv6's simple memory management into a modern system supporting demand paging, copy-on-write, and swap. These features are fundamental to efficient memory utilization and enable memory overcommitment common in modern operating systems.

**Core Objective**: Implement on-demand memory allocation, copy-on-write fork, swap mechanism, and improved kernel memory allocators while maintaining system stability and performance.

## Objectives

### Primary Goals
1. Implement demand paging with lazy allocation
2. Implement copy-on-write (COW) fork to optimize process creation
3. Add swap support for memory overcommitment
4. Implement page replacement policy (LRU or Clock algorithm)
5. Enhance kernel memory allocator (slab allocator for common objects)
6. Establish memory pressure handling and OOM killer

### Learning Outcomes
- Deep understanding of virtual memory management
- Page fault handling and recovery mechanisms
- Memory allocation strategies and their trade-offs
- Performance implications of different memory policies
- Resource management under pressure

## Functional Requirements

### FR1: Demand Paging

**Requirement**: Allocate physical memory only when pages are actually accessed, not when virtual memory is reserved.

**Current xv6 Behavior**:
- `exec()` allocates all pages immediately
- `sbrk()` allocates pages immediately
- Process always has physical memory for all virtual pages

**New Behavior with Demand Paging**:
- `exec()` only sets up page table with invalid PTEs
- `sbrk()` extends virtual address space without allocating physical pages
- First access to page triggers page fault
- Page fault handler allocates physical page on demand
- Zero-fill page before mapping

**Lazy Allocation Benefits**:
- Faster process creation (exec)
- Faster heap growth (sbrk)
- Programs that allocate but don't use memory waste less physical memory
- Foundation for memory overcommitment

**Page Fault Handling**:
- Distinguish between demand-zero fault and invalid access
- Demand-zero: allocate page, zero it, map it, resume
- Invalid access: kill process (segmentation fault)
- Must handle faults in both user and kernel code paths

**Zero-Fill Optimization**:
- Allocate physical page
- Fill with zeros (security: don't leak previous data)
- Map into user page table with appropriate permissions
- Flush TLB entry

**Edge Cases to Handle**:
- Stack growth: automatic stack expansion on fault near stack
- Guard pages: detect stack overflow
- Heap growth: distinguish valid heap access from invalid
- Fork: child inherits demand-paged regions
- Exec: new program starts with demand paging

**Success Criteria**:
- `exec()` significantly faster (measured in microseconds)
- `sbrk()` constant time regardless of size
- Memory not wasted on unused allocations
- All usertests pass
- No security holes (zero-fill enforced)

### FR2: Copy-on-Write (COW) Fork

**Requirement**: Share physical memory between parent and child after fork, copying pages only when written.

**Current xv6 Behavior**:
- `fork()` copies entire parent page table
- Allocates new physical pages for all parent pages
- Copies content of each page
- Expensive for large processes
- Child immediately has own copy of all memory

**COW Fork Behavior**:
- `fork()` shares physical pages between parent and child
- Mark all writable pages as read-only in both page tables
- Increment reference count on each shared page
- First write by either process triggers page fault
- Page fault handler:
  - Allocate new physical page
  - Copy content from shared page
  - Map new page as writable in faulting process
  - Decrement reference count on old page
  - If reference count reaches 1, page can become writable again

**Reference Counting**:
- Need reference count for each physical page
- Track how many page tables reference each page
- Increment on share (fork, COW mapping)
- Decrement on unmap or COW fault
- Free page when count reaches zero

**Page Fault Handling**:
- Distinguish COW fault from protection violation
- COW fault: read-only page that is actually writable (COW bit set)
- Protection violation: kill process
- COW copy: preserve page contents exactly

**Optimization: Page Sharing Heuristics**:
- Don't COW read-only pages (text segment): can share permanently
- Small processes: may be faster to copy than manage COW
- Large processes: COW saves significant time and memory

**Interaction with Demand Paging**:
- Demand-paged pages are not present, can't be COW
- After demand-paged page allocated, can then be COW on fork
- Need to track both states: COW and demand-paged

**Success Criteria**:
- `fork()` 5-10x faster for large processes
- Memory usage significantly reduced when child and parent share pages
- Correctness: parent and child modifications independent
- All usertests pass (including forktest, forkforkfork)
- Reference counting correct (no leaks, no use-after-free)

### FR3: Swap Support

**Requirement**: Allow total virtual memory to exceed physical memory by paging out to disk.

**Swap Space Management**:
- Dedicated swap partition or swap file on disk
- Swap space divided into page-sized slots
- Bitmap or free list to track free/allocated slots
- Allocate slot when paging out
- Free slot when paging in or when page freed

**Page-Out Policy**:
- Trigger: physical memory low (below threshold)
- Select victim pages to evict (LRU or Clock algorithm)
- Write dirty pages to swap
- Clean pages can be discarded (if backed by file)
- Update PTE: mark as swapped, store swap slot number
- Free physical page

**Page-In on Fault**:
- Page fault on swapped-out page
- Allocate physical page (may require paging out another page)
- Read page from swap slot into physical page
- Update PTE: mark as present, clear swap bit
- Free swap slot
- Resume execution

**Page Table Entry (PTE) Format**:
- Present bit: 0 if swapped out
- Swapped bit: 1 if in swap, 0 if demand-paged or invalid
- Swap slot number: stored in PTE when swapped
- Dirty bit: track if page modified (already in RISC-V)
- Access bit: track if page recently accessed (for LRU)

**Swap I/O**:
- Synchronous swap-in: block until page read
- Asynchronous swap-out (optional): continue after writing
- Batch swap-out: write multiple pages in one I/O operation
- Swap I/O via buffer cache or direct disk access

**Page Replacement Algorithms**:

**Clock Algorithm** (recommended for simplicity):
- Circular list of all physical pages
- Clock hand points to candidate for eviction
- Each page has access bit (set by hardware or simulate)
- Algorithm:
  - If access bit = 0: evict this page
  - If access bit = 1: clear bit, advance hand
  - Repeat until victim found
- Simple, efficient, approximates LRU

**LRU (Least Recently Used)** (alternative):
- Track access time for each page
- Evict page with oldest access time
- More accurate than Clock
- More expensive (need timestamp updates)

**Working Set** (optional, advanced):
- Track pages accessed in recent time window
- Keep working set in memory
- Evict pages outside working set
- Better for interactive workloads

**Memory Pressure Handling**:
- Low memory threshold: start paging out (e.g., <20% free)
- Critical threshold: aggressive paging (e.g., <5% free)
- OOM threshold: invoke Out-of-Memory killer (e.g., <1% free)
- Reclaim pages from: file buffer cache, slab caches, user pages

**OOM Killer**:
- Last resort when swap exhausted and memory critically low
- Select victim process to kill
- Selection heuristics:
  - Avoid kernel processes
  - Prefer large processes
  - Prefer low priority processes
  - Avoid recently started processes
- Kill victim, reclaim all its memory
- Log OOM kill event

**Success Criteria**:
- System survives when memory demand exceeds physical RAM
- Processes run (slowly) when swapping
- No thrashing under reasonable load
- OOM killer invoked only when truly out of memory
- Swap I/O measurably slower than memory access (validates it's working)
- All usertests pass even with small physical memory (e.g., 32MB)

### FR4: Page Replacement Policy Implementation

**Requirement**: Efficiently select victim pages for eviction.

**Clock Algorithm Details**:

**Data Structures**:
- Array of page frames (all physical pages)
- Clock hand: index into array
- Access bit per page (in PTE or separate table)
- Dirty bit per page (in PTE)

**Page Frame States**:
- Free: not allocated to any process
- In-use: allocated and present
- Swapped: allocated but paged out

**Eviction Algorithm**:
```
find_victim_page():
  loop:
    page = frames[clock_hand]
    if page is free:
      return page  // Fast path
    if page.access_bit == 0:
      if page.dirty:
        write page to swap
      return page
    else:
      page.access_bit = 0
      advance clock_hand
      continue
```

**Access Bit Management**:
- Set by hardware on page access (RISC-V) or simulated by page fault
- Cleared by Clock algorithm
- Periodic reset to prevent all bits becoming 1

**Dirty Bit Management**:
- Set by hardware on page write (RISC-V) or simulated
- Checked before eviction
- Dirty pages must be written to swap
- Clean pages can be discarded (if read-only) or freed (if demand-paged)

**Performance Optimization**:
- Prefer clean pages over dirty pages (no I/O needed)
- Avoid evicting recently accessed pages
- Batch write multiple dirty pages together
- Background page-out daemon (optional): proactively write dirty pages

**Success Criteria**:
- Clock algorithm selects reasonable victims
- Access pattern affects eviction (frequently accessed pages stay)
- Dirty pages written to swap before eviction
- Performance acceptable under memory pressure

### FR5: Improved Kernel Memory Allocator

**Requirement**: Efficient allocation for kernel objects of common sizes.

**Current xv6 Allocator**:
- Free list of full pages
- kalloc() returns full page (4096 bytes)
- Wasteful for small objects (e.g., 64-byte structure)
- No per-object type management

**Slab Allocator Design**:

**Concepts**:
- Slab: contiguous pages containing objects of one size
- Cache: collection of slabs for one object type
- Object: fixed-size allocation unit

**Per-Type Caches**:
- Cache for `struct proc` (process control blocks)
- Cache for `struct inode` (file system inodes)
- Cache for `struct buf` (buffer cache entries)
- Cache for common sizes: 16, 32, 64, 128, 256, 512, 1024 bytes
- Large allocations (>2KB): fall back to page allocator

**Slab Structure**:
- Each slab contains multiple objects of same size
- Free list of objects within slab
- Slab states: empty, partial, full
- Allocate from partial slabs first (reduce fragmentation)

**Allocation Algorithm**:
```
slab_alloc(cache):
  if cache has partial slab:
    allocate from partial slab
  else if cache has empty slab:
    use empty slab
  else:
    allocate new slab from page allocator
  return object
```

**Deallocation**:
- Return object to its slab
- If slab becomes empty, can free it (or keep for reuse)
- Coalesce free objects within slab

**Benefits**:
- Reduced fragmentation
- Faster allocation (no page allocation overhead)
- Better cache locality (objects of same type grouped)
- Type safety (can initialize/destroy objects)

**Object Constructors/Destructors** (optional):
- Constructor: initialize object when first allocated
- Destructor: cleanup before object freed
- Reduces repeated initialization overhead

**Success Criteria**:
- Small object allocation 2-5x faster than kalloc()
- Reduced memory fragmentation
- Internal fragmentation <15% on average
- All kernel allocations use slab allocator
- No memory leaks (all allocated objects freed)

### FR6: Memory Statistics and Monitoring

**Requirement**: Expose memory usage information for debugging and tuning.

**System-Wide Statistics**:
- Total physical memory
- Free physical memory
- Used physical memory
- Swap total / used / free
- Page faults (demand-paging)
- COW faults
- Page-ins / page-outs
- OOM kills

**Per-Process Statistics**:
- Virtual memory size
- Resident set size (physical memory)
- Shared memory
- Major faults (swap-in)
- Minor faults (demand-paging, COW)

**System Calls**:
- `getmeminfo(struct meminfo*)` - System-wide memory stats
- `getprocmem(pid, struct procmem*)` - Per-process memory stats

**Debugging Support**:
- Print memory map of process
- Dump page table contents
- Show swap usage
- Show slab allocator statistics

**Success Criteria**:
- Statistics accurate and useful for debugging
- Easy to identify memory leaks
- Can detect thrashing conditions
- Minimal overhead from statistics collection

## Non-Functional Requirements

### NFR1: Performance

**Latency**:
- Page fault handling: <100 microseconds (demand-paging, COW)
- Swap-in: depends on disk I/O (~10ms typical)
- Swap-out: amortized over multiple pages
- Fork: <1ms for typical process with COW

**Throughput**:
- Allocator: >1M allocations/sec for slab allocator
- Page allocator: >100K pages/sec

### NFR2: Correctness

**Invariants**:
- Reference counts never negative
- All physical pages accounted (allocated or free)
- No use-after-free
- No double-free
- TLB coherency maintained

**Memory Safety**:
- All pages zero-filled before first use
- No information leakage between processes
- Protection bits enforced

### NFR3: Robustness

**Error Handling**:
- Graceful degradation under memory pressure
- OOM killer as last resort
- No kernel panic due to memory exhaustion
- Process isolation maintained under stress

**Recovery**:
- System remains functional after OOM kill
- Swap I/O errors handled gracefully
- Reference count recovery if corruption detected

### NFR4: Efficiency

**Memory Overhead**:
- Reference count array: 1 byte per page (<0.1% overhead)
- Slab allocator metadata: <5% overhead
- Page tables: same as current xv6

**Swap Overhead**:
- Swap metadata: bitmap or free list (<1% of swap size)
- Swap I/O buffering: minimal (one page buffer acceptable)

## Design Constraints

### DC1: Page Size Fixed at 4KB

**Constraint**: xv6 uses 4KB pages (RISC-V PAGESIZE), not configurable.

**Rationale**: Supporting multiple page sizes (huge pages) adds significant complexity. 4KB is standard and sufficient for educational OS.

### DC2: Single-Level Swap (No Swap Tiers)

**Constraint**: One swap device, no hierarchy of fast/slow swap.

**Rationale**: Swap tiering is optimization for production systems. Not needed for learning memory management fundamentals.

### DC3: No NUMA Support

**Constraint**: Assume uniform memory access (UMA), not NUMA.

**Rationale**: xv6 runs on simple QEMU virtual machine with UMA. NUMA adds complexity without educational benefit.

### DC4: Synchronous Swap-In

**Constraint**: Process blocks until swap-in completes.

**Rationale**: Asynchronous page-in requires complex scheduling and I/O subsystem. Synchronous is simpler and sufficient.

### DC5: Limited Swap Size

**Constraint**: Swap size limited to physical disk size (e.g., 64MB swap file).

**Rationale**: Avoids infinite swap growth. Realistic constraint for embedded/small systems.

### DC6: No Memory Compression

**Constraint**: No in-memory compression of swapped pages.

**Rationale**: Compression adds complexity and CPU overhead. Disk swap is conceptually clearer for learning.

## Testing Requirements

### Test Suite

**Demand Paging Tests**:
- `test_lazy_sbrk`: Allocate large heap, verify pages allocated on access
- `test_lazy_exec`: Execute program, verify pages faulted in on demand
- `test_zero_fill`: Verify all demand-paged pages zero-filled
- `test_invalid_access`: Verify invalid access kills process
- `test_stack_growth`: Verify stack grows on fault

**COW Fork Tests**:
- `test_cow_basic`: Fork, verify pages shared
- `test_cow_write`: Write in child, verify copy created
- `test_cow_parent_write`: Write in parent, verify independent copies
- `test_cow_refcount`: Fork multiple children, verify reference counts
- `test_cow_exec`: Exec after fork, verify COW pages freed
- `test_forkforkfork`: xv6 stress test, should be faster and use less memory

**Swap Tests**:
- `test_swap_basic`: Allocate more than physical memory, verify swap used
- `test_swap_in`: Page-out, then access page, verify page-in
- `test_swap_stress`: Many processes, high memory pressure
- `test_swap_thrash`: Detect and measure thrashing
- `test_oom_killer`: Exhaust memory, verify OOM killer invoked

**Page Replacement Tests**:
- `test_clock_algorithm`: Verify Clock algorithm selects victims correctly
- `test_access_bit`: Verify access bits affect eviction
- `test_dirty_preference`: Verify clean pages evicted before dirty

**Slab Allocator Tests**:
- `test_slab_alloc_free`: Allocate and free objects
- `test_slab_fragmentation`: Measure internal fragmentation
- `test_slab_performance`: Compare with page allocator
- `test_slab_stress`: Many allocations of different sizes

**Memory Pressure Tests**:
- `test_low_memory`: System behavior at 10% free memory
- `test_critical_memory`: System behavior at 1% free memory
- `test_memory_recovery`: System recovery after pressure relieved

**Correctness Tests**:
- `test_refcount_leak`: No reference count leaks
- `test_memory_leak`: No physical page leaks
- `test_zero_fill_security`: Verify no information leakage
- `test_tlb_coherency`: Verify TLB flushed after page table changes

### Performance Benchmarks

**Fork Benchmark**:
- Measure fork time before and after COW
- Measure memory usage before and after COW
- Expected: 5-10x speedup, 50% memory reduction

**Allocation Benchmark**:
- Measure slab allocator vs page allocator
- Different object sizes: 16, 64, 256, 1024 bytes
- Expected: 2-5x speedup for small objects

**Page Fault Benchmark**:
- Measure demand-paging fault latency
- Measure COW fault latency
- Measure swap-in latency
- Expected: <100μs for demand/COW, ~10ms for swap

**Swap Performance**:
- Measure throughput with different amounts of swap activity
- Measure impact of swap on overall system performance
- Expected: significant slowdown when swapping (expected behavior)

### Success Criteria

**Functional Correctness**:
- [ ] All demand paging tests pass
- [ ] All COW fork tests pass
- [ ] All swap tests pass
- [ ] All slab allocator tests pass
- [ ] All usertests pass with new memory management
- [ ] System stable under memory pressure

**Performance Validation**:
- [ ] Fork 5x faster with COW
- [ ] Slab allocator 2x faster for small objects
- [ ] Page fault latency <100μs
- [ ] No performance regression in non-memory-intensive workloads

**Resource Management**:
- [ ] No memory leaks in 24-hour stress test
- [ ] Reference counts always correct
- [ ] OOM killer prevents system deadlock
- [ ] System recovers after OOM kill

## Implementation Guidance

### Phase 3 Implementation is NOT Provided

This specification describes WHAT to build, not HOW:

**What You Should Figure Out**:
- How to track reference counts efficiently
- How to implement Clock algorithm data structures
- How to handle race conditions in page fault handler
- How to integrate swap with existing buffer cache
- How to design slab allocator data structures

**What You Should Research**:
- Linux memory management (mm subsystem)
- FreeBSD UVM (Virtual Memory system)
- Academic papers on COW and demand paging
- Original Unix V6 swapping mechanism
- Solaris slab allocator design (Bonwick paper)

**What You Should Design**:
- Page fault handler state machine
- Reference counting scheme
- Swap file format and management
- Slab allocator cache hierarchy
- Memory pressure detection and response

### Recommended Implementation Order

1. **Week 1**: Demand paging
   - Add PTE flags for demand-paged pages
   - Implement page fault handler for demand-zero
   - Modify sbrk() for lazy allocation
   - Modify exec() for lazy loading
   - Test and debug

2. **Week 2**: Copy-on-write fork
   - Add reference counting infrastructure
   - Modify fork() to share pages
   - Implement COW page fault handler
   - Handle reference count management
   - Test extensively (forktest)

3. **Week 3**: Swap support
   - Implement swap space management
   - Implement page-out mechanism
   - Implement page-in on fault
   - Implement Clock algorithm
   - Test with small physical memory

4. **Week 4**: Slab allocator
   - Design slab allocator data structures
   - Implement allocation/deallocation
   - Create caches for common kernel objects
   - Convert kernel to use slab allocator
   - Measure performance improvements

5. **Week 5**: Memory pressure and polish
   - Implement memory pressure detection
   - Implement OOM killer
   - Add memory statistics
   - Comprehensive testing and benchmarking
   - Fix bugs and optimize

### Common Pitfalls

**Pitfall 1: Race Conditions in Page Fault Handler**
- Multiple threads can fault on same page simultaneously
- Must use locking to prevent double allocation
- TLB shootdown required on SMP

**Pitfall 2: Reference Count Errors**
- Off-by-one errors are common
- Must handle fork, exit, exec correctly
- Use assertions to verify counts

**Pitfall 3: TLB Coherency**
- Must flush TLB after changing PTE
- Must flush on all CPUs on SMP
- Forgetting TLB flush causes subtle bugs

**Pitfall 4: Swap Deadlock**
- Page fault while swapping requires memory
- Can deadlock if no free pages
- Reserve emergency pages for swap I/O

**Pitfall 5: Thrashing**
- System can become unresponsive if swapping too much
- Need to detect thrashing and throttle
- OOM killer must activate before total deadlock

**Pitfall 6: Security: Information Leakage**
- Demand-paged pages must be zero-filled
- Swap pages must be cleared or encrypted
- Reference counting must prevent use-after-free

## References

### Memory Management Fundamentals

**Textbooks**:
- "Operating Systems: Three Easy Pieces" - Chapters 13-24 (Virtual Memory)
- "Modern Operating Systems" (Tanenbaum) - Chapter 3 (Memory Management)
- "Operating System Concepts" (Silberschatz) - Chapters 9-10 (Memory Management)

**Classic Papers**:
- "Virtual Memory Architecture in SunOS" (Gingell et al., 1987)
- "The Slab Allocator: An Object-Caching Kernel Memory Allocator" (Bonwick, 1994)
- "Reconsidering Custom Memory Allocation" (Berger et al., 2002)

### Copy-on-Write

**Papers and Documentation**:
- "Analysis of the Virtual Memory Performance of a Workstation" (Chen et al., 1992)
- BSD fork() implementation
- Linux COW implementation in kernel/fork.c

### Swap and Paging

**Linux Kernel**:
- Linux mm subsystem documentation
- Linux swap implementation (mm/swap.c, mm/page_io.c)
- Linux page reclaim (mm/vmscan.c)

**Other Systems**:
- FreeBSD UVM design and implementation
- Solaris Virtual Memory architecture
- Windows Memory Manager

### Page Replacement Algorithms

**Classic Papers**:
- "A Study of Replacement Algorithms for Virtual-Storage Computer" (Belady, 1966) - introduced LRU
- "WSClock — A Simple and Effective Algorithm for Virtual Memory Management" (Carr & Hennessy, 1981)
- "The Working Set Model for Program Behavior" (Denning, 1968)

**Algorithm Descriptions**:
- "Operating Systems: Three Easy Pieces" - Chapter 22 (Page Replacement)
- "Modern Operating Systems" - Section 3.4 (Page Replacement Algorithms)

### xv6 Memory Management

**Study Files**:
- `kernel/mm/vm.c` - Virtual memory implementation
- `kernel/mm/kalloc.c` - Physical page allocator
- `kernel/proc/proc.c` - fork() implementation
- `kernel/proc/exec.c` - exec() implementation
- `kernel/boot/trap.c` - Page fault handling entry point
- xv6 Book Chapter 3 - Page tables

### Slab Allocator

**Primary Reference**:
- "The Slab Allocator: An Object-Caching Kernel Memory Allocator" (Bonwick, 1994) - original Solaris paper

**Implementations**:
- Linux SLUB allocator (mm/slub.c)
- Linux SLAB allocator (mm/slab.c)
- FreeBSD UMA allocator

### Performance Analysis

**Tools and Techniques**:
- "Systems Performance: Enterprise and the Cloud" (Gregg, 2013)
- Linux perf tools for memory profiling
- Valgrind for memory leak detection

## Appendix: Data Structure Examples

**Note**: These are EXAMPLES for understanding, not complete implementations.

### Example: Reference Count Structure

```c
// In kernel/mm/kalloc.c or new kernel/mm/refcount.c

// Reference count for each physical page
// Indexed by physical page number
struct {
  spinlock lock;
  uint8 count[PHYSTOP / PGSIZE];  // One count per page
} refcounts;

void ref_init(void);
void ref_inc(uint64 pa);
void ref_dec(uint64 pa);  // Free page if count reaches 0
int ref_get(uint64 pa);
```

### Example: Page Frame Structure for Clock

```c
// In kernel/mm/swap.c

struct page_frame {
  uint64 pa;           // Physical address
  uint8 access_bit;    // Recently accessed
  uint8 dirty_bit;     // Modified
  uint32 swap_slot;    // Swap slot if paged out
};

struct {
  struct page_frame *frames;
  int num_frames;
  int clock_hand;      // Current position in Clock algorithm
  spinlock lock;
} page_frames;
```

### Example: Slab Cache Structure

```c
// In kernel/mm/slab.c

struct slab {
  struct slab *next;     // Next slab in cache
  void *mem;             // Start of slab memory
  int num_objects;       // Total objects in slab
  int num_free;          // Free objects
  void *free_list;       // Free objects list
};

struct kmem_cache {
  const char *name;      // Cache name (for debugging)
  size_t object_size;    // Size of each object
  struct slab *partial;  // Partially full slabs
  struct slab *full;     // Full slabs
  struct slab *empty;    // Empty slabs
  spinlock lock;

  // Statistics
  uint64 num_allocs;
  uint64 num_frees;
  uint64 num_slabs;
};

// Predefined caches
extern struct kmem_cache proc_cache;
extern struct kmem_cache inode_cache;
extern struct kmem_cache buf_cache;
```

### Example: Swap Slot Management

```c
// In kernel/mm/swap.c

#define SWAP_SLOTS (SWAP_SIZE / PGSIZE)

struct {
  spinlock lock;
  uint8 bitmap[SWAP_SLOTS / 8];  // Bitmap of free slots
  int num_free;
} swap_allocator;

int swap_alloc(void);        // Returns slot number or -1
void swap_free(int slot);
int swap_read(int slot, void *buf);
int swap_write(int slot, const void *buf);
```

## Appendix: PTE Format Extensions

**Example PTE Bit Usage** (RISC-V Sv39):

```
Bits    Name        Meaning
----    ----        -------
0       V           Valid (present in memory)
1       R           Readable
2       W           Writable
3       X           Executable
4       U           User accessible
5       G           Global mapping
6       A           Accessed (set by hardware)
7       D           Dirty (set by hardware)
8       RSW0        Reserved for software (use for COW bit)
9       RSW1        Reserved for software (use for SWAP bit)
10-53   PPN         Physical page number OR swap slot number
54-63   Reserved
```

**Software-Defined Bits**:
- COW bit (RSW0): set if page is copy-on-write
- SWAP bit (RSW1): set if page is swapped out
- When SWAP=1, PPN field contains swap slot number instead of physical address

**Example PTE Encodings**:
- Present, writable: V=1, W=1, COW=0, SWAP=0
- Present, COW: V=1, W=0, COW=1, SWAP=0
- Swapped out: V=0, SWAP=1, PPN=slot number
- Demand-paged: V=0, SWAP=0 (not yet allocated)

---

**Phase Status**: Ready for Implementation
**Estimated Effort**: 100-140 hours over 4-5 weeks
**Prerequisites**: Phase 2 complete (advanced schedulers)
**Outputs**: Demand paging, COW fork, swap, slab allocator
**Next Phase**: [Phase 4: File System Enhancement](phase4-filesystem-enhancement.md)
