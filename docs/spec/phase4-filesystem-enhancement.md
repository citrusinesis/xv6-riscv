# Phase 4: File System Enhancement

**Duration**: 5-6 weeks
**Prerequisites**: Phase 3 complete (memory management enhanced)
**Next Phase**: Phase 5 (IPC Mechanism Implementation)

## Overview

Phase 4 modernizes xv6's simple file system with extent-based allocation, journaling for crash consistency, and symbolic links. These enhancements improve performance for large files, ensure data integrity across crashes, and add essential file system features.

**Core Objective**: Replace simple block allocation with extent-based allocation, implement write-ahead logging for crash consistency, add symbolic links, and optimize the VFS layer for performance.

## Objectives

### Primary Goals
1. Implement extent-based block allocation for efficient large file storage
2. Add journaling (write-ahead logging) for crash consistency
3. Implement symbolic links with circular detection
4. Add hard link support (reference counting for inodes)
5. Implement sparse file support (file holes)
6. Enhance VFS layer with pathname cache and directory entry cache
7. Establish comprehensive file system testing including crash recovery

### Learning Outcomes
- Understanding of modern file system design patterns
- Experience with crash consistency mechanisms
- Knowledge of metadata and data integrity techniques
- Skills in file system performance optimization
- Understanding of journaling trade-offs

## Functional Requirements

### FR1: Extent-Based Block Allocation

**Requirement**: Replace xv6's indirect block scheme with extent-based allocation for better large file performance.

**Current xv6 Block Allocation**:
- Direct blocks: 12 blocks directly in inode (48KB)
- Indirect block: 1 level of indirection (256 blocks = 1MB)
- Total file size limit: ~1MB
- Fragmentation: each block allocated separately
- Poor sequential I/O performance

**Extent-Based Allocation**:
- Extent: contiguous range of blocks
- Extent descriptor: (start_block, length)
- Inode contains array of extent descriptors
- Fewer metadata accesses for large files
- Better sequential I/O performance

**Extent Tree Structure**:
- Small files (<4 extents): extents stored directly in inode
- Large files (>4 extents): B-tree of extent descriptors
- Depth: automatically grows with file size
- Maximum file size: 4GB (configurable)

**Extent Descriptor Format**:
```
struct extent {
  uint32 start_block;    // First block number
  uint32 num_blocks;     // Number of contiguous blocks (1-32768)
  uint32 file_offset;    // Offset in file (in blocks)
  uint32 flags;          // Extent flags (allocated, unwritten, etc.)
};
```

**In-Inode Extents** (for small files):
- Store 4-6 extent descriptors directly in inode
- Covers most small files without indirection
- Fast access (no extra disk reads)

**Extent Tree** (for large files):
- Root extent in inode points to extent tree blocks
- Internal nodes: extent descriptors pointing to more nodes
- Leaf nodes: extent descriptors pointing to data blocks
- Balanced tree structure (B-tree or similar)

**Extent Allocation Strategy**:
- Best-fit: find smallest extent that fits request
- First-fit: find first extent that fits
- Delayed allocation: allocate extents on flush, not on write
- Preallocation: allocate more than requested for future growth

**Extent Splitting and Merging**:
- Split: when writing to middle of extent
- Merge: combine adjacent extents when possible
- Coalesce: merge free extents during allocation

**Benefits Over xv6 Indirect Blocks**:
- Fewer metadata blocks for large files
- Better sequential read/write performance
- Support for much larger files (>1MB)
- Reduced fragmentation

**File Holes** (sparse files):
- Extent with "unallocated" flag: no physical blocks
- Read from hole returns zeros
- Write to hole allocates extent
- Efficient for sparse files (e.g., databases, VM images)

**Success Criteria**:
- Large files (100MB+) use significantly fewer metadata blocks
- Sequential I/O performance improved by 2-5x
- File size limit increased to 4GB
- Sparse files save disk space
- All file operations correct (read, write, truncate)

