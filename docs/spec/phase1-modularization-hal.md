# Phase 1: Modularization + HAL Foundation

**Duration**: 4-5 months
**Prerequisites**: Phase 0 complete
**Next Phase**: Phase 2 (Advanced Scheduler Implementation)

## Overview

Phase 1 is the most critical phase of this project. It transforms xv6 from a monolithic, architecture-specific implementation into a modular, portable kernel with a Hardware Abstraction Layer. All future phases depend on this foundation.

**Core Objective**: Refactor xv6 into modular components with all hardware interactions isolated through HAL interfaces, while maintaining 100% functional compatibility.

## Objectives

### Primary Goals
1. Implement HAL interfaces for all hardware interactions (CPU, MMU, interrupts, atomics, timer)
2. Separate RISC-V specific code into `kernel/arch/riscv/`
3. Refactor kernel into architecture-independent modules
4. Establish comprehensive testing infrastructure
5. Achieve zero functionality regression

### Learning Outcomes
- Hardware abstraction design patterns in C
- Large-scale refactoring strategies
- Test-driven development for systems programming
- Managing complexity in kernel development

## Functional Requirements

### FR1: Hardware Abstraction Layer

**Requirement**: All hardware interactions must go through defined HAL interfaces.

**Interfaces Required**:

#### HAL-CPU: CPU Operations
- CPU initialization
- CPU identification (which CPU am I?)
- CPU count
- Interrupt enable/disable/query
- Context switching
- Halt/wait for interrupt
- Return to user space from trap

**Success Criteria**:
- No direct access to CPU control registers outside HAL implementation
- Context switching works identically to xv6
- Interrupt state management is correct

#### HAL-MMU: Memory Management Unit
- Page table creation/destruction
- Page table switching
- Page table walk (multi-level)
- Page mapping/unmapping
- TLB flush (all/single page)
- PTE manipulation (PA ↔ PTE conversion, flag setting)

**Success Criteria**:
- All page table operations use HAL
- No direct manipulation of RISC-V page table format outside HAL
- TLB management is correct (no stale TLB issues)

#### HAL-INTR: Interrupt Controller
- Interrupt controller initialization
- Enable/disable specific interrupt types
- Claim interrupt (for handling)
- Complete interrupt (acknowledge)
- Set interrupt priority

**Success Criteria**:
- All PLIC access goes through HAL
- Interrupt routing works correctly
- No missed or spurious interrupts

#### HAL-Atomic: Atomic Operations
- Compare-and-swap (32-bit and 64-bit)
- Atomic add
- Atomic swap
- Memory barriers (full, load, store)

**Success Criteria**:
- Spinlocks use HAL atomic operations
- No race conditions in synchronization primitives
- Memory ordering is correct on multi-core

#### HAL-Timer: Timer Operations
- Timer initialization
- Get current time (ticks)
- Get timer frequency
- Set timer interval
- Get time in microseconds

**Success Criteria**:
- Timer interrupts delivered correctly
- Scheduler uses HAL timer
- Time measurement is accurate

### FR2: Architecture Separation

**Requirement**: All RISC-V specific code must be in `kernel/arch/riscv/`.

**Code to Separate**:
- Boot code (entry.S, start.c)
- Trap handling (trampoline.S, kernelvec.S, trap.c)
- HAL implementations
- Architecture-specific headers (riscv.h, memlayout.h)

**Success Criteria**:
- Core kernel has no #ifdef for architecture
- Adding x86_64 support (Phase 11) requires no changes to core kernel
- Clear separation between portable and architecture code

### FR3: Module Interfaces

**Requirement**: Major subsystems must have well-defined interfaces.

**Interfaces Required**:

#### Scheduler Interface
```c
typedef struct {
  void (*init)(void);
  void (*enqueue)(struct proc *p);
  struct proc *(*dequeue)(void);
  void (*tick)(struct proc *p);
  void (*yield)(struct proc *p);
} SchedOps;
```

**Purpose**: Enable pluggable scheduling algorithms (Phase 2).

#### Memory Allocator Interface
```c
typedef struct {
  void (*init)(void);
  void *(*alloc)(void);
  void (*free)(void *pa);
  uint64 (*available)(void);
} MemAllocOps;
```

