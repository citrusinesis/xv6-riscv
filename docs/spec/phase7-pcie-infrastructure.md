# Phase 7: PCIe Infrastructure

**Duration**: 6-8 weeks
**Prerequisites**: Phase 6 (Hybrid Kernel Transition) complete
**Next Phase**: Phase 8 (Network Card Driver)

## Overview

Phase 7 establishes the PCIe (Peripheral Component Interconnect Express) infrastructure that enables modern hardware device support. This phase transforms the kernel from supporting only simple, memory-mapped devices to handling complex PCIe devices with sophisticated interrupt mechanisms and DMA capabilities.

**Core Objective**: Implement PCIe device enumeration, configuration space access, MSI/MSI-X interrupt handling, and DMA infrastructure to enable modern device drivers in subsequent phases.

## Objectives

### Primary Goals
1. Implement PCIe configuration space access and manipulation
2. Create device enumeration and discovery mechanism
3. Implement driver framework with device/driver matching
4. Add MSI (Message Signaled Interrupts) and MSI-X support
5. Establish DMA (Direct Memory Access) infrastructure
6. Integrate PCIe subsystem with HAL from Phase 1

### Learning Outcomes
- Understanding of PCIe bus architecture and topology
- Device enumeration and configuration mechanisms
- Modern interrupt delivery mechanisms (MSI/MSI-X vs legacy INTx)
- DMA operation, coherency, and IOMMU concepts
- Driver framework design patterns
- Resource management in complex hardware scenarios

## Functional Requirements

### FR1: PCIe Configuration Space Access

**Requirement**: Provide mechanism to access and manipulate PCIe configuration space for all devices on the bus.

**Operations Required**:

#### Configuration Space Basics
- Read/write configuration registers (8-bit, 16-bit, 32-bit)
- Access standard configuration header (Type 0 and Type 1)
- Parse capability lists (PCI capabilities and PCIe extended capabilities)
- Traverse PCIe hierarchy (root complex, bridges, endpoints)

#### Configuration Space Layout
Must support access to:
- **Header Type 0** (Endpoints): Device ID, Vendor ID, BARs, capabilities
- **Header Type 1** (Bridges): Bus numbers, I/O base/limit, memory base/limit
- **Standard Capabilities**: Power management, MSI, MSI-X, PCIe capability
- **Extended Capabilities**: Advanced Error Reporting (AER), Alternative Routing-ID

#### Address Mapping
- Map PCIe configuration space into kernel virtual memory
- Support ECAM (Enhanced Configuration Access Mechanism) for PCIe
- Handle multi-segment configuration spaces (if applicable)
- Validate device addresses before access

**Success Criteria**:
- Can read vendor/device ID from all PCIe devices
- Can enumerate all capabilities for a device
- Can modify configuration registers (command register, BARs)
- No system hangs from invalid configuration access

### FR2: Device Enumeration and Discovery

**Requirement**: Automatically discover and enumerate all PCIe devices on system boot.

**Enumeration Process**:

#### Bus Scanning
- Scan all buses starting from root complex (bus 0)
- For each bus, scan all devices (0-31)
- For each device, scan all functions (0-7)
- Detect multi-function devices via header type
- Follow bridges to discover downstream buses

#### Device Information Collection
For each discovered device, collect:
- Vendor ID and Device ID
- Class code (base class, sub-class, programming interface)
- Revision ID
- Subsystem vendor/device ID
- Base Address Registers (BARs) and their types (memory/IO, size)
- Interrupt line and pin
- Capabilities present

#### Topology Mapping
- Build device tree representing PCIe hierarchy
- Track parent-child relationships (bridges and endpoints)
- Assign bus numbers to bridges
- Calculate and assign address ranges

**Success Criteria**:
- All PCIe devices detected and cataloged
- Device tree accurately represents topology
- No duplicate device registrations
- Enumeration completes in <1 second on typical systems

### FR3: Driver Framework and Device Matching

**Requirement**: Provide infrastructure for registering drivers and matching them to discovered devices.

**Framework Components**:

#### Driver Registration
- Interface for drivers to register with PCIe subsystem
- Specify supported device IDs (vendor/device, class code)
- Provide probe, remove, suspend, resume callbacks
- Support for multiple drivers per device class

