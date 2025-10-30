# Phase 6: Hybrid Kernel Transition - Server Separation

**Duration**: 6-8 weeks
**Prerequisites**: Phase 5 complete (IPC mechanism implemented)
**Next Phase**: Phase 7 (PCIe Infrastructure) or Phase 10 (Optimization)

## Overview

Phase 6 represents the most significant architectural transformation of the project: moving the file system and disk driver from kernel space to user space. This creates a hybrid kernel architecture where core services run in user space, communicating with the kernel via IPC.

**Core Objective**: Transform xv6 from a monolithic kernel to a hybrid kernel by implementing file system and disk driver as user-space servers, establishing a clean kernel-user boundary, and ensuring system stability and security with isolated services.

**Critical Milestone**: This phase fundamentally changes the OS architecture. Success here validates the entire project's direction toward a Darwin/XNU-inspired hybrid kernel.

## Objectives

### Primary Goals
1. Move file system implementation to user-space server
2. Move disk driver to user-space driver server
3. Implement VFS as kernel-user IPC bridge
4. Manage I/O privilege separation and DMA access
5. Enable crash recovery of user-space servers without kernel reboot
6. Establish inter-server communication patterns
7. Validate performance is within acceptable bounds (<20% overhead)

### Learning Outcomes
- Understanding hybrid/microkernel architecture trade-offs
- Experience with kernel-user boundary design
- Knowledge of device driver isolation techniques
- Skills in system architecture decomposition
- Understanding of privilege separation and security

## Functional Requirements

### FR1: File System Server Architecture

**Requirement**: Implement file system as user-space server process communicating via IPC.

**File System Server (FSS) Design**:
- User-space process with special privileges
- Starts early in boot sequence (before multi-user)
- Receives file system operations via IPC from kernel VFS
- Maintains file system state (buffer cache, inode cache)
- Performs all file system logic (allocation, directories, journaling)
- Communicates with disk driver server for I/O

**FS Server Responsibilities**:
- Inode allocation and management
- Block allocation and extent management
- Directory operations (lookup, create, unlink)
- File operations (read, write, truncate)
- Journaling and crash recovery
- Buffer cache management
- File system consistency checking (fsck)

**FS Server State**:
- In-memory inode cache
- Buffer cache (cached disk blocks)
- Journal state
- Free block and inode bitmaps
- Open file table

**FS Server Lifecycle**:
1. Boot: kernel starts FS server before init
2. Initialize: FS server mounts root file system
3. Ready: FS server registers with kernel VFS
4. Running: services requests from kernel
5. Crash: kernel detects death, can restart FS server
6. Recovery: FS server replays journal on restart

**FS Server Interface** (IPC messages):
- `fs_lookup(path)` → inode number
- `fs_create(dir_ino, name, type)` → inode number
- `fs_unlink(dir_ino, name)` → success/error
- `fs_read(ino, offset, size, buf)` → data
- `fs_write(ino, offset, size, buf)` → success/error
- `fs_getattr(ino)` → file attributes (size, permissions, etc.)
- `fs_setattr(ino, attrs)` → success/error
- `fs_sync(ino)` → flush to disk

**Success Criteria**:
- FS server starts successfully at boot
- FS server handles all file system operations
- FS server maintains file system consistency
- FS server can crash and restart without data loss
- FS server performance within 20% of in-kernel implementation

### FR2: Disk Driver Server Architecture

**Requirement**: Implement disk driver as user-space server with DMA and interrupt access.

**Disk Driver Server (DDS) Design**:
- User-space process with device access privileges
- Manages virtio disk device (in QEMU)
- Handles interrupts via kernel upcalls
- Manages DMA buffers
- Provides block I/O interface to FS server

**DDS Responsibilities**:
- Device initialization (virtio setup)
- Request queue management (virtio queue)
- DMA buffer allocation and mapping
- Interrupt handling (via kernel upcall)
- Request completion notification
- Error handling and retry