**Purpose**: Enable different allocation strategies (Phase 3).

#### Device Driver Interface
```c
typedef struct {
  const char *name;
  int major;
  int (*init)(void);
  int (*read)(char *buf, int n);
  int (*write)(const char *buf, int n);
  int (*ioctl)(int cmd, void *arg);
  void (*intr)(void);
} DeviceOps;
```

**Purpose**: Standardize driver registration (Phase 7+).

**Success Criteria**:
- Existing implementations wrapped with interfaces
- Changing scheduler/allocator doesn't require kernel rebuild
- Clear contracts between modules

### FR4: Testing Infrastructure

**Requirement**: Comprehensive testing at three levels.

#### Unit Tests (Host-based)
- Test architecture-independent code on development machine
- Use mock HAL implementations
- Fast execution (<1 minute for all tests)
- Coverage target: >80% of testable code

**Components to Test**:
- String utilities (memset, memmove, strlen, etc.)
- Spinlock operations
- Memory allocator
- Process list management
- File system utilities (path parsing, etc.)

#### Integration Tests (QEMU-based)
- Test inter-module interactions in real kernel
- Run in QEMU (automated)
- Moderate speed (5-10 minutes)

**Tests Required**:
- System call interface
- Process creation (fork/exec)
- File operations
- Memory allocation
- Inter-process operations
- Multi-CPU functionality

#### End-to-End Tests
- Complete system functionality
- All existing xv6 usertests must pass
- Run in QEMU (automated)
- Slower (20-30 minutes)

**Success Criteria**:
- 100% pass rate on existing tests
- New tests for refactored code
- Automated CI pipeline running all tests

### FR5: Zero Regression

**Requirement**: All existing xv6 functionality must work identically.

**Verification**:
- All usertests pass
- Boot sequence unchanged
- System call behavior identical
- File system operations correct
- Multi-CPU operation correct

**Performance**:
- <5% performance regression acceptable
- Major operations: fork, exec, read, write, system call overhead
- Context switch time should be identical

## Non-Functional Requirements

### NFR1: Code Quality
- No compiler warnings with `-Wall -Werror`
- Follow coding standards from Phase 0
- All functions documented
- Complex logic has explanatory comments

### NFR2: Portability
- Core kernel must be architecture-independent
- Only HAL implementations contain architecture code
- No RISC-V assumptions in core kernel

### NFR3: Testability
- All HAL operations mockable
- Core logic testable without hardware
- Deterministic behavior for testing

### NFR4: Performance
- Inline functions for hot paths
- Minimize indirect calls in critical paths
- Context switch time unchanged
- TLB flush overhead minimal

### NFR5: Maintainability
- Clear module boundaries
- Documented interfaces
- Consistent naming conventions
- Git history preserves context

## Implementation Tasks

### Task 1: Create HAL Directory Structure (Week 1)

**Steps**:
1. Create `kernel/hal/include/` directory
2. Create `kernel/arch/riscv/hal/` directory
3. Create `kernel/arch/riscv/include/` directory
4. Update CMakeLists.txt with new paths

**Deliverables**:
- Directory structure created
- Build system updated
- Compiles successfully (empty interfaces)

### Task 2: Define HAL Interfaces (Week 1-2)

**Steps**:
1. Write `hal/include/hal_cpu.h`
2. Write `hal/include/hal_mmu.h`
3. Write `hal/include/hal_intr.h`
4. Write `hal/include/hal_atomic.h`
5. Write `hal/include/hal_timer.h`
6. Write `hal/include/hal.h` (includes all HAL headers)

**Deliverables**:
- All HAL header files with documented interfaces
- Example usage for each function
- Clear specification of behavior

**Design Considerations**:
- Keep interfaces thin (minimal abstraction)
- Use explicit types (uint64, uint32, not unsigned long)
- Document pre/post-conditions
- Specify error handling

### Task 3: Implement RISC-V HAL (Week 3-5)

**Steps**:
1. Implement `arch/riscv/hal/hal_cpu_riscv.c`
2. Implement `arch/riscv/hal/hal_mmu_riscv.c`
3. Implement `arch/riscv/hal/hal_intr_riscv.c`
4. Implement `arch/riscv/hal/hal_atomic_riscv.c`
5. Implement `arch/riscv/hal/hal_timer_riscv.c`
6. Update build system