#### Device-Driver Matching
- Match devices to drivers by:
  - Exact vendor/device ID match (highest priority)
  - Subsystem vendor/device ID match
  - Class code match (fallback)
- Support wildcard matches (all devices of a class)
- Allow driver priority/ordering

#### Driver Lifecycle
- Call probe() when device/driver match found
- Allocate device-specific data structure
- Call remove() on device removal or driver unload
- Handle driver re-binding scenarios

#### Resource Allocation
- Allocate and map BARs into kernel virtual memory
- Allocate interrupt vectors
- Allocate DMA buffers
- Track resource ownership per driver

**Interface Specification**:
```c
struct pci_driver {
  const char *name;
  const struct pci_device_id *id_table;
  int (*probe)(struct pci_device *dev, const struct pci_device_id *id);
  void (*remove)(struct pci_device *dev);
  void (*suspend)(struct pci_device *dev);
  void (*resume)(struct pci_device *dev);
};

int pci_register_driver(struct pci_driver *driver);
void pci_unregister_driver(struct pci_driver *driver);
```

**Success Criteria**:
- Drivers successfully register with framework
- Devices matched to appropriate drivers
- Probe functions called for matching devices
- Resource allocation works correctly
- No resource leaks on driver removal

### FR4: Interrupt Handling (MSI/MSI-X)

**Requirement**: Support modern interrupt mechanisms including legacy INTx, MSI, and MSI-X.

**Interrupt Types**:

#### Legacy INTx Interrupts
- Support shared interrupt lines
- Implement interrupt routing via IOAPIC (x86) or PLIC (RISC-V)
- Handle interrupt masking and acknowledgment
- Maintain compatibility with older devices

#### MSI (Message Signaled Interrupts)
- Enable MSI capability in device configuration
- Allocate message address and data
- Support up to 32 interrupt vectors per device
- Program device MSI capability registers
- Route MSI messages to appropriate CPU

#### MSI-X (Extended MSI)
- Enable MSI-X capability
- Map MSI-X table and PBA (Pending Bit Array)
- Support up to 2048 interrupt vectors per device
- Per-vector masking capability
- Independent interrupt vector allocation

**Interrupt Management**:
- Allocate interrupt vectors from system pool
- Associate interrupt handlers with vectors
- Support shared handlers for shared interrupts
- Implement interrupt affinity (CPU pinning)
- Provide statistics (interrupt count, latency)

**Interface Specification**:
```c
int pci_enable_msi(struct pci_device *dev, int nvec);
int pci_enable_msix(struct pci_device *dev, struct msix_entry *entries, int nvec);
void pci_disable_msi(struct pci_device *dev);
void pci_disable_msix(struct pci_device *dev);
int request_irq(int vector, irq_handler_t handler, void *dev_id);
void free_irq(int vector, void *dev_id);
```

**Success Criteria**:
- Can enable MSI and MSI-X on capable devices
- Interrupt delivery works reliably
- Interrupt handlers invoked correctly
- No spurious interrupts
- Performance better than legacy interrupts

### FR5: DMA (Direct Memory Access) Infrastructure

**Requirement**: Provide infrastructure for devices to perform DMA operations safely and efficiently.

**DMA Components**:

#### DMA Buffer Allocation
- Allocate physically contiguous memory for DMA
- Support different DMA coherency models
- Handle alignment requirements
- Support large (multi-page) allocations
- Track DMA buffer ownership

#### Address Translation
- Translate virtual addresses to physical for DMA
- Handle IOMMU if present (optional for Phase 7)
- Support 32-bit and 64-bit DMA addressing
- Provide DMA address mapping/unmapping

#### Scatter-Gather Lists
- Build scatter-gather descriptor lists
- Support non-contiguous memory regions
- Provide iterator/builder interface
- Handle platform-specific descriptor formats

#### Cache Coherency
- Ensure DMA buffer coherency with CPU caches
- Provide cache flush/invalidate operations
- Support coherent vs non-coherent DMA
- Handle architecture-specific coherency requirements

#### DMA Completion
- Provide mechanism to notify on DMA completion
- Support polling and interrupt-driven completion
- Handle DMA errors and timeouts
- Implement completion callbacks

