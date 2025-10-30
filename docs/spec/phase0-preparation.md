# Phase 0: Preparation & Architecture Design

**Duration**: 3-4 weeks
**Prerequisites**: None
**Next Phase**: Phase 1 (Modularization + HAL Foundation)

## Overview

Phase 0 is the planning and design phase. Before writing any code, you must thoroughly understand the xv6 codebase and design the architectural foundations that will guide all future development.

**Core Objective**: Analyze xv6 architecture, design HAL interfaces, and establish development standards that will enable the transformation to a hybrid kernel.

## Objectives

### Primary Goals
1. Complete analysis of xv6-riscv codebase structure and dependencies
2. Design Hardware Abstraction Layer (HAL) interface specifications
3. Plan modular directory structure for hybrid kernel architecture
4. Define coding standards and conventions
5. Set up development environment and workflow

### Learning Outcomes
- Deep understanding of xv6 architecture and design decisions
- Experience with interface-driven design
- Skills in architectural planning for large refactoring projects
- Understanding of hardware abstraction requirements

## Deliverables

### 1. Codebase Analysis Document

**Purpose**: Document current xv6 architecture to inform refactoring decisions.

**Required Content**:

#### 1.1 Module Dependency Map
- Identify all major subsystems (process, memory, filesystem, drivers, etc.)
- Document dependencies between modules
- Identify circular dependencies that need breaking
- Create visual dependency graph

**Questions to Answer**:
- Which modules directly access hardware?
- Which modules depend on architecture-specific code?
- What are the key interfaces between modules?
- Where are the abstraction boundaries?

#### 1.2 Hardware Interaction Analysis
- List all points where code directly accesses hardware registers
- Document RISC-V specific instructions used (`csrr`, `csrw`, etc.)
- Identify interrupt and trap handling mechanisms
- Document memory-mapped I/O regions

**Files to Analyze**:
- `kernel/riscv.h` - RISC-V specific definitions
- `kernel/memlayout.h` - Memory layout
- `kernel/start.c`, `kernel/entry.S` - Boot sequence
- `kernel/trap.c`, `kernel/trampoline.S` - Trap handling
- `kernel/vm.c` - Page table operations
- `kernel/plic.c` - Interrupt controller
- `kernel/uart.c` - Serial driver

#### 1.3 Data Structure Inventory
- Document all major data structures
- Identify which contain architecture-specific fields
- Determine which can be made architecture-independent

**Key Structures**:
- `struct proc` - Process control block
- `struct context` - Saved registers for context switch
- `struct trapframe` - Saved user state during traps
- `struct cpu` - Per-CPU state
- `pagetable_t` - Page table type

### 2. HAL Interface Design Document

**Purpose**: Specify the HAL interfaces that will abstract all hardware interactions.

**Required Content**:

#### 2.1 HAL Modules
Define interfaces for each hardware abstraction:

**CPU Abstraction**:
- Operations: context switching, CPU identification, interrupt control
- State: per-CPU data, current process
- Requirements: must support multi-core, must be efficient

**MMU Abstraction**:
- Operations: page table manipulation, TLB management, address translation
- State: current page table
- Requirements: support multiple page table formats (Sv39, Sv48)

**Interrupt Controller Abstraction**:
- Operations: enable/disable interrupts, register handlers, claim/complete
- State: interrupt routing tables
- Requirements: support PLIC (RISC-V) and APIC (x86_64)

**Timer Abstraction**:
- Operations: read timer, set interval, get frequency
- State: timer configuration
- Requirements: support microsecond precision

**Atomic Operations Abstraction**:
- Operations: compare-and-swap, atomic add, memory barriers
- State: none
- Requirements: map to ISA-specific atomics (RISC-V AMO, x86 LOCK prefix)

#### 2.2 Interface Granularity
For each HAL module, decide:
- Should it use function pointers (runtime polymorphism)?
- Should it use inline functions/macros (compile-time)?
- What is the performance trade-off?

**Guidelines**:
- Hot paths (context switch, TLB flush): inline or macro
- Cold paths (initialization, error handling): function pointers acceptable
- Testing paths: prefer function pointers for mockability

#### 2.3 Error Handling Strategy
- Define error code conventions
- Specify when functions can panic vs. return errors
- Document recovery strategies

### 3. Directory Structure Plan

**Purpose**: Design the directory layout that will organize the modular hybrid kernel.

**Required Decisions**:

#### 3.1 Top-Level Organization
```
kernel/
├── hal/           # Hardware Abstraction Layer interfaces
├── arch/          # Architecture-specific implementations
├── core/          # Core kernel (architecture-independent)
├── mm/            # Memory management
├── fs/            # File system (until Phase 6)
├── drivers/       # Device drivers
├── ipc/           # IPC mechanism (Phase 5+)
├── net/           # Network stack (Phase 8+)
└── include/       # Global kernel headers
```

#### 3.2 Architecture-Specific Layout
```
arch/
├── riscv/
│   ├── include/      # RISC-V headers
│   ├── boot/         # Boot code
│   ├── hal/          # HAL implementation
│   └── trap/         # Trap handling
└── x86_64/          # Future: Phase 11
    └── ...
```

