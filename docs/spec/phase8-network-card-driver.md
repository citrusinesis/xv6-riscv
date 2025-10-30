# Phase 8: Network Card Driver and Basic Network Stack

**Duration**: 4-5 weeks
**Prerequisites**: Phase 7 (PCIe Infrastructure) complete
**Next Phase**: Phase 9 (Graphics Support - Optional) or Phase 10 (Optimization & Completion)

## Overview

Phase 8 brings network connectivity to the operating system by implementing a real network card driver (Intel e1000) and a minimal TCP/IP stack. This enables the OS to communicate with external systems, demonstrating practical device driver development and network protocol implementation.

**Core Objective**: Implement Intel e1000 network driver and basic network stack (Ethernet, ARP, IP, ICMP, UDP) to enable network communication including responding to ping requests.

## Objectives

### Primary Goals
1. Implement Intel e1000 (e1000e) network card driver using PCIe infrastructure
2. Create network device abstraction layer
3. Implement basic network stack (Layer 2-4)
4. Add socket API for user-space network access
5. Enable ping (ICMP echo) functionality
6. Support basic UDP communication

### Learning Outcomes
- Real-world device driver development
- Network card architecture (ring buffers, DMA descriptors)
- Network protocol stack implementation
- Packet processing and routing
- Socket API design
- Interrupt-driven I/O at scale

## Functional Requirements

### FR1: Intel e1000 Network Driver

**Requirement**: Implement fully functional driver for Intel e1000 network adapter, supporting packet transmission and reception.

**Hardware Initialization**:

#### Device Detection and Setup
- Detect e1000 device via PCIe enumeration (Vendor: 0x8086, Device: 0x100E and variants)
- Map MMIO regions (BAR0 for registers)
- Enable bus mastering for DMA
- Read MAC address from EEPROM
- Configure receive and transmit engines

#### Register Programming
- Program receive control register (RCTL)
- Program transmit control register (TCTL)
- Configure interrupt mask and throttling
- Set up multicast table array (MTA)
- Configure flow control (optional)

#### Ring Buffer Management
- Allocate transmit descriptor ring (minimum 64 descriptors)
- Allocate receive descriptor ring (minimum 64 descriptors)
- Allocate packet buffers for each descriptor
- Program descriptor base addresses and lengths
- Maintain head and tail pointers

**Descriptor Format**:
```c
struct e1000_rx_desc {
  uint64_t buffer_addr;  // Physical address of receive buffer
  uint16_t length;       // Length of data
  uint16_t checksum;     // Packet checksum
  uint8_t status;        // Descriptor status
  uint8_t errors;        // Descriptor errors
  uint16_t special;      // Special field
};

struct e1000_tx_desc {
  uint64_t buffer_addr;  // Physical address of transmit buffer
  uint16_t length;       // Data length
  uint8_t cso;           // Checksum offset
  uint8_t cmd;           // Command field
  uint8_t status;        // Status field
  uint8_t css;           // Checksum start
  uint16_t special;      // Special field
};
```

**Packet Transmission**:
- Accept packet from network stack
- Find available transmit descriptor
- Copy packet data to DMA buffer (or use zero-copy with proper locking)
- Fill descriptor fields (address, length, command)
- Update tail pointer to notify hardware
- Hardware DMAs packet and generates interrupt on completion
- Reclaim descriptor in interrupt handler

**Packet Reception**:
- Pre-allocate receive buffers
- Hardware DMAs received packets into buffers
- Generate interrupt when packets arrive
- Read descriptor status in interrupt handler
- Extract packet data
- Pass packet to network stack
- Refill descriptor with new buffer
- Update tail pointer

**Interrupt Handling**:
- Enable MSI or legacy interrupts via PCIe infrastructure
- Handle transmit complete interrupts
- Handle receive interrupts
- Handle link status change
- Implement NAPI-style polling (optional optimization)

**Success Criteria**:
- Driver successfully initializes e1000 device
- Can transmit Ethernet frames
- Can receive Ethernet frames
- Interrupts properly handled
- No packet loss under normal load
- Link status correctly detected

### FR2: Network Device Abstraction

**Requirement**: Provide generic network device interface to decouple drivers from protocol stack.

