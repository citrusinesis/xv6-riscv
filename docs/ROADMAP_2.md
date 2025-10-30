# Project Context for Educational Hybrid OS Development

## Project Overview

**Goal**: Develop an educational operating system based on xv6, evolving it into a hybrid kernel architecture inspired by Darwin/XNU.

**Key Characteristics**:

-   Base: xv6 (simple Unix-like teaching OS)
-   Target Architecture: Hybrid kernel (monolithic core + user-space servers)
-   Primary Language: Pure C (C11 standard)
-   Development Methodology: Test-Driven Development (TDD)
-   Multi-architecture support: x86_64 (primary), RISC-V (secondary)
-   Build System: CMake
-   Educational purpose: Focus on learning OS concepts, not production use

## Core Design Principles

### 1. Hardware Abstraction Layer (HAL) First

-   All hardware-specific code must be isolated through HAL interfaces
-   HAL must be designed and stabilized in Phase 1
-   Function pointer-based abstraction for testability
-   Thin abstraction layer (minimal overhead)

### 2. Modular Architecture

-   Interface-based design for all major subsystems
-   Clear separation between:
    -   Hardware abstraction (`hal/`)
    -   Architecture-specific code (`arch/x86_64/`, `arch/riscv/`)
    -   Core kernel logic (`core/`)
    -   User-space servers (after Phase 6)

### 3. Testability from Day One

-   Unit tests for all HAL-independent code
-   Mock implementations of HAL for host-based testing
-   Integration tests in QEMU environment
-   End-to-end system tests

### 4. Performance Awareness

-   Benchmarking from Phase 2 onwards
-   Continuous performance regression detection
-   Quantitative validation of design decisions

## Development Phases

### Phase 0: Preparation & Architecture Design (3-4 weeks)

**Objectives**:

-   Analyze xv6 codebase thoroughly
-   Design HAL interface specifications
-   Plan directory structure
-   Define coding standards
-   Set up development environment

**Deliverables**:

-   HAL interface design document
-   Architecture design document
-   Directory structure plan
-   Development workflow setup

**Key Decisions**:

-   HAL interface granularity
-   Module boundaries
-   Testing strategy

---

### Phase 1: Modularization + HAL Foundation (4-5 months)

**Objectives**:

-   Refactor xv6 into modular components
-   Implement HAL for all hardware interactions
-   Separate architecture-specific code
-   Maintain existing functionality during refactoring

**Core Components to Develop**:

1. **HAL Interfaces**:

    - CPU abstraction (context switching, TLB)
    - MMU abstraction (page table manipulation)
    - Interrupt controller abstraction
    - Atomic operations abstraction
    - Timer abstraction

2. **Module Interfaces**:

    - VFS (Virtual File System) interface
    - Device driver interface
    - Scheduler interface
    - Memory allocator interface

3. **Architecture Separation**:
    - Move x86_64-specific code to `arch/x86_64/`
    - Implement HAL operations for x86_64
    - Boot code organization

**Testing Requirements**:

-   All original xv6 tests must pass
-   Unit tests for each module interface
-   Mock HAL implementations
-   Integration tests in QEMU

**Success Criteria**:

-   Zero functionality regression
-   All hardware access goes through HAL
-   Architecture-specific code is isolated
-   80%+ code coverage in unit tests

---

### Phase 2: Advanced Scheduler Implementation (4-5 weeks)

**Objectives**:

-   Implement multiple scheduling algorithms
-   Enable runtime scheduler selection
-   Measure and validate scheduler characteristics

**Scheduler Algorithms to Implement**:

1. **Priority-based Scheduler**:

    - Fixed priority levels
    - Priority inversion handling
    - Starvation prevention

2. **Multi-Level Feedback Queue (MLFQ)**:

    - Multiple priority queues
    - Dynamic priority adjustment
    - Time quantum per level

3. **Completely Fair Scheduler (CFS)**:
    - Virtual runtime tracking
    - Red-black tree for runqueue
    - Fairness guarantees

**Functional Requirements**:

-   Each scheduler should be a pluggable module
-   Scheduler selection via boot parameter
-   Per-process scheduling statistics
-   Load balancing (foundation for future SMP)

**Testing Requirements**:

-   Unit tests for each scheduler logic
-   Fairness measurement (Gini coefficient)
-   Latency measurement
-   CPU utilization tests

**Benchmarks**:

-   Context switch latency
-   CPU fairness distribution
-   Response time distribution
-   Throughput (processes/second)

**Success Criteria**:

