# Phase 11: Multi-Architecture Porting (RISC-V to x86_64)

**Duration**: 6-8 weeks
**Prerequisites**: Phases 1-10 complete, HAL stable, Phase 10 optimization done
**Next Phase**: None (Project Complete)

## Overview

Phase 11 validates the Hardware Abstraction Layer (HAL) design from Phase 1 by porting the entire operating system from RISC-V to x86_64 architecture. This phase demonstrates the portability achieved through careful architectural design and provides practical experience with multi-architecture operating system development.

**Core Objective**: Port the hybrid kernel OS to x86_64 architecture with minimal changes to core kernel code, demonstrating HAL effectiveness and establishing a true multi-architecture operating system.

**Important Note**: This phase is the ultimate validation of Phase 1's HAL design. If Phase 1 was done correctly, porting should require changes only to architecture-specific code in `kernel/arch/`, not to core kernel logic.

## Objectives

### Primary Goals
1. Implement x86_64 HAL providing identical interface to RISC-V HAL
2. Port boot sequence and early initialization to x86_64
3. Adapt memory management for x86_64 page tables (4-level)
4. Port interrupt and exception handling to x86_64
5. Ensure all core functionality works identically on both architectures
6. Achieve >95% test pass rate on x86_64

### Learning Outcomes
- x86_64 architecture fundamentals (protected mode, long mode)
- Differences between RISC and CISC architectures
- Multi-architecture build system configuration
- Portable OS design principles
- Cross-architecture debugging techniques
- Architecture-specific optimization trade-offs

## Functional Requirements

### FR1: x86_64 HAL Implementation

**Requirement**: Implement complete x86_64 HAL matching the interface defined in Phase 1, providing identical functionality to RISC-V HAL.

**HAL Modules to Implement**:

#### HAL-CPU (x86_64)
```c
// kernel/arch/x86_64/hal/hal_cpu_x86_64.c

void HalCpuInit(void) {
  // Initialize GDT, IDT, TSS
  // Set up per-CPU structures
  // Enable required CPU features (SSE, etc.)
}

int HalCpuId(void) {
  // Read APIC ID or use GS-relative per-CPU data
  // Return current CPU number (0-based)
}

void HalIntrEnable(void) {
  // STI instruction
  asm volatile("sti");
}

void HalIntrDisable(void) {
  // CLI instruction
  asm volatile("cli");
}

int HalIntrGet(void) {
  // Read RFLAGS.IF bit
  uint64_t flags;
  asm volatile("pushfq; popq %0" : "=r"(flags));
  return (flags & 0x200) ? 1 : 0;
}

void HalContextSwitch(HalContext *old, HalContext *new) {
  // Save old context (RBP, RBX, R12-R15, RIP, RSP)
  // Restore new context
  // Similar to RISC-V but different registers
}
```

**Key Differences from RISC-V**:
- x86_64 has fewer registers (16 general purpose vs 32 on RISC-V)
- Interrupt enable/disable: STI/CLI vs setting sstatus.SIE
- CPU ID: APIC ID vs tp register
- Context: RBP, RBX, R12-R15 vs s0-s11
- Stack grows down on both (no difference)

#### HAL-MMU (x86_64)
```c
// kernel/arch/x86_64/hal/hal_mmu_x86_64.c

// x86_64 uses 4-level page tables (PML4 -> PDPT -> PD -> PT)
// RISC-V uses 3-level page tables (Sv39)

pagetable_t HalPtAlloc(void) {
  // Allocate page for PML4
  // Zero it
  // Return physical address
}

pte_t *HalPtWalk(pagetable_t pagetable, uint64_t va, int alloc) {
  // Walk 4 levels instead of 3
  // PML4 (bits 39-47) -> PDPT (bits 30-38) -> PD (bits 21-29) -> PT (bits 12-20)
  // Allocate intermediate tables if alloc=1
  // Return PTE pointer or NULL
}

void HalPtMap(pagetable_t pagetable, uint64_t va, uint64_t pa, uint64_t perm) {
  // Walk to PTE
  // Set PTE: PA | permissions | present
  // x86_64 PTE format: [PA][flags]
}

void HalTlbFlush(void) {
  // Reload CR3
  uint64_t cr3;
  asm volatile("movq %%cr3, %0" : "=r"(cr3));
  asm volatile("movq %0, %%cr3" : : "r"(cr3));
}

void HalTlbFlushPage(uint64_t va) {
  // INVLPG instruction
  asm volatile("invlpg (%0)" : : "r"(va));
}
```