**Network Device Structure**:
```c
struct netdev {
  char name[16];                  // e.g., "eth0"
  uint8_t mac_addr[6];            // MAC address
  uint32_t mtu;                   // Maximum Transmission Unit
  uint32_t flags;                 // IFF_UP, IFF_RUNNING, etc.

  // Statistics
  uint64_t tx_packets;
  uint64_t rx_packets;
  uint64_t tx_bytes;
  uint64_t rx_bytes;
  uint64_t tx_errors;
  uint64_t rx_errors;
  uint64_t tx_dropped;
  uint64_t rx_dropped;

  // Operations
  const struct netdev_ops *ops;
  void *priv;                     // Driver private data
};

struct netdev_ops {
  int (*open)(struct netdev *dev);
  int (*stop)(struct netdev *dev);
  int (*xmit)(struct netdev *dev, struct sk_buff *skb);
  int (*ioctl)(struct netdev *dev, int cmd, void *arg);
  void (*set_multicast)(struct netdev *dev);
};
```

**Device Registration**:
- Register network device with kernel
- Assign device name (eth0, eth1, etc.)
- Publish MAC address
- Make device available to network stack

**Device Operations**:
- **open()**: Enable device, start interrupt handling
- **stop()**: Disable device, stop interrupts
- **xmit()**: Transmit packet
- **ioctl()**: Device-specific control operations
- **set_multicast()**: Configure multicast filtering

**Success Criteria**:
- Multiple network devices can coexist
- Device registration/unregistration works
- Operations correctly invoke driver functions
- Statistics accurately tracked

### FR3: Network Stack - Layer 2 (Ethernet)

**Requirement**: Implement Ethernet frame processing including frame parsing, validation, and routing to upper layers.

**Ethernet Frame Format**:
```
+------------------+------------------+--------+--------+-----+-------+
| Dest MAC (6)     | Src MAC (6)      | Type   | Data   | ... | FCS   |
| 00:11:22:33:44:55| 66:77:88:99:AA:BB| (2)    |        |     | (4)   |
+------------------+------------------+--------+--------+-----+-------+
```

**Frame Processing**:

#### Receive Path
- Validate minimum frame size (64 bytes)
- Validate maximum frame size (MTU + headers)
- Check destination MAC (unicast, broadcast, multicast)
- Parse EtherType field
- Route to appropriate protocol handler:
  - 0x0800: IPv4
  - 0x0806: ARP
  - 0x86DD: IPv6 (future)
- Discard invalid or unsupported frames

#### Transmit Path
- Accept packet from upper layer with destination MAC
- Fill Ethernet header (dest MAC, src MAC, EtherType)
- Calculate padding if needed (minimum 64 bytes)
- Pass to network device for transmission

**Protocol Registration**:
- Allow protocols to register for specific EtherTypes
- Dispatch received frames to registered handlers
- Handle multiple protocols simultaneously

**Success Criteria**:
- Correctly parse Ethernet frames
- Route frames to appropriate protocol
- Transmit properly formatted frames
- Handle broadcast and multicast
- Discard malformed frames

### FR4: Network Stack - ARP Protocol

**Requirement**: Implement Address Resolution Protocol to map IP addresses to MAC addresses.

**ARP Packet Format**:
```
+--------+--------+--------+--------+--------+--------+
| HW Type| Proto  | HW Len | Proto  | Opcode |        |
| (2)    | Type(2)| (1)    | Len(1) | (2)    |        |
+--------+--------+--------+--------+--------+--------+
| Sender MAC Address (6 bytes)                        |
+-----------------------------------------------------+
| Sender IP Address (4 bytes)                         |
+-----------------------------------------------------+
| Target MAC Address (6 bytes)                        |
+-----------------------------------------------------+
| Target IP Address (4 bytes)                         |
+-----------------------------------------------------+
```

**ARP Operations**:

#### ARP Request
- Send when MAC address for IP is unknown
- Broadcast to all hosts on network
- Contains sender's MAC and IP
- Asks "who has IP address X?"

#### ARP Reply
- Send in response to ARP request
- Unicast to requester
- Contains responder's MAC and IP

#### ARP Table
- Cache IP-to-MAC mappings
- Entry timeout (default: 300 seconds)
- Maximum table size (e.g., 128 entries)
- LRU eviction when table full