-   All three schedulers implement common interface
-   Measurable fairness improvements in CFS
-   No performance regression in context switches

---

### Phase 3: Memory Management Enhancement (4-5 weeks)

**Objectives**:

-   Implement on-demand paging
-   Add copy-on-write fork
-   Support swap mechanism
-   Improve memory allocator

**Features to Implement**:

1. **Demand Paging**:

    - Lazy page allocation
    - Page fault handler
    - Page reclamation policy (LRU/Clock)

2. **Copy-on-Write Fork**:

    - Shared pages after fork
    - Write protection
    - COW fault handler

3. **Swap Support**:

    - Swap space management
    - Page-out policy
    - Swap-in on page fault

4. **Memory Allocator Improvements**:
    - Slab allocator for kernel objects
    - Buddy allocator improvements
    - Memory pool for common sizes

**Functional Requirements**:

-   Physical memory overcommit support
-   Memory pressure handling
-   OOM (Out-of-Memory) killer
-   Memory statistics tracking

**Testing Requirements**:

-   Fork bomb survival test
-   Memory pressure scenarios
-   COW correctness verification
-   Page fault latency measurement

**Benchmarks**:

-   Page fault handling time
-   Fork latency (COW vs normal)
-   Memory allocation speed
-   TLB miss rate

**Success Criteria**:

-   COW fork is faster than normal fork
-   System survives memory exhaustion
-   Proper page reclamation under pressure

---

### Phase 4: File System Enhancement (5-6 weeks)

**Objectives**:

-   Replace simple block allocation with extent-based system
-   Add journaling for crash consistency
-   Implement symbolic links
-   Improve VFS layer

**Features to Implement**:

1. **Extent-based Allocation**:

    - Extent tree structure
    - Contiguous block allocation
    - Efficient large file support

2. **Journaling**:

    - Write-ahead logging
    - Transaction support
    - Crash recovery mechanism

3. **Symbolic Links**:

    - Symlink inode type
    - Path resolution with symlinks
    - Circular symlink detection

4. **VFS Improvements**:
    - Pathname cache
    - Directory entry cache
    - Buffer cache optimization

**Functional Requirements**:

-   Crash consistency guarantees
-   Large file support (>4GB)
-   Hard link and symlink support
-   File hole support (sparse files)

**Testing Requirements**:

-   Crash recovery tests (power failure simulation)
-   Large file I/O tests
-   Symlink path resolution tests
-   Concurrent file access tests

**Benchmarks**:

-   Sequential read/write throughput
-   Random I/O IOPS
-   File creation/deletion speed
-   Directory traversal time

**Fuzzing Targets**:

-   Inode parser
-   Directory entry parser
-   Extent tree operations

**Success Criteria**:

-   No data loss after simulated crashes
-   Improved throughput for large files
-   All fuzzing runs without crashes

---

### Phase 5: IPC Mechanism Implementation (4-5 weeks)

**Objectives**:

-   Design and implement Mach-style port-based IPC
-   Enable zero-copy message passing
-   Support asynchronous messaging
-   Prepare for Phase 6 microkernel services

**IPC Features to Implement**:

1. **Port-based Messaging**:

    - Port creation and destruction
    - Send/receive rights management
    - Port name space per process

2. **Message Structure**:

    - Fixed header + variable payload
    - Out-of-line memory descriptors
    - Capability transfer

3. **Zero-copy Transfer**:

    - Page remapping for large messages
    - Threshold-based copy/remap decision
    - DMA preparation (for Phase 7)

4. **Asynchronous Operations**:
    - Non-blocking send
    - Receive with timeout
    - Message queue management

**Functional Requirements**:

-   Reliable message delivery
-   Priority-based message queuing
-   Message size up to multiple pages
-   Dead port detection

**Testing Requirements**:

-   Message ordering verification
-   Zero-copy correctness tests
-   Performance comparison (copy vs zero-copy)
-   Stress tests with many ports

**Benchmarks**:

-   Message passing latency (various sizes)
-   Throughput (messages/second)
-   Zero-copy vs normal copy performance
-   Context switch overhead in IPC

**Success Criteria**:

-   <10μs latency for small messages
-   Zero-copy shows benefits for >4KB messages
-   No message loss or corruption

---

### Phase 6: Hybrid Kernel Transition - Server Separation (6-8 weeks)

**Objectives**:

-   Move file system implementation to user-space server
-   Move disk driver to user-space server
-   Implement VFS as kernel-user interface
-   Manage I/O privilege separation