**Deliverables**:
- All RISC-V HAL implementations
- Compiles successfully
- Basic smoke test (kernel boots)

**Implementation Strategy**:
- Extract existing code from vm.c, proc.c, trap.c
- Wrap in HAL functions
- Preserve exact behavior
- Add comments explaining RISC-V specifics

### Task 4: Move Architecture-Specific Code (Week 6-7)

**Steps**:
1. Move `kernel/boot/` → `arch/riscv/boot/`
2. Move trap code → `arch/riscv/trap/`
3. Move `kernel/include/riscv.h` → `arch/riscv/include/`
4. Move `kernel/include/memlayout.h` → `arch/riscv/include/`
5. Update all #includes in kernel
6. Update build system
7. Test kernel boots correctly

**Deliverables**:
- All architecture code in arch/riscv/
- Core kernel directory clean of RISC-V specifics
- Kernel boots and runs

### Task 5: Set Up Testing Infrastructure (Week 8-9)

**Steps**:
1. Integrate Unity test framework
2. Integrate CMocka for mocking
3. Create `tests/unit/` directory structure
4. Create mock HAL implementations
5. Write first unit tests (string utilities)
6. Set up CI pipeline (GitHub Actions)
7. Create integration test harness

**Deliverables**:
- Unit tests compile and run on host
- CI pipeline running tests
- Mock HAL for testing
- Documentation on writing tests

### Task 6: Update Core Kernel - Virtual Memory (Week 10-11)

**Steps**:
1. Update `kernel/mm/vm.c` to use HAL MMU operations
2. Remove direct RISC-V page table manipulation
3. Write unit tests for page table operations
4. Test with usertests
5. Verify performance (page fault, fork time)

**Functions to Update**:
- `walk()` → use `HalPtWalk()`
- `mappages()` → use `HalPtMap()`
- `uvmcopy()` → use HAL operations
- `kvmmap()` → use HAL operations
- Page table creation/destruction

**Deliverables**:
- vm.c uses only HAL MMU operations
- No direct PTE manipulation in vm.c
- All usertests pass
- Performance within 5% of baseline

### Task 7: Update Core Kernel - Process Management (Week 12-13)

**Steps**:
1. Update `kernel/core/proc/proc.c` to use HAL CPU operations
2. Update context switching to use HAL
3. Remove direct RISC-V register access
4. Write unit tests for process operations
5. Test multi-CPU operation

**Functions to Update**:
- `scheduler()` → use `HalCpuId()`, `HalIntrEnable()`
- `sched()` → use `HalContextSwitch()`
- `yield()` → use HAL operations
- `mycpu()` → use `HalCpuId()`

**Deliverables**:
- proc.c uses only HAL CPU operations
- Context switching via HAL
- Multi-CPU scheduler works correctly
- All usertests pass

### Task 8: Update Core Kernel - Interrupts & Traps (Week 14-15)

**Steps**:
1. Update trap handling to use HAL interrupt operations
2. Update PLIC driver to use HAL
3. Update timer code to use HAL timer
4. Remove direct interrupt controller access
5. Test interrupt delivery

**Components to Update**:
- `kernel/arch/riscv/trap/trap.c` → use HAL for interrupt dispatch
- `kernel/drivers/plic.c` → use HAL interrupt operations
- Timer interrupt setup → use HAL timer

**Deliverables**:
- All interrupt handling via HAL
- Timer interrupts correct
- External interrupts (UART) work
- All usertests pass

### Task 9: Update Synchronization Primitives (Week 16)

**Steps**:
1. Update `kernel/lib/spinlock.c` to use HAL atomic operations
2. Remove direct RISC-V atomic instructions
3. Test spinlock correctness (multi-CPU stress test)
4. Measure spinlock performance

**Functions to Update**:
- `acquire()` → use `HalIntrGet()`, `HalIntrDisable()`
- `release()` → use `HalIntrRestore()`, `HalMemoryBarrier()`
- Test-and-set → use `HalAtomicCas()`