**ARP Processing**:
```c
struct arp_entry {
  uint32_t ip_addr;
  uint8_t mac_addr[6];
  uint64_t timestamp;
  uint8_t state;  // INCOMPLETE, REACHABLE, STALE
};
```

- Receive ARP request: if for our IP, send reply
- Receive ARP reply: update ARP table
- Send ARP request: when need MAC for IP
- Query ARP table before sending IP packet

**Success Criteria**:
- ARP requests sent when needed
- ARP replies correctly generated
- ARP table populated and maintained
- Can resolve IP to MAC address
- Handle ARP timeouts gracefully

### FR5: Network Stack - IP (Internet Protocol)

**Requirement**: Implement IPv4 packet processing including routing, fragmentation, and reassembly (simplified version).

**IPv4 Header Format**:
```
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|Version|  IHL  |Type of Service|          Total Length         |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|         Identification        |Flags|      Fragment Offset    |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|  Time to Live |    Protocol   |         Header Checksum       |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                       Source Address                          |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                    Destination Address                        |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
```

**IP Processing**:

#### Receive Path
- Validate header length (minimum 20 bytes)
- Validate header checksum
- Check IP version (4)
- Decrement TTL
- Check if packet is for us (compare destination IP)
- Parse protocol field:
  - 1: ICMP
  - 6: TCP (future)
  - 17: UDP
- Pass to protocol handler
- Forward packets not for us (if routing enabled)

#### Transmit Path
- Fill IP header fields:
  - Version: 4, IHL: 5 (20 bytes)
  - Total length: header + data
  - TTL: 64 (default)
  - Protocol: ICMP/UDP/TCP
  - Source IP: our IP
  - Destination IP: target IP
- Calculate header checksum
- Lookup next hop (routing table)
- Resolve MAC address via ARP
- Pass to Ethernet layer

**IP Configuration**:
- Configure IP address (static configuration for Phase 8)
- Configure netmask
- Configure default gateway
- Simple routing table (local network + default route)

**Fragmentation** (Simplified):
- Phase 8: Only support non-fragmented packets (DF flag set)
- Phase 8: Discard fragmented packets
- Future: Implement fragmentation and reassembly

**Success Criteria**:
- Valid IP packets processed correctly
- Invalid packets discarded
- Checksum validation works
- TTL correctly decremented
- Routing to local network and default gateway

### FR6: Network Stack - ICMP (Ping)

**Requirement**: Implement ICMP protocol to support ping (echo request/reply) and error messages.

**ICMP Header Format**:
```
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|     Type      |     Code      |          Checksum             |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                             Data                              |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
```

**ICMP Types**:
- Type 0: Echo Reply
- Type 3: Destination Unreachable
- Type 8: Echo Request
- Type 11: Time Exceeded

**Echo Request/Reply Processing**:

#### Receive Echo Request (Type 8)
- Validate checksum
- Create echo reply
- Copy identifier and sequence number
- Copy data payload
- Swap source and destination IPs
- Calculate checksum
- Send reply

#### Send Echo Request
- User program calls ping
- Create ICMP echo request
- Set identifier (process ID)
- Set sequence number (incremental)
- Include data payload (optional)
- Send to destination IP

#### Receive Echo Reply (Type 0)
- Match identifier and sequence to pending request
- Calculate round-trip time
- Wake up waiting process
- Return success to user

**Error Messages**:
- Generate "Destination Unreachable" when:
  - No route to host
  - Port unreachable (UDP)
  - Protocol unreachable
- Generate "Time Exceeded" when TTL reaches 0

**Success Criteria**:
- Can respond to ping from external host
- Can send ping to external host
- Round-trip time accurately measured
- Echo request/reply matching works
- Error messages generated appropriately

### FR7: Network Stack - UDP Protocol

**Requirement**: Implement UDP (User Datagram Protocol) for connectionless datagram service.

**UDP Header Format**:
```
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|          Source Port          |       Destination Port        |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|            Length             |           Checksum            |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                             Data                              |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
```

**UDP Processing**:

#### Receive Path
- Validate length field
- Validate checksum (optional in IPv4)
- Lookup socket by (dest IP, dest port)
- If socket exists:
  - Copy data to socket receive buffer
  - Wake up waiting process
- If no socket:
  - Send ICMP port unreachable