**Critical Milestone**: This is the biggest architectural change in the project.

**Components to Implement**:

1. **File System Server**:

    - User-space process with special privileges
    - Handles VFS operations via IPC
    - Manages file system state
    - Crash recovery isolation

2. **Disk Driver Server**:

    - User-space device driver
    - DMA buffer management
    - Interrupt handling via kernel upcalls
    - Block cache management

3. **Kernel VFS Layer**:

    - IPC bridge to FS server
    - Pathname lookup in kernel
    - Security checks
    - Caching strategy

4. **Privilege Management**:
    - I/O port access control
    - DMA region mapping
    - Interrupt routing
    - Capability-based access

**Functional Requirements**:

-   File operations work transparently to user processes
-   FS server crash doesn't kill kernel
-   Performance overhead <20% vs monolithic
-   Security isolation between servers

**Testing Requirements**:

-   FS server crash and restart test
-   Concurrent access from multiple processes
-   Security tests (privilege escalation attempts)
-   End-to-end file operation tests

**Benchmarks**:

-   File operation latency vs Phase 4
-   IPC overhead measurement
-   System call overhead
-   Throughput under concurrent load

**Success Criteria**:

-   All file operations work correctly
-   FS server can be restarted without reboot
-   Performance penalty acceptable for educational purpose

---

### Phase 7: PCIe Infrastructure (6-8 weeks)

**Objectives**:

-   Implement PCIe configuration space access
-   Device enumeration and driver framework
-   MSI/MSI-X interrupt support
-   DMA infrastructure

**PCIe Features to Implement**:

1. **Configuration Space Access**:

    - PCI configuration space mapping
    - Device/function enumeration
    - Capability list parsing
    - BAR (Base Address Register) setup

2. **Driver Framework**:

    - Device driver registration
    - Vendor/device ID matching
    - Driver probe/remove interface
    - Resource allocation

3. **Interrupt Handling**:

    - Legacy interrupt support
    - MSI (Message Signaled Interrupts)
    - MSI-X (extended MSI)
    - Interrupt routing

4. **DMA Support**:
    - DMA buffer allocation
    - Physical address translation
    - Scatter-gather list support
    - DMA completion notification

**Functional Requirements**:

-   Enumerate all PCIe devices on boot
-   Match drivers to devices
-   Handle hot-plug events (optional)
-   Manage interrupt vectors

**Testing Requirements**:

-   Device enumeration tests
-   Interrupt delivery tests
-   DMA correctness tests
-   Multiple device tests

**Success Criteria**:

-   All PCIe devices detected
-   At least one real driver working (e.g., e1000)
-   DMA transfers complete without corruption

---

### Phase 8: Network Card Driver (4-5 weeks)

**Objectives**:

-   Implement Intel e1000 network driver
-   Basic network stack (ARP, IP, ICMP)
-   Socket API foundation
-   Enable network communication

**Network Features to Implement**:

1. **e1000 Driver**:

    - Device initialization
    - TX/RX ring buffer management
    - Interrupt handling
    - Link status monitoring

2. **Network Stack (Minimal)**:

    - Ethernet frame processing
    - ARP protocol
    - IP packet routing
    - ICMP (ping) support

3. **Socket API Basics**:
    - Socket creation/destruction
    - Bind/listen/accept
    - Send/receive
    - Raw socket support

**Functional Requirements**:

-   Send and receive Ethernet frames
-   Respond to ping (ICMP echo)
-   ARP table management
-   Multiple sockets per process

**Testing Requirements**:

-   Loopback tests
-   Ping tests
-   Packet capture analysis
-   Throughput tests

**Benchmarks**:

-   Packet throughput (packets/second)
-   Latency (round-trip time)
-   CPU utilization during network I/O

**Success Criteria**:

-   Successfully ping the OS from host
-   Send and receive packets reliably
-   No packet loss under normal load

---

### Phase 9: Graphics Support (8-10 weeks) - Optional

**Objectives**:

-   VESA BIOS extensions support
-   Framebuffer management
-   Bitmap font rendering
-   Simple window system

**Graphics Features to Implement**:

1. **VESA Support**:

    - Mode enumeration
    - Mode switching
    - Framebuffer mapping
    - Linear framebuffer access

2. **Framebuffer Management**:

    - Pixel format abstraction
    - Double buffering
    - Dirty region tracking
    - Hardware cursor (optional)

3. **Font Rendering**:

    - Bitmap font loading
    - Text rendering
    - Unicode support (basic)
    - Anti-aliasing (optional)

