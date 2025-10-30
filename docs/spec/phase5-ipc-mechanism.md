# Phase 5: IPC Mechanism Implementation

**Duration**: 4-5 weeks
**Prerequisites**: Phase 4 complete (file system enhanced)
**Next Phase**: Phase 6 (Hybrid Kernel Transition)

## Overview

Phase 5 implements a Mach-style port-based IPC mechanism, providing the foundation for the hybrid kernel architecture in Phase 6. This IPC system enables efficient, capability-based communication between processes and will be critical for user-space servers.

**Core Objective**: Design and implement Mach-inspired port-based IPC with message passing, zero-copy optimization, asynchronous operations, and capability transfer, preparing for microkernel-style services in Phase 6.

## Objectives

### Primary Goals
1. Implement port-based IPC mechanism inspired by Mach
2. Support synchronous and asynchronous message passing
3. Implement zero-copy message transfer for large messages
4. Enable capability transfer (port rights in messages)
5. Implement priority-based message queuing
6. Establish comprehensive IPC performance benchmarking
7. Prepare IPC infrastructure for Phase 6 user-space servers

### Learning Outcomes
- Understanding of capability-based security models
- Experience with zero-copy optimization techniques
- Knowledge of microkernel IPC design patterns
- Skills in measuring and optimizing IPC latency
- Understanding of message-based communication trade-offs

## Functional Requirements

### FR1: Port-Based Communication Model

**Requirement**: Implement Mach-style ports as endpoints for message-based IPC.

**Port Concepts**:
- Port: kernel object representing communication endpoint
- Send right: capability to send messages to port
- Receive right: capability to receive messages from port
- Port set: group of ports for multiplexed receive
- Port name space: per-process namespace for port rights

**Port Properties**:
- Each port has unique kernel identifier (port ID)
- Each port has one receive right (owner)
- Port can have multiple send rights (distributed)
- Send rights are capabilities (can be transferred)
- Receive right is unique and non-copyable

**Port Lifecycle**:
1. Allocate: create new port, get receive right
2. Make-send: create send right from receive right
3. Transfer: send port rights in messages
4. Destroy: deallocate port when all rights released
5. Dead port: port with no receive right (send rights remain)

**Port Name Space**:
- Each process has local port name space
- Port names are integers (like file descriptors)
- Kernel maintains mapping: (process, port_name) → port_right
- Port names are process-local (not global)

**Port Rights Management**:
- Reference counting for send rights
- Tracking: which processes hold which rights
- Transfer: move rights between processes via messages
- Revocation: destroy all rights to a port

**Success Criteria**:
- Port allocation and deallocation work correctly
- Send and receive rights managed independently
- Port name spaces isolated per process
- Reference counting prevents premature port destruction

### FR2: Message Structure and Passing

**Requirement**: Define message format and implement send/receive operations.

**Message Structure**:
```
Message:
  Header:
    - Message size (total)
    - Destination port
    - Reply port (optional)
    - Message ID (optional)
    - Flags (e.g., no-reply, priority)
  Body:
    - Inline data (copied)
    - Out-of-line data descriptors (for zero-copy)
    - Port rights descriptors (capabilities)
  Trailer (optional):
    - Sender credentials (PID, UID)
    - Security token
```

**Inline Data**:
- Small data copied in message body
- Maximum inline size: configurable (e.g., 512 bytes)
- Fast for small messages
- Simple implementation

**Out-of-Line (OOL) Data**:
- Large data transferred by page remapping
- Descriptor: address, size, deallocate flag
- Zero-copy optimization
- Used for data >4KB (configurable threshold)

**Port Rights in Messages**:
- Can send port rights as part of message
- Types: send right, receive right, send-once right
- Kernel transfers rights during message send
- Enables capability delegation

**Message Sending**:
- `ipc_send(port_name, message, flags, timeout)` system call
- Options: blocking, non-blocking, timeout
- Queues message at destination port
- Returns: success, port destroyed, timeout, queue full

