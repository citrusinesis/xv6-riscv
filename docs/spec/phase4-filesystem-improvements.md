# Phase 4: Filesystem Improvements

**Duration**: 4-5 weeks
**Prerequisites**: Phase 1

## Objectives

Extend xv6 filesystem with modern features: large files, symbolic links, improved journaling, and performance optimizations.

## Features to Implement

### 1. Large File Support

Current xv6 limitation: Max file size = 12 direct blocks + 1 indirect block = 140 blocks = 70KB

**Requirements**:
- Add double indirect blocks support
- Max file size: 12 + 128 + 128*128 = 16524 blocks ≈ 8MB
- Optionally add triple indirect for even larger files
- Modify `struct dinode` in `kernel/fs.h`:
  ```c
  struct dinode {
    // ... existing fields
    uint addrs[NDIRECT+2];  // Direct, indirect, double indirect
  };
  ```
- Update functions: `bmap()`, `itrunc()`

**System Call** (enhancement):
- `int fstat(int fd, struct stat *st)` - Should report correct file size

### 2. Symbolic Links

**System Call**: `int symlink(char *target, char *path)`

**Requirements**:
- New inode type: `T_SYMLINK`
- Store target path in first data block
- Add `readlink(char *path, char *buf, int bufsize)` syscall
- Modify `open()` to follow symlinks (with loop detection, max depth = 8)
- `O_NOFOLLOW` flag option
- Modify `stat()` to handle symlinks (lstat vs stat behavior)

**Files to Modify**:
- `kernel/fs.h` - Add T_SYMLINK type
- `kernel/sysfile.c` - Implement symlink(), readlink()
- `kernel/fs.c` - Modify namei() for link resolution

### 3. Hard Link Improvements

**Requirements**:
- Fix hard link reference counting
- Prevent hardlinks to directories (except . and ..)
- Implement proper cleanup in `unlink()`
- Add link count to `stat` output

**Enhanced**:
- `int link(char *old, char *new)` - Already exists, ensure it's robust
- Prevent dangling references

### 4. Extent-Based Block Allocation

Current: Block-by-block allocation (slow, fragmented)

**Requirements**:
- Implement extent allocation: contiguous block ranges
- Extent structure:
  ```c
  struct extent {
    uint start_block;  // Starting block number
    uint length;       // Number of contiguous blocks
  };
  ```
- Modify block allocator: `balloc()` → `balloc_extent(int nblocks)`
- Try to allocate contiguous blocks when possible
- Benefits: Reduced seek time, better performance

**Optional**: Extent tree instead of flat array

### 5. Improved Journaling

Current xv6 has simple logging, enhance it:

**Requirements**:
- Increase log size (current: 30 blocks)
- Implement group commit (batch multiple transactions)
- Add checksum verification to log blocks
- Async log writes (write-behind)
- Modify `kernel/log.c`

**Features**:
- Increase `LOGSIZE` in `kernel/param.h`
- Add log block checksums
- Implement `begin_op_sync()` vs `begin_op_async()`

### 6. Directory Improvements

**Features**:
- Directory caching (cache frequently accessed directories)
- Faster directory lookup (hash table instead of linear scan)
- Larger directory support (current limit: 512 entries)

**Requirements**:
- Implement directory entry cache (dcache)
- Hash-based lookup for large directories
- Support for directory entries beyond first block

**System Calls** (enhancements):
- Make `ls` faster with directory caching

### 7. Block Cache Optimization

**Requirements**:
- Implement LRU replacement policy (current is simpler)
- Add prefetching for sequential reads
- Increase buffer cache size (modify `NBUF` in `kernel/param.h`)
- Add cache statistics: hit rate, miss rate

**System Call**:
- `int getcachestats(struct cachestats *stats)` - Return cache performance

**Enhancement**:
- Read-ahead mechanism in `readi()` for sequential access

### 8. File Access Timestamps

**Requirements**:
- Add timestamps to `struct dinode`:
  - `uint ctime` - Creation time
  - `uint mtime` - Modification time
  - `uint atime` - Access time
- Update timestamps appropriately:
  - `ctime`: When inode created
  - `mtime`: When file content modified
  - `atime`: When file read (optional: can disable for performance)