#### Transmit Path
- User provides data, destination IP, destination port
- Allocate packet buffer
- Fill UDP header:
  - Source port: from socket
  - Destination port: from user
  - Length: header (8) + data length
  - Checksum: optional (can set to 0)
- Pass to IP layer for transmission

**Socket Binding**:
- Bind socket to local port
- Port 0-1023: privileged (require root)
- Port 1024-65535: unprivileged
- Prevent duplicate bindings
- Support wildcard binding (0.0.0.0)

**Success Criteria**:
- Can send UDP datagrams
- Can receive UDP datagrams
- Port demultiplexing works correctly
- Checksum validation correct (if implemented)
- No packet loss under normal load

### FR8: Socket API

**Requirement**: Provide user-space socket API for network communication.

**Socket System Calls**:

#### socket()
```c
int socket(int domain, int type, int protocol);
// domain: AF_INET (IPv4)
// type: SOCK_DGRAM (UDP), SOCK_RAW (raw IP)
// protocol: 0 (auto), IPPROTO_UDP, IPPROTO_ICMP
// returns: socket file descriptor
```

#### bind()
```c
int bind(int sockfd, const struct sockaddr *addr, int addrlen);
// Bind socket to local address and port
```

#### sendto()
```c
int sendto(int sockfd, const void *buf, size_t len, int flags,
           const struct sockaddr *dest_addr, int addrlen);
// Send datagram to destination
```

#### recvfrom()
```c
int recvfrom(int sockfd, void *buf, size_t len, int flags,
             struct sockaddr *src_addr, int *addrlen);
// Receive datagram (blocking)
```

#### close()
```c
int close(int sockfd);
// Close socket
```

**Socket Address Structure**:
```c
struct sockaddr_in {
  uint16_t sin_family;      // AF_INET
  uint16_t sin_port;        // Port number (network byte order)
  uint32_t sin_addr;        // IP address (network byte order)
  char sin_zero[8];         // Padding
};
```

**Socket Implementation**:
- Socket is a special file descriptor
- Maintain socket table per process
- Socket buffer for received data
- Blocking receive (sleep until data available)
- Non-blocking send (return immediately or -EWOULDBLOCK)

**Raw Sockets** (Optional):
- Allow direct access to IP layer
- Useful for implementing ping in user space
- Require privilege to create

**Success Criteria**:
- User programs can create sockets
- Can bind to specific ports
- Can send and receive UDP datagrams
- Blocking receive works correctly
- Multiple sockets work independently

## Non-Functional Requirements

### NFR1: Performance
- Packet transmission latency: <100 microseconds
- Packet reception latency: <100 microseconds
- Throughput: >10 Mbps (limited by QEMU, not driver)
- Interrupt rate: <1000 interrupts/sec under normal load
- Ping round-trip time: <1ms on local network

### NFR2: Reliability
- No packet corruption
- Handle out-of-order packets gracefully
- Recover from descriptor ring full
- Handle network cable disconnect/reconnect
- Survive continuous high packet rate

### NFR3: Resource Management
- Bounded memory usage for buffers
- Release resources on socket close
- No memory leaks in transmit/receive paths
- Limit number of sockets per process

### NFR4: Security
- Validate all packet headers
- Bounds check buffer access
- Prevent IP spoofing from user space
- Enforce port privilege separation
- Validate user-provided addresses

### NFR5: Compatibility
- Interoperate with standard network tools (ping, nc, etc.)
- Follow RFC specifications:
  - RFC 791: IP
  - RFC 792: ICMP
  - RFC 768: UDP
  - RFC 826: ARP
- Compatible with Linux/BSD socket API

## Design Constraints

### DC1: Scope Limitations
- **TCP not required**: Phase 8 focuses on UDP
- **IPv6 not required**: Only IPv4 implementation
- **Advanced features deferred**:
  - QoS, VLAN tagging
  - Jumbo frames
  - Hardware offloads (checksum, segmentation)
  - Multicast routing

### DC2: Simplifications Allowed
- Static IP configuration (no DHCP)
- Simple routing (local network + default gateway)
- No IP fragmentation/reassembly
- No IP options support
- UDP checksum optional
- Single network interface

### DC3: QEMU Environment
- Test with QEMU e1000 emulation
- QEMU networking modes:
  - User mode: Simple NAT, no incoming connections
  - Tap mode: Full network access, requires setup
