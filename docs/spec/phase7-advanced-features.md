# Phase 7: Advanced Features

**Duration**: 4-6 weeks
**Difficulty**: Advanced
**Prerequisites**: Multiple prior phases depending on feature

## Objectives

Implement modern OS features: containers, security mechanisms, performance tools, and advanced kernel capabilities.

## Features to Implement

### 1. Namespaces (Containerization)

Implement Linux-style namespaces for process isolation.

**Namespace Types**:
1. **PID Namespace** - Isolated process ID space
2. **Mount Namespace** - Isolated filesystem view
3. **Network Namespace** - Isolated network stack (requires Phase 6)
4. **IPC Namespace** - Isolated IPC resources

**System Calls**:
- `int unshare(int flags)` - Create new namespace
- `int setns(int fd, int nstype)` - Join existing namespace
- `int clone(int (*fn)(void*), void *stack, int flags, void *arg)` - Fork with namespace options

**Requirements**:
- Add to `struct proc`:
  ```c
  struct namespace {
    int pid_ns_id;      // PID namespace ID
    int mount_ns_id;    // Mount namespace ID
    int net_ns_id;      // Network namespace ID
    int ipc_ns_id;      // IPC namespace ID
  };
  struct namespace *ns;
  ```
- PID namespace: Process sees only PIDs in its namespace
- Mount namespace: Separate filesystem mount points
- Implement `ps` to show namespaced processes

**Flags**:
- `CLONE_NEWPID` - New PID namespace
- `CLONE_NEWNS` - New mount namespace
- `CLONE_NEWNET` - New network namespace
- `CLONE_NEWIPC` - New IPC namespace

### 2. Control Groups (cgroups)

Resource limits for process groups.

**System Calls**:
- `int cgroup_create(char *name)` - Create cgroup
- `int cgroup_add(int cgid, int pid)` - Add process to cgroup
- `int cgroup_set_limit(int cgid, int resource, uint64 limit)` - Set resource limit

**Resources to Limit**:
- CPU time (percentage or absolute time)
- Memory usage (max bytes)
- Number of processes
- Disk I/O bandwidth

**Requirements**:
- Cgroup hierarchy (tree structure)
- Per-cgroup statistics
- Enforce limits in scheduler, allocator, etc.
- Add to `struct proc`:
  ```c
  int cgroup_id;
  ```

**Data Structures**:
```c
struct cgroup {
  char name[16];
  uint64 cpu_limit;      // CPU time limit (ticks per 100 ticks)
  uint64 mem_limit;      // Memory limit (bytes)
  int proc_limit;        // Max number of processes
  uint64 cpu_usage;      // Current CPU usage
  uint64 mem_usage;      // Current memory usage
  int proc_count;        // Current process count
};
```

### 3. Security Features

#### 3.1 Address Space Layout Randomization (ASLR)

**Requirements**:
- Randomize stack base address
- Randomize heap base address
- Randomize mmap region addresses
- Use RISC-V time CSR as entropy source
- Apply randomization in `exec()` and memory allocation

#### 3.2 Stack Canaries

**Requirements**:
- Place random canary value before return address on stack
- Check canary value before function return
- Kill process if canary corrupted (stack overflow detected)
- Compiler support or manual instrumentation in key functions

#### 3.3 System Call Filtering (seccomp)

**System Call**: `int seccomp(int mode, struct seccomp_filter *filter)`

**Modes**:
- `SECCOMP_MODE_STRICT` - Only allow read, write, exit, sigreturn
- `SECCOMP_MODE_FILTER` - Use BPF filter to allow/deny syscalls

**Requirements**:
- Add syscall filter to `struct proc`
- Check filter in `syscall()` before executing
- Return -EPERM if syscall not allowed
- Cannot relax restrictions once applied (security)

**Example**:
```c
// Allow only certain syscalls
struct seccomp_filter filter;
filter.allowed[SYS_read] = 1;
filter.allowed[SYS_write] = 1;
filter.allowed[SYS_exit] = 1;
seccomp(SECCOMP_MODE_FILTER, &filter);
```