**Page Table Differences**:
- **RISC-V Sv39**: 3-level, 39-bit virtual address
- **x86_64**: 4-level (PML4, PDPT, PD, PT), 48-bit virtual address
- PTE format different (flags in different positions)
- Both little-endian, 64-bit PTEs

#### HAL-INTR (x86_64)
```c
// kernel/arch/x86_64/hal/hal_intr_x86_64.c

void HalIntrInit(void) {
  // Initialize PIC or IOAPIC
  // Initialize Local APIC
  // Set up IDT (interrupt descriptor table)
  // Map interrupt vectors
}

void HalIntrRegister(int vector, void (*handler)(void)) {
  // Add entry to IDT
  // Set interrupt gate descriptor
}

int HalIntrClaim(void) {
  // Read interrupt vector (from interrupt frame)
  // Or read IOAPIC/APIC registers
}

void HalIntrComplete(int vector) {
  // Send EOI (End Of Interrupt) to APIC
  // Write to APIC EOI register
}
```

**Interrupt Controller Differences**:
- **RISC-V**: PLIC (Platform-Level Interrupt Controller)
- **x86_64**: PIC (legacy) or IOAPIC + Local APIC (modern)
- Vector assignment different
- EOI mechanism different

#### HAL-Atomic (x86_64)
```c
// kernel/arch/x86_64/hal/hal_atomic_x86_64.c

int HalAtomicCas(volatile int *ptr, int old, int new) {
  // CMPXCHG with LOCK prefix
  int result = old;
  asm volatile("lock; cmpxchgl %2, %1"
               : "=a"(result), "+m"(*ptr)
               : "r"(new), "0"(old)
               : "memory");
  return result;
}

void HalMemoryBarrier(void) {
  // MFENCE instruction
  asm volatile("mfence" ::: "memory");
}
```

**Atomic Operations**:
- **RISC-V**: AMO (Atomic Memory Operation) instructions (LR/SC, AMOSWAP, AMOADD)
- **x86_64**: LOCK prefix on instructions (XCHG, CMPXCHG, ADD)
- Both provide strong ordering guarantees

#### HAL-Timer (x86_64)
```c
// kernel/arch/x86_64/hal/hal_timer_x86_64.c

void HalTimerInit(void) {
  // Initialize Local APIC timer or HPET
  // Set up timer interrupt (vector 32)
  // Configure timer interval
}

uint64_t HalTimerRead(void) {
  // Read TSC (Time Stamp Counter)
  uint32_t lo, hi;
  asm volatile("rdtsc" : "=a"(lo), "=d"(hi));
  return ((uint64_t)hi << 32) | lo;
}

uint64_t HalTimerFreq(void) {
  // Calibrate TSC frequency
  // Or read from CPUID
  // Return Hz
}
```

**Timer Differences**:
- **RISC-V**: CLINT (Core Local Interruptor) with mtime/mtimecmp
- **x86_64**: APIC timer or HPET (High Precision Event Timer)
- TSC (Time Stamp Counter) for high-resolution time