#### 3.3 Testing Layout
```
tests/
├── unit/            # Unit tests (host-based)
│   ├── hal_mock/    # Mock HAL implementations
│   └── ...
├── integration/     # Integration tests (QEMU)
└── e2e/             # End-to-end tests
```

**Rationale for Each Directory**: Document why each directory exists and what belongs in it.

### 4. Coding Standards Document

**Purpose**: Establish consistent code style for the entire project.

**Required Standards**:

#### 4.1 Language and Compiler
- Pure C11, no C++ features
- No compiler-specific extensions (except where necessary for OS dev)
- Explicit integer types (`uint32_t`, `int64_t`)
- Compile with `-Wall -Werror`

#### 4.2 Naming Conventions
**Inspired by Google C++ Style, adapted for C**:

- **Functions**: `PascalCase` for public APIs (e.g., `HalCpuInit`, `SchedEnqueue`)
- **Variables**: `snake_case` (e.g., `proc_count`, `cpu_id`)
- **Types**: `PascalCase` or `snake_case_t` (e.g., `HalContext` or `hal_context_t`)
- **Constants**: `kConstantName` (e.g., `kMaxProcesses`, `kPageSize`)
- **Macros**: `MACRO_NAME` (e.g., `HAL_PTE_VALID`) - minimize usage
- **Static functions**: `snake_case` with module prefix (e.g., `sched_enqueue`)
- **Global variables**: `g_` prefix (e.g., `g_sched_ops`)

#### 4.3 Code Organization
- 2-space indentation (no tabs)
- 80-character line limit
- Header guards: `#pragma once` or traditional
- Include order: system → HAL → kernel → local

#### 4.4 Documentation
- Function comments for complex logic
- Interface documentation in headers
- Implementation notes in source
- TODO format: `// TODO(username): description`

### 5. Development Environment Setup

**Purpose**: Configure tools and workflow for efficient development.

**Required Setup**:

#### 5.1 Build System
- CMake 3.20+ configuration
- Support for multiple architectures (RISC-V initially)
- Separate build targets: kernel, user programs, tests
- Debug and release configurations

#### 5.2 Toolchain
- **RISC-V**: riscv64-unknown-elf-gcc or riscv64-linux-gnu-gcc
- **QEMU**: 7.2+ with riscv64-softmmu
- **Debugger**: riscv64-unknown-elf-gdb or gdb-multiarch
- **Future (Phase 11)**: x86_64-elf-gcc

#### 5.3 Testing Tools
- **Unit tests**: Unity test framework
- **Mocking**: CMocka
- **Coverage**: gcov/lcov
- **Fuzzing**: AFL++ or libFuzzer (Phase 4+)

#### 5.4 Version Control
- Git workflow (main, development, feature branches)
- Commit message conventions
- Branch naming conventions

#### 5.5 CI/CD
- GitHub Actions or similar
- Automated builds on commit
- Automated test execution
- Coverage reporting

## Key Decisions to Make

### Decision 1: HAL Implementation Strategy

**Options**:

**A. Function Pointer Tables (Runtime Polymorphism)**
```c
typedef struct {
  void (*init)(void);
  int (*cpu_id)(void);
  void (*intr_enable)(void);
} HalCpuOps;

extern HalCpuOps g_hal_cpu;
```

**Pros**: Maximum flexibility, easy mocking, clean architecture
**Cons**: Small overhead from indirect calls, requires initialization

**B. Compile-Time Selection (Macros/Inline)**
```c
#ifdef ARCH_RISCV
  static inline int HalCpuId(void) { return r_tp(); }
#elif ARCH_X86_64
  static inline int HalCpuId(void) { /* x86 implementation */ }
#endif
```

**Pros**: Zero overhead, compiler can optimize
**Cons**: Less flexible, harder to test, more #ifdefs

**Recommended**: Hybrid approach
- Hot paths: inline functions with #ifdef
- Cold paths: function pointers
- Testing: function pointers via build flag

### Decision 2: Module Interface Abstraction Level

**Questions**:
- How abstract should scheduler interface be?
- Should VFS be designed now or in Phase 4?
- What level of driver framework is needed?

**Guidelines**:
- Design interfaces for Phase 1-6 now
- Keep them simple and extensible
- Over-engineering risk: design for current needs, refactor when needed

### Decision 3: Testing Strategy

**Unit Test Scope**:
- What percentage of code should be unit testable?
- Target: >80% of architecture-independent code

**Integration Test Approach**:
- Use existing xv6 test framework or new framework?
- How to automate QEMU-based tests?

### Decision 4: Performance Budgets

**Acceptable Overhead**:
- Phase 1 (HAL): <5% performance regression
- Phase 2 (Scheduler): Depends on algorithm, measure baseline
- Phase 5 (IPC): <10μs for small messages
- Phase 6 (Server separation): <20% overhead vs monolithic

**Measurement Strategy**:
- Benchmark before each phase
- Track regressions
- Document trade-offs

## Success Criteria