- Performance limited by QEMU emulation

### DC4: Integration Requirements
- Use PCIe infrastructure from Phase 7
- Support user-space network stack (Phase 6 hybrid kernel)
- Work with file descriptor abstraction
- Integrate with VFS for socket files

## Testing Requirements

### Unit Tests

**e1000 Driver**:
- Mock PCIe configuration space
- Test descriptor ring management
- Test transmit function
- Test receive function
- Test interrupt handling

**Network Stack**:
- Test Ethernet frame parsing
- Test IP packet parsing
- Test checksum calculation
- Test ARP table operations
- Test UDP header creation

**Socket API**:
- Test socket creation
- Test bind operation
- Test sendto/recvfrom
- Test error handling

### Integration Tests (QEMU)

**Driver Tests**:
- Load e1000 driver
- Verify device initialization
- Send test packet
- Receive test packet
- Measure interrupt rate

**Protocol Tests**:
- Send/receive Ethernet frames
- ARP request/reply cycle
- Send/receive IP packets
- Respond to ping
- Send/receive UDP datagrams

**Socket Tests**:
- Create UDP socket
- Bind to port
- Send datagram
- Receive datagram
- Multiple sockets

**End-to-End Tests**:
- Ping OS from host
- Ping host from OS
- UDP echo server in OS
- UDP client in OS
- Interoperability with standard tools

### Performance Tests

**Throughput**:
- Measure UDP throughput (MB/s)
- Measure packet rate (packets/sec)
- Test with various packet sizes (64B to 1500B)

**Latency**:
- Measure ping round-trip time
- Measure interrupt latency
- Measure packet processing time

**Stress Tests**:
- Continuous high packet rate
- Packet flood (test descriptor ring full)
- Many concurrent sockets
- Large UDP datagrams (near MTU)

**Resource Tests**:
- Memory usage under load
- Socket table limits
- Buffer exhaustion handling

## Success Criteria

### Functional Success
- [ ] e1000 driver successfully initializes device
- [ ] Can transmit and receive Ethernet frames
- [ ] ARP resolution works
- [ ] Can respond to ping from external host
- [ ] Can ping external host from OS
- [ ] UDP sockets functional
- [ ] All integration tests pass

### Architectural Success
- [ ] Clean separation between driver and network stack
- [ ] Protocol layers properly abstracted
- [ ] Socket API compatible with POSIX
- [ ] Integration with hybrid kernel model
- [ ] No layering violations

### Quality Success
- [ ] >70% code coverage in unit tests
- [ ] All unit tests pass
- [ ] No memory leaks detected
- [ ] No packet corruption under stress
- [ ] Code review approved

### Performance Success
- [ ] Ping RTT <5ms (QEMU environment)
- [ ] UDP throughput >10 Mbps
- [ ] Packet transmit latency <100μs
- [ ] Interrupt overhead acceptable
- [ ] Boot time increase <200ms

### Interoperability Success
- [ ] Can ping from Linux/Windows host
- [ ] Can receive pings from OS
- [ ] UDP communication with nc (netcat)
- [ ] Wireshark captures show valid packets
- [ ] ARP visible in host ARP table

## Implementation Strategy

### Phase 8.1: e1000 Driver Basics (Week 1)

**Tasks**:
1. Detect e1000 device via PCIe
2. Map MMIO regions
3. Read MAC address
4. Initialize receive/transmit rings
5. Program basic registers
6. Enable interrupts
7. Test with loopback

**Deliverable**: Driver loads and initializes hardware

### Phase 8.2: Packet Transmission (Week 1)

**Tasks**:
1. Implement transmit function
2. Fill transmit descriptors
3. Trigger transmission
4. Handle transmit complete interrupt
5. Test sending raw Ethernet frame

**Deliverable**: Can transmit packets

### Phase 8.3: Packet Reception (Week 2)

**Tasks**:
1. Implement receive function
2. Handle receive interrupt
3. Process receive descriptors
4. Refill descriptor ring
5. Test receiving Ethernet frames

**Deliverable**: Can receive packets

### Phase 8.4: Network Stack - Layers 2-3 (Week 2-3)

**Tasks**:
1. Implement Ethernet frame processing
2. Implement ARP protocol and table
3. Implement IP packet processing
4. Implement routing table (simple)
5. Test with crafted packets

