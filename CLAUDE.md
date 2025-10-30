# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Important Context

**This is an educational project.** xv6-riscv is a re-implementation of Unix Version 6 for teaching operating system concepts at MIT (6.1810). The codebase is deliberately simplified for pedagogical purposes. When working with this code, focus on understanding and explaining concepts rather than generating working implementations.

## Building and Running

### Basic Commands

- `make qemu` - Build and run xv6 in QEMU emulator
- `make qemu-gdb` - Run xv6 with GDB debugging support (then run `gdb` in another terminal)
- `make clean` - Clean all build artifacts
- `./test-xv6.py <test>` - Run automated tests (e.g., `./test-xv6.py usertests`)
- `./test-xv6.py -q usertests` - Run quick usertests

### Requirements

- RISC-V toolchain (riscv64-unknown-elf- or riscv64-linux-gnu-)
- QEMU compiled for riscv64-softmmu (minimum version 7.2)
- Target architecture: rv64gc (RISC-V 64-bit with general extensions and compressed instructions)

### Build Process

The Makefile automatically:
1. Compiles kernel from `kernel/` directory
2. Compiles user programs from `user/` directory
3. Generates `usys.S` from `user/usys.pl` (system call stubs)
4. Creates `fs.img` filesystem image using `mkfs/mkfs`
5. Links kernel at 0x80000000 (KERNBASE) per `kernel/kernel.ld`
6. Links user programs at 0x0 per `user/user.ld`

### QEMU Tips

**Exiting QEMU:**
- Press `Ctrl-A` then `X` to quit QEMU
- Or type `Ctrl-A` then `C` to enter QEMU monitor, then type `quit`

**QEMU Monitor:**
- `Ctrl-A` then `C` - Enter/exit QEMU monitor console
- Useful monitor commands:
  - `info registers` - Display CPU registers
  - `info mem` - Show page table mappings
  - `info qtree` - Display device tree
  - `xp /10i $pc` - Disassemble 10 instructions at program counter
  - `x /20x 0x80000000` - Display 20 words of memory at address (hex)

**Debugging:**
- Use `make qemu-gdb` to start QEMU with GDB server on port 26000
- In another terminal, run `riscv64-unknown-elf-gdb` (or `gdb-multiarch`)
- GDB will automatically connect and load symbols from `kernel/kernel`
- Useful GDB commands:
  - `b main` - Set breakpoint at main
  - `c` - Continue execution
  - `si` - Step one instruction
  - `p variable` - Print variable value
  - `x/20x $sp` - Examine stack

**Customizing QEMU:**
- Change CPU count: `make CPUS=1 qemu` (useful for debugging race conditions)
- The Makefile passes `-machine virt -bios none -m 128M` to QEMU
- Serial output goes to both QEMU console and `qemu.out` file

**Common Issues:**
- If xv6 hangs at boot, check QEMU version (need 7.2+)
- If you see "timeout" errors in tests, the system might be running on 1 CPU
- Filesystem corruption: `make clean` then rebuild

## High-Level Architecture

### Memory Layout

**Physical Memory (RISC-V QEMU virt machine):**
- 0x00001000 - Boot ROM
- 0x02000000 - CLINT (Core Local Interruptor)
- 0x0C000000 - PLIC (Platform-Level Interrupt Controller)
- 0x10000000 - UART0
- 0x10001000 - VirtIO disk
- 0x80000000 - Kernel entry, text, data
- After `end` - Kernel page allocation area up to PHYSTOP (128MB)

**Virtual Memory (User Process):**
- 0x0 - Program text, data, bss
- Then - Fixed-size stack (1 page by default)
- Then - Expandable heap (grows with sbrk)
- TRAPFRAME (1 page below TRAMPOLINE) - Saved user registers
- TRAMPOLINE (at MAXVA - PGSIZE) - Trampoline code page (shared with kernel)

### Core Subsystems