**Message Receiving**:
- `ipc_receive(port_name, message, flags, timeout)` system call
- Options: blocking, non-blocking, timeout
- Dequeues message from port
- Returns: success, port destroyed, timeout, interrupted

**Receive on Port Set**:
- `ipc_receive_from_set(port_set, message, flags, timeout)`
- Receive from any port in set
- Useful for server multiplexing multiple clients
- Returns: success + which port received from

**Success Criteria**:
- Small messages (<512 bytes) delivered correctly
- Large messages (>4KB) use zero-copy
- Port rights transferred correctly in messages
- Send and receive with various flags work
- Timeout handling correct

### FR3: Zero-Copy Message Transfer

**Requirement**: Optimize large message transfer using page remapping instead of copying.

**Zero-Copy Mechanism**:
- For data >threshold (e.g., 4KB): use page remapping
- Sender's pages unmapped from sender address space
- Pages mapped into receiver address space
- No data copying (only page table manipulation)
- Significantly faster for large messages

**Copy vs Zero-Copy Decision**:
- Small messages (<4KB): always copy (overhead not worth it)
- Large messages (≥4KB): zero-copy if page-aligned
- Unaligned: copy or use partial zero-copy
- Configurable threshold

**Page Remapping Details**:
- Sender marks pages for transfer
- Kernel unmaps pages from sender
- Kernel maps pages into receiver
- Receiver owns pages after receive
- Deallocate flag: free sender's copy after send

**COW Optimization** (from Phase 3):
- If message is read-only, can use COW instead of transfer
- Share pages between sender and receiver
- More efficient for broadcast scenarios

**Alignment and Padding**:
- Zero-copy requires page alignment (4KB on RISC-V)
- If data unaligned, must copy or pad
- Trade-off: alignment overhead vs copy overhead

**Virtual Memory Integration**:
- Use Phase 3 page table operations
- TLB flush required after remapping
- Handle page faults if pages swapped out

**Success Criteria**:
- Large messages (>4KB) significantly faster than copy
- Zero-copy latency <10μs overhead vs direct copy
- Memory correctly transferred (sender no longer has access)
- Alignment handled correctly
- Benchmark shows clear performance improvement

### FR4: Asynchronous Message Operations

**Requirement**: Support non-blocking send/receive and message queuing.

**Non-Blocking Send**:
- `ipc_send(port, msg, IPC_NOWAIT, 0)` - Return immediately
- If queue full: return EWOULDBLOCK instead of blocking
- Useful for servers that can't block

**Non-Blocking Receive**:
- `ipc_receive(port, msg, IPC_NOWAIT, 0)` - Return immediately
- If no messages: return EWOULDBLOCK instead of blocking
- Polling-based receive

**Timeout-Based Operations**:
- `ipc_send(port, msg, 0, timeout_ms)` - Block up to timeout
- `ipc_receive(port, msg, 0, timeout_ms)` - Block up to timeout
- Return ETIMEDOUT if timeout expires
- Enables bounded waiting

**Message Queuing**:
- Each port has message queue (FIFO by default)
- Queue capacity: configurable (e.g., 32 messages)
- Queue full: block sender or return error
- Queue empty: block receiver or return error

**Priority Queuing** (optional but recommended):
- Messages with priority field
- High-priority messages dequeued first
- Useful for real-time or critical messages

**Message Queue Management**:
- Per-port queue limit
- Global message limit (prevent DoS)
- Memory allocation for queued messages
- Cleanup on port destruction

**Success Criteria**:
- Non-blocking operations return immediately
- Timeout operations respect timeout values
- Message queuing works correctly (FIFO or priority)
- Queue overflow handled gracefully
- No message loss on properly sized queues

### FR5: Capability Transfer and Security

**Requirement**: Enable secure transfer of capabilities (port rights) in messages.

**Capability Model**:
- Port rights are capabilities
- Holding send right: can send to port
- Holding receive right: can receive from port
- Transfer right: ability to transfer capability to others

