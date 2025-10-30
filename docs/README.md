# xv6-riscv Documentation

This directory contains comprehensive documentation for transforming xv6-riscv into a hybrid kernel operating system inspired by Darwin/XNU.

## Project Overview

This project evolves xv6 (a simple Unix-like teaching OS) into a hybrid kernel architecture through systematic phases. The development methodology emphasizes:

- **Test-Driven Development (TDD)**: Unit, integration, and end-to-end tests
- **Hardware Abstraction Layer (HAL)**: Multi-architecture support (RISC-V, x86_64)
- **Modular Design**: Interface-based architecture with clear separation of concerns
- **Educational Focus**: Learning OS concepts, not just building features
- **Pure C Implementation**: C11 standard, minimal compiler-specific extensions

## Documentation Structure

```
docs/
├── README.md                    # This file
├── ROADMAP_2.md                 # Hybrid kernel development roadmap (22-24 months)
└── spec/                        # Detailed phase specifications
    ├── Phase 0-1: Foundation
    │   ├── phase0-preparation.md
    │   └── phase1-modularization-hal.md
    ├── Phase 2-4: Core Enhancements
    │   ├── phase2-advanced-scheduler.md
    │   ├── phase3-memory-management.md
    │   └── phase4-filesystem-enhancement.md
    ├── Phase 5-6: Hybrid Kernel Transition
    │   ├── phase5-ipc-mechanism.md
    │   └── phase6-hybrid-kernel-transition.md
    ├── Phase 7-9: Hardware & I/O
    │   ├── phase7-pcie-infrastructure.md
    │   ├── phase8-network-card-driver.md
    │   └── phase9-graphics-support.md (OPTIONAL)
    └── Phase 10-11: Finalization
        ├── phase10-optimization-completion.md
        └── phase11-multi-architecture-porting.md
```

## Getting Started

1. **Read the roadmap**: [ROADMAP_2.md](ROADMAP_2.md)
2. **Start with Phase 0**: [Phase 0 Specification](spec/phase0-preparation.md)
3. **Understand xv6**: Read CLAUDE.md for project context
4. **Set up environment**: Install RISC-V toolchain, QEMU, build tools
5. **Begin implementation**: Follow phase specifications in order

## Phase Overview

| Phase | Title | Duration | Focus | Status |
|-------|-------|----------|-------|--------|
| **0** | Preparation & Architecture Design | 3-4 weeks | Analysis, HAL design, planning | ✅ Spec Ready |
| **1** | Modularization + HAL Foundation | 4-5 months | HAL implementation, arch separation | 🚧 In Progress |
| **2** | Advanced Scheduler | 4-5 weeks | Priority, MLFQ, CFS schedulers | ✅ Spec Ready |
| **3** | Memory Management | 4-5 weeks | Demand paging, COW, swap | ✅ Spec Ready |
| **4** | File System Enhancement | 5-6 weeks | Extents, journaling, symlinks | ✅ Spec Ready |
| **5** | IPC Mechanism | 4-5 weeks | Mach-style port-based IPC | ✅ Spec Ready |
| **6** | Hybrid Kernel Transition | 6-8 weeks | FS & driver servers | ✅ Spec Ready |
| **7** | PCIe Infrastructure | 6-8 weeks | Device enumeration, MSI, DMA | ✅ Spec Ready |
| **8** | Network Card Driver | 4-5 weeks | e1000, TCP/IP stack | ✅ Spec Ready |
| **9** | Graphics Support | 8-10 weeks | VESA, framebuffer, window system | ✅ Spec Ready (Optional) |
| **10** | Optimization & Completion | 4-6 weeks | Performance, stability, docs | ✅ Spec Ready |
| **11** | Multi-Architecture Porting | 6-8 weeks | x86_64 port | ✅ Spec Ready |

## How to Use the Specifications

Each specification document is designed for **educational purposes** and follows these principles:

### ✅ What Specifications Include

- **Functional Requirements**: WHAT needs to be built
- **Interface Specifications**: APIs, contracts, data structures (conceptual)
- **Testing Requirements**: Unit, integration, e2e test criteria
- **Success Criteria**: Measurable goals for phase completion
- **Design Constraints**: Architectural boundaries and trade-offs
- **References**: Links to papers, existing implementations, learning resources