**DDS Privilege Management**:
- MMIO access: kernel maps device registers to DDS
- DMA access: kernel pins and maps DMA buffers
- Interrupt access: kernel delivers interrupts via IPC
- No direct hardware access (kernel mediates)

**DDS Interface** (IPC messages):
- `disk_read(block_num, buf)` → data + completion status
- `disk_write(block_num, buf)` → completion status
- `disk_sync()` → flush write cache
- `disk_get_info()` → disk size, block size, etc.

**DMA Buffer Management**:
- FS server allocates buffer
- DDS requests kernel to pin buffer (prevent swapping)
- Kernel maps buffer physical address for DMA
- DDS programs virtio queue with physical addresses
- Completion: kernel delivers interrupt to DDS via IPC
- DDS notifies FS server of completion

**Interrupt Handling**:
- Hardware interrupt: kernel receives interrupt
- Kernel identifies DDS as handler
- Kernel sends IPC message to DDS (interrupt notification)
- DDS handles interrupt (check virtio queue, complete requests)
- DDS replies to kernel (interrupt handled)
- DDS notifies FS server of I/O completion

**Success Criteria**:
- DDS successfully initializes virtio disk
- DDS handles read/write requests
- DDS correctly manages DMA buffers
- DDS handles interrupts via kernel upcalls
- I/O performance within 20% of in-kernel driver

### FR3: Kernel VFS Layer (IPC Bridge)

**Requirement**: Kernel VFS routes file system operations to FS server via IPC.

**Kernel VFS Responsibilities**:
- Expose file system system calls (open, read, write, etc.)
- Translate system calls to IPC messages to FS server
- Manage file descriptors and open file table
- Perform security checks (permissions, capabilities)
- Cache pathname lookups (dcache)
- Handle FS server crashes (error propagation or restart)

**System Call Translation**:
```
User process: open("/etc/passwd", O_RDONLY)
  ↓
Kernel VFS: sys_open()
  - Parse path: "/etc/passwd"
  - Security check: can user access?
  - IPC to FS server: fs_lookup("/etc/passwd")
  ↓
FS Server: handles fs_lookup()
  - Walk directory tree
  - Find inode
  - IPC reply: inode number + attributes
  ↓
Kernel VFS: receives reply
  - Allocate file descriptor
  - Store inode number in fd table
  - Return fd to user process
```

**File Descriptor Management**:
- Kernel maintains per-process fd table
- Each fd contains: inode number, offset, flags
- Inode number is handle to FS server
- Read/write operations: kernel uses inode number in IPC to FS

**Pathname Cache** (in kernel):
- Cache: pathname → inode number
- Speeds up repeated lookups
- Invalidated by FS server on unlink, rename, etc.
- Reduces IPC overhead

**Security Enforcement** (in kernel):
- Permission checks: kernel checks before IPC
- FS server trusted (runs as root equivalent)
- Kernel enforces user permissions
- FS server can trust kernel's checks

**FS Server Crash Handling**:
- Kernel detects FS server death (port becomes dead)
- Options:
  1. Return error to all file operations (ENOTAVAIL)
  2. Restart FS server, replay journal, continue
  3. Kernel panic (if FS is critical)
- Recommended: restart FS server with journaling

**Success Criteria**:
- All file system calls work transparently
- User processes unaware of kernel-user split
- Pathname cache reduces IPC overhead
- Security checks enforced
- FS server crash handled gracefully

### FR4: Inter-Server Communication

**Requirement**: FS server and disk driver server communicate efficiently.

**Communication Pattern**:
```
FS Server → Disk Driver:
  IPC: disk_read(block_num, buffer)

Disk Driver → Kernel:
  Request: pin buffer, get physical address

Kernel → Disk Driver:
  Reply: buffer pinned, PA = 0x80100000

Disk Driver:
  Program virtio queue with PA

[Interrupt occurs]

Kernel → Disk Driver:
  IPC: interrupt notification

Disk Driver:
  Check virtio queue, I/O complete

Disk Driver → FS Server:
  IPC reply: disk_read complete, data in buffer
```