**Port Right Types**:
- **Send right**: can send messages, can be duplicated
- **Receive right**: can receive messages, unique owner
- **Send-once right**: can send one message, then destroyed
- **Port set right**: can receive from set of ports
- **Dead name**: reference to destroyed port

**Transferring Rights in Messages**:
- Message descriptor specifies: port name, right type, disposition
- Disposition: copy, move, make-send
- Kernel validates rights during send
- Kernel inserts rights into receiver's name space
- Automatic cleanup if transfer fails

**Example Transfer Scenarios**:

**Make-Send**:
- Process A has receive right to port P
- A sends message to B with make-send of P
- A retains receive right, B gets send right
- B can now send to P

**Move-Receive**:
- Process A has receive right to port P
- A sends message to B moving receive right
- A loses receive right, B gains receive right
- B is now owner of P

**Copy-Send**:
- Process A has send right to port P
- A sends message to B with copy-send of P
- Both A and B have send rights
- Reference count incremented

**Security Properties**:
- Cannot forge capabilities (kernel-managed)
- Cannot elevate privileges without delegation
- Port destruction revokes all rights
- Sender identity authenticated (trailer)

**Dead Port Detection**:
- When receive right destroyed, port becomes dead
- Send to dead port: returns error or queues notification
- Notification messages: inform senders of port death
- Cleanup: release resources associated with dead port

**Success Criteria**:
- Port rights transferred correctly in messages
- Reference counting correct (no leaks)
- Security model enforced (no capability forgery)
- Dead port detection works
- Sender credentials included in trailer

### FR6: IPC Performance Optimization

**Requirement**: Minimize IPC latency and maximize throughput.

**Optimization Targets**:
- Small message latency: <10μs (same CPU)
- Large message (zero-copy) latency: <50μs
- Message throughput: >100,000 messages/sec (small messages)
- Context switch overhead: minimize

**Fast Path Optimization**:
- Simple messages: inline data only, no rights, no OOL
- Fast path: avoid allocations, minimize locking
- Direct handoff: sender directly to receiver (no queue)
- Spin briefly before blocking (reduce context switches)

**Direct Message Handoff**:
- If receiver waiting: transfer directly to receiver
- Avoid queuing overhead
- Reduces latency significantly
- Requires synchronization between send and receive

**Lock Optimization**:
- Fine-grained locking: per-port locks, not global
- Lock-free operations where possible
- RCU for port lookup (read-mostly)
- Minimize lock hold time

**Message Buffer Management**:
- Slab allocator for message structures (Phase 3)
- Pre-allocated message buffers
- Avoid allocation in fast path
- Reclaim buffers on receive

**Benchmark Suite**:
- Ping-pong: measure round-trip latency
- Streaming: measure one-way throughput
- Broadcast: one sender, multiple receivers
- Many-to-one: multiple senders, one receiver

**Profiling and Measurement**:
- Cycle-accurate timing using CPU counters
- Breakdown: send overhead, receive overhead, context switch
- Identify bottlenecks
- Compare with Linux pipes, sockets

**Success Criteria**:
- Small message latency <10μs
- Zero-copy latency <50μs
- Throughput >100K messages/sec
- Comparable to or better than pipes for small messages
- Clear benefit of zero-copy for large messages

### FR7: IPC System Calls and API

**Requirement**: Define complete system call interface for IPC.

**Port Management**:
- `port_allocate(task, right, port_name*)` - Create new port
- `port_deallocate(task, port_name)` - Destroy port right
- `port_insert_right(task, port_name, right_type, ...)` - Add right
- `port_extract_right(task, port_name, right_type, ...)` - Remove right
- `port_set_create(task, port_set*)` - Create port set
- `port_set_add(task, port_set, port_name)` - Add port to set

**Message Passing**:
- `ipc_send(port, message, flags, timeout)` - Send message
- `ipc_receive(port, message, flags, timeout)` - Receive message
- `ipc_send_receive(send_port, recv_port, msg, ...)` - RPC pattern
- `ipc_reply(reply_port, message)` - Reply to request

