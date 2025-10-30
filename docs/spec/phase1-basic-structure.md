# Phase 1: Basic xv6 Structure Understanding

**Duration**: 2-3 weeks
**Prerequisites**: C programming, basic OS concepts

## Objectives

Understand xv6 architecture and implement basic system call extensions.

## Features to Implement

### 1. Process Information System Call

**System Call**: `int getprocinfo(int pid, struct procinfo *info)`

**Requirements**:
- Return process information for given PID
- Include: PID, parent PID, state, name, memory usage, runtime statistics
- Return -1 if process not found
- Define `struct procinfo` in appropriate header

**Files to Modify**:
- `kernel/proc.h` - Add procinfo structure
- `kernel/sysproc.c` - Implement sys_getprocinfo()
- `kernel/syscall.h` - Add syscall number
- `kernel/syscall.c` - Register syscall
- `user/user.h` - Add user-space declaration
- `user/usys.pl` - Add syscall stub

### 2. Process Statistics Tracking

**Requirements**:
- Track creation time, total CPU time, wait time for each process
- Add fields to `struct proc`:
  - `uint64 ctime` - Creation timestamp
  - `uint64 rtime` - Total running time
  - `uint64 wtime` - Total waiting time
- Update statistics in appropriate locations (scheduler, fork, etc.)

**System Call**: `int getprocstats(int pid, struct procstats *stats)`

### 3. System Call Tracer

**System Call**: `int trace(int mask)`

**Requirements**:
- Enable tracing of system calls for current process and its children
- `mask` is a bitmask of syscall numbers to trace
- When traced syscall executes, print: `<pid>: syscall <name> -> <return_value>`
- Add `int trace_mask` field to `struct proc`
- Inherit trace mask in fork()

**Example**:
```c
trace(1 << SYS_fork | 1 << SYS_exec);  // Trace fork and exec
```

### 4. Process Listing Tool

**User Program**: `ps`

**Requirements**:
- Display all active processes in system
- Show: PID, PPID, State, Name, Memory, CPU time
- Format as table with headers
- Use getprocinfo() syscall

**Output Example**:
```
PID  PPID  STATE    NAME      MEM    TIME
1    0     SLEEP    init      12K    0.1s
2    1     RUN      sh        16K    0.5s
```

### 5. System Uptime

**System Call**: `int uptime_ms(void)`

**Requirements**:
- Return system uptime in milliseconds
- Based on tick counter
- Calculate: `ticks * MS_PER_TICK`

## Deliverables

- [ ] All 4 system calls implemented and working
- [ ] `ps` user program functional
- [ ] Test suite covering:
  - getprocinfo() with valid/invalid PIDs
  - trace() with various syscall combinations
  - Statistics accuracy verification
  - ps output correctness
- [ ] Documentation:
  - Brief description of boot process
  - System call implementation steps
  - Data structure modifications

## Success Criteria

1. **Functionality**: All system calls return correct results
2. **Error Handling**: Properly handle invalid inputs
3. **No Regressions**: Existing xv6 tests still pass
4. **Code Quality**: Follow xv6 coding style, add appropriate comments
5. **Testing**: Comprehensive tests for all features

## Testing

Create test programs:
- `procinfo_test` - Test getprocinfo with various scenarios
- `trace_test` - Test tracing mechanism
- `stats_test` - Verify statistics tracking accuracy

Run existing xv6 tests:
```bash
make qemu
# In xv6:
$ usertests
```

## Key Concepts to Understand

Study these before implementing:
- xv6 boot sequence (entry.S → start.c → main.c)
- System call mechanism (ecall → trampoline → usertrap → syscall)
- Process structure and lifecycle
- Context switching
- Process states (UNUSED, USED, SLEEPING, RUNNABLE, RUNNING, ZOMBIE)

## References

- xv6 Book: Chapters 1-4
- MIT 6.S081: Lectures 1-4, Lab syscall
- Source files: `kernel/proc.c`, `kernel/trap.c`, `kernel/syscall.c`