**Interface Specification**:
```c
void *dma_alloc_coherent(struct pci_device *dev, size_t size, dma_addr_t *dma_handle);
void dma_free_coherent(struct pci_device *dev, size_t size, void *vaddr, dma_addr_t dma_handle);
dma_addr_t dma_map_single(struct pci_device *dev, void *ptr, size_t size, enum dma_direction dir);
void dma_unmap_single(struct pci_device *dev, dma_addr_t addr, size_t size, enum dma_direction dir);
int dma_map_sg(struct pci_device *dev, struct scatterlist *sg, int nents, enum dma_direction dir);
void dma_unmap_sg(struct pci_device *dev, struct scatterlist *sg, int nents, enum dma_direction dir);
```

**Success Criteria**:
- DMA buffers allocate successfully
- Physical addresses correctly provided to devices
- DMA transfers complete without corruption
- Cache coherency maintained
- No memory leaks from DMA operations

### FR6: Integration with Existing Kernel

**Requirement**: Integrate PCIe subsystem seamlessly with HAL, hybrid kernel architecture, and existing drivers.

**Integration Points**:

#### HAL Integration
- Use HAL for architecture-specific operations:
  - Interrupt controller configuration (PLIC, IOAPIC, GIC)
  - Memory barriers and cache operations
  - MMIO (Memory-Mapped I/O) access
  - Physical address translation

#### User-Space Driver Server Support
- Enable PCIe device access from user-space driver servers
- Provide system calls for:
  - Device enumeration queries
  - MMIO region mapping
  - Interrupt vector allocation
  - DMA buffer management
- Enforce security checks for device access

#### Backward Compatibility
- Existing simple drivers (UART, virtio) continue to work
- PCIe subsystem optional (not required for basic boot)
- No performance impact on non-PCIe code paths

**Success Criteria**:
- PCIe subsystem integrates cleanly with HAL
- User-space servers can manage PCIe devices
- No regressions in existing functionality
- Boot time impact <100ms

## Non-Functional Requirements

### NFR1: Performance
- Configuration space access: <10 microseconds per access
- Enumeration: <1 second for typical system
- MSI interrupt latency: <5 microseconds from device to handler
- DMA setup overhead: <20 microseconds per operation

### NFR2: Security
- Validate all configuration space addresses
- Prevent unauthorized MMIO region access
- Enforce device ownership (one driver per device)
- Validate DMA addresses are within allocated buffers
- Prevent DMA to kernel code/data regions

### NFR3: Reliability
- Handle device removal gracefully
- Recover from configuration access errors
- Detect and report AER errors
- Handle interrupt storms (excessive interrupts)
- Validate all device-provided data

### NFR4: Portability
- Architecture-independent core implementation
- HAL-based platform-specific operations
- Support both RISC-V and x86_64 (via HAL)
- Configurable for different PCIe topologies

### NFR5: Debuggability
- Log all device discoveries
- Provide sysfs-like interface to query devices
- Dump configuration space on demand
- Track interrupt delivery statistics
- Log DMA buffer allocations

## Design Constraints

### DC1: Memory Constraints
- Configuration space mapping: Limited by available virtual address space
- DMA buffers: Limited by physical memory availability
- Device structures: Support at least 64 devices
- Interrupt vectors: Limited by interrupt controller capabilities

### DC2: Architecture Support
- Primary: RISC-V (qemu virt machine)
- Future: x86_64 (Phase 11)
- Must use HAL for all architecture-specific operations
- No direct register access outside HAL

### DC3: QEMU Limitations
- Work within QEMU's PCIe implementation
- QEMU virt machine provides PCIe root complex
- Test with QEMU-emulated devices (e1000, virtio-pci)
- No real hardware required for basic functionality

### DC4: Educational Focus
- Prioritize code clarity over maximum optimization
- Comprehensive comments explaining PCIe concepts
- Simple, understandable algorithms
- Avoid overly complex abstractions

### DC5: Compatibility
- Follow PCIe specification (v3.0 minimum)
- Compatible with Linux driver model (where applicable)
- Support standard capabilities
- Interoperate with QEMU device models

## Testing Requirements