**Message Construction** (user-space helpers):
- `message_init(message, size)` - Initialize message
- `message_add_inline(message, data, size)` - Add inline data
- `message_add_ool(message, addr, size, dealloc)` - Add OOL data
- `message_add_port(message, port_name, disposition)` - Add port right

**Query Operations**:
- `port_get_attributes(port_name, attrs*)` - Get port attributes
- `port_get_queue_status(port_name, status*)` - Queue length, etc.
- `ipc_get_stats(stats*)` - Global IPC statistics

**Success Criteria**:
- Complete API for port and message operations
- Intuitive and consistent with Mach IPC
- Easy to use from user-space programs
- Well-documented with examples

## Non-Functional Requirements

### NFR1: Performance

**Latency Targets**:
- Small message (<512 bytes): <10μs
- Medium message (512B-4KB): <20μs
- Large message (>4KB, zero-copy): <50μs
- Context switch overhead: <5μs

**Throughput Targets**:
- Same-CPU: >100K messages/sec
- Cross-CPU: >50K messages/sec (with SMP)

### NFR2: Correctness

**Invariants**:
- Exactly one receive right per port (uniqueness)
- Reference counts always accurate
- No message loss (unless queue overflow with NOWAIT)
- No message duplication
- FIFO ordering (unless priority queuing)

**Security**:
- Capability security enforced
- No privilege escalation without delegation
- Sender identity authenticated
- Port name space isolation

### NFR3: Scalability

**Limits**:
- Maximum ports per process: configurable (e.g., 1024)
- Maximum global ports: configurable (e.g., 16384)
- Maximum queued messages per port: configurable (e.g., 32)
- Maximum message size: configurable (e.g., 64KB inline + unlimited OOL)

### NFR4: Robustness

**Error Handling**:
- Graceful handling of port death
- Cleanup on process termination (all ports released)
- Deadlock avoidance (timeout on blocking operations)
- Resource exhaustion handling (port/message limits)

### NFR5: Compatibility

**Mach IPC Similarity**:
- Similar concepts (ports, rights, messages)
- Compatible semantics (not binary compatible)
- Simplified where appropriate for educational purposes
- Document differences from Mach

## Design Constraints

### DC1: Single-Machine IPC Only

**Constraint**: No distributed IPC across machines.

**Rationale**: Network IPC adds complexity (marshaling, endianness, security). Local IPC sufficient for hybrid kernel.

### DC2: Synchronous Zero-Copy

**Constraint**: Zero-copy requires synchronous handoff (sender blocks until receiver receives).

**Rationale**: Asynchronous zero-copy requires complex memory ownership tracking. Synchronous is simpler.

### DC3: No Message Batching

**Constraint**: One message per send/receive system call.

**Rationale**: Batching complicates API. Can be added later if needed.

### DC4: Fixed Message Size Limit

**Constraint**: Maximum inline message size fixed at compile time.

**Rationale**: Dynamic sizing adds complexity. Fixed limit is simple and predictable.

### DC5: Limited Port Set Size

**Constraint**: Port sets limited to reasonable number (e.g., 64 ports per set).

**Rationale**: Large port sets complicate implementation and degrade performance.

### DC6: No Multicast

**Constraint**: No one-to-many message broadcast primitive.

**Rationale**: Multicast requires complex queuing and synchronization. Can be implemented in user space if needed.

## Testing Requirements

### Test Suite

**Port Management Tests**:
- `test_port_allocate`: Allocate and deallocate ports
- `test_port_rights`: Send/receive rights management
- `test_port_namespace`: Process-local name spaces
- `test_port_refcount`: Reference counting correctness
- `test_port_set`: Port set operations

**Message Passing Tests**:
- `test_send_receive_inline`: Small inline messages
- `test_send_receive_ool`: Large OOL messages
- `test_send_receive_ports`: Port rights in messages
- `test_blocking_send`: Blocking on full queue
- `test_blocking_receive`: Blocking on empty queue
- `test_nonblocking`: Non-blocking send/receive
- `test_timeout`: Timeout-based operations