### FR2: Journaling for Crash Consistency

**Requirement**: Ensure file system consistency after crashes using write-ahead logging (journaling).

**Current xv6 Logging**:
- Simple log-structured approach
- All operations logged before commit
- Synchronous: every operation waits for log commit
- Correct but slow

**Enhanced Journaling System**:

**Transaction Model**:
- Group related operations into atomic transactions
- Transaction states: active, committing, committed
- All-or-nothing: either all operations succeed or none
- Crash recovery: replay committed transactions, discard incomplete

**Journal Structure**:
- Dedicated journal area on disk (circular buffer)
- Journal header: transaction ID, sequence number, checksum
- Journal entries: logged operations (metadata writes)
- Journal commit block: marks transaction complete
- Journal superblock: head and tail pointers

**Write-Ahead Logging Protocol**:
1. Begin transaction: allocate transaction ID
2. Log all metadata changes to journal
3. Write journal commit block
4. Wait for commit block to reach disk (barrier)
5. Apply changes to in-place locations (checkpoint)
6. Mark journal entries as reclaimable

**Journal Entry Types**:
- Metadata block write: inode, directory entry, bitmap
- Block allocation/deallocation
- Inode allocation/deallocation
- Directory operations (create, unlink, rename)

**Metadata vs Data Journaling**:

**Metadata Journaling** (recommended):
- Journal only metadata (inodes, directories, bitmaps)
- Data written directly to disk (ordered mode)
- Faster than full journaling
- Data may be inconsistent after crash (acceptable for most uses)

**Full Data Journaling** (optional):
- Journal both metadata and data
- Slower but guarantees data consistency
- Write data twice (journal + in-place)
- Configurable per-mount or per-file

**Ordered Mode** (recommended default):
- Write data to disk before committing metadata transaction
- Ensures metadata doesn't point to garbage data
- Balance of performance and consistency
- Used by ext3/ext4 default mode

**Checkpointing**:
- Periodic: flush dirty blocks to disk
- Lazy: delay checkpointing to batch writes
- Eager: checkpoint immediately after commit (slower, simpler)
- On-demand: when journal space low

**Journal Wraparound**:
- Journal is circular buffer
- Head: oldest uncommitted transaction
- Tail: next write position
- When full: must checkpoint to free space
- Journal size: 1-10% of file system size (configurable)

**Crash Recovery**:
- On mount: check if clean shutdown
- If dirty: scan journal for committed transactions
- Replay committed transactions (redo log)
- Discard incomplete transactions
- Mark file system clean

**Barriers and Ordering**:
- Commit block must reach disk after all log entries
- Use disk write barriers (cache flush) or FUA (Force Unit Access)
- Critical for correctness: cannot rely on write reordering

**Success Criteria**:
- File system consistent after simulated crash
- No data loss for committed transactions
- Recovery completes in <1 second
- Performance overhead <20% vs non-journaled
- Extensive crash recovery testing (power-fail simulation)

### FR3: Symbolic Links

**Requirement**: Implement symbolic links (symlinks) with circular reference detection.

**Symbolic Link Semantics**:
- Symlink: file containing pathname of target
- Target can be absolute or relative path
- Target may or may not exist (dangling symlink allowed)
- Following symlink: resolve to target
- Operations on symlink vs target: configurable

**Symlink Inode**:
- Type: T_SYMLINK (new inode type)
- Size: length of target pathname
- Data: target pathname string
- Fast symlink: store short paths in inode (like ext4)
- Slow symlink: allocate data blocks for long paths

**Fast Symlink Optimization**:
- If target path <60 bytes: store in inode block array
- Avoid extra disk read for short symlinks
- Most symlinks are short (within directory)

**Path Resolution with Symlinks**:
- Walk pathname component by component
- If component is symlink: resolve to target
- Continue walking from target
- Repeat until no symlinks or max depth reached