#### 3.4 Capabilities

**Requirements**:
- Split root privileges into fine-grained capabilities
- Capabilities: CAP_NET_ADMIN, CAP_SYS_ADMIN, CAP_KILL, etc.
- Add to `struct proc`:
  ```c
  uint64 capabilities;  // Bitmap of capabilities
  ```
- Check capabilities instead of just uid == 0

**System Calls**:
- `int capset(uint64 caps)` - Set process capabilities
- `uint64 capget(void)` - Get process capabilities

### 4. Performance Monitoring and Profiling

#### 4.1 Kernel Profiler

**Requirements**:
- Sample program counter periodically (timer interrupt)
- Build histogram of PC values
- Identify hot functions in kernel
- System call to retrieve profiling data

**System Call**: `int kprof_start(void)`, `int kprof_stop(void)`, `int kprof_read(struct kprof_data *data)`

**Data Structure**:
```c
#define KPROF_BUCKETS 1000
struct kprof_data {
  uint64 samples[KPROF_BUCKETS];
  uint64 bucket_size;  // Address range per bucket
};
```

#### 4.2 Lock Contention Analysis

**Requirements**:
- Track lock acquisition times
- Count lock contentions (failed acquire attempts)
- Identify lock bottlenecks

**Enhancement to spinlock**:
```c
struct spinlock {
  // ... existing fields
  uint64 acquire_count;
  uint64 contention_count;
  uint64 total_wait_time;
};
```

**System Call**: `int getlockstats(struct lockstats *stats)`

#### 4.3 Memory Leak Detector

**Requirements**:
- Track all `kalloc()` and `kfree()` calls
- Store allocation backtraces (at least caller address)
- Detect unfreed allocations
- System call to dump leak report

**System Call**: `int memleak_check(void)`

### 5. Advanced IPC Mechanisms

#### 5.1 Message Queues

**System Calls**:
- `int msgget(int key)` - Create/get message queue
- `int msgsnd(int msgid, void *msg, int len)` - Send message
- `int msgrcv(int msgid, void *buf, int len)` - Receive message
- `int msgctl(int msgid, int cmd)` - Control message queue

**Requirements**:
- Fixed-size message queue array
- FIFO ordering
- Blocking receive if queue empty
- Wake up receivers when message arrives

#### 5.2 Semaphores

**System Calls**:
- `int sem_init(int key, int value)` - Create semaphore
- `int sem_wait(int semid)` - P operation (wait/decrement)
- `int sem_post(int semid)` - V operation (signal/increment)
- `int sem_destroy(int semid)` - Destroy semaphore

**Requirements**:
- Counting semaphores
- Sleep when value is 0 (sem_wait)
- Wake up waiters on sem_post

#### 5.3 Event Notification (epoll-like)

**System Call**: `int wait_events(struct event *events, int maxevents, int timeout)`

**Requirements**:
- Monitor multiple file descriptors for I/O readiness
- Return when any fd is ready
- Support sockets, pipes, files
- Timeout support

### 6. Loadable Kernel Modules (Optional - Very Advanced)

**Requirements**:
- ELF loading in kernel space
- Symbol resolution and linking
- Module initialization and cleanup functions
- `insmod` and `rmmod` utilities

**System Calls**:
- `int init_module(void *module_image, uint64 len)` - Load module
- `int delete_module(char *name)` - Unload module
- `int lsmod(struct module_info *info, int count)` - List modules

**Module Structure**:
```c
struct module {
  char name[32];
  void *base_addr;
  uint64 size;
  int (*init)(void);
  void (*exit)(void);
  int refcount;
};
```

### 7. Journaling Shell (Advanced Shell)

Enhance xv6 shell with advanced features:

**Features**:
- Command history (up/down arrows)
- Tab completion
- Job control (background processes with &, fg, bg)
- Pipes and redirection enhancements
- Environment variables
- Shell scripts