**Zero-Copy Tests**:
- `test_zerocopy_correctness`: Data transferred correctly
- `test_zerocopy_performance`: Faster than copy for large messages
- `test_zerocopy_alignment`: Aligned and unaligned data
- `test_zerocopy_ownership`: Sender loses access after send

**Capability Transfer Tests**:
- `test_makesend`: Make-send right transfer
- `test_movereceive`: Move receive right
- `test_copysend`: Copy send right
- `test_deadport`: Dead port detection
- `test_capability_security`: Cannot forge capabilities

**Performance Tests**:
- `bench_pingpong`: Round-trip latency
- `bench_streaming`: One-way throughput
- `bench_zerocopy`: Zero-copy vs copy
- `bench_context_switch`: Context switch overhead
- `bench_many_to_one`: Multiple senders to one receiver

**Stress Tests**:
- `test_many_ports`: 1000+ ports per process
- `test_many_messages`: High message rate
- `test_queue_overflow`: Queue full scenarios
- `test_port_death_cleanup`: Cleanup on port destruction
- `test_process_exit`: Cleanup on process exit

**Correctness Tests**:
- `test_message_ordering`: FIFO or priority ordering
- `test_no_message_loss`: All messages delivered
- `test_no_duplication`: No duplicate messages
- `test_sender_identity`: Sender credentials correct

### Success Criteria

**Functional Correctness**:
- [ ] All port management tests pass
- [ ] All message passing tests pass
- [ ] All zero-copy tests pass
- [ ] All capability transfer tests pass
- [ ] All stress tests pass without crashes or leaks

**Performance Validation**:
- [ ] Small message latency <10μs
- [ ] Zero-copy latency <50μs
- [ ] Throughput >100K messages/sec
- [ ] Zero-copy faster than copy for messages >4KB

**Security Validation**:
- [ ] Capability security enforced
- [ ] No unauthorized access to ports
- [ ] Sender identity correctly authenticated

## Implementation Guidance

### Phase 5 Implementation is NOT Provided

This specification describes WHAT to build, not HOW:

**What You Should Figure Out**:
- How to design port data structures
- How to implement zero-copy page remapping
- How to handle race conditions in message passing
- How to optimize for low latency
- How to integrate with scheduler (blocking operations)

**What You Should Research**:
- Mach IPC design and implementation
- L4 microkernel fast IPC
- QNX message passing
- Capability-based security systems
- Zero-copy techniques in networking

**What You Should Design**:
- Port and message data structures
- Port name space management
- Message queuing algorithm
- Zero-copy threshold and policy
- Lock strategy for concurrency

### Recommended Implementation Order

1. **Week 1**: Port infrastructure
   - Design port and right data structures
   - Implement port allocation/deallocation
   - Implement port name space management
   - Test port management

2. **Week 2**: Basic message passing
   - Implement message structure
   - Implement synchronous send/receive (inline only)
   - Implement message queuing
   - Test basic send/receive

3. **Week 3**: Zero-copy and OOL data
   - Implement OOL data descriptors
   - Implement zero-copy page remapping
   - Test zero-copy correctness and performance
   - Benchmark copy vs zero-copy

4. **Week 4**: Capability transfer and async operations
   - Implement port rights in messages
   - Implement capability transfer
   - Implement non-blocking and timeout operations
   - Test capability transfer and security

5. **Week 5**: Optimization and comprehensive testing
   - Optimize fast path
   - Implement priority queuing (optional)
   - Port sets (optional)
   - Comprehensive benchmarking and stress testing

### Common Pitfalls

**Pitfall 1: Race Conditions in Port Death**
- Port can be destroyed while messages in flight
- Must handle gracefully (return error or notification)
- Synchronization between port operations

**Pitfall 2: Reference Count Errors**
- Off-by-one in send right reference counting
- Must increment before transfer, decrement on failure
- Use assertions to verify counts

