# Phase 5: Advanced Memory Management

**Duration**: 3-4 weeks
**Prerequisites**: Phase 1

## Objectives

Implement advanced virtual memory features: lazy allocation, copy-on-write, memory-mapped files, and swap space.

## Features to Implement

### 1. Lazy Allocation

Current xv6: `sbrk()` allocates and zeros pages immediately.

**Requirements**:
- `sbrk(n)` only increases process size, doesn't allocate pages
- Allocate pages on-demand when page fault occurs
- Modify `usertrap()` to handle page faults (scause = 13 or 15)
- Check if fault address is valid (between heap start and  end)
- Allocate page, zero it, map into page table
- Resume execution

**Benefit**: Faster process creation, lower memory usage if pages not accessed

**Files to Modify**:
- `kernel/trap.c` - Handle page fault
- `kernel/sysproc.c` - Modify `sys_sbrk()`
- `kernel/vm.c` - Add lazy allocation support

### 2. Copy-on-Write Fork (COW)

Current xv6: `fork()` copies all parent pages immediately (slow, wasteful).

**Requirements**:
- Share parent pages with child initially (mark as read-only)
- Set PTE_W flag off, set custom PTE_COW flag
- On write fault (page fault with scause = 15):
  - Check if page is COW
  - Allocate new page
  - Copy content from original page
  - Map new page with write permission
  - Decrement reference count on original page
- Implement reference counting for physical pages:
  ```c
  int page_refcount[PHYSTOP/PGSIZE];
  ```
- Free page only when refcount reaches 0

**Benefit**: Faster fork, less memory usage

**Files to Modify**:
- `kernel/vm.c` - Modify `uvmcopy()` for COW
- `kernel/trap.c` - Handle write faults
- `kernel/kalloc.c` - Add reference counting

### 3. Zero-Fill on Demand

**Requirements**:
- Don't allocate pages immediately, especially for BSS segment
- Maintain single zero-filled page shared across processes
- On first write, copy zero page to new page
- Similar to COW but source is always zeros

**Benefit**: Reduce memory for large uninitialized arrays

### 4. Memory-Mapped Files (mmap)

**System Call**: `void *mmap(void *addr, int length, int prot, int flags, int fd, int offset)`

**Parameters**:
- `addr` - Suggested address (0 = kernel chooses)
- `length` - Size of mapping
- `prot` - PROT_READ, PROT_WRITE, PROT_EXEC
- `flags` - MAP_SHARED, MAP_PRIVATE, MAP_ANONYMOUS
- `fd` - File descriptor (or -1 for anonymous)
- `offset` - File offset

**System Call**: `int munmap(void *addr, int length)`

**Requirements**:
- Allocate virtual address space for mapping
- Don't read file immediately (lazy load on page fault)
- On page fault:
  - Read corresponding file page into memory
  - Map into process page table
- Track mappings in `struct proc`:
  ```c
  struct vma {  // Virtual Memory Area
    uint64 addr;
    uint64 length;
    int prot;
    int flags;
    struct file *file;
    uint64 offset;
  };
  struct vma vmas[16];  // Per-process
  ```
- On `munmap()` or process exit:
  - If MAP_SHARED and dirty, write back to file
  - Free pages
  - Remove mapping

**Benefit**: Efficient file I/O, shared memory

**Files to Modify**:
- `kernel/sysfile.c` - Implement mmap/munmap
- `kernel/trap.c` - Handle page faults for mmap regions
- `kernel/proc.h` - Add VMA tracking

### 5. Swap Space

**Requirements**:
- Reserve disk space for swapping (or use swap file)
- Implement page replacement algorithm: LRU or Clock
- On memory pressure (out of physical pages):
  - Select victim page using LRU
  - Write to swap if dirty
  - Mark PTE as swapped (custom flag)
  - Free physical page
- On page fault for swapped page:
  - Allocate new physical page
  - Read from swap
  - Update page table
  - Resume execution

**Data Structures**:
```c
// Track swapped pages
struct swap_entry {
  uint64 va;         // Virtual address
  int swap_offset;   // Offset in swap space
  struct proc *proc; // Owner process
};

// LRU for page replacement
struct page_info {
  void *pa;          // Physical address
  uint64 last_access; // For LRU
  int referenced;    // For clock algorithm
};
```

**System Calls**:
- `int swapon(char *path)` - Enable swap file
- `int swapoff(char *path)` - Disable swap
- `int getswapinfo(struct swapinfo *info)` - Get swap stats

**Benefit**: Support larger memory footprint than physical RAM

### 6. Huge Pages

**Requirements**:
- Support 2MB huge pages (RISC-V supports this)
- Modify page table code to handle 2MB pages
- Add flag to `mmap()`: MAP_HUGETLB
- Allocate contiguous 512 pages (2MB)
- Set appropriate PTE flags