**Job Control System Calls**:
- Reuse signal infrastructure (SIGTSTP, SIGCONT)
- Process groups already partially implemented

### 8. Dynamic Linker (Optional)

**Requirements**:
- Support for shared libraries (.so files)
- Position-independent code (PIC)
- Dynamic symbol resolution
- Modify `exec()` to invoke dynamic linker

**Benefits**: Reduced memory usage, shared code across processes

### 9. Multi-User Support

**Requirements**:
- User database (simple file or in-memory)
- Login system
- User authentication (password hashing)
- Permissions based on user ID
- Switch users with `su` command

**System Calls**:
- `int setuid(int uid)` - Set user ID
- `int getuid(void)` - Get user ID
- `int login(char *username, char *password)` - Authenticate user

**Files**:
- `/etc/passwd` - User database
- `/etc/shadow` - Password hashes (optional)

### 10. Power Management (If time permits)

**Requirements**:
- CPU idle states (halt when no runnable processes)
- Dynamic frequency scaling (if QEMU supports)
- Timer coalescing to reduce wakeups

**System Call**: `int poweroff(void)` - Shutdown system cleanly

## Deliverables

Choose based on interest (implement 3-5 features from above):

- [ ] At least one containerization feature (namespaces or cgroups)
- [ ] At least two security features (ASLR, canaries, seccomp, or capabilities)
- [ ] Performance tools (profiler, lock analysis, or leak detector)
- [ ] Advanced IPC (message queues or semaphores)
- [ ] Enhanced shell with job control
- [ ] Multi-user support
- [ ] Test suite for chosen features
- [ ] Documentation and usage examples
- [ ] Performance analysis showing benefits

## Success Criteria

1. **Isolation**: Namespaces properly isolate processes
2. **Resource Control**: cgroups enforce limits correctly
3. **Security**: Security features prevent exploits
4. **Performance**: Profiling tools identify bottlenecks accurately
5. **Usability**: Features integrate well with existing system
6. **Stability**: No regressions, system remains stable

## Testing

### Namespace Test
```c
// Create isolated PID namespace
unshare(CLONE_NEWPID);
// Child process sees itself as PID 1
if(fork() == 0) {
  printf("My PID: %d\n", getpid());  // Prints: 1
}
```

### cgroup Test
```c
// Limit memory to 1MB
int cg = cgroup_create("limited");
cgroup_set_limit(cg, CGROUP_MEM, 1024*1024);
cgroup_add(cg, getpid());
// Try to allocate 2MB - should fail or be killed
char *p = sbrk(2*1024*1024);
```

### seccomp Test
```c
// Restrict to read/write/exit only
struct seccomp_filter filter = {0};
filter.allowed[SYS_read] = 1;
filter.allowed[SYS_write] = 1;
filter.allowed[SYS_exit] = 1;
seccomp(SECCOMP_MODE_FILTER, &filter);

// This should fail
open("file", O_RDONLY);  // Returns -EPERM
```

## Key Concepts to Understand

Study before implementing:
- Containerization and isolation mechanisms
- Resource accounting and limits
- Security principles (least privilege, defense in depth)
- Performance profiling techniques
- Inter-process communication patterns
- Dynamic linking and loading
- Authentication and access control

## References

- Linux namespaces documentation
- Linux cgroups documentation
- Linux capabilities(7) man page
- Linux seccomp(2) man page
- "Understanding the Linux Kernel" - Chapters on containers and security
- Docker/LXC implementation (for reference)
- MIT 6.S081: Advanced lectures and labs

## Implementation Notes

- **Start Small**: Choose 1-2 features to implement deeply rather than many superficially
- **Incremental**: Build features incrementally with tests at each step
- **Integration**: Ensure new features integrate well with existing system
- **Documentation**: Document design decisions and trade-offs
- **Security**: Be extra careful with security features - test thoroughly