**Pitfall 3: TLB Coherency in Zero-Copy**
- Must flush TLB after remapping pages
- Must flush on both sender and receiver CPUs (SMP)
- Forgetting causes data corruption

**Pitfall 4: Deadlock in Synchronous IPC**
- Two processes send to each other: deadlock
- Use timeouts or non-blocking operations
- Detect and break cycles

**Pitfall 5: Message Buffer Leaks**
- Must free message buffers after receive
- Handle error paths (port death during send)
- Track all allocations

**Pitfall 6: Security: Capability Validation**
- Must validate port rights at send time
- Cannot trust user-space port names
- Kernel must check rights before operations

## References

### Mach IPC

**Primary References**:
- "Mach: A New Kernel Foundation for UNIX Development" (Accetta et al., 1986)
- "The Mach System" (Rashid et al., 1989)
- OSF Mach IPC documentation
- Darwin/XNU Mach IPC implementation (osfmk/ipc/)

**Implementation**:
- XNU kernel: osfmk/ipc/ipc_port.c, ipc_mqueue.c
- GNU Mach: ipc/ directory

### L4 Microkernel IPC

**Papers**:
- "Improving IPC by Kernel Design" (Liedtke, 1993)
- "On μ-Kernel Construction" (Liedtke, 1995)
- "L4 Reference Manual" (various versions)

**Key Concepts**:
- Fast IPC path (direct handoff)
- IPC timeout
- Short message optimization
- Zero-copy string transfer

### Capability-Based Security

**Papers**:
- "Protection" (Lampson, 1974)
- "The Confused Deputy" (Hardy, 1988)
- "Capability Myths Demolished" (Miller et al., 2003)

### Zero-Copy Techniques

**Papers**:
- "Fbufs: A High-Bandwidth Cross-Domain Transfer Facility" (Druschel & Peterson, 1993)
- "IO-Lite: A Unified I/O Buffering and Caching System" (Pai et al., 1999)

**Implementations**:
- Linux sendfile(), splice() system calls
- BSD zero-copy socket buffers

### IPC Performance

**Measurement**:
- "Measuring Capability-Based Systems" (Shapiro et al., 1999)
- "The Performance of μ-Kernel-Based Systems" (Härtig et al., 1997)
- lmbench IPC benchmarks

### QNX Message Passing

**References**:
- QNX Neutrino Microkernel documentation
- "Getting Started with QNX Neutrino: A Guide for Realtime Programmers"
- MsgSend/MsgReceive API

### Textbooks

**Operating Systems**:
- "Operating Systems: Three Easy Pieces" - IPC chapter
- "Modern Operating Systems" (Tanenbaum) - Chapter 2 (IPC)
- "Operating System Concepts" (Silberschatz) - Chapter 3 (IPC)

## Appendix: Data Structure Examples

**Note**: These are EXAMPLES for understanding, not complete implementations.

### Example: Port Structure

```c
// In kernel/ipc/include/port.h

typedef uint32 port_id_t;
typedef uint32 port_name_t;  // Per-process port name

#define PORT_RIGHT_SEND     0x01
#define PORT_RIGHT_RECEIVE  0x02
#define PORT_RIGHT_SEND_ONCE 0x04

struct port {
  port_id_t id;              // Unique port ID
  spinlock lock;             // Protect port state

  // Rights
  struct proc *receiver;     // Process with receive right (owner)
  int send_right_count;      // Number of send rights

  // Message queue
  struct message_queue {
    struct message *head;
    struct message *tail;
    int count;
    int limit;               // Max queued messages
  } queue;

  // Waiters
  struct proc *waiters_send;    // Blocked senders
  struct proc *waiters_receive; // Blocked receivers

  // State
  int flags;                 // PORT_FLAG_DEAD, etc.
  int seqno;                 // Sequence number
};

struct port_right {
  port_id_t port_id;         // Which port
  int right_type;            // SEND, RECEIVE, SEND_ONCE
  int refcount;              // For send rights
};
```