### ❌ What Specifications DON'T Include

- **Complete Code Implementations**: Learn by implementing yourself
- **Copy-Paste Solutions**: Educational value comes from solving challenges
- **Step-by-Step Algorithms**: Understand concepts, implement your way

### Reading a Specification

Each spec contains:

1. **Overview**: Phase goals and context
2. **Objectives**: What you'll learn and achieve
3. **Functional Requirements**: Feature descriptions and interfaces
4. **Non-Functional Requirements**: Performance, quality standards
5. **Testing Requirements**: How to verify correctness
6. **Success Criteria**: Completion checklist
7. **Implementation Strategy**: Suggested approach (week-by-week)
8. **Common Pitfalls**: Known challenges and solutions
9. **References**: Academic papers, OS implementations, tools

## Implementation Workflow

### Before Starting a Phase

1. Read the specification completely
2. Review prerequisite knowledge (study guide in spec)
3. Set up any new tools/frameworks required
4. Understand success criteria
5. Create a task list or project plan

### During Implementation

1. **Follow TDD**: Write tests before implementation
2. **Commit frequently**: Small, logical commits with clear messages
3. **Run tests constantly**: Verify correctness continuously
4. **Measure performance**: Benchmark critical operations
5. **Document decisions**: Record design choices and trade-offs

### After Completing a Phase

1. **Verify success criteria**: Check all items on completion checklist
2. **Run full test suite**: Ensure no regressions
3. **Performance validation**: Verify performance targets met
4. **Documentation**: Update docs with implementation details
5. **Code review**: Review and refactor if needed
6. **Plan next phase**: Read next specification and prepare

## Testing Strategy

### Three-Tier Testing Pyramid

```
         /\
        /E2E\        20% - End-to-end (Full system, slow)
       /------\
      /  Int   \     30% - Integration (QEMU, moderate)
     /----------\
    /    Unit    \   50% - Unit tests (Host, fast)
   /--------------\
```

### Coverage Goals

- **Unit tests**: >80% line coverage of architecture-independent code
- **Integration tests**: All major features and inter-module interactions
- **E2E tests**: Real-world usage scenarios and stress tests

### Test Execution

- **Continuous**: Unit tests run on every file save
- **On commit**: Integration tests via pre-commit hook
- **On PR**: Full test suite including E2E tests
- **Nightly**: Extended stress tests, fuzzing, performance benchmarks

## Development Tools

### Required Tools

- **Build System**: CMake 3.20+
- **Compiler**: GCC/Clang with C11 support
- **Cross-Compilers**:
  - riscv64-unknown-elf-gcc (or riscv64-linux-gnu-gcc)
  - x86_64-elf-gcc (Phase 11)
- **Emulator**: QEMU 7.2+ (riscv64-softmmu, x86_64-softmmu)
- **Debugger**: GDB with multi-arch support
- **Testing**: Unity (unit tests), CMocka (mocking)
- **Version Control**: Git

### Optional Tools

- **Coverage**: gcov, lcov
- **Fuzzing**: AFL++, libFuzzer
- **Profiling**: perf, gprof
- **Memory Debugging**: Valgrind (for host tests)
- **Static Analysis**: clang-tidy, cppcheck

## Resources

### Primary Documentation

- **[ROADMAP_2.md](ROADMAP_2.md)**: Overall project plan and methodology
- **[CLAUDE.md](../CLAUDE.md)**: Project-specific guidance for AI assistance
- **Phase Specifications**: Detailed requirements in `spec/` directory

### xv6 Learning