- Include timestamps in `stat` structure

**System Call**:
- `int utime(char *path, uint atime, uint mtime)` - Set timestamps

### 9. File Permissions Enhancement

Current xv6 has minimal permissions, add:

**Requirements**:
- Full UNIX permission bits: rwxrwxrwx (owner, group, other)
- Modify `struct dinode`:
  - `uint mode` - Permission bits
  - `uint uid` - Owner user ID
  - `uint gid` - Group ID
- Implement permission checking in `open()`, `read()`, `write()`
- Add `chmod()`, `chown()` system calls

**System Calls**:
- `int chmod(char *path, uint mode)` - Change file permissions
- `int chown(char *path, uint uid, uint gid)` - Change owner

### 10. Filesystem Statistics

**System Call**: `int statfs(struct fsinfo *info)`

**Requirements**:
- Return filesystem information:
  - Total blocks
  - Free blocks
  - Total inodes
  - Free inodes
  - Block size
  - Maximum file size
- Implement by scanning bitmap and inode table

**User Program**: `df` - Display filesystem usage

## Deliverables

- [ ] Large file support with double-indirect blocks
- [ ] Symbolic links fully functional
- [ ] Hard links robust and safe
- [ ] Extent-based allocation (at least basic version)
- [ ] Enhanced journaling with checksums
- [ ] Directory cache implementation
- [ ] LRU block cache with statistics
- [ ] Timestamps on all files
- [ ] Full UNIX permissions
- [ ] Filesystem statistics system call
- [ ] User programs:
  - `ln -s` - Create symbolic link
  - `readlink` - Read symbolic link
  - `df` - Filesystem usage
  - `du` - Directory usage
- [ ] Test suite:
  - Large file creation and verification
  - Symbolic link traversal and loops
  - Permission enforcement tests
  - Extent allocation verification
  - Cache hit rate measurement
  - Crash recovery tests (journaling)
- [ ] Performance benchmarks:
  - File creation throughput
  - Sequential read/write bandwidth
  - Random read/write IOPS
  - Directory listing performance
  - Before/after comparison

## Success Criteria

1. **Large Files**: Create and read 5MB+ files successfully
2. **Symlinks**: Follow chains of symlinks, detect loops
3. **Permissions**: Enforce read/write/execute permissions correctly
4. **Performance**: 20%+ improvement in sequential I/O
5. **Reliability**: Survive crashes without data loss (journaling)
6. **Compatibility**: All existing filesystem tests pass

## Testing

### Large File Test
```c
// Create 5MB file
int fd = open("bigfile", O_CREATE | O_RDWR);
for(int i = 0; i < 5000; i++) {
  write(fd, buffer, 1024);  // Write 1KB at a time
}
close(fd);

// Verify
struct stat st;
stat("bigfile", &st);
assert(st.size == 5120000);
```

### Symlink Test
```c
// Create chain
symlink("target", "link1");
symlink("link1", "link2");
open("link2", O_RDONLY);  // Should open "target"

// Detect loop
symlink("loop2", "loop1");
symlink("loop1", "loop2");
open("loop1", O_RDONLY);  // Should return -1 (ELOOP)
```

### Permission Test
```c
chmod("file", 0644);  // rw-r--r--
// Try to execute: should fail
exec("file");  // Error: permission denied
```

## Key Concepts to Understand

Study before implementing:
- xv6 filesystem structure (superblock, inodes, data blocks, bitmap)
- Buffer cache mechanism (`kernel/bio.c`)
- Logging/journaling (`kernel/log.c`)
- Pathname resolution (`kernel/fs.c: namei()`)
- Block allocation (`kernel/fs.c: balloc()`)
- Inode structure and operations
- File descriptor layer vs inode layer

## References

- MIT 6.S081: Lectures 13-15, Lab fs
- xv6 Book: Chapter 8 (File System)
- "Operating Systems: Three Easy Pieces" - File System chapters
- Linux ext2/ext3 filesystem documentation
- Source files: `kernel/fs.c`, `kernel/file.c`, `kernel/bio.c`, `kernel/log.c`