**Deliverables**:
- Spinlocks use only HAL atomics
- No race conditions under stress test
- Performance unchanged

### Task 10: Create Module Interfaces (Week 17)

**Steps**:
1. Create scheduler interface (`kernel/core/proc/include/sched.h`)
2. Wrap existing round-robin scheduler
3. Create memory allocator interface (`kernel/mm/include/kalloc.h`)
4. Wrap existing free-list allocator
5. Create device driver interface (`kernel/drivers/include/driver.h`)
6. Register existing drivers (console, UART)

**Deliverables**:
- Scheduler is pluggable (foundation for Phase 2)
- Memory allocator is pluggable (foundation for Phase 3)
- Device drivers use consistent interface
- All usertests pass

### Task 11: Comprehensive Testing (Week 18-19)

**Steps**:
1. Write unit tests for all testable modules
2. Achieve >80% code coverage
3. Write integration tests for inter-module interactions
4. Run stress tests (long-running, concurrent)
5. Fix all identified bugs
6. Performance benchmarking

**Test Coverage**:
- String utilities: 100%
- Spinlocks: 100%
- Memory allocator: >90%
- Page table operations: >80%
- Process management: >80%
- File system utilities: >80%

**Deliverables**:
- Comprehensive test suite
- Coverage report >80%
- All tests passing
- Performance benchmarks documented

### Task 12: Documentation & Polish (Week 20)

**Steps**:
1. Write HAL design document
2. Write porting guide (how to add x86_64)
3. Write testing guide
4. Update CLAUDE.md with Phase 1 changes
5. Code review and cleanup
6. Prepare Phase 2 planning

**Deliverables**:
- Complete documentation
- Clean git history
- Ready for Phase 2

## Testing Requirements

### Unit Test Examples

**Test: Spinlock Acquire/Release**
```c
// tests/unit/test_spinlock.c
void test_spinlock_acquire_release(void) {
  // Setup mock HAL
  mock_hal_init();

  struct spinlock lock;
  initlock(&lock, "test");

  // Acquire should disable interrupts
  acquire(&lock);
  TEST_ASSERT_TRUE(mock_hal_interrupts_disabled());
  TEST_ASSERT_TRUE(lock.locked);

  // Release should re-enable interrupts
  release(&lock);
  TEST_ASSERT_FALSE(mock_hal_interrupts_disabled());
  TEST_ASSERT_FALSE(lock.locked);
}
```

**Test: Page Table Walk**
```c
// tests/unit/test_vm.c
void test_pagetable_walk(void) {
  // Setup mock HAL with mock allocator
  mock_hal_mmu_init();
  mock_kalloc_init();

  pagetable_t pt = HalPtAlloc();

  // Walk non-existent page (should return NULL)
  pte_t *pte = HalPtWalk(pt, 0x1000, 0);
  TEST_ASSERT_NULL(pte);

  // Walk with alloc (should allocate intermediate tables)
  pte = HalPtWalk(pt, 0x1000, 1);
  TEST_ASSERT_NOT_NULL(pte);
}
```

### Integration Test Examples

**Test: Fork and Exec**
```c
// tests/integration/test_fork.c
int main() {
  printf("test_fork: ");

  int pid = fork();
  if (pid < 0) {
    printf("FAIL: fork returned %d\n", pid);
    exit(1);
  }

  if (pid == 0) {
    // Child: exec a simple program
    char *argv[] = { "echo", "child", 0 };
    exec("echo", argv);
    printf("FAIL: exec failed\n");
    exit(1);
  }

  // Parent: wait for child
  int status;
  int wpid = wait(&status);
  if (wpid != pid) {
    printf("FAIL: wait returned wrong pid\n");
    exit(1);
  }

  printf("OK\n");
  exit(0);
}
```

**Test: Multi-CPU Synchronization**
```c
// tests/integration/test_multicore.c
volatile int counter = 0;
struct spinlock lock;

void worker() {
  for (int i = 0; i < 1000; i++) {
    acquire(&lock);
    counter++;
    release(&lock);
  }
  exit(0);
}

int main() {
  initlock(&lock, "counter");

  // Fork 4 workers
  for (int i = 0; i < 4; i++) {
    if (fork() == 0) {
      worker();
    }
  }

  // Wait for all
  for (int i = 0; i < 4; i++) {
    wait(0);
  }

  // Counter should be exactly 4000
  if (counter == 4000) {
    printf("test_multicore: OK\n");
  } else {
    printf("test_multicore: FAIL (counter=%d)\n", counter);
  }
  exit(0);
}
```