### Unit Tests

**Configuration Space Access**:
- Read vendor/device ID
- Parse capability list
- Read/write command register
- Validate bounds checking

**Device Enumeration**:
- Enumerate all buses
- Detect bridges correctly
- Build device tree
- Handle multi-function devices

**Driver Framework**:
- Register driver
- Match devices by ID
- Call probe callback
- Resource allocation/deallocation

**Mock Requirements**:
- Mock PCIe configuration space
- Mock interrupt controller
- Mock memory allocator
- Deterministic device enumeration

### Integration Tests (QEMU)

**Device Discovery**:
- Boot with multiple PCIe devices
- Verify all devices enumerated
- Check device tree structure
- Query device properties

**Driver Loading**:
- Load test driver for virtio-pci device
- Verify probe called
- Allocate and map BARs
- Request and receive interrupts

**MSI/MSI-X**:
- Enable MSI on test device
- Generate test interrupt
- Verify handler invoked
- Measure interrupt latency

**DMA Operations**:
- Allocate DMA buffer
- Perform test DMA transfer
- Verify data integrity
- Test scatter-gather

**User-Space Access**:
- Enumerate devices from user space
- Map MMIO region in user space
- Handle interrupts in user-space driver

### Stress Tests

**Device Enumeration**:
- Boot with maximum supported devices (64+)
- Rapid device hotplug/removal (if supported)
- Concurrent enumeration attempts

**Interrupt Handling**:
- High-frequency interrupts (10000/sec)
- Multiple devices generating interrupts
- Interrupt storm detection

**DMA Stress**:
- Concurrent DMA operations
- Large DMA transfers (multi-MB)
- Scatter-gather with many segments
- DMA while system under memory pressure

### Performance Tests

**Benchmarks Required**:
- Configuration space read/write latency
- Device enumeration time vs device count
- Interrupt delivery latency (legacy vs MSI vs MSI-X)
- DMA throughput (MB/s)
- DMA setup overhead
- Cache coherency overhead

**Comparison Points**:
- Compare MSI latency to legacy interrupts (expect 30-50% improvement)
- Compare DMA throughput to programmed I/O
- Measure enumeration scaling (linear with device count)

## Success Criteria

### Functional Success
- [ ] All PCIe devices on QEMU virt machine enumerated
- [ ] Virtio-pci device successfully probed and functional
- [ ] MSI interrupts enabled and working
- [ ] DMA transfers complete without corruption
- [ ] User-space driver can access PCIe device
- [ ] All integration tests pass

### Architectural Success
- [ ] Clean separation between core PCIe code and HAL
- [ ] Driver framework supports multiple drivers
- [ ] Resource management prevents leaks
- [ ] Security checks enforce device ownership
- [ ] Code is portable (no RISC-V specifics in core)

### Quality Success
- [ ] >75% code coverage in unit tests
- [ ] All unit tests pass
- [ ] No memory leaks detected
- [ ] No crashes under stress tests
- [ ] Code review approved

### Performance Success
- [ ] Configuration access <10μs
- [ ] Device enumeration <1s
- [ ] MSI interrupt latency <5μs
- [ ] DMA throughput >100 MB/s
- [ ] Boot time increase <100ms

### Documentation Success
- [ ] PCIe subsystem architecture documented
- [ ] Driver development guide written
- [ ] API reference complete
- [ ] Example driver provided
- [ ] Troubleshooting guide written

## Implementation Strategy

### Phase 7.1: Configuration Space and Enumeration (Weeks 1-2)

**Tasks**:
1. Map PCIe ECAM region into kernel virtual memory
2. Implement configuration space read/write functions
3. Implement bus scanning algorithm
4. Build device discovery and registration
5. Create device information structures
6. Test with QEMU virt machine

**Deliverable**: Can enumerate all devices and print their properties

### Phase 7.2: Driver Framework (Weeks 3-4)

**Tasks**:
1. Design driver registration interface
2. Implement device-driver matching
3. Create resource management (BAR allocation, mapping)
4. Implement probe/remove callbacks
5. Create simple test driver for virtio-pci
6. Test driver lifecycle

**Deliverable**: Test driver successfully probes and accesses device