**Success Criteria**:
- All HAL functions compile for x86_64
- HAL interface identical to RISC-V
- Core kernel code unchanged (no #ifdef ARCH_X86_64 in core/)
- HAL unit tests pass on x86_64 (with mock)

### FR2: x86_64 Boot Sequence

**Requirement**: Implement boot loader and early initialization for x86_64, transitioning from BIOS/UEFI to long mode and jumping to kernel.

**Boot Process**:

#### Stage 1: BIOS Boot (Legacy)
- BIOS loads bootloader from first sector of disk (MBR)
- Bootloader runs in 16-bit real mode
- Load kernel image from disk
- Set up minimal GDT
- Enter protected mode (32-bit)

#### Stage 2: Protected Mode
- Set up 32-bit GDT and segments
- Enable paging (identity map + higher half)
- Transition to long mode (64-bit)
- Jump to kernel entry point

#### Stage 3: Long Mode (64-bit)
- Running in 64-bit mode
- Set up final GDT
- Set up IDT (interrupt descriptor table)
- Initialize BSP (bootstrap processor) per-CPU data
- Call kernel main

**Boot Code Structure**:
```
kernel/arch/x86_64/boot/
├── boot.S          # MBR bootloader (16-bit)
├── boot32.S        # Protected mode setup
├── boot64.S        # Long mode entry
├── entry.S         # Kernel entry point
└── main.c          # C initialization
```

**x86_64 Boot vs RISC-V**:
- **RISC-V**: Boots directly in machine mode (M-mode), then supervisor mode (S-mode)
- **x86_64**: Real mode → Protected mode → Long mode
- **RISC-V**: Simple, single address space
- **x86_64**: Segmentation (legacy), paging required for long mode

**QEMU Considerations**:
- Use QEMU's `-kernel` option to bypass bootloader (multiboot)
- Or implement simple bootloader for educational value
- QEMU can boot from disk image with MBR

**UEFI Boot** (Optional):
- More modern but more complex
- Bootloader is EFI application
- System already in 64-bit mode
- Simpler memory setup

**Success Criteria**:
- Bootloader successfully loads kernel
- Kernel runs in long mode
- GDT and IDT set up correctly
- Can print to console (serial or VGA)
- Jumps to kernel main() function

### FR3: x86_64 Page Table Management

**Requirement**: Adapt memory management to x86_64's 4-level page table structure while maintaining identical kernel MM interface.

**Page Table Structure**:

#### 4-Level Paging
```
Virtual Address (48 bits used):
[Sign extend][PML4 index][PDPT index][PD index][PT index][Offset]
   63-48        47-39        38-30       29-21      20-12    11-0

PML4 (Page Map Level 4): 512 entries, each points to PDPT
PDPT (Page Directory Pointer Table): 512 entries, each points to PD
PD (Page Directory): 512 entries, each points to PT
PT (Page Table): 512 entries, each points to 4KB page
```

**Page Table Entry (PTE) Format**:
```
Bits    | Field
--------|------------------
0       | Present
1       | Read/Write
2       | User/Supervisor
3       | Write-Through
4       | Cache Disable
5       | Accessed
6       | Dirty
7       | Page Size (PS)
8       | Global
9-11    | Available
12-51   | Physical Address
52-62   | Available
63      | No Execute (NX)
```

**Key Operations**:
- **kvmmap()**: Map kernel virtual address, unchanged interface
- **uvmmap()**: Map user virtual address, unchanged interface
- **walk()**: Walk 4 levels instead of 3, internal change only

**Memory Layout** (x86_64):
```
0x0000000000000000 - User space (lower half, 0-128TB)
0xFFFF800000000000 - Kernel space (higher half, -128TB to -1)

Kernel memory map:
0xFFFF800000000000 - Physical memory direct map
0xFFFFFFFF80000000 - Kernel code/data (higher 2GB)
```

**Differences from RISC-V**:
- RISC-V Sv39: 512GB address space (39 bits)
- x86_64: 256TB address space (48 bits)
- PTE flags different but similar concepts
- Both support NX (no execute) bit

**Success Criteria**:
- Page table walks work correctly
- Virtual memory maps correctly
- User and kernel spaces separated
- TLB flushes effective
- No TLB coherency issues

### FR4: x86_64 Trap and Interrupt Handling

**Requirement**: Implement x86_64 exception and interrupt handling, integrating with IDT and APIC.

**Interrupt Descriptor Table (IDT)**:
```c
struct idt_entry {
  uint16_t offset_low;   // Offset bits 0-15
  uint16_t selector;     // Code segment selector
  uint8_t ist;           // Interrupt Stack Table offset
  uint8_t type_attr;     // Type and attributes
  uint16_t offset_mid;   // Offset bits 16-31
  uint32_t offset_high;  // Offset bits 32-63
  uint32_t zero;         // Reserved
} __attribute__((packed));
```

**IDT Setup**:
- 256 entries (vectors 0-255)
- Vectors 0-31: CPU exceptions (divide error, page fault, etc.)
- Vector 32-47: IRQs (from PIC/IOAPIC)
- Vector 48+: Software interrupts (system calls)
- Vector 128: System call entry (INT 0x80)

**Exception Handling**:

#### CPU Exceptions
```
Vector | Exception
-------|---------------------
0      | Divide Error
1      | Debug
2      | NMI
3      | Breakpoint
6      | Invalid Opcode
13     | General Protection Fault
14     | Page Fault
...
```

**Page Fault Handler**:
- Read CR2 register for faulting address
- Check error code for fault type (present, write, user)
- Handle copy-on-write, demand paging, or kill process

**Interrupt Handling**:

#### External Interrupts
- Timer: Vector 32 (IRQ0)
- Keyboard: Vector 33 (IRQ1)
- Serial: Vector 36 (IRQ4)
- Disk: Various (depends on controller)

**System Call Entry**:
- **x86_64 legacy**: INT 0x80 instruction
- **x86_64 modern**: SYSCALL/SYSRET instructions (faster)
- **RISC-V**: ECALL instruction
- All use register passing for arguments

**Implementation**:
```
kernel/arch/x86_64/trap/
├── trapentry.S    # IDT stubs, save context
├── trap.c         # Trap handler (dispatch to kernel)
└── syscall.S      # System call entry (SYSCALL)
```

**Success Criteria**:
- IDT correctly populated
- Exceptions handled (page fault, GPF, etc.)
- External interrupts delivered
- System calls work
- Context saved/restored correctly

### FR5: x86_64 Device Drivers

**Requirement**: Port or adapt device drivers to x86_64, using HAL for hardware access where possible.

**Device Adaptation**:

#### Serial Port (UART)
- x86_64: 8250/16550 UART (I/O ports 0x3F8)
- RISC-V: 16550 UART (MMIO)
- Same register layout, different access method
- Use HAL for I/O port vs MMIO abstraction

#### Console/VGA
- x86_64: VGA text mode (0xB8000) or framebuffer
- RISC-V: UART console only
- Add VGA driver for x86_64
- Framebuffer for graphics mode

#### Disk
- x86_64: IDE/ATA, AHCI, virtio-blk
- RISC-V: virtio-disk
- Port virtio-blk driver (standard interface)
- Optionally add IDE driver for legacy

#### Network
- x86_64: e1000, virtio-net
- RISC-V: virtio-net, e1000
- e1000 driver should work on both (PCIe)
- Ensure MSI/MSI-X works on x86_64

**I/O Port Abstraction**:
```c
// HAL for I/O ports (x86_64 specific)
static inline uint8_t inb(uint16_t port) {
  uint8_t data;
  asm volatile("inb %1, %0" : "=a"(data) : "d"(port));
  return data;
}

static inline void outb(uint16_t port, uint8_t data) {
  asm volatile("outb %0, %1" : : "a"(data), "d"(port));
}

// RISC-V: No I/O ports, only MMIO
// Provide empty stubs or return error
```

**Success Criteria**:
- Serial console works
- Disk I/O functional
- Network functional (if e1000 driver ported)
- Device drivers use HAL consistently

### FR6: Multi-Architecture Build System

**Requirement**: Extend CMake build system to support building for both RISC-V and x86_64 with architecture selection.

**Build System Structure**:
```cmake
# Top-level CMakeLists.txt

option(ARCH "Target architecture" "riscv64")

if(ARCH STREQUAL "riscv64")
  set(CMAKE_C_COMPILER riscv64-unknown-elf-gcc)
  set(ARCH_DIR kernel/arch/riscv)
  set(QEMU_CMD qemu-system-riscv64)
elseif(ARCH STREQUAL "x86_64")
  set(CMAKE_C_COMPILER x86_64-elf-gcc)
  set(ARCH_DIR kernel/arch/x86_64)
  set(QEMU_CMD qemu-system-x86_64)
endif()

add_subdirectory(${ARCH_DIR})
add_subdirectory(kernel/core)
add_subdirectory(kernel/mm)
# ... other directories
```

**Architecture-Specific Sources**:
```cmake
# kernel/arch/riscv/CMakeLists.txt
set(ARCH_SOURCES
  boot/entry.S
  boot/start.c
  hal/hal_cpu_riscv.c
  hal/hal_mmu_riscv.c
  # ...
)

# kernel/arch/x86_64/CMakeLists.txt
set(ARCH_SOURCES
  boot/boot.S
  boot/entry.S
  boot/main.c
  hal/hal_cpu_x86_64.c
  hal/hal_mmu_x86_64.c
  # ...
)
```

**Build Targets**:
```
make ARCH=riscv64    # Build for RISC-V
make ARCH=x86_64     # Build for x86_64
make qemu            # Run in QEMU (uses ARCH setting)
make test            # Run tests for current architecture
```

**Cross-Compilation**:
- RISC-V: riscv64-unknown-elf-gcc or riscv64-linux-gnu-gcc
- x86_64: x86_64-elf-gcc or native gcc (if building on x86_64)
- Separate object directories: build/riscv64/, build/x86_64/

**Success Criteria**:
- Can build for RISC-V and x86_64 from same source tree
- Architecture selection via command-line flag
- No code duplication (core kernel shared)
- Clean separation of architecture-specific files

### FR7: Testing and Validation

**Requirement**: Ensure all functionality works correctly on x86_64 with >95% test pass rate.

**Test Strategy**:

#### Unit Tests (Host-Based)
- Unit tests already architecture-independent (use mock HAL)
- Should work on both architectures without changes
- Run unit tests for x86_64 HAL implementation

#### Integration Tests (QEMU)
- Run full integration test suite on x86_64
- Compare results with RISC-V
- Fix any architecture-specific bugs
- Target: 100% parity with RISC-V

#### Compatibility Tests
- Ensure system calls behave identically
- Verify file system compatibility (same disk image on both)
- Test IPC works identically
- Test network works identically

#### Performance Comparison
- Run benchmark suite on both architectures
- Compare performance characteristics
- Document performance differences
- Understand architectural impact on performance

**Test Pass Criteria**:
- >95% of RISC-V tests pass on x86_64
- Any failures documented and justified
- Critical functionality works on both

**Success Criteria**:
- All integration tests pass on x86_64
- Usertests pass
- System stable for 24+ hours
- Performance within 20% of RISC-V (accounting for architectural differences)

### FR8: Documentation and Cross-Architecture Guide

**Requirement**: Document the porting process, architectural differences, and provide guide for adding future architectures.

**Documentation Deliverables**:

#### Porting Guide
- How to port to a new architecture
- HAL interface contract
- Boot sequence requirements
- Memory layout considerations
- Testing checklist

#### Architecture Comparison
- RISC-V vs x86_64 comparison table
- Design decisions and trade-offs
- Performance characteristics
- Instruction set differences

#### HAL Reference
- Complete HAL interface specification
- Expected behavior for each function
- Error handling requirements
- Performance expectations

#### Future Architecture Support
- ARM64 considerations (for future)
- Other potential architectures (MIPS, PowerPC)
- HAL extensions that may be needed

**Success Criteria**:
- Porting guide clear and complete
- Architecture comparison informative
- HAL reference accurate
- Documentation enables future ports

## Non-Functional Requirements

### NFR1: Code Sharing
- >95% of kernel code shared between architectures
- Only arch/ directory differs
- No #ifdef ARCH_XXX in core kernel
- Minimal duplication

### NFR2: Performance Parity
- x86_64 performance within 20% of RISC-V
- Context switch time comparable
- System call overhead comparable
- Understand and document differences

### NFR3: Maintainability
- Changes to core kernel don't require updating both architectures
- Architecture-specific code isolated
- Clear interfaces prevent coupling
- Easy to add new architectures

### NFR4: Testing Parity
- Same test coverage on both architectures
- All critical tests pass on both
- Continuous testing on both (CI)

## Design Constraints

### DC1: HAL Interface Frozen
- Cannot change HAL interface at this stage
- Any issues found must work around or document as known limitation
- HAL interface changes would require re-porting

### DC2: QEMU Limitations
- Test on QEMU only (no real hardware required)
- QEMU may not emulate all hardware features
- Some optimizations may not be testable (e.g., cache behavior)

### DC3: Time Budget
- 6-8 weeks for complete port
- Focus on core functionality
- Defer non-critical features if needed

### DC4: Educational Focus
- Porting exercise is educational
- Prioritize learning over optimization
- Document decisions and trade-offs

## Testing Requirements

### Unit Tests

**HAL Tests**:
- Test each x86_64 HAL function
- Mock x86_64 hardware (GDT, IDT, page tables)
- Verify correct behavior
- Compare with RISC-V HAL tests

### Integration Tests (QEMU x86_64)

**Boot Tests**:
- Kernel boots successfully
- Console output works
- Reaches main()

**Functionality Tests**:
- Process creation (fork, exec)
- Memory management (allocation, paging)
- File system (read, write, create, delete)
- IPC (message passing)
- Network (if implemented)

**Stress Tests**:
- Run 24-hour stress test on x86_64
- Compare stability with RISC-V
- Fix any crashes or hangs

### Cross-Architecture Tests

**Compatibility**:
- Same user programs run on both
- Same file system image works on both
- IPC between different architectures (if networked)

### Performance Tests

**Benchmarks**:
- Run full benchmark suite on x86_64
- Compare with RISC-V baseline
- Analyze differences
- Document architectural impact

## Success Criteria

### Functional Success
- [ ] Kernel boots on x86_64
- [ ] All core subsystems functional
- [ ] >95% of integration tests pass
- [ ] Usertests pass on x86_64
- [ ] System stable for 24+ hours

### Architectural Success
- [ ] HAL interface unchanged
- [ ] Core kernel unchanged (no arch-specific code)
- [ ] >95% code shared between architectures
- [ ] Clear separation maintained

### Quality Success
- [ ] All unit tests pass on x86_64
- [ ] Test coverage identical to RISC-V
- [ ] No major bugs introduced
- [ ] Performance within acceptable range

### Documentation Success
- [ ] Porting guide complete
- [ ] Architecture comparison documented
- [ ] HAL fully specified
- [ ] Future porting guidance provided

### Validation Success
- [ ] Phase 1 HAL design validated
- [ ] Portability goals achieved
- [ ] Lessons learned documented
- [ ] Project complete

## Implementation Strategy

### Week 1: x86_64 HAL Skeleton

**Tasks**:
1. Create arch/x86_64/ directory structure
2. Implement HAL function stubs
3. Set up x86_64 build system
4. Compile (but don't run yet)

**Deliverable**: x86_64 build compiles

### Week 2-3: Boot and Initialization

**Tasks**:
1. Implement bootloader (or multiboot)
2. Implement long mode transition
3. Implement entry.S
4. Initialize GDT, IDT
5. Boot to kernel main

**Deliverable**: Kernel boots and prints to console

### Week 3-4: HAL Implementation

**Tasks**:
1. Implement CPU HAL (interrupts, context switch)
2. Implement MMU HAL (page tables)
3. Implement Timer HAL
4. Implement Atomic HAL
5. Test each module

**Deliverable**: Core HAL functional

### Week 4-5: Trap and Interrupt Handling

**Tasks**:
1. Set up IDT
2. Implement exception handlers
3. Implement interrupt handlers
4. Implement system call entry
5. Test traps and syscalls

**Deliverable**: Interrupts and system calls work

### Week 5-6: Device Drivers

**Tasks**:
1. Port serial driver
2. Port disk driver
3. Port network driver (if applicable)
4. Test device I/O

**Deliverable**: Devices functional

### Week 6-7: Testing and Debugging

**Tasks**:
1. Run integration tests
2. Fix bugs and failures
3. Run stress tests
4. Performance testing
5. Stability testing

**Deliverable**: >95% tests pass

### Week 7-8: Documentation and Finalization

**Tasks**:
1. Write porting guide
2. Document architectural differences
3. Complete HAL specification
4. Final code review
5. Project completion celebration

**Deliverable**: Complete, multi-architecture OS

## Common Pitfalls

### Pitfall 1: Changing Core Kernel for x86_64
**Problem**: Adding x86_64-specific code to core kernel defeats HAL purpose.
**Solution**: All architecture code goes in arch/x86_64/. Fix HAL if interface inadequate.

### Pitfall 2: Different Semantics in HAL
**Problem**: x86_64 HAL behaves differently than RISC-V HAL.
**Solution**: Ensure identical interface and semantics. Test extensively.

### Pitfall 3: Page Table Confusion
**Problem**: 4-level page tables complex, easy to get wrong.
**Solution**: Draw diagrams, carefully trace page table walks, test thoroughly.

### Pitfall 4: Interrupt/Exception Numbering
**Problem**: Confusing exception vectors with IRQ numbers.
**Solution**: Use clear naming, document vector assignments.

### Pitfall 5: Assuming Little-Endian
**Problem**: Code assumes little-endian (both RISC-V and x86_64 are).
**Solution**: Be explicit about endianness. Future ARM may be big-endian.

### Pitfall 6: Performance Comparison Misinterpretation
**Problem**: Assuming performance differences are bugs.
**Solution**: Understand architectural reasons (e.g., x86_64 has variable-length instructions, deeper pipelines).

### Pitfall 7: Build System Complexity
**Problem**: Build system becomes unmanageable.
**Solution**: Keep it simple. Clear separation of arch-specific and common code.

## References

### x86_64 Architecture
- **Intel 64 and IA-32 Architectures Software Developer Manuals** - Complete ISA reference
- **AMD64 Architecture Programmer's Manual** - AMD's x86_64 specification
- **OSDev Wiki: x86_64** - Practical OS development guide
- **"Computer Architecture: A Quantitative Approach"** - Architectural concepts

### Multi-Architecture OS Design
- **Linux kernel arch/ directory** - Multi-architecture reference
- **FreeBSD sys/amd64/** - x86_64 OS implementation
- **Zircon kernel** - Modern multi-arch kernel
- **seL4** - Verified kernel, multiple architectures

### x86_64 Boot and Initialization
- **Multiboot Specification** - Standard boot protocol
- **UEFI Specification** - Modern firmware interface
- **"Rolling Your Own Bootloader"** - Bootloader tutorial
- **GRUB source code** - Reference bootloader

### Page Tables and Memory
- **"What Every Programmer Should Know About Memory"** - Memory hierarchy
- **Intel SDM Volume 3: System Programming Guide** - Paging chapter
- **OSDev Wiki: Paging** - x86_64 paging tutorial

### Interrupts and Exceptions
- **Intel SDM Volume 3: Interrupt and Exception Handling** - Complete reference
- **"8259A Programmable Interrupt Controller"** - PIC datasheet
- **"I/O APIC Datasheet"** - IOAPIC reference
- **OSDev Wiki: Interrupts** - Practical guide

### Tools
- **QEMU**: qemu-system-x86_64 for testing
- **GDB**: Debugging x86_64 code
- **Bochs**: Alternative x86_64 emulator with debugging
- **objdump**: Disassemble x86_64 binaries

## Appendix A: x86_64 vs RISC-V Quick Reference

| Feature | RISC-V | x86_64 |
|---------|--------|--------|
| **ISA Type** | RISC | CISC |
| **Instruction Length** | Fixed (32-bit) | Variable (1-15 bytes) |
| **Registers** | 32 (x0-x31) | 16 (RAX-R15) |
| **Page Table Levels** | 3 (Sv39) | 4 (PML4) |
| **Virtual Address Bits** | 39 | 48 |
| **Interrupt Enable** | sstatus.SIE | RFLAGS.IF (STI/CLI) |
| **Context Switch** | s0-s11, sp, ra | RBP, RBX, R12-R15, RSP, RIP |
| **System Call** | ECALL | SYSCALL or INT 0x80 |
| **Privilege Levels** | 3 (M, S, U) | 4 (Ring 0-3, use 0 and 3) |
| **TLB Flush** | sfence.vma | Reload CR3 or INVLPG |
| **Atomic Ops** | LR/SC, AMO | LOCK prefix |
| **Endianness** | Little (usually) | Little |

## Appendix B: x86_64 Memory Layout

```
User Space (Lower Half):
0x0000000000000000 - 0x0000000000001000   Null page (unmapped)
0x0000000000001000 - 0x0000000040000000   User program (text, data, heap)
0x0000000040000000 - 0x0000800000000000   User stack (grows down)

Kernel Space (Higher Half):
0xFFFF800000000000 - 0xFFFF880000000000   Physical memory direct map (512GB)
0xFFFF880000000000 - 0xFFFFFF0000000000   Kernel heap and dynamic allocations
0xFFFFFF0000000000 - 0xFFFFFF8000000000   vmalloc/ioremap area
0xFFFFFF8000000000 - 0xFFFFFFFF80000000   (unused)
0xFFFFFFFF80000000 - 0xFFFFFFFF81000000   Kernel text, data, bss (2GB)
0xFFFFFFFF81000000 - 0xFFFFFFFFFFFFFFFF   Kernel modules, etc.
```

## Appendix C: Example Page Table Walk (x86_64)

**Virtual Address**: 0xFFFFFFFF80001000 (kernel address)

**Breakdown**:
```
Bits 63-48: Sign extension (all 1s)
Bits 47-39: PML4 index = 0x1FF (511)
Bits 38-30: PDPT index = 0x1FF (511)
Bits 29-21: PD index   = 0x1C0 (448)
Bits 20-12: PT index   = 0x001 (1)
Bits 11-0:  Offset     = 0x000
```

**Walk**:
1. CR3 points to PML4 table
2. PML4[511] points to PDPT
3. PDPT[511] points to PD
4. PD[448] points to PT
5. PT[1] contains PTE with physical address
6. Physical address + offset = final physical address

---

**Phase Status**: Specification Complete
**Estimated Effort**: 240-320 hours over 6-8 weeks
**Prerequisites**: Phases 1-10 complete, HAL stable, baseline established
**Outputs**: Complete multi-architecture OS, validated HAL design, porting guide
**Next Phase**: None - Project Complete!

**Congratulations**: You have built a portable, hybrid kernel operating system from scratch, demonstrating deep understanding of OS principles, architecture, and design.