## Success Criteria

### Functional Success
- [ ] All existing xv6 usertests pass (100% pass rate)
- [ ] Kernel boots successfully
- [ ] Multi-CPU operation works correctly
- [ ] All system calls behave identically
- [ ] File system operations correct
- [ ] No crashes or hangs in stress tests

### Architectural Success
- [ ] All hardware access through HAL interfaces
- [ ] No RISC-V specific code in core kernel
- [ ] Architecture code isolated in arch/riscv/
- [ ] Module interfaces defined and used
- [ ] Clear separation of concerns

### Quality Success
- [ ] >80% code coverage in unit tests
- [ ] All unit tests pass
- [ ] All integration tests pass
- [ ] No compiler warnings
- [ ] Code review approved

### Performance Success
- [ ] <5% regression in context switch time
- [ ] <5% regression in system call overhead
- [ ] <5% regression in fork time
- [ ] <5% regression in file I/O throughput
- [ ] TLB flush overhead minimal

### Documentation Success
- [ ] HAL design document complete
- [ ] Porting guide written
- [ ] Testing guide written
- [ ] All interfaces documented
- [ ] CLAUDE.md updated

## Performance Benchmarks

### Baseline Measurements (Before Refactoring)

Run these benchmarks before starting Phase 1:

**Microbenchmarks**:
- Context switch time (cycles)
- System call overhead (getpid, cycles)
- TLB flush time (cycles)
- Spinlock acquire/release (cycles)

**Macrobenchmarks**:
- Fork time (μs)
- Exec time (μs)
- File read/write throughput (MB/s)
- Process creation rate (procs/sec)

**Tool**: Write a user-space benchmark program

### Target Performance (After Refactoring)

- Context switch: <5% slower
- System call: <5% slower
- Fork: <5% slower
- Exec: <5% slower
- File I/O: <5% slower

**Acceptable Trade-off**: Small performance cost for portability and testability.

## Risk Management

### Risk 1: Breaking Existing Functionality
**Likelihood**: High
**Impact**: High
**Mitigation**:
- Incremental refactoring (one module at a time)
- Run usertests after every change
- Maintain stable branch
- Extensive integration testing

### Risk 2: Performance Regression
**Likelihood**: Medium
**Impact**: Medium
**Mitigation**:
- Benchmark before refactoring
- Inline hot paths
- Profile and optimize critical functions
- Accept <5% regression for abstraction

### Risk 3: Over-Engineering HAL
**Likelihood**: Medium
**Impact**: Low
**Mitigation**:
- Keep HAL minimal
- Design for RISC-V and x86_64 only
- Refactor HAL if needed in Phase 11
- Review interfaces with community

### Risk 4: Testing Infrastructure Complexity
**Likelihood**: Low
**Impact**: Medium
**Mitigation**:
- Use established frameworks (Unity, CMocka)
- Start with simple tests
- Automate early
- Write tests incrementally

### Risk 5: Schedule Overrun
**Likelihood**: Medium
**Impact**: Low
**Mitigation**:
- This is an educational project (no hard deadline)
- Break into smaller milestones
- Focus on learning, not speed
- It's okay to take 6 months instead of 4

## Common Pitfalls

### Pitfall 1: Trying to Refactor Everything at Once
**Problem**: Changing too much code simultaneously makes debugging impossible.
**Solution**: Refactor one module at a time. Run tests after each change.

### Pitfall 2: Not Testing Enough
**Problem**: Subtle bugs introduced during refactoring.
**Solution**: Write tests before refactoring. Achieve high coverage.

### Pitfall 3: Ignoring Performance
**Problem**: HAL overhead causes significant slowdown.
**Solution**: Benchmark critical paths. Use inline functions where needed.

### Pitfall 4: Poor Git Hygiene
**Problem**: Lost track of changes, can't revert broken refactoring.
**Solution**: Commit frequently. Write clear commit messages. Use branches.

