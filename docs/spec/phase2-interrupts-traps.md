# Phase 2: Interrupt and Trap Mechanisms

**Duration**: 3-4 weeks
**Prerequisites**: Phase 1, RISC-V assembly basics

## Objectives

Master trap handling and implement advanced interrupt features including signals and performance monitoring.

## Features to Implement

### 1. Performance Counter Interface

**System Calls**:
- `int getperf(struct perfstat *ps)` - Get performance counters
- `int resetperf(void)` - Reset performance counters

**Requirements**:
- Access RISC-V performance counters: cycle, instret, time
- Define `struct perfstat` with cycle count, instruction count, timestamp
- Provide CSR access wrappers in `kernel/riscv.h`

**Use Case**: Profile code sections to measure cycles and IPC

### 2. Configurable Timer Interval

**System Call**: `int settimer(int interval_us)`

**Requirements**:
- Allow dynamic adjustment of timer interrupt interval
- Default: ~10ms, configurable range: 1ms - 100ms
- Only root/privileged process can modify
- Affects scheduling quantum

**Files to Modify**:
- `kernel/trap.c` - Timer interrupt handler
- `kernel/start.c` - Timer setup

### 3. Signal System

Implement UNIX-style signal mechanism for inter-process communication.

**System Calls**:
- `int kill(int pid, int sig)` - Send signal to process
- `sighandler_t signal(int signum, sighandler_t handler)` - Register handler
- `int sigreturn(void)` - Return from signal handler
- `int sigprocmask(int how, uint64 *set, uint64 *oldset)` - Block signals

**Signals to Support**:
- `SIGKILL (9)` - Kill process (cannot be caught)
- `SIGSTOP (19)` - Stop process
- `SIGCONT (18)` - Continue stopped process
- `SIGUSR1 (10)` - User-defined signal 1
- `SIGUSR2 (12)` - User-defined signal 2
- `SIGCHLD (17)` - Child process state changed
- `SIGALRM (14)` - Alarm timer expired

**Requirements**:
- Add to `struct proc`:
  - `uint64 pending_signals` - Bitmap of pending signals
  - `sighandler_t handlers[32]` - Signal handlers
  - `uint64 signal_mask` - Blocked signals
  - `struct trapframe saved_tf` - For signal context
- Deliver signals before returning to user space (in `usertrapret()`)
- Support signal inheritance in `fork()`
- Implement default actions (terminate, ignore, stop, continue)
- Save/restore process context when calling user signal handler

**Signal Masking**:
- `SIG_BLOCK (0)` - Add signals to mask
- `SIG_UNBLOCK (1)` - Remove signals from mask
- `SIG_SETMASK (2)` - Set signal mask

### 4. Alarm System

**System Call**: `int alarm(int ticks, void (*handler)(void))`

**Requirements**:
- Call user-space handler after specified ticks
- Use existing signal infrastructure (SIGALRM)
- Only one active alarm per process
- `alarm(0, 0)` cancels alarm
- Handler runs in user space

**Use Case**: Timeouts, periodic tasks

### 5. Watchdog Timer

**System Calls**:
- `int watchdog_set(int timeout_ticks)` - Set watchdog timeout
- `int watchdog_reset(void)` - Reset watchdog timer

**Requirements**:
- Kill process if it doesn't reset watchdog within timeout
- Add to `struct proc`:
  - `uint64 watchdog_timeout` - Timeout value (0 = disabled)
  - `uint64 watchdog_last_reset` - Last reset time
- Check watchdog status on each timer interrupt
- Send SIGKILL if expired

**Use Case**: Detect hung processes

### 6. Trap Information System

**System Call**: `int gettrapinfo(struct trapinfo *info)`

**Requirements**:
- Return information about last trap
- Include: scause, sepc, stval, trap type, process state
- Useful for debugging and error handling

**Enhancement**: Trap logging
- Optionally log all traps to kernel buffer
- Syscall to retrieve trap log

### 7. Nested Interrupt Support (Optional - Advanced)

**Requirements**:
- Allow timer interrupts during kernel trap handling
- Implement interrupt priority levels:
  - `IPL_NONE (0)` - All interrupts enabled
  - `IPL_TIMER (1)` - Timer interrupts disabled
  - `IPL_IO (2)` - I/O interrupts disabled
  - `IPL_HIGH (3)` - All interrupts disabled
- Add `spl_set(int level)` function
- Ensure interrupt stack safety

**Use Case**: Better system responsiveness

## Deliverables

- [ ] Performance counter interface working
- [ ] Configurable timer implemented
- [ ] Full signal system with all 7 signals
- [ ] Signal masking and blocking functional
- [ ] Alarm system operational
- [ ] Watchdog timer functional
- [ ] Trap information accessible
- [ ] Test programs for each feature:
  - `perftest` - Performance counter usage
  - `sigtest` - Signal sending and handling
  - `alarmtest` - Alarm functionality
  - `watchdogtest` - Watchdog operation
- [ ] Documentation of trap handling flow

## Success Criteria

1. **Signal Delivery**: Signals delivered reliably and promptly
2. **Signal Safety**: No race conditions in signal handling
3. **Performance**: Minimal overhead from new features
4. **Compatibility**: All existing tests pass
5. **Nested Signals**: Handle signals during signal handler execution

## Testing

### Signal Tests
```c
// Test signal handler registration
signal(SIGUSR1, my_handler);
kill(getpid(), SIGUSR1);  // Should call my_handler

// Test signal blocking
sigprocmask(SIG_BLOCK, 1 << SIGUSR1, 0);
kill(getpid(), SIGUSR1);  // Should not call handler yet
sigprocmask(SIG_UNBLOCK, 1 << SIGUSR1, 0);  // Now handler called
```

### Alarm Test
```c
alarm(100, alarm_handler);  // Call handler after 100 ticks
// ... do work ...
// Handler called after timeout
```

### Performance Test
```c
struct perfstat start, end;
getperf(&start);
// Code to profile
getperf(&end);
printf("Cycles: %ld, IPC: %f\n",
    end.cycles - start.cycles,
    (end.instret - start.instret) / (end.cycles - start.cycles));
```

## Key Concepts to Understand

Study before implementing:
- RISC-V privilege levels (M, S, U modes)
- CSR registers: sstatus, sie, sip, stvec, sepc, scause, stval, satp
- Trap types: interrupts vs exceptions
- Trampoline mechanism and page table switching
- Signal delivery in UNIX systems
- Interrupt nesting and priority

## References

- RISC-V Privileged Architecture Manual
- MIT 6.S081: Lectures 5-7, Lab traps, Lab alarm
- xv6 Book: Chapters 5-6
- Linux signal(7) man page
- Source files: `kernel/trap.c`, `kernel/trampoline.S`