**Benefit**: Reduced TLB misses, better performance for large allocations

### 7. Memory Protection

**Requirements**:
- Implement guard pages (unmapped pages to detect stack overflow)
- Add guard page below user stack
- On stack overflow (access to guard page), kill process
- Implement stack expansion (limited)

**Enhancement**:
- Detect NULL pointer dereferences (page 0 always unmapped)
- Implement Address Space Layout Randomization (ASLR):
  - Randomize heap base
  - Randomize stack base
  - Randomize mmap region

### 8. Shared Memory

**System Calls**:
- `int shmget(int key, int size)` - Create shared memory segment
- `void *shmat(int shmid, void *addr)` - Attach shared memory
- `int shmdt(void *addr)` - Detach shared memory
- `int shmctl(int shmid, int cmd)` - Control shared memory

**Requirements**:
- Global table of shared memory segments
- Multiple processes can attach to same segment
- Physical pages shared across processes
- Implement reference counting
- Permissions checking

**Use Case**: IPC, shared data structures between processes

### 9. Memory Statistics

**System Call**: `int getmeminfo(struct meminfo *info)`

**Requirements**:
- Return memory statistics:
  - Total physical memory
  - Free memory
  - Process memory usage (RSS, virtual size)
  - Swap usage
  - Cache size
  - Page fault count

**User Program**: `free` - Display memory usage

### 10. Page Table Walking Tool

**System Call**: `int walk_pagetable(uint64 va, struct pte_info *info)`

**Requirements**:
- Return page table entry information for given virtual address
- Include: physical address, permissions, flags, level in page table
- Useful for debugging

**User Program**: `pmap <pid>` - Display process memory map

## Deliverables

- [ ] Lazy allocation functional
- [ ] Copy-on-write fork working
- [ ] Zero-fill on demand implemented
- [ ] mmap/munmap with file backing
- [ ] Anonymous mmap (MAP_ANONYMOUS)
- [ ] Swap space with page replacement
- [ ] Memory protection (guard pages, ASLR)
- [ ] Shared memory IPC
- [ ] Memory statistics system call
- [ ] User programs:
  - `free` - Memory usage display
  - `pmap` - Process memory map
  - `mmaptest` - Test mmap functionality
  - `cowtest` - Test COW fork
- [ ] Test suite:
  - Lazy allocation verification
  - COW correctness tests
  - mmap file I/O tests
  - Swap stress tests
  - Memory leak detection
- [ ] Performance benchmarks:
  - Fork latency (with and without COW)
  - Page fault handling latency
  - mmap vs read/write performance
  - Memory throughput with swap

## Success Criteria

1. **Lazy Allocation**: Process can allocate GB of virtual memory instantly
2. **COW**: Fork is 10x+ faster than copy fork
3. **mmap**: Can map files larger than physical RAM
4. **Swap**: System continues running when RAM exhausted
5. **Correctness**: No memory corruption, proper isolation
6. **Compatibility**: All existing tests pass

## Testing

### Lazy Allocation Test
```c
char *p = sbrk(10 * 1024 * 1024);  // 10MB, should be instant
// First access will fault and allocate
p[0] = 1;  // Page fault, allocate page
p[PGSIZE] = 2;  // Another page fault
```

### COW Test
```c
int pid = fork();
if(pid == 0) {
  // Child modifies memory
  buf[0] = 'x';  // Triggers COW
  // Child should have own copy now
}
```

### mmap Test
```c
int fd = open("largefile", O_RDONLY);
void *p = mmap(0, 10*1024*1024, PROT_READ, MAP_PRIVATE, fd, 0);
// Access memory
char c = ((char*)p)[0];  // Page fault, loads from file
munmap(p, 10*1024*1024);
```

### Swap Test
```c
// Allocate more than physical RAM
for(int i = 0; i < 1000; i++) {
  char *p = sbrk(PGSIZE);
  p[0] = i;  // Touch page to force allocation
}
// Some pages should be swapped out
```

## Key Concepts to Understand

Study before implementing:
- Page tables and TLB
- Page faults and fault handling
- Copy-on-write mechanism
- Memory-mapped I/O
- Page replacement algorithms (LRU, Clock, Second Chance)
- Reference counting and garbage collection
- Virtual memory areas (VMAs)
- Demand paging
- Thrashing and working set

## References

- MIT 6.S081: Lectures 9-12, Lab cow, Lab mmap
- xv6 Book: Chapter 3 (Page Tables)
- "Operating Systems: Three Easy Pieces" - Virtual Memory chapters
- Linux mmap(2), shmget(2) man pages
- RISC-V page table format documentation
- Source files: `kernel/vm.c`, `kernel/kalloc.c`, `kernel/trap.c`