### Phase 7.3: Interrupt Handling (Weeks 4-5)

**Tasks**:
1. Implement legacy INTx support
2. Parse MSI capability
3. Implement MSI enable/disable
4. Parse MSI-X capability
5. Implement MSI-X enable/disable
6. Integrate with HAL interrupt controller
7. Test interrupt delivery

**Deliverable**: Can receive interrupts via MSI and MSI-X

### Phase 7.4: DMA Infrastructure (Weeks 5-6)

**Tasks**:
1. Implement DMA buffer allocation (coherent)
2. Implement address translation (virtual to physical)
3. Create scatter-gather list builder
4. Implement cache coherency operations
5. Add DMA completion notification
6. Test with virtio-pci device

**Deliverable**: DMA transfers work correctly

### Phase 7.5: User-Space Integration (Week 7)

**Tasks**:
1. Create system calls for device enumeration
2. Implement MMIO region mapping to user space
3. Add interrupt forwarding to user space
4. Implement user-space DMA buffer management
5. Create test user-space driver
6. Test end-to-end user-space driver

**Deliverable**: User-space driver can control PCIe device

### Phase 7.6: Testing and Documentation (Week 8)

**Tasks**:
1. Write comprehensive unit tests
2. Write integration tests
3. Perform stress testing
4. Benchmark performance
5. Write architecture documentation
6. Write driver development guide
7. Code review and refinement

**Deliverable**: Complete, tested, documented PCIe subsystem

## Common Pitfalls

### Pitfall 1: Incorrect Configuration Space Access
**Problem**: Accessing invalid bus/device/function combinations causes system hangs.
**Solution**: Always check if device exists (read vendor ID, check for 0xFFFF) before further access.

### Pitfall 2: BAR Size Calculation Errors
**Problem**: Incorrectly calculating BAR size from probing mechanism.
**Solution**: Write 0xFFFFFFFF to BAR, read back, invert and add 1. Remember to restore original value.

### Pitfall 3: Interrupt Routing Confusion
**Problem**: MSI interrupts not delivered due to incorrect routing configuration.
**Solution**: Ensure message address and data correctly programmed. Verify interrupt controller setup.

### Pitfall 4: DMA Coherency Issues
**Problem**: DMA transfers show stale or corrupted data.
**Solution**: Properly flush/invalidate caches before/after DMA. Understand architecture's coherency model.

### Pitfall 5: Resource Leaks
**Problem**: BAR mappings, interrupt vectors, or DMA buffers not freed on driver unload.
**Solution**: Implement cleanup in driver remove() function. Use reference counting for shared resources.

### Pitfall 6: Endianness Issues
**Problem**: Configuration space and device registers may be little-endian while CPU is big-endian.
**Solution**: Use appropriate byte-swapping functions (le32_to_cpu, cpu_to_le32).

### Pitfall 7: Race Conditions
**Problem**: Concurrent access to device from multiple CPUs.
**Solution**: Use locks to protect device state. Be careful with interrupt context.

## References

### Specifications
- **PCI Local Bus Specification 3.0** - Base PCI specification
- **PCI Express Base Specification 3.0** - PCIe architecture and protocol
- **PCI Bus System Architecture (4th Edition)** - Detailed explanation of PCI/PCIe
- **RISC-V Privileged Specification** - Interrupt and memory management

### Reference Implementations
- **Linux kernel**: `drivers/pci/` - Comprehensive PCIe implementation
- **FreeBSD**: `sys/dev/pci/` - Alternative PCIe implementation
- **QEMU**: `hw/pci/` - Device-side PCIe implementation
- **EDK2/UEFI**: PCIe enumeration and configuration

### Learning Resources
- **OSDev Wiki**: PCI and PCIe articles
- **"Understanding PCI Express" by Alberto Leon-Garcia** - Accessible introduction
- **"Linux Device Drivers" (3rd Edition)** - Chapter 12: PCI Drivers
- **QEMU documentation**: PCIe support in qemu virt machines

### Related xv6 Code
- **virtio_disk.c** - Simple MMIO device (reference for driver structure)
- **plic.c** - Interrupt controller (reference for interrupt handling)
- **kalloc.c** - Physical memory allocation (for DMA buffers)