### Example: Message Structure

```c
// In kernel/ipc/include/message.h

#define IPC_MSG_INLINE_MAX 512

struct message {
  struct message *next;      // For queueing

  // Header
  uint32 size;               // Total message size
  port_name_t dest_port;     // Destination
  port_name_t reply_port;    // Reply port (optional)
  uint32 msg_id;             // Message ID
  uint32 flags;              // Message flags

  // Body
  uint32 inline_size;        // Size of inline data
  char inline_data[IPC_MSG_INLINE_MAX];

  // Out-of-line data
  int num_ool;
  struct ool_descriptor {
    void *addr;
    uint32 size;
    int deallocate;          // Free after transfer
  } ool_descs[8];            // Max 8 OOL regions

  // Port rights
  int num_ports;
  struct port_descriptor {
    port_name_t name;
    int right_type;
    int disposition;         // COPY, MOVE, MAKE_SEND
  } port_descs[8];           // Max 8 port rights

  // Trailer (sender info)
  struct {
    int sender_pid;
    int sender_uid;
  } trailer;
};
```

### Example: Port Name Space

```c
// In kernel/ipc/include/ipc.h

#define PORT_NAME_MAX 1024

struct port_namespace {
  spinlock lock;
  struct port_right *rights[PORT_NAME_MAX];  // Indexed by port_name
  int next_name;             // Next available name
};

// In struct proc
struct proc {
  // ... existing fields ...
  struct port_namespace port_ns;  // Per-process port namespace
};
```

### Example: System Call Prototypes

```c
// In kernel/ipc/include/ipc_syscalls.h

// Port management
int sys_port_allocate(int *port_name);
int sys_port_deallocate(int port_name);
int sys_port_insert_right(int port_name, int right_type);
int sys_port_set_create(int *port_set);

// Message passing
int sys_ipc_send(int port_name, struct message *msg, int flags, uint64 timeout);
int sys_ipc_receive(int port_name, struct message *msg, int flags, uint64 timeout);
int sys_ipc_send_receive(int send_port, int recv_port, struct message *msg, int flags);

// Query
int sys_port_get_attributes(int port_name, struct port_attrs *attrs);
int sys_ipc_get_stats(struct ipc_stats *stats);
```

## Appendix: Performance Benchmark Example

**Example Benchmark Output** (illustrative):

```
IPC Performance Benchmarks
==========================

Ping-Pong (Round-Trip Latency):
  Message Size     Latency (μs)    Throughput (msg/s)
  ------------     ------------    ------------------
  64 bytes         8.2             122,000
  512 bytes        9.1             110,000
  4 KB (copy)      18.4            54,400
  4 KB (zero-copy) 12.6            79,400
  64 KB (zero-copy) 42.1           23,800

Streaming (One-Way Throughput):
  Message Size     Throughput (msg/s)  Bandwidth (MB/s)
  ------------     ------------------  ----------------
  64 bytes         156,000             9.5
  512 bytes        142,000             69
  4 KB             92,000              359

Context Switch Overhead:
  Null send/receive: 5.3 μs
  Scheduler overhead: 2.1 μs
  IPC overhead: 3.2 μs

Comparison with Pipes:
  64-byte message:
    Pipes: 6.8 μs
    IPC:   8.2 μs (1.2x slower)
  4KB message:
    Pipes: 15.2 μs (copy)
    IPC:   12.6 μs (zero-copy, 1.2x faster)

Capability Transfer:
  Transfer send right: 10.5 μs (1.3x overhead)
  Transfer receive right: 11.2 μs
```

---

**Phase Status**: Ready for Implementation
**Estimated Effort**: 100-120 hours over 4-5 weeks
**Prerequisites**: Phase 4 complete (file system enhanced)
**Outputs**: Port-based IPC, zero-copy, capability transfer, benchmarks
**Next Phase**: [Phase 6: Hybrid Kernel Transition](phase6-hybrid-kernel-transition.md)