**Request/Reply Pattern**:
- FS server sends request to DDS
- DDS processes asynchronously
- DDS replies when I/O completes
- FS server can handle multiple outstanding requests

**Buffer Sharing**:
- FS server and DDS share buffer via zero-copy IPC (Phase 5)
- Kernel manages buffer mapping
- Avoids data copying between servers

**Synchronization**:
- FS server can block waiting for I/O completion
- Or: use asynchronous IPC (Phase 5 non-blocking)
- Multiple I/O requests can be in flight

**Success Criteria**:
- FS and DDS communicate efficiently
- Buffer sharing works correctly (zero-copy)
- I/O completion notifications reliable
- No deadlocks between servers

### FR5: Privilege Management and Security

**Requirement**: Isolate server privileges and enforce security boundaries.

**Privilege Separation**:
- Kernel: full hardware access, highest privilege
- FS Server: file system state access, medium privilege
- Disk Driver: device MMIO/DMA access, medium privilege
- User processes: no special privileges, lowest

**Capability-Based Access**:
- Servers hold port capabilities (Phase 5)
- Only FS server can access FS server port
- Only DDS can access disk driver port
- Kernel mediates all communication

**MMIO Access Control**:
- Kernel maps device registers to DDS address space
- Only DDS can access these pages
- Other processes cannot access device registers
- Kernel enforces page table protections