**Circular Reference Detection**:
- Problem: symlink A -> B, B -> A (infinite loop)
- Solution: limit symlink traversal depth (e.g., 8 or 40)
- Return ELOOP error if depth exceeded
- Track depth during path resolution

**System Calls**:
- `symlink(target, linkpath)` - Create symbolic link
- `readlink(path, buf, size)` - Read symlink target
- `lstat(path, stat)` - Stat symlink itself, not target
- `stat(path, stat)` - Stat follows symlinks

**Following vs Not Following**:
- Most operations follow symlinks (open, stat)
- Some operations don't (lstat, unlink, rename)
- Consistent with POSIX semantics

**Symlink Permissions**:
- Symlink itself typically 0777 (permissions ignored)
- Access control on target, not symlink
- Exception: some systems check symlink ownership

**Success Criteria**:
- Symlinks correctly resolve to targets
- Circular symlinks detected and return ELOOP
- Dangling symlinks allowed (target doesn't exist)
- All symlink system calls work correctly
- Compatible with POSIX symlink semantics

### FR4: Hard Links (Reference Counting)

**Requirement**: Support multiple directory entries (hard links) pointing to same inode.

**Current xv6**: Limited hard link support (only for directories "." and "..")

**Enhanced Hard Links**:
- Multiple directory entries point to same inode
- Reference count: number of directory entries
- Unlink: decrement reference count
- Delete inode only when reference count reaches zero

**Inode Reference Count**:
- Field: `uint16 nlink` in inode
- Incremented on link()
- Decremented on unlink()
- Inode freed when nlink reaches 0 and no open file descriptors

**System Call**:
- `link(oldpath, newpath)` - Create hard link

**Restrictions on Hard Links**:
- Cannot hard link directories (prevents cycles in directory tree)
- Cannot hard link across file systems (inode numbers local)
- Both restrictions enforced by kernel

**Link Count Consistency**:
- Must update nlink atomically with directory entry
- Use transactions to ensure consistency
- Crash recovery must verify link counts

**Success Criteria**:
- Multiple hard links point to same inode
- Unlink decrements reference count
- File data persists until all links removed
- Cannot create directory hard links
- Link count consistent after crash

### FR5: Sparse File Support (File Holes)

**Requirement**: Support file holes (unallocated regions) for sparse files.

**Sparse File Concept**:
- File with "holes": regions with no allocated blocks
- Read from hole returns zeros
- Write to hole allocates blocks
- Efficient for sparse data (e.g., large files with gaps)

**Implementation with Extents**:
- Extent with UNALLOCATED flag represents hole
- No physical blocks allocated
- Read: detect unallocated extent, return zeros
- Write: allocate extent, write data

**Seek Operations**:
- `lseek(fd, offset, SEEK_SET)` - Set file position (can create hole)
- `lseek(fd, offset, SEEK_DATA)` - Find next data (skip holes)
- `lseek(fd, offset, SEEK_HOLE)` - Find next hole

**File Size vs Allocated Size**:
- File size: logical size (includes holes)
- Allocated size: actual disk blocks used
- Stat: report both sizes

**Success Criteria**:
- Can create sparse files with holes
- Read from hole returns zeros
- Allocated size less than logical size
- Hole detection works correctly

### FR6: VFS Layer Optimization

**Requirement**: Improve VFS performance with caching.

**Pathname Cache (dcache)**:
- Cache: pathname → inode mapping
- LRU eviction: discard old entries when full
- Invalidation: on unlink, rename, directory modifications
- Significantly speeds up repeated path lookups

**Directory Entry Cache**:
- Cache: directory inode → list of entries
- Avoids repeated directory scans
- Invalidation: on directory modifications

**Inode Cache** (already exists in xv6):
- Enhance: better eviction policy (LRU instead of first available)
- Pinning: keep frequently used inodes in cache

**Buffer Cache Optimization**:
- Read-ahead: prefetch sequential blocks
- Write-behind: batch writes for efficiency
- Adaptive: learn access patterns

**Success Criteria**:
- Pathname lookup 5-10x faster for cached paths
- Reduced disk I/O for repeated operations
- Cache hit rate >90% for typical workloads

### FR7: File System Testing and Fuzzing

**Requirement**: Comprehensive testing including crash recovery and fuzzing.

**Crash Recovery Tests**:
- Power-fail simulation: crash at random points
- Verify file system consistent after recovery
- Verify committed data not lost
- Automated testing: crash, recover, verify, repeat

**Fuzzing Targets**:
- Inode parser: malformed inodes
- Directory entry parser: malformed entries
- Extent tree: malformed extent descriptors
- Journal: malformed journal entries

**Fuzzing Tools**:
- AFL++ or libFuzzer
- Generate random file system images
- Mount and perform operations
- Detect crashes, hangs, assertion failures

**Concurrency Tests**:
- Multiple processes accessing same file
- Concurrent directory modifications
- Stress tests: many files, deep directories

**Success Criteria**:
- All crash recovery tests pass
- Zero crashes from fuzzing
- Concurrent operations correct
- File system stable under stress

## Non-Functional Requirements

### NFR1: Performance

**Throughput**:
- Sequential read: >50 MB/s (on virtio disk)
- Sequential write: >40 MB/s
- Random I/O: limited by disk (virtio ~1000 IOPS)

**Latency**:
- Small file create: <1ms
- Small file read: <0.5ms
- Directory lookup: <0.2ms (cached)

**Scalability**:
- Support files up to 4GB
- Support file systems up to 1TB (theoretical)
- Support >100,000 files (limited by inodes)

### NFR2: Correctness

**Crash Consistency**:
- File system consistent after any crash
- Committed transactions not lost
- Uncommitted transactions may be lost

**Data Integrity**:
- Checksums for journal (optional but recommended)
- Checksums for metadata (optional)
- Detect and report corruption

### NFR3: Compatibility

**On-Disk Format**:
- Design for forward compatibility
- Version number in superblock
- Reserved fields for future extensions

**POSIX Compliance**:
- Symlink semantics match POSIX
- File permissions and ownership
- Standard file system operations

### NFR4: Maintainability

**Code Organization**:
- Separate extent management from journaling
- Modular design for each feature
- Clear interfaces between VFS and FS implementation

**Debugging Support**:
- File system consistency checker (fsck)
- Dump utilities for structures
- Extensive assertions

## Design Constraints

### DC1: Single File System Type

**Constraint**: One file system implementation, not pluggable VFS.

**Rationale**: Supporting multiple file system types (VFS abstraction) is complex. Focus on one well-designed file system.

### DC2: No Delayed Allocation

**Constraint**: Allocate extents on write, not on flush.

**Rationale**: Delayed allocation requires complex space reservation and error handling. Immediate allocation is simpler.

### DC3: Synchronous Metadata Journaling

**Constraint**: Metadata transactions commit synchronously.

**Rationale**: Asynchronous commit requires complex group commit and flush handling. Synchronous is simpler and correct.

### DC4: No Online Resize

**Constraint**: File system size fixed at creation.

**Rationale**: Online resize requires complex extent and metadata relocation. Out of scope for educational OS.

### DC5: Limited Journal Size

**Constraint**: Journal size 10% of file system, max 128MB.

**Rationale**: Large journals waste space. Small journals sufficient for typical workloads.

### DC6: No Compression or Encryption

**Constraint**: No transparent compression or encryption.

**Rationale**: Compression and encryption add complexity. Can be added in future phases if desired.

## Testing Requirements

### Test Suite

**Extent-Based Allocation Tests**:
- `test_extent_small_file`: Small file uses in-inode extents
- `test_extent_large_file`: Large file uses extent tree
- `test_extent_fragmented`: File with many extents
- `test_extent_sparse`: Sparse file with holes
- `test_extent_truncate`: Truncate frees extents
- `test_extent_performance`: Sequential I/O performance

**Journaling Tests**:
- `test_journal_create`: Create file, verify journaled
- `test_journal_commit`: Verify transaction commits
- `test_journal_replay`: Crash recovery replays committed transactions
- `test_journal_wraparound`: Journal wraps correctly
- `test_journal_checkpoint`: Checkpointing frees journal space

**Crash Recovery Tests**:
- `test_crash_during_write`: Crash during file write
- `test_crash_during_create`: Crash during file creation
- `test_crash_during_unlink`: Crash during unlink
- `test_crash_during_rename`: Crash during rename
- `test_crash_random`: Random crash points, verify consistency
- Run 1000+ crash recovery iterations

**Symlink Tests**:
- `test_symlink_create`: Create and follow symlink
- `test_symlink_absolute`: Absolute path symlinks
- `test_symlink_relative`: Relative path symlinks
- `test_symlink_circular`: Detect circular symlinks (ELOOP)
- `test_symlink_dangling`: Dangling symlinks allowed
- `test_symlink_depth`: Max depth enforcement

**Hard Link Tests**:
- `test_hardlink_create`: Create hard links
- `test_hardlink_refcount`: Reference count correct
- `test_hardlink_unlink`: Unlink decrements count
- `test_hardlink_directory`: Cannot link directories (EPERM)

**Sparse File Tests**:
- `test_sparse_create`: Create sparse file
- `test_sparse_read`: Read from hole returns zeros
- `test_sparse_write`: Write to hole allocates blocks
- `test_sparse_stat`: Allocated size < logical size

**VFS Cache Tests**:
- `test_dcache_hit`: Pathname cache hit rate
- `test_dcache_invalidate`: Cache invalidated on unlink
- `test_inode_cache`: Inode cache eviction

**Fuzzing Tests**:
- `fuzz_inode`: Fuzz inode structure
- `fuzz_dirent`: Fuzz directory entries
- `fuzz_extent`: Fuzz extent descriptors
- `fuzz_journal`: Fuzz journal entries
- Run 24+ hours of fuzzing

**Concurrency Tests**:
- `test_concurrent_write`: Multiple writers to same file
- `test_concurrent_create`: Concurrent file creation
- `test_concurrent_unlink`: Concurrent unlink
- `test_rename_race`: Rename race conditions

### Success Criteria

**Functional Correctness**:
- [ ] All extent allocation tests pass
- [ ] All journaling tests pass
- [ ] All crash recovery tests pass (1000+ iterations)
- [ ] All symlink tests pass
- [ ] All hard link tests pass
- [ ] All sparse file tests pass
- [ ] Original xv6 file tests pass

**Performance Validation**:
- [ ] Sequential read >50 MB/s
- [ ] Sequential write >40 MB/s
- [ ] Large file I/O 2-5x faster than xv6
- [ ] Pathname lookup 5-10x faster with cache

**Robustness**:
- [ ] No crashes from fuzzing (24+ hours)
- [ ] File system consistent after all crash tests
- [ ] Concurrent operations correct under stress

## Implementation Guidance

### Phase 4 Implementation is NOT Provided

This specification describes WHAT to build, not HOW:

**What You Should Figure Out**:
- How to design extent tree structure
- How to implement journal wraparound
- How to handle crash recovery edge cases
- How to implement pathname cache eviction
- How to fuzz file system structures

**What You Should Research**:
- ext4 extent tree design (Linux kernel documentation)
- XFS extent allocation
- ext3/ext4 journaling (JBD/JBD2)
- POSIX symlink and hard link semantics
- File system fuzzing techniques

**What You Should Design**:
- Extent descriptor layout
- Journal entry format
- Transaction commit protocol
- Pathname cache data structures
- Crash recovery algorithm

### Recommended Implementation Order

1. **Week 1**: Extent-based allocation
   - Design extent descriptor format
   - Implement in-inode extents (small files)
   - Modify file read/write for extents
   - Test with small files

2. **Week 2**: Extent tree and large files
   - Implement extent tree (B-tree)
   - Handle extent splitting and merging
   - Support large files (>1MB)
   - Test with large files

3. **Week 3**: Journaling infrastructure
   - Design journal format
   - Implement transaction begin/commit
   - Implement journal write
   - Test basic journaling

4. **Week 4**: Crash recovery
   - Implement journal replay
   - Implement checkpointing
   - Test crash recovery scenarios
   - Run extensive crash tests

5. **Week 5**: Symlinks and hard links
   - Implement symlink creation and resolution
   - Implement circular detection
   - Implement hard link reference counting
   - Test all link operations

6. **Week 6**: VFS optimization and polish
   - Implement pathname cache
   - Implement sparse file support
   - Optimize buffer cache
   - Comprehensive testing and fuzzing

### Common Pitfalls

**Pitfall 1: Journal Commit Ordering**
- Commit block must be written AFTER log entries
- Use write barriers or FUA to enforce ordering
- Failure causes corruption on replay

**Pitfall 2: Extent Tree Corruption**
- Balancing B-tree is complex and error-prone
- Use extensive assertions
- Test with random operations

**Pitfall 3: Reference Count Errors**
- Off-by-one in hard link counts
- Must be atomic with directory entry changes
- Use transactions

**Pitfall 4: Symlink Path Buffer Overflow**
- Target path can be up to PATH_MAX (e.g., 4096 bytes)
- Must check lengths and prevent overflow
- Security: validate all paths

**Pitfall 5: Cache Invalidation**
- Stale cache entries cause incorrect behavior
- Must invalidate on rename, unlink, directory mods
- Race conditions in concurrent access

**Pitfall 6: Crash Recovery Non-Idempotence**
- Replay must be idempotent (can replay multiple times)
- Use sequence numbers or checksums
- Test by replaying multiple times

## References

### Extent-Based File Systems

**Papers and Documentation**:
- ext4 Extent Trees (Linux kernel documentation)
- "Analysis of Extent-Based Storage Allocation" (Schmuck & Haskin, 1999)
- XFS Allocation Groups and Extents (SGI documentation)

**Implementations**:
- Linux ext4: fs/ext4/extents.c
- XFS: fs/xfs/libxfs/xfs_bmap.c
- HFS+: Apple file system with extents

### Journaling File Systems

**Classic Papers**:
- "A Log-Structured File System" (Rosenblum & Ousterhout, 1992)
- "Journaling the Linux ext2fs Filesystem" (Tweedie, 1998)
- "Optimizing the Metadata Performance of JBD2" (Chidambaram et al., 2014)

**Implementations**:
- Linux JBD2 (Journal Block Device): fs/jbd2/
- ext3/ext4 journaling: fs/ext4/
- XFS journaling: fs/xfs/xfs_log.c

**Crash Consistency**:
- "All File Systems Are Not Created Equal" (Pillai et al., 2014)
- "ALICE: Application-Level Intelligent Crash Explorer" (Gunawi et al., 2006)

### Symbolic Links

**Standards**:
- POSIX.1-2008: Symbolic links specification
- Linux symlink(2) and readlink(2) man pages

**Implementation References**:
- Linux VFS: fs/namei.c (path resolution)
- FreeBSD symlink implementation

### File System Fuzzing

**Tools and Techniques**:
- "JUXTA: Cross-checking File Systems with Model Checking" (Min et al., 2014)
- "Finding Crash-Consistency Bugs with Bounded Black-Box Testing" (Mohan et al., 2018)
- AFL++ file system fuzzing
- syzkaller for file system fuzzing

### xv6 File System

**Study Files**:
- `kernel/fs/fs.c` - File system implementation
- `kernel/fs/bio.c` - Buffer cache
- `kernel/fs/log.c` - Simple logging
- `kernel/fs/file.c` - File descriptor layer
- xv6 Book Chapter 8 - File system

### File System Design

**Textbooks**:
- "Operating Systems: Three Easy Pieces" - Chapters 39-44 (File Systems)
- "Modern Operating Systems" (Tanenbaum) - Chapter 4 (File Systems)
- "Operating System Concepts" (Silberschatz) - Chapters 13-15 (File Systems)

**Advanced Topics**:
- "File Systems Unfit as Distributed Storage Backends: Lessons from 10 Years of Ceph Evolution" (Weil et al., 2019)
- "The Design and Implementation of a Log-Structured File System" (Rosenblum & Ousterhout, 1992)

## Appendix: Data Structure Examples

**Note**: These are EXAMPLES for understanding, not complete implementations.

### Example: Extent Descriptor

```c
// In kernel/fs/include/extent.h

#define EXTENT_FLAG_ALLOCATED   0x01
#define EXTENT_FLAG_UNWRITTEN   0x02  // For preallocation
#define EXTENT_FLAG_SPARSE      0x04  // Hole in file

struct extent {
  uint32 file_block;     // Logical block in file
  uint32 disk_block;     // Physical block on disk
  uint32 num_blocks;     // Number of contiguous blocks
  uint32 flags;          // Extent flags
};

// In-inode extent storage (for small files)
#define INODE_EXTENTS 4

struct dinode {
  // ... existing fields ...
  struct extent extents[INODE_EXTENTS];  // Direct extents
  uint32 extent_tree_block;              // If more extents needed
};
```

### Example: Journal Structure

```c
// In kernel/fs/include/journal.h

#define JOURNAL_MAGIC 0x4A52424C  // "JRBL"

struct journal_header {
  uint32 magic;          // Magic number
  uint32 txn_id;         // Transaction ID
  uint32 seq_num;        // Sequence number
  uint32 num_entries;    // Number of entries in this transaction
  uint32 checksum;       // Header checksum
};

struct journal_entry {
  uint32 block_num;      // Block number to write
  uint32 checksum;       // Entry checksum
  char data[BSIZE];      // Block data
};

struct journal_commit {
  uint32 magic;          // JOURNAL_MAGIC
  uint32 txn_id;         // Transaction ID
  uint32 checksum;       // Commit block checksum
};
```

### Example: Symlink Inode

```c
// In kernel/fs/include/fs.h

#define T_DIR     1
#define T_FILE    2
#define T_DEVICE  3
#define T_SYMLINK 4   // New type

// Fast symlink: path stored in inode data blocks
#define FAST_SYMLINK_MAX 60

struct dinode {
  uint16 type;           // File type (T_SYMLINK for symlinks)
  // ... other fields ...
  union {
    uint32 addrs[NDIRECT+1];  // For regular files
    char target[FAST_SYMLINK_MAX];  // For fast symlinks
  };
};
```

## Appendix: Crash Recovery Pseudocode

**Note**: This is high-level logic for understanding, not complete implementation.

```
journal_recovery():
  read journal superblock
  if file_system_clean:
    return  // No recovery needed

  txn_id = journal_superblock.oldest_txn
  while txn_id <= journal_superblock.newest_txn:
    header = read_journal_header(txn_id)
    if header.magic != JOURNAL_MAGIC:
      break  // Incomplete transaction, stop

    entries = read_journal_entries(header)
    commit = read_journal_commit(txn_id)

    if commit.magic == JOURNAL_MAGIC and commit.txn_id == txn_id:
      // Transaction committed, replay it
      for entry in entries:
        write_block(entry.block_num, entry.data)
      flush_disk()
    else:
      // Transaction not committed, discard
      break

    txn_id++

  mark_filesystem_clean()
```

---

**Phase Status**: Ready for Implementation
**Estimated Effort**: 120-160 hours over 5-6 weeks
**Prerequisites**: Phase 3 complete (memory management)
**Outputs**: Extent-based FS, journaling, symlinks, crash recovery tests
**Next Phase**: [Phase 5: IPC Mechanism Implementation](phase5-ipc-mechanism.md)