### Tools
- **lspci** (in Linux) - Enumerate and display PCI devices (reference behavior)
- **setpci** (in Linux) - Read/write PCI configuration space
- **QEMU monitor**: `info pci` command - Inspect PCIe devices in QEMU

## Appendix A: PCIe Configuration Space Layout

**Type 0 Configuration Header (Endpoint Device)**:
```
Offset  | Register
--------|--------------------------------------------------
0x00    | Device ID (16-bit) | Vendor ID (16-bit)
0x04    | Status (16-bit) | Command (16-bit)
0x08    | Class Code (24-bit) | Revision ID (8-bit)
0x0C    | BIST | Header Type | Latency | Cache Line Size
0x10    | Base Address Register 0 (BAR0)
0x14    | Base Address Register 1 (BAR1)
0x18    | Base Address Register 2 (BAR2)
0x1C    | Base Address Register 3 (BAR3)
0x20    | Base Address Register 4 (BAR4)
0x24    | Base Address Register 5 (BAR5)
0x28    | Cardbus CIS Pointer
0x2C    | Subsystem ID | Subsystem Vendor ID
0x30    | Expansion ROM Base Address
0x34    | Reserved | Capabilities Pointer
0x38    | Reserved
0x3C    | Max_Lat | Min_Gnt | Interrupt Pin | Interrupt Line
```

**Important Registers**:
- **Command Register (0x04)**: Enable I/O, memory, bus master, interrupts
- **Status Register (0x06)**: Capabilities list, interrupt status
- **BARs (0x10-0x24)**: Memory/IO region addresses and sizes
- **Capabilities Pointer (0x34)**: Start of capability list

## Appendix B: MSI Capability Structure

**MSI Capability Layout**:
```
Offset  | Field
--------|--------------------------------------------------
0x00    | Capability ID (0x05 for MSI) | Next Capability
0x02    | Message Control
0x04    | Message Address (Lower 32 bits)
0x08    | Message Address Upper (if 64-bit capable)
0x0C    | Message Data (16-bit)
0x0E    | Mask Bits (if per-vector masking capable)
0x12    | Pending Bits (if per-vector masking capable)
```

**Message Control Register**:
- Bit 0: MSI Enable
- Bits 1-3: Multiple Message Capable (2^n messages supported)
- Bits 4-6: Multiple Message Enable (2^n messages enabled)
- Bit 7: 64-bit Address Capable
- Bit 8: Per-Vector Masking Capable

## Appendix C: Example Driver Structure

**Minimal PCIe Driver**:
```c
static const struct pci_device_id test_pci_ids[] = {
  { PCI_DEVICE(0x8086, 0x100e) },  // Intel e1000
  { 0, }
};

static int test_probe(struct pci_device *pdev, const struct pci_device_id *id) {
  // 1. Enable device
  pci_enable_device(pdev);

  // 2. Request regions
  pci_request_regions(pdev, "test_driver");

  // 3. Map BARs
  void __iomem *mmio = pci_iomap(pdev, 0, 0);

  // 4. Enable MSI
  int nvec = pci_enable_msi(pdev, 1);

  // 5. Request IRQ
  request_irq(pdev->irq, test_interrupt_handler, pdev);

  // 6. Enable bus mastering (for DMA)
  pci_set_master(pdev);

  return 0;
}

static void test_remove(struct pci_device *pdev) {
  // Cleanup in reverse order
  free_irq(pdev->irq, pdev);
  pci_disable_msi(pdev);
  pci_iounmap(pdev, mmio);
  pci_release_regions(pdev);
  pci_disable_device(pdev);
}

static struct pci_driver test_driver = {
  .name = "test_pci_driver",
  .id_table = test_pci_ids,
  .probe = test_probe,
  .remove = test_remove,
};

void init_test_driver(void) {
  pci_register_driver(&test_driver);
}
```

---

**Phase Status**: Specification Complete
**Estimated Effort**: 240-320 hours over 6-8 weeks
**Prerequisites**: Phase 6 complete, HAL stable, IPC working
**Outputs**: Working PCIe subsystem, driver framework, example drivers
**Next Phase**: [Phase 8: Network Card Driver](phase8-network-card-driver.md)