- [xv6 Book (RISC-V)](https://pdos.csail.mit.edu/6.828/2023/xv6/book-riscv-rev3.pdf)
- [MIT 6.S081 Course](https://pdos.csail.mit.edu/6.828/)
- [xv6 Source](https://github.com/mit-pdos/xv6-riscv)

### Architecture Specifications

- [RISC-V ISA Manual](https://riscv.org/technical/specifications/)
- [RISC-V Privileged Spec](https://riscv.org/specifications/privileged-isa/)
- [Intel x86_64 Manual](https://www.intel.com/content/www/us/en/developer/articles/technical/intel-sdm.html)

### Reference Implementations

- **Linux Kernel**: Multi-architecture HAL design (arch/ directory)
- **Darwin/XNU**: Hybrid kernel architecture
- **Zircon**: Modern microkernel with clean abstractions
- **seL4**: Formally verified kernel design

### Academic Papers

- "The Flux OSKit" (Ford et al., 1997) - OS toolkit design
- "Improving IPC by Kernel Design" (Liedtke, 1993) - Microkernel IPC
- "The Linux Scheduler: a Decade of Wasted Cores" (Lozi et al., 2016)
- "Crash Consistency: FSCK and Journaling" (OSTEP book chapter)

### Books

- *Operating Systems: Three Easy Pieces* (Arpaci-Dusseau)
- *Modern Operating Systems* (Tanenbaum)
- *The Design and Implementation of the FreeBSD Operating System* (McKusick)
- *Computer Systems: A Programmer's Perspective* (Bryant & O'Hallaron)

## Progress Tracking

### Recommended Practices

1. **Maintain a Development Log**:
   - Features implemented
   - Challenges encountered and solutions
   - Design decisions and rationale
   - Performance measurements
   - Time spent per phase

2. **Use Version Control Effectively**:
   - One feature branch per major task
   - Clear commit messages referencing issues
   - Tag releases at phase completions
   - Maintain clean git history

3. **Document as You Go**:
   - Update CLAUDE.md with architectural changes
   - Document non-obvious design decisions
   - Write inline comments for complex logic
   - Create architecture diagrams

4. **Measure Progress**:
   - Track test coverage over time
   - Monitor performance benchmarks
   - Count lines of code (architecture-independent vs. specific)
   - Record successful test runs

## Common Pitfalls

### Pitfall 1: Skipping Phase 0
**Problem**: Jumping into implementation without design.
**Solution**: Complete Phase 0 thoroughly. Good design saves months of refactoring.

### Pitfall 2: Over-Engineering
**Problem**: Building for hypothetical future requirements.
**Solution**: Implement for known needs. Refactor when requirements become clear.

### Pitfall 3: Insufficient Testing
**Problem**: Breaking existing functionality during refactoring.
**Solution**: Maintain >80% test coverage. Run tests continuously.

### Pitfall 4: Ignoring Performance
**Problem**: Abstractions causing significant slowdown.
**Solution**: Benchmark critical paths. Use inline functions for hot paths.

### Pitfall 5: Poor Documentation
**Problem**: Forgetting design rationale after 6 months.
**Solution**: Document decisions immediately. Future you will thank present you.

## Getting Help

### Community Resources

- **MIT 6.S081 Forum**: Ask questions about xv6 concepts
- **OSDev Forums**: General OS development community
- **RISC-V Discord**: Architecture-specific questions
- **GitHub Issues**: Report bugs in this project

### Asking Effective Questions

1. **Provide context**: Which phase? What are you implementing?
2. **Show your work**: What have you tried? What didn't work?
3. **Include details**: Error messages, unexpected behavior, environment
4. **Be specific**: "How does trap handling work?" vs "My trap handler crashes when..."

## Project Status

**Current Phase**: Phase 1 (Modularization + HAL Foundation)
**Last Updated**: 2025-10-30

See [ROADMAP_2.md](ROADMAP_2.md) for detailed status and timeline.

## Contributing

This is an educational project. While the primary goal is personal learning, contributions are welcome:

1. **Bug Reports**: Found an issue in specifications? Open an issue
2. **Improvements**: Better explanations or additional references
3. **Test Cases**: Share your test implementations
4. **Learning Experience**: Blog about your journey

## License

This documentation is provided for educational purposes. The xv6 kernel itself is under MIT license (see LICENSE file).

---

**Good luck on your xv6 hybrid kernel journey!**

For questions or guidance, refer to:
- [ROADMAP_2.md](ROADMAP_2.md) - Overall project plan
- [CLAUDE.md](../CLAUDE.md) - Project-specific guidance
- [Phase 0 Specification](spec/phase0-preparation.md) - Start here