4. **Window System**:
    - Window creation/destruction
    - Z-order management
    - Event handling (keyboard/mouse)
    - Simple compositing

**Functional Requirements**:

-   Display text on screen
-   Multiple windows
-   Window movement/resize
-   Keyboard/mouse input

**Testing Requirements**:

-   Rendering correctness tests
-   Performance tests (FPS)
-   Event handling tests

**Success Criteria**:

-   Usable graphical terminal
-   Acceptable rendering performance
-   Stable window management

---

### Phase 10: Optimization & Completion (4-6 weeks)

**Objectives**:

-   Performance profiling and optimization
-   Stability improvements
-   Comprehensive benchmarking
-   Documentation completion

**Optimization Areas**:

-   Hot path optimization
-   Cache-friendly data structures
-   Lock contention reduction
-   Algorithm improvements

**Stability Work**:

-   Edge case handling
-   Error path testing
-   Resource leak detection
-   Race condition fixes

**Documentation**:

-   Architecture documentation
-   API documentation
-   Design decision rationale
-   User manual

**Success Criteria**:

-   All benchmarks show acceptable performance
-   No known critical bugs
-   Complete documentation

---

### Phase 11: Multi-Architecture Porting (6-8 weeks)

**Objectives**:

-   Complete x86_64 architecture isolation
-   Port to RISC-V architecture
-   Cross-compilation support
-   Architecture-specific testing

**RISC-V Porting Tasks**:

1. **Boot and Initialization**:

    - RISC-V boot protocol
    - SBI (Supervisor Binary Interface) calls
    - Device tree parsing
    - Initial page table setup

2. **HAL Implementation**:

    - RISC-V context switching
    - MMU operations (Sv39/Sv48)
    - Trap handling
    - Timer and interrupt controller

3. **Build System**:
    - Cross-compiler setup
    - Architecture selection in CMake
    - QEMU targets for both architectures
    - Separate test suites

**Functional Requirements**:

-   All core features work on both architectures
-   Shared codebase with minimal `#ifdef`
-   Performance comparable between architectures

**Testing Requirements**:

-   Port all unit tests to RISC-V
-   Integration tests on QEMU RISC-V
-   Cross-architecture consistency tests

**Success Criteria**:

-   Both architectures boot successfully
-   Core functionality identical
-   Test pass rate >95% on both

---

## Testing Strategy

### Three-tier Testing Approach

**Tier 1: Unit Tests (Host Environment)**

-   Run on development machine (x86_64 Linux/Mac)
-   Use Unity test framework
-   Mock HAL implementations via CMocka
-   Fast feedback (<1 minute for all tests)
-   Continuous execution during development

**Tier 2: Integration Tests (QEMU)**

-   Run full kernel in QEMU
-   Test inter-module interactions
-   File system, IPC, networking tests
-   Moderate speed (5-10 minutes)
-   Run on every commit

**Tier 3: End-to-End Tests (Full Boot)**

-   Complete boot sequence
-   User-space test programs
-   System stability tests
-   Slow (20-30 minutes)
-   Run before merge to main branch

### Test Coverage Goals

-   Unit tests: >80% line coverage
-   Integration tests: All major features
-   E2E tests: Real-world scenarios

---

## Benchmarking Strategy

### Continuous Benchmarking

-   Run critical benchmarks on every PR
-   Compare against baseline
-   Detect performance regressions
-   Track improvements over phases

### Benchmark Suite by Phase

-   Phase 2: Scheduler benchmarks (latency, fairness, throughput)
-   Phase 3: Memory benchmarks (page fault, fork, allocation)
-   Phase 4: File system benchmarks (I/O, metadata operations)
-   Phase 5: IPC benchmarks (message passing latency/throughput)
-   Phase 6+: End-to-end system call benchmarks

### Performance Regression Policy

-   > 5% regression requires investigation
-   > 10% regression blocks merge
-   Document all performance trade-offs

---

## Fuzzing Strategy

### Priority Fuzzing Targets

**Phase 4 (File System)**:

-   Inode parser
-   Directory entry parser
-   Extent tree operations

**Phase 5 (IPC)**:

-   Message parser
-   Port operations
-   Capability transfer

**Phase 6+ (System Interfaces)**:

-   System call input validation
-   VFS interface
-   Server communication protocols

### Fuzzing Tools

-   AFL++ for simple parsers
-   libFuzzer with ASAN/UBSAN for complex logic
-   Continuous fuzzing in CI (nightly runs)

### Success Criteria