### Documentation Complete
- [ ] Codebase analysis document written
- [ ] HAL interface design document written
- [ ] Directory structure plan documented with rationale
- [ ] Coding standards document written
- [ ] All key decisions documented

### Environment Ready
- [ ] Build system (CMake) configured and tested
- [ ] RISC-V toolchain installed and verified
- [ ] QEMU running xv6 successfully
- [ ] GDB debugging setup and tested
- [ ] Version control workflow established

### Design Review
- [ ] HAL interfaces reviewed for completeness
- [ ] Directory structure reviewed for scalability
- [ ] Coding standards reviewed for consistency
- [ ] Testing strategy reviewed for feasibility

### Knowledge Acquired
- [ ] Can explain xv6 boot sequence
- [ ] Can trace a system call from user to kernel
- [ ] Can explain page table structure
- [ ] Can explain process scheduling
- [ ] Can explain trap handling mechanism

## Study Guide

### Week 1: Boot and Initialization

**Goals**:
- Understand how xv6 boots
- Learn RISC-V privilege levels
- Understand memory layout

**Files to Study**:
1. `kernel/entry.S` - First code executed
2. `kernel/start.c` - Machine mode initialization
3. `kernel/main.c` - Kernel initialization
4. `kernel/memlayout.h` - Physical memory map

**Exercises**:
- Draw the boot sequence flowchart
- Document what each initialization function does
- Explain why entry.S sets up a stack before calling start()

### Week 2: Memory Management

**Goals**:
- Understand physical memory allocation
- Understand virtual memory and page tables
- Learn RISC-V Sv39 page table format

**Files to Study**:
1. `kernel/kalloc.c` - Physical allocator
2. `kernel/vm.c` - Virtual memory
3. `kernel/riscv.h` - Page table macros
4. `kernel/proc.c` - Process memory layout

**Exercises**:
- Draw the page table structure for a process
- Trace how walk() finds a PTE
- Explain the difference between kvmmap() and uvmmap()

### Week 3: Process Management and Traps

**Goals**:
- Understand process structure and lifecycle
- Understand trap handling mechanism
- Learn context switching

**Files to Study**:
1. `kernel/proc.c` - Process management
2. `kernel/trap.c` - Trap handler
3. `kernel/trampoline.S` - User/kernel transition
4. `kernel/swtch.S` - Context switch

**Exercises**:
- Draw process state diagram
- Trace a system call from user space to kernel and back
- Explain why trampoline needs to be mapped in both user and kernel space

### Week 4: Design and Documentation

**Goals**:
- Synthesize knowledge into design documents
- Make key architectural decisions
- Plan implementation strategy

**Tasks**:
- Write all deliverable documents
- Create HAL interface specifications
- Design directory structure
- Establish coding standards
- Set up development environment

## Resources

### Primary Resources
- **xv6 Book (RISC-V edition)**: https://pdos.csail.mit.edu/6.828/2023/xv6/book-riscv-rev3.pdf
- **MIT 6.S081 Course**: https://pdos.csail.mit.edu/6.828/2023/schedule.html
- **RISC-V Privileged Spec**: https://riscv.org/specifications/privileged-isa/

### Reference Implementations
- **Linux kernel arch/ directory**: Example of multi-architecture support
- **Darwin/XNU source**: Hybrid kernel architecture
- **seL4**: Formally verified kernel with HAL
- **Zircon**: Modern microkernel with clean HAL design

### Design References
- "The Flux OSKit" paper - OS toolkit design
- "Improving IPC by Kernel Design" (Liedtke) - Microkernel principles
- Google C++ Style Guide (adapt for C)

### Tools Documentation
- CMake documentation
- Unity test framework documentation
- CMocka documentation
- GDB manual

## Common Pitfalls

### Pitfall 1: Over-Engineering
**Problem**: Designing overly complex HAL for hypothetical future needs.
**Solution**: Design for known requirements (RISC-V, x86_64). Keep it simple.

### Pitfall 2: Insufficient Analysis
**Problem**: Starting Phase 1 without understanding xv6 deeply.
**Solution**: Complete all study exercises. Don't rush this phase.

### Pitfall 3: Unclear Interfaces
**Problem**: Vague HAL interfaces lead to confusion in Phase 1.
**Solution**: Write example usage code for each HAL function.

### Pitfall 4: Ignoring Performance
**Problem**: Not measuring baseline performance before refactoring.
**Solution**: Write and run benchmarks during Phase 0.

## Next Steps

After completing Phase 0:

1. **Review**: Have design documents reviewed by peers or community
2. **Prototype**: Optionally, create small HAL prototypes to validate design
3. **Plan Phase 1**: Create detailed task list for Phase 1 based on designs
4. **Proceed**: Begin Phase 1 implementation with confidence

**Success Indicator**: You should be able to explain your entire HAL design and directory structure to someone else without referring to notes.

---

**Phase Status**: Planning
**Estimated Effort**: 40-60 hours
**Prerequisites**: Strong C programming, basic OS concepts
**Outputs**: 5 design documents, working dev environment
**Next Phase**: [Phase 1: Modularization + HAL Foundation](phase1-modularization-hal.md)