**Deliverable**: IP layer functional

### Phase 8.5: ICMP and Ping (Week 3)

**Tasks**:
1. Implement ICMP echo request/reply
2. Implement ping utility
3. Test bidirectional ping
4. Measure round-trip times

**Deliverable**: Ping works

### Phase 8.6: UDP and Sockets (Week 4)

**Tasks**:
1. Implement UDP protocol
2. Implement socket system calls
3. Create UDP echo server test
4. Test with external client

**Deliverable**: UDP communication works

### Phase 8.7: Testing and Optimization (Week 5)

**Tasks**:
1. Write comprehensive tests
2. Stress testing
3. Performance benchmarking
4. Fix bugs and optimize
5. Documentation

**Deliverable**: Complete, tested network subsystem

## Common Pitfalls

### Pitfall 1: Endianness Issues
**Problem**: Network byte order (big-endian) vs host byte order.
**Solution**: Use htons(), htonl(), ntohs(), ntohl() consistently. Test on both endianness.

### Pitfall 2: DMA Buffer Alignment
**Problem**: e1000 requires 16-byte alignment for descriptors.
**Solution**: Ensure DMA allocations properly aligned. Check alignment in allocator.

### Pitfall 3: Descriptor Ring Full
**Problem**: Transmit or receive ring full causes packet drops or hangs.
**Solution**: Check for available descriptors before queuing. Implement backpressure.

### Pitfall 4: Interrupt Storms
**Problem**: Too many interrupts cause poor performance.
**Solution**: Implement interrupt throttling/coalescing in hardware. Use NAPI-style polling.

### Pitfall 5: Checksum Errors
**Problem**: Incorrect IP/UDP checksum calculation.
**Solution**: Follow RFC specification exactly. Test with known-good packets. Include pseudo-header for UDP.

### Pitfall 6: ARP Table Races
**Problem**: Concurrent access to ARP table from multiple contexts.
**Solution**: Protect ARP table with lock. Handle timeout carefully.

### Pitfall 7: Socket Buffer Management
**Problem**: Leaked buffers or use-after-free in socket code.
**Solution**: Reference counting for buffers. Clear state on socket close.

### Pitfall 8: Packet Ordering
**Problem**: Assuming packets arrive in order.
**Solution**: Don't make ordering assumptions (especially for UDP). Design protocol handlers to be stateless.

## References

### Device Specifications
- **Intel 82540EP/EM Gigabit Ethernet Controller Datasheet** - Complete hardware reference
- **Intel e1000 Software Developer's Manual** - Register programming guide
- **PCI/PCIe specifications** - For device configuration

### Protocol Specifications (RFCs)
- **RFC 791**: Internet Protocol (IP)
- **RFC 792**: Internet Control Message Protocol (ICMP)
- **RFC 768**: User Datagram Protocol (UDP)
- **RFC 826**: Address Resolution Protocol (ARP)
- **RFC 1071**: Computing the Internet Checksum
- **RFC 1122**: Requirements for Internet Hosts

### Reference Implementations
- **Linux kernel**:
  - `drivers/net/ethernet/intel/e1000/` - e1000 driver
  - `net/ipv4/` - IPv4 stack
  - `net/core/` - Network core
- **BSD kernel**: `sys/netinet/` - BSD network stack
- **lwIP**: Lightweight TCP/IP stack (good educational reference)
- **QEMU**: `hw/net/e1000.c` - Device emulation

### Learning Resources
- **"TCP/IP Illustrated, Volume 1" by W. Richard Stevens** - Network protocols explained
- **"Understanding Linux Network Internals" by Christian Benvenuti** - Linux network stack internals
- **"Linux Device Drivers" (3rd Edition)** - Chapter 17: Network Drivers
- **Beej's Guide to Network Programming** - Socket API tutorial

### Tools
- **Wireshark**: Packet capture and analysis
- **tcpdump**: Command-line packet capture
- **netcat (nc)**: Network testing tool
- **ping**: ICMP echo utility
- **iperf**: Network performance testing

## Appendix A: e1000 Register Map