-   Zero crashes from fuzzing in critical components
-   All found bugs must be fixed before phase completion

---

## Development Toolchain

### Required Tools

-   CMake 3.20+
-   GCC/Clang with C11 support
-   Cross-compilers: x86_64-elf-gcc, riscv64-unknown-elf-gcc
-   QEMU (x86_64 and RISC-V system emulation)
-   Unity test framework
-   CMocka for mocking
-   AFL++ / libFuzzer for fuzzing
-   Git for version control

### Optional Tools

-   gcov/lcov for coverage
-   Valgrind for memory debugging (host tests)
-   GDB for kernel debugging
-   perf for profiling

---

## Coding Standards

### C Language Standards

-   Pure C11, no C++ features
-   No compiler-specific extensions (except where necessary for OS development)
-   Explicit integer types (uint32_t, int64_t, etc.)

### Naming Conventions (Google C++ Style adapted for C)

-   Functions: `PascalCase` (e.g., `SchedulerInit`)
-   Variables/parameters: `snake_case` (e.g., `proc_count`)
-   Types/structs: `PascalCase` or `snake_case_t` (e.g., `struct Process` or `process_t`)
-   Constants: `kConstantName` (e.g., `kMaxProcesses`)
-   Macros: `MACRO_NAME` (minimize usage)

### Code Organization

-   2-space indentation (no tabs)
-   80-character line limit
-   Header guards: `#pragma once` or traditional
-   No `using namespace` equivalent
-   Forward declarations when possible

### Comments

-   Function comments for complex logic
-   TODO format: `// TODO(username): description`
-   Single-line: `//`, block comments for disabling code only

---

## Project Structure

```
project/
├── kernel/
│   ├── hal/              # Hardware abstraction interfaces
│   ├── core/             # Core kernel (scheduler, proc, etc.)
│   ├── mm/               # Memory management
│   ├── fs/               # File system (until Phase 6)
│   ├── ipc/              # IPC mechanism
│   ├── net/              # Network stack
│   └── arch/
│       ├── x86_64/       # x86_64-specific code
│       └── riscv/        # RISC-V-specific code
├── servers/              # User-space servers (Phase 6+)
│   ├── fs_server/
│   └── driver_server/
├── user/                 # User-space programs
├── tests/
│   ├── unit/             # Unit tests (host)
│   ├── integration/      # Integration tests (QEMU)
│   ├── e2e/              # End-to-end tests
│   ├── benchmark/        # Benchmarks
│   └── fuzzing/          # Fuzzing harnesses
├── docs/                 # Documentation
├── cmake/                # CMake modules
└── scripts/              # Build and test scripts
```

---

## Critical Success Factors

1. **HAL Quality**: HAL must be well-designed and stable before Phase 11
2. **Test Coverage**: High test coverage prevents regressions during refactoring
3. **IPC Performance**: Phase 6 success depends on efficient IPC
4. **Incremental Progress**: Each phase must be fully completed before moving on
5. **Documentation**: Document design decisions as you go
6. **Time Management**: Don't let Phase 9 (graphics) distract from core functionality

---

## Educational Goals

### Learning Outcomes

-   Deep understanding of OS architecture
-   Experience with hybrid/microkernel design
-   Practical TDD in systems programming
-   Performance analysis and optimization
-   Multi-architecture considerations
-   Security isolation techniques

### Skills Developed

-   Low-level C programming
-   Hardware abstraction design
-   Concurrent programming
-   Debugging complex systems
-   Performance profiling
-   Build system management

---

## What NOT to Include in Specifications

❌ **Complete code implementations**: Specifications should describe WHAT to build, not HOW in detailed code

❌ **Copy-paste solutions**: Educational value comes from implementation challenges

❌ **Full algorithms**: Describe algorithm requirements, not step-by-step pseudocode

✅ **Instead, provide**:

-   Functional requirements
-   Interface specifications
-   Test criteria
-   Success metrics
-   Design constraints
-   References to existing implementations (xv6, Linux, Darwin)

---

## Estimated Timeline

**Part-time development (10-15 hours/week)**:

-   Total: 22-24 months

**Full-time development (40 hours/week)**:

-   Total: 8-10 months

**Per Phase**:

-   Short phases (2-5 weeks): Focused feature work
-   Long phases (6-8 weeks): Major architectural changes
-   Buffer time: Add 20% for unexpected challenges

---

This context should enable specification documents to be written for each phase, focusing on functional requirements, design constraints, testing criteria, and success metrics, while leaving implementation details as learning exercises.