**DMA Access Control**:
- Only kernel can pin pages for DMA
- DDS requests pinning via system call
- Kernel verifies request is valid
- Kernel provides physical addresses (DDS can't translate)

**Interrupt Routing**:
- Kernel receives all interrupts
- Kernel routes to appropriate server (DDS)
- Servers cannot intercept other servers' interrupts

**Security Properties**:
- FS server crash doesn't crash kernel
- DDS crash doesn't crash kernel
- User process cannot directly access disk
- Servers isolated from each other (except via IPC)

**Success Criteria**:
- Privilege separation enforced
- Security properties verified
- Attempted privilege escalation blocked
- Servers cannot access each other's state

### FR6: Server Crash Recovery

**Requirement**: System remains functional after server crash.

**Crash Detection**:
- Kernel detects server death (process exit or fault)
- Port becomes dead (send to dead port returns error)
- Kernel logs crash for debugging

**FS Server Crash Recovery**:
1. Kernel detects FS server crash
2. Return error to in-flight requests (ENOTAVAIL)
3. Kernel restarts FS server
4. FS server mounts file system
5. FS server replays journal (crash recovery)
6. FS server signals ready to kernel
7. Kernel resumes file operations

**Disk Driver Server Crash Recovery**:
1. Kernel detects DDS crash
2. Kernel restarts DDS
3. DDS reinitializes device
4. DDS resumes I/O operations
5. FS server retries failed I/O requests

**Crash Recovery Challenges**:
- In-flight IPC requests must be handled
- File descriptor state must be preserved (kernel handles this)
- Journal replay ensures file system consistency
- Device must be reinitialized correctly

**Testing Crash Recovery**:
- Automated tests: kill FS server, verify recovery
- Automated tests: kill DDS, verify recovery
- Verify no data loss after recovery
- Verify no file system corruption

**Success Criteria**:
- FS server can be killed and restarted
- DDS can be killed and restarted
- File system consistent after FS server crash
- I/O resumes after DDS crash
- No kernel crash due to server crash

### FR7: Performance Optimization

**Requirement**: Minimize overhead from kernel-user split.

**Performance Goals**:
- File operations: <20% overhead vs monolithic
- I/O throughput: <20% reduction
- Latency: <100μs overhead per operation

**Optimization Strategies**:

**IPC Optimization** (from Phase 5):
- Fast path for small messages
- Zero-copy for buffer I/O
- Direct handoff when possible
- Minimize context switches

**Caching** (in kernel VFS):
- Pathname cache: avoid FS server lookups
- Inode attribute cache: avoid getattr calls
- Read-ahead: batch read requests
- Write-behind: batch write requests

**Batching**:
- Group multiple small operations into one IPC
- Example: readdir() returns multiple entries
- Reduces IPC overhead

**Asynchronous I/O**:
- FS server submits multiple I/O requests to DDS
- DDS processes queue asynchronously
- Overlaps computation and I/O

**Buffer Management**:
- FS server maintains buffer cache
- Zero-copy buffer sharing with DDS
- Minimize buffer copying

**Benchmark and Profile**:
- Measure overhead of IPC vs direct call
- Identify bottlenecks (IPC, context switch, copying)
- Optimize hot paths

**Success Criteria**:
- File system operations <20% slower than monolithic
- I/O throughput <20% lower than monolithic
- Latency overhead measured and documented
- Performance acceptable for educational purposes

## Non-Functional Requirements

### NFR1: Reliability

**Fault Isolation**:
- FS server crash doesn't crash kernel
- DDS crash doesn't crash kernel
- User process crash doesn't affect servers

**Availability**:
- System continues running after server restart
- Minimal downtime during server crash recovery
- No data loss from server crash (journaling)

### NFR2: Security

**Isolation**:
- Servers cannot access each other's memory
- Servers cannot access kernel memory
- User processes cannot access server memory

**Access Control**:
- File permissions enforced by kernel
- Device access restricted to DDS
- IPC ports capability-protected

### NFR3: Performance

**Throughput**:
- File I/O: >40 MB/s sequential read
- File I/O: >30 MB/s sequential write
- Metadata ops: >1000/sec (create, unlink)

**Latency**:
- File open: <1ms
- Small read/write: <0.5ms
- IPC overhead: <100μs per operation

### NFR4: Maintainability

**Code Organization**:
- Clear separation: kernel VFS, FS server, DDS
- Well-defined interfaces (IPC messages)
- Modular design for future servers

**Debugging**:
- Server logging and tracing
- Kernel-server communication logs
- Crash dumps for debugging

### NFR5: Compatibility

**User Space**:
- All existing user programs work unchanged
- POSIX file system semantics preserved
- System call interface unchanged

## Design Constraints

### DC1: Single File System Server

**Constraint**: One FS server instance, not distributed or replicated.

**Rationale**: Multiple FS servers require complex synchronization. Single server sufficient for educational OS.

### DC2: Synchronous File System Operations

**Constraint**: File system calls block until FS server replies.

**Rationale**: Asynchronous file I/O complicates error handling and semantics. Synchronous is simpler.

### DC3: No Hot-Pluggable Drivers

**Constraint**: DDS must be present at boot, cannot be loaded dynamically.

**Rationale**: Dynamic driver loading requires complex module infrastructure. Static drivers sufficient.

### DC4: Single Disk Device

**Constraint**: One disk device (virtio block) supported.

**Rationale**: Multiple disks require partition management and device enumeration. Single disk simplifies.

### DC5: No Network File Systems

**Constraint**: No NFS, SMB, or distributed file systems.

**Rationale**: Network file systems require networking stack (Phase 8). Local FS only for now.

### DC6: Trusted Servers

**Constraint**: FS server and DDS are trusted (run as root equivalent).

**Rationale**: Full server sandboxing requires complex security mechanisms. Trust model simpler for education.

## Testing Requirements

### Test Suite

**FS Server Tests**:
- `test_fs_server_start`: FS server boots successfully
- `test_fs_server_mount`: FS server mounts file system
- `test_fs_server_operations`: All file operations via FS server
- `test_fs_server_crash`: FS server crash and recovery
- `test_fs_server_journal`: Journal replay after crash

**Disk Driver Tests**:
- `test_dds_start`: DDS starts and initializes device
- `test_dds_read_write`: DDS handles I/O requests
- `test_dds_interrupt`: Interrupt handling via kernel upcall
- `test_dds_dma`: DMA buffer management
- `test_dds_crash`: DDS crash and recovery

**Kernel VFS Tests**:
- `test_vfs_system_calls`: All file system calls work
- `test_vfs_ipc_bridge`: VFS to FS server IPC
- `test_vfs_security`: Permission checks enforced
- `test_vfs_cache`: Pathname caching works
- `test_vfs_fd_management`: File descriptors managed correctly

**Inter-Server Communication Tests**:
- `test_fs_to_dds`: FS server to DDS communication
- `test_buffer_sharing`: Zero-copy buffer sharing
- `test_io_completion`: I/O completion notifications
- `test_concurrent_io`: Multiple I/O requests in flight

**Crash Recovery Tests**:
- `test_fs_crash_recovery`: Kill FS server during operation
- `test_dds_crash_recovery`: Kill DDS during I/O
- `test_journal_replay`: Verify data after crash recovery
- `test_crash_stress`: Repeated crashes and recovery

**Performance Tests**:
- `bench_file_io`: Sequential and random I/O throughput
- `bench_metadata`: Create, unlink, stat operations
- `bench_ipc_overhead`: Measure IPC overhead
- `bench_vs_monolithic`: Compare with Phase 4 performance

**End-to-End Tests**:
- `test_all_usertests`: All xv6 usertests pass
- `test_shell`: Shell works normally
- `test_compiletest`: Can compile programs
- `test_stress`: Long-running stress test

### Success Criteria

**Functional Correctness**:
- [ ] FS server implements all file system operations
- [ ] DDS handles all disk I/O
- [ ] Kernel VFS routes all operations correctly
- [ ] All xv6 usertests pass
- [ ] User programs work unchanged

**Crash Recovery**:
- [ ] FS server can crash and restart without data loss
- [ ] DDS can crash and restart without system crash
- [ ] Journal replay ensures consistency
- [ ] 100+ crash recovery test iterations pass

**Performance**:
- [ ] File I/O within 20% of monolithic
- [ ] Metadata operations within 20% of monolithic
- [ ] Measured IPC overhead documented
- [ ] Performance acceptable for educational use

**Security and Isolation**:
- [ ] Servers isolated from each other
- [ ] Security checks enforced
- [ ] Privilege separation working
- [ ] No privilege escalation possible

## Implementation Guidance

### Phase 6 Implementation is NOT Provided

This specification describes WHAT to build, not HOW:

**What You Should Figure Out**:
- How to structure FS server code
- How to manage DMA buffers between kernel and DDS
- How to handle interrupt upcalls
- How to implement crash recovery
- How to optimize IPC overhead

**What You Should Research**:
- Darwin/XNU file system architecture (VFS + user-space FS)
- Minix 3 architecture (user-space drivers and servers)
- QNX resource managers (file system as server)
- L4 Linux (Linux in user space)
- User-space device drivers (DPDK, SPDK)

**What You Should Design**:
- IPC message protocol between VFS and FS server
- DMA buffer management protocol
- Interrupt upcall mechanism
- Crash recovery strategy
- Server startup and initialization sequence

### Recommended Implementation Order

1. **Week 1-2**: FS server skeleton
   - Create FS server process
   - Port file system code from kernel to server
   - Implement basic IPC message handling
   - Test: FS server starts and handles lookup

2. **Week 2-3**: Kernel VFS bridge
   - Implement kernel VFS layer
   - Translate system calls to IPC
   - Manage file descriptors in kernel
   - Test: open, read, write via FS server

3. **Week 3-4**: Full FS server implementation
   - Implement all file operations
   - Move buffer cache to FS server
   - Implement journaling in FS server
   - Test: all file operations work

4. **Week 4-5**: Disk driver server
   - Create DDS process
   - Port disk driver to user space
   - Implement DMA buffer management
   - Implement interrupt upcalls
   - Test: I/O via DDS

5. **Week 5-6**: Integration and optimization
   - Connect FS server to DDS
   - Implement crash recovery
   - Optimize IPC overhead
   - Test: stress tests, crash recovery

6. **Week 6-8**: Testing and polish
   - Comprehensive testing (all usertests)
   - Performance benchmarking
   - Crash recovery testing
   - Documentation and cleanup

### Common Pitfalls

**Pitfall 1: Deadlock in IPC**
- FS server waits for DDS, DDS waits for kernel
- Use timeouts or non-blocking IPC
- Careful state machine design

**Pitfall 2: DMA Buffer Lifecycle**
- Buffer freed while I/O in progress
- Use reference counting or pinning
- Clear ownership model

**Pitfall 3: Interrupt Upcall Race Conditions**
- Interrupt arrives while DDS not ready
- Queue interrupts in kernel
- DDS polls on startup

**Pitfall 4: FS Server Crash During Write**
- Data loss if write not journaled
- Ensure journal committed before reply
- Test crash at every point in operation

**Pitfall 5: File Descriptor Leaks**
- Kernel fd table grows unbounded
- Properly close fds on process exit
- Handle FS server crash (close all fds)

**Pitfall 6: Performance: Too Much IPC**
- Every operation requires multiple IPC round trips
- Cache in kernel VFS where possible
- Batch operations when feasible

## References

### Hybrid Kernel Architectures

**Darwin/XNU**:
- "Mac OS X Internals: A Systems Approach" (Singh)
- XNU source code: bsd/vfs/ (VFS layer)
- IOKit documentation (user-space drivers)

**Windows NT**:
- "Windows Internals" (Russinovich et al.)
- NT microkernel architecture
- User-mode drivers framework

### Microkernel Systems

**Minix 3**:
- "Operating Systems: Design and Implementation" (Tanenbaum)
- Minix 3 architecture: user-space drivers and servers
- Minix 3 source code

**L4**:
- "L4 Linux: The Road to Multi-Server Systems" (Härtig et al., 2005)
- L4 microkernel IPC
- User-space driver frameworks

**QNX**:
- QNX Neutrino microkernel architecture
- Resource managers (file systems as servers)
- Adaptive partitioning

### User-Space Device Drivers

**Papers**:
- "Microdrivers: A New Architecture for Device Drivers" (Srinivasan & Thiebaut, 1995)
- "User-Level Device Drivers: Achieved Performance" (Leslie et al., 2005)

**Implementations**:
- DPDK (Data Plane Development Kit) - user-space network drivers
- SPDK (Storage Performance Development Kit) - user-space storage drivers
- FUSE (Filesystem in Userspace)

### File System as Server

**FUSE**:
- FUSE documentation and examples
- FUSE kernel module (file system operations via user space)
- Performance characteristics

**Plan 9**:
- "The Use of Name Spaces in Plan 9" (Pike et al., 1993)
- File servers and 9P protocol
- Everything is a file server

### Crash Recovery

**Papers**:
- "Rethink the Sync" (Nightingale et al., 2006)
- "Improving File System Availability with Optimistic Crash Consistency" (Chidambaram et al., 2013)

**Techniques**:
- Journaling in user-space servers
- Checkpoint and restart
- Transaction recovery

### Performance Analysis

**Microbenchmarks**:
- lmbench: file system latency and throughput
- Comparing monolithic vs microkernel
- "The Performance of μ-Kernel-Based Systems" (Härtig et al., 1997)

### xv6 File System

**Study Files**:
- `kernel/fs/fs.c` - Current file system (to be moved)
- `kernel/fs/virtio_disk.c` - Current disk driver (to be moved)
- `kernel/fs/file.c` - File descriptor layer (stays in kernel)
- `kernel/syscall/sysfile.c` - File system calls (modify for IPC)

## Appendix: IPC Protocol Example

**Example: Read Operation**

```
User Process:
  read(fd, buf, 1024)
    ↓
Kernel VFS (sys_read):
  1. Lookup fd in fd table → ino = 42, offset = 0
  2. Security check: can user read?
  3. Prepare IPC message:
     {
       type: FS_READ,
       ino: 42,
       offset: 0,
       size: 1024,
       reply_port: kernel_port
     }
  4. Send IPC to FS server port
  5. Block waiting for reply
    ↓
FS Server:
  6. Receive IPC message
  7. Lookup inode 42 in inode cache
  8. Check if data in buffer cache
  9. If not cached, send IPC to DDS:
     {
       type: DISK_READ,
       block: 100,
       buffer: <shared buffer>,
       reply_port: fs_server_port
     }
  10. Block waiting for disk I/O
    ↓
Disk Driver Server:
  11. Receive IPC from FS server
  12. Request kernel to pin buffer
  13. Kernel pins buffer, returns physical address
  14. DDS programs virtio queue
  15. DDS waits for interrupt
    [Interrupt occurs]
  16. Kernel sends interrupt IPC to DDS
  17. DDS checks virtio queue, I/O complete
  18. DDS sends IPC reply to FS server:
      {
        type: DISK_READ_REPLY,
        status: SUCCESS,
        data: <in shared buffer>
      }
    ↓
FS Server:
  19. Receive reply from DDS
  20. Copy data from disk buffer to FS buffer cache
  21. Copy requested 1024 bytes to reply buffer
  22. Send IPC reply to kernel VFS:
      {
        type: FS_READ_REPLY,
        status: SUCCESS,
        size: 1024,
        data: <1024 bytes>
      }
    ↓
Kernel VFS:
  23. Receive reply from FS server
  24. Copy data to user buffer (copyout)
  25. Update fd offset: offset += 1024
  26. Return to user process: return 1024
```

## Appendix: Server Process Structure

**Example: File System Server Main Loop**

```c
// User-space FS server: servers/fs_server/main.c

void fs_server_main() {
  // Initialize FS server
  fs_init();
  buffer_cache_init();
  journal_init();

  // Mount root file system
  fs_mount("/");

  // Register with kernel (send port to kernel)
  kernel_register_fs_server(my_port);

  printf("FS server ready\n");

  // Main message loop
  while (1) {
    struct ipc_message msg;

    // Receive request from kernel VFS
    int ret = ipc_receive(my_port, &msg, 0, 0);
    if (ret < 0) {
      // Handle error (port death, interrupt)
      continue;
    }

    // Dispatch based on message type
    switch (msg.type) {
      case FS_LOOKUP:
        handle_lookup(&msg);
        break;
      case FS_READ:
        handle_read(&msg);
        break;
      case FS_WRITE:
        handle_write(&msg);
        break;
      // ... other operations ...
      default:
        send_error_reply(&msg, EINVAL);
    }
  }
}

void handle_read(struct ipc_message *msg) {
  uint32 ino = msg->args.ino;
  uint64 offset = msg->args.offset;
  uint32 size = msg->args.size;

  // Read data (may require disk I/O via DDS)
  char *buf = kalloc();
  int n = fs_read_inode(ino, offset, size, buf);

  // Send reply to kernel
  struct ipc_message reply;
  reply.type = FS_READ_REPLY;
  reply.args.status = (n >= 0) ? SUCCESS : errno;
  reply.args.size = n;
  message_add_inline(&reply, buf, n);

  ipc_send(msg->reply_port, &reply, 0, 0);

  kfree(buf);
}
```

---

**Phase Status**: Ready for Implementation
**Estimated Effort**: 160-200 hours over 6-8 weeks
**Prerequisites**: Phase 5 complete (IPC mechanism)
**Outputs**: User-space FS server, user-space disk driver, hybrid kernel
**Next Phase**: [Phase 7: PCIe Infrastructure](../ROADMAP_2.md) or [Phase 10: Optimization](../ROADMAP_2.md)

**Critical Note**: This is the most challenging phase of the project. Take time to plan carefully, implement incrementally, and test thoroughly at each step.