**Important Registers**:
```
Offset  | Register | Description
--------|----------|--------------------------------------------
0x0000  | CTRL     | Device Control
0x0008  | STATUS   | Device Status
0x00D0  | ICR      | Interrupt Cause Read
0x00D8  | IMS      | Interrupt Mask Set
0x0100  | RCTL     | Receive Control
0x0400  | TCTL     | Transmit Control
0x2800  | RDBAL    | RX Descriptor Base Address Low
0x2804  | RDBAH    | RX Descriptor Base Address High
0x2808  | RDLEN    | RX Descriptor Length
0x2810  | RDH      | RX Descriptor Head
0x2818  | RDT      | RX Descriptor Tail
0x3800  | TDBAL    | TX Descriptor Base Address Low
0x3804  | TDBAH    | TX Descriptor Base Address High
0x3808  | TDLEN    | TX Descriptor Length
0x3810  | TDH      | TX Descriptor Head
0x3818  | TDT      | TX Descriptor Tail
0x5400  | RAL[0]   | Receive Address Low
0x5404  | RAH[0]   | Receive Address High
```

## Appendix B: Packet Processing Flow

**Receive Path**:
```
Hardware → RX Descriptor → Driver Interrupt Handler
    ↓
Extract packet → Ethernet Layer (parse header)
    ↓
ARP? → ARP Handler → Update ARP table
IP?  → IP Layer (validate, route)
    ↓
ICMP? → ICMP Handler (echo reply, errors)
UDP?  → UDP Layer → Demux by port
    ↓
Socket → Copy to socket buffer → Wake up process
```

**Transmit Path**:
```
User process → sendto() → System call handler
    ↓
UDP Layer → Build UDP header
    ↓
IP Layer → Build IP header → Routing table lookup
    ↓
ARP table lookup → Resolve MAC (or ARP request)
    ↓
Ethernet Layer → Build Ethernet header
    ↓
Driver → TX Descriptor → Hardware → Physical transmission
```

## Appendix C: Example Socket Usage

**UDP Echo Server**:
```c
int main() {
  int sockfd = socket(AF_INET, SOCK_DGRAM, 0);

  struct sockaddr_in addr;
  addr.sin_family = AF_INET;
  addr.sin_port = htons(7); // Echo port
  addr.sin_addr = INADDR_ANY;

  bind(sockfd, (struct sockaddr*)&addr, sizeof(addr));

  char buf[1500];
  while (1) {
    struct sockaddr_in client;
    int addrlen = sizeof(client);
    int n = recvfrom(sockfd, buf, sizeof(buf), 0,
                     (struct sockaddr*)&client, &addrlen);
    if (n > 0) {
      sendto(sockfd, buf, n, 0,
             (struct sockaddr*)&client, addrlen);
    }
  }
}
```

**Ping Implementation**:
```c
int ping(const char *host) {
  int sockfd = socket(AF_INET, SOCK_RAW, IPPROTO_ICMP);

  struct sockaddr_in addr;
  addr.sin_family = AF_INET;
  addr.sin_addr = inet_addr(host);

  // Build ICMP echo request
  struct icmp_packet {
    uint8_t type;      // 8 (echo request)
    uint8_t code;      // 0
    uint16_t checksum;
    uint16_t id;
    uint16_t seq;
    char data[56];
  } pkt;

  pkt.type = 8;
  pkt.code = 0;
  pkt.id = getpid();
  pkt.seq = 1;
  pkt.checksum = 0;
  pkt.checksum = calculate_checksum(&pkt, sizeof(pkt));

  uint64_t start = get_time_us();
  sendto(sockfd, &pkt, sizeof(pkt), 0,
         (struct sockaddr*)&addr, sizeof(addr));

  // Receive reply
  recvfrom(sockfd, &pkt, sizeof(pkt), 0, NULL, NULL);
  uint64_t rtt = get_time_us() - start;

  printf("Reply from %s: time=%llu us\n", host, rtt);
  close(sockfd);
}
```

---

**Phase Status**: Specification Complete
**Estimated Effort**: 160-200 hours over 4-5 weeks
**Prerequisites**: Phase 7 complete, PCIe working, DMA functional
**Outputs**: Working network driver, basic TCP/IP stack, socket API
**Next Phase**: [Phase 9: Graphics Support](phase9-graphics-support.md) (Optional) or [Phase 10: Optimization & Completion](phase10-optimization-completion.md)