**Process Management (`kernel/proc.c`, `kernel/proc.h`):**
- Process table with max NPROC (64) processes
- States: UNUSED, USED, SLEEPING, RUNNABLE, RUNNING, ZOMBIE
- Each process has: pagetable, trapframe, context, kernel stack, open files, cwd
- Context switching via `swtch()` in `kernel/swtch.S`
- Scheduler runs on each CPU, round-robin through RUNNABLE processes

**Virtual Memory (`kernel/vm.c`):**
- Three-level page tables (RISC-V Sv39)
- Kernel has single page table shared by all processes (direct-mapped from KERNBASE)
- Each process has separate user page table
- `uvmalloc()`/`uvmdealloc()` - Grow/shrink process memory
- `uvmcopy()` - Copy parent page table to child (for fork)
- `copyout()`/`copyin()` - Transfer data between kernel and user space

**Synchronization:**
- Spinlocks (`kernel/spinlock.c`) - For short critical sections, disable interrupts
- Sleep locks (`kernel/sleeplock.c`) - For longer critical sections, can sleep

**File System (`kernel/fs.c`, `kernel/bio.c`, `kernel/log.c`):**
- Simple Unix-like filesystem on virtio disk
- Logging layer for crash recovery (write-ahead logging)
- Buffer cache (`kernel/bio.c`) - In-memory cache of disk blocks (NBUF buffers)
- Inodes - Max NINODE (50) active in-memory inodes
- Directory structure - Directories are files containing dirent entries

**System Calls (`kernel/syscall.c`, `kernel/sysproc.c`, `kernel/sysfile.c`):**
- User code executes `ecall` instruction → trap to kernel
- `user/usys.S` generated from `user/usys.pl` - Stubs for each syscall
- Arguments extracted via `argint()`, `argaddr()`, `argstr()`
- Syscall number in a7 register determines which syscall to invoke

**Traps and Interrupts (`kernel/trap.c`, `kernel/trampoline.S`):**
- Trampoline page mapped at same VA in kernel and user space
- User trap: uservec saves registers to trapframe → jumps to usertrap()
- Kernel trap: kernelvec saves registers on stack → jumps to kerneltrap()
- Timer interrupts drive scheduling via yield()

### Key Data Structures

- `struct proc` - Per-process state (kernel/proc.h:85)
- `struct cpu` - Per-CPU state (kernel/proc.h:22)
- `struct trapframe` - Saved user registers during trap (kernel/proc.h:43)
- `struct context` - Saved kernel registers for context switch (kernel/proc.h:2)
- `struct inode` - In-memory inode (kernel/file.h)
- `struct buf` - Buffer cache entry (kernel/buf.h)

### Bootstrap Sequence

1. `kernel/entry.S` - CPU starts in machine mode, sets up stack, jumps to start()
2. `kernel/start.c` - Configures machine mode, switches to supervisor mode, jumps to main()
3. `kernel/main.c` - First CPU initializes subsystems, other CPUs wait then initialize their state
4. All CPUs enter scheduler() which never returns

## Important Constants (kernel/param.h)

- NPROC=64 - Max processes
- NCPU=8 - Max CPUs
- NOFILE=16 - Open files per process
- MAXARG=32 - Max exec arguments
- FSSIZE=2000 - Filesystem size in blocks

## Common Patterns

**Adding a System Call:**
1. Add prototype to `kernel/defs.h`
2. Add implementation to `kernel/sysproc.c` or `kernel/sysfile.c`
3. Add syscall number to `kernel/syscall.h`
4. Add entry to syscalls[] array in `kernel/syscall.c`
5. Add stub to `user/usys.pl`
6. Add prototype to `user/user.h`

**Process Creation:**
- `fork()` creates child process by copying parent's page table
- Child starts with same state as parent but different PID
- `exec()` replaces process memory with new program

**Sleeping/Waking:**
- `sleep(chan, lock)` - Sleep on channel, release lock, reacquire on wakeup
- `wakeup(chan)` - Wake all processes sleeping on channel
- Always called with a lock held to avoid lost wakeups