### Pitfall 5: Incomplete HAL Abstraction
**Problem**: Some hardware access still direct.
**Solution**: Grep for hardware register access. Code review. Use static analysis.

## References

### xv6 Understanding
- xv6 Book, Chapter 2 (Operating system organization)
- xv6 Book, Chapter 3 (Page tables)
- xv6 Book, Chapter 7 (Scheduling)
- MIT 6.S081 lectures 1-5

### HAL Design
- Linux kernel `arch/` directory structure
- Zircon kernel HAL design
- The Flux OSKit paper (1997)
- seL4 HAL design

### Testing
- Unity test framework documentation
- CMocka documentation
- "Test-Driven Development for Embedded C" (James Grenning)

### RISC-V
- RISC-V Privileged Specification v1.10
- RISC-V Instruction Set Manual
- QEMU RISC-V documentation

## Appendix A: Example HAL Interface

```c
// kernel/hal/include/hal_cpu.h

#pragma once
#include "types.h"

// Opaque context structure (defined in arch-specific code)
typedef struct HalContext HalContext;

// Initialize CPU HAL
void HalCpuInit(void);

// Get current CPU ID (0-based)
int HalCpuId(void);

// Get total number of CPUs
int HalCpuCount(void);

// Interrupt control
void HalIntrEnable(void);
void HalIntrDisable(void);
int HalIntrGet(void);          // Returns 1 if enabled, 0 if disabled
void HalIntrRestore(int old);  // Restore previous interrupt state

// Context switching
// Saves current context to 'old' and loads context from 'new'
void HalContextSwitch(HalContext *old, HalContext *new);

// Initialize a new context for a process
// 'fn' will be called when context is first switched to
// 'stack_top' is the top of the stack for this context
void HalContextInit(HalContext *ctx, void (*fn)(void), void *stack_top);

// Per-CPU startup initialization
void HalCpuStartup(void);

// Halt CPU until next interrupt (for idle loop)
void HalCpuWait(void);

// Return from trap to user space
// (used by trap handler to return to user mode)
void HalUserTrapReturn(void);
```

## Appendix B: Example RISC-V HAL Implementation

```c
// kernel/arch/riscv/hal/hal_cpu_riscv.c

#include "hal/hal_cpu.h"
#include "riscv.h"

void HalCpuInit(void) {
  // RISC-V: Nothing to do, CPUs initialized in start.c
}

int HalCpuId(void) {
  // RISC-V: CPU ID stored in tp register
  return r_tp();
}

int HalCpuCount(void) {
  // Defined at compile time
  extern int ncpu;
  return ncpu;
}

void HalIntrEnable(void) {
  // RISC-V: Set SIE bit in sstatus
  w_sstatus(r_sstatus() | SSTATUS_SIE);
}

void HalIntrDisable(void) {
  // RISC-V: Clear SIE bit in sstatus
  w_sstatus(r_sstatus() & ~SSTATUS_SIE);
}

int HalIntrGet(void) {
  // RISC-V: Read SIE bit from sstatus
  uint64 x = r_sstatus();
  return (x & SSTATUS_SIE) ? 1 : 0;
}

// ... more functions ...
```

## Appendix C: File Migration Checklist

For each kernel file, track refactoring progress:

- [ ] `kernel/mm/vm.c` - Update to use HAL MMU
- [ ] `kernel/core/proc/proc.c` - Update to use HAL CPU
- [ ] `kernel/arch/riscv/trap/trap.c` - Update to use HAL interrupts
- [ ] `kernel/lib/spinlock.c` - Update to use HAL atomics
- [ ] `kernel/drivers/plic.c` - Update to use HAL interrupts
- [ ] `kernel/boot/main.c` - Update to use HAL initialization
- [ ] ... (continue for all files)

---

**Phase Status**: Ready for Implementation
**Estimated Effort**: 300-400 hours over 4-5 months
**Prerequisites**: Phase 0 complete, development environment ready
**Outputs**: Modular kernel with HAL, >80% test coverage
**Next Phase**: [Phase 2: Advanced Scheduler Implementation](phase2-advanced-scheduler.md)
