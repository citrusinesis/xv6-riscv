# Phase 6: Networking Stack Implementation

**Duration**: 6-8 weeks
**Difficulty**: Advanced
**Prerequisites**: Phase 1, Phase 2

## Objectives

Implement a TCP/IP networking stack from scratch, including device driver, protocols, and socket API.

## Features to Implement

### 1. Network Device Driver (virtio-net)

**Requirements**:
- Implement virtio-net device driver for QEMU
- Initialize device: setup virtqueues (TX and RX)
- Packet transmission: enqueue packet to TX virtqueue
- Packet reception: handle RX interrupts, dequeue packets
- DMA support for packet buffers

**Data Structures**:
```c
struct net_dev {
  volatile uint32 *mmio;  // MMIO registers
  struct virtq tx_vq;     // Transmit queue
  struct virtq rx_vq;     // Receive queue
  uint8 mac_addr[6];      // MAC address
};
```

**Functions to Implement**:
- `net_init()` - Initialize network device
- `net_send(void *data, int len)` - Transmit packet
- `net_recv()` - Receive packet (called from interrupt)
- `netintr()` - Network interrupt handler

**Files**:
- `kernel/virtio_net.c` - Driver implementation
- `kernel/virtio_net.h` - Driver interface

### 2. Ethernet Layer

**Requirements**:
- Ethernet frame structure (dest MAC, src MAC, type, data, CRC)
- Frame parsing and creation
- MAC address handling
- Support Ethernet types: IPv4 (0x0800), ARP (0x0806)

**Data Structures**:
```c
struct eth_hdr {
  uint8 dest[6];    // Destination MAC
  uint8 src[6];     // Source MAC
  uint16 type;      // EtherType
} __attribute__((packed));
```

**Functions**:
- `eth_send(uint8 *dest_mac, uint16 type, void *data, int len)`
- `eth_recv(struct mbuf *m)` - Parse and dispatch frame

### 3. ARP Protocol

**Requirements**:
- ARP table: mapping IP ↔ MAC address
- ARP request/reply handling
- ARP cache with timeout (TTL = 300 seconds)
- ARP table lookup

**Data Structures**:
```c
struct arp_entry {
  uint32 ip;        // IP address
  uint8 mac[6];     // MAC address
  uint64 expire;    // Expiration time
};

struct arp_table {
  struct arp_entry entries[256];
  int count;
};
```

**Functions**:
- `arp_lookup(uint32 ip, uint8 *mac)` - Find MAC for IP
- `arp_request(uint32 ip)` - Send ARP request
- `arp_recv(struct mbuf *m)` - Handle ARP packet
- `arp_update(uint32 ip, uint8 *mac)` - Update ARP table

### 4. IP Layer

**Requirements**:
- IPv4 packet header parsing and creation
- IP address assignment (static for now)
- Routing table (simple: default gateway only)
- IP fragmentation and reassembly (optional, basic)
- Checksum calculation and verification
- TTL handling

**Data Structures**:
```c
struct ip_hdr {
  uint8 version_ihl;   // Version (4 bits) + IHL (4 bits)
  uint8 tos;           // Type of service
  uint16 len;          // Total length
  uint16 id;           // Identification
  uint16 frag_off;     // Fragment offset
  uint8 ttl;           // Time to live
  uint8 protocol;      // Protocol (TCP=6, UDP=17, ICMP=1)
  uint16 checksum;     // Header checksum
  uint32 src;          // Source IP
  uint32 dest;         // Destination IP
} __attribute__((packed));

struct route_entry {
  uint32 network;      // Network address
  uint32 netmask;      // Netmask
  uint32 gateway;      // Gateway IP
  int metric;          // Route metric
};
```

**Functions**:
- `ip_send(uint32 dest_ip, uint8 protocol, void *data, int len)`
- `ip_recv(struct mbuf *m)` - Handle IP packet
- `ip_checksum(struct ip_hdr *hdr)` - Calculate checksum
- `ip_route(uint32 dest_ip)` - Find next hop

**IP Configuration**:
- Static IP: 10.0.2.15 (QEMU default)
- Netmask: 255.255.255.0
- Gateway: 10.0.2.2

### 5. ICMP Protocol

**Requirements**:
- Implement ICMP echo request/reply (ping)
- ICMP error messages: Destination Unreachable, Time Exceeded
- Checksum calculation

**Data Structures**:
```c
struct icmp_hdr {
  uint8 type;          // ICMP type
  uint8 code;          // ICMP code
  uint16 checksum;     // Checksum
  uint16 id;           // Identifier
  uint16 seq;          // Sequence number
} __attribute__((packed));
```

**ICMP Types**:
- Type 0: Echo Reply
- Type 8: Echo Request
- Type 3: Destination Unreachable
- Type 11: Time Exceeded

**Functions**:
- `icmp_send_echo(uint32 dest_ip, uint16 id, uint16 seq)`
- `icmp_recv(struct mbuf *m)` - Handle ICMP packet

**User Program**: `ping <ip>` - Send ICMP echo requests

### 6. UDP Protocol

**Requirements**:
- UDP socket support
- Checksum calculation (optional: can disable)
- Port binding and demultiplexing
- Socket buffer management

**Data Structures**:
```c
struct udp_hdr {
  uint16 src_port;     // Source port
  uint16 dest_port;    // Destination port
  uint16 len;          // Length
  uint16 checksum;     // Checksum
} __attribute__((packed));

struct udp_socket {
  uint16 port;         // Local port
  struct sockbuf rxbuf;// Receive buffer
  int used;            // Socket in use
};
```

**Functions**:
- `udp_bind(int sock, uint16 port)`
- `udp_send(int sock, uint32 dest_ip, uint16 dest_port, void *data, int len)`
- `udp_recv(int sock, void *buf, int len)`
- `udp_input(struct mbuf *m)` - Handle incoming UDP

### 7. TCP Protocol (Simplified)

This is complex; implement basic TCP first, can enhance later.

**Basic TCP Features**:
- Three-way handshake (SYN, SYN-ACK, ACK)
- Connection establishment and termination
- Reliable delivery (ACK, retransmission)
- Flow control (sliding window, basic)
- Congestion control (optional: basic slow start)

**Data Structures**:
```c
struct tcp_hdr {
  uint16 src_port;
  uint16 dest_port;
  uint32 seq;          // Sequence number
  uint32 ack;          // Acknowledgment number
  uint8 data_off;      // Data offset (4 bits) + reserved (4 bits)
  uint8 flags;         // Flags (SYN, ACK, FIN, RST, etc.)
  uint16 window;       // Window size
  uint16 checksum;
  uint16 urgent;       // Urgent pointer
} __attribute__((packed));

// TCP socket states
enum tcp_state {
  TCP_CLOSED,
  TCP_LISTEN,
  TCP_SYN_SENT,
  TCP_SYN_RECEIVED,
  TCP_ESTABLISHED,
  TCP_FIN_WAIT_1,
  TCP_FIN_WAIT_2,
  TCP_CLOSE_WAIT,
  TCP_CLOSING,
  TCP_LAST_ACK,
  TCP_TIME_WAIT
};

struct tcp_socket {
  enum tcp_state state;
  uint32 local_ip;
  uint16 local_port;
  uint32 remote_ip;
  uint16 remote_port;

  // Sequence numbers
  uint32 snd_nxt;      // Next sequence to send
  uint32 snd_una;      // Oldest unacknowledged sequence
  uint32 rcv_nxt;      // Next expected sequence

  // Buffers
  struct sockbuf rxbuf;
  struct sockbuf txbuf;

  // Timers
  uint64 retrans_timer;
  int retrans_count;
};
```

**Functions to Implement**:
- `tcp_connect(uint32 dest_ip, uint16 dest_port)` - Initiate connection
- `tcp_listen(uint16 port)` - Listen for connections
- `tcp_accept(int listen_sock)` - Accept incoming connection
- `tcp_send(int sock, void *data, int len)` - Send data
- `tcp_recv(int sock, void *buf, int len)` - Receive data
- `tcp_close(int sock)` - Close connection
- `tcp_input(struct mbuf *m)` - Handle incoming TCP segment
- `tcp_retransmit(struct tcp_socket *sock)` - Retransmit unacked data

**Simplifications** (for initial version):
- Fixed window size (e.g., 4096 bytes)
- Simple timeout-based retransmission (no fast retransmit)
- No selective acknowledgment (SACK)
- No congestion control (can add later)

### 8. Socket API

Implement BSD-style socket API:

**System Calls**:
- `int socket(int domain, int type, int protocol)` - Create socket
  - domain: AF_INET
  - type: SOCK_STREAM (TCP), SOCK_DGRAM (UDP)
- `int bind(int sockfd, struct sockaddr *addr, int addrlen)` - Bind to port
- `int listen(int sockfd, int backlog)` - Listen for connections (TCP)
- `int accept(int sockfd, struct sockaddr *addr, int *addrlen)` - Accept connection
- `int connect(int sockfd, struct sockaddr *addr, int addrlen)` - Connect to remote
- `int send(int sockfd, void *buf, int len, int flags)` - Send data
- `int recv(int sockfd, void *buf, int len, int flags)` - Receive data
- `int sendto(int sockfd, void *buf, int len, int flags, struct sockaddr *dest, int destlen)` - UDP send
- `int recvfrom(int sockfd, void *buf, int len, int flags, struct sockaddr *src, int *srclen)` - UDP recv
- `int close(int sockfd)` - Close socket (already exists, extend for sockets)

**Data Structures**:
```c
struct sockaddr {
  uint16 family;       // AF_INET
  uint16 port;         // Port number
  uint32 addr;         // IP address
  uint8 zero[8];       // Padding
};

struct socket {
  int type;            // SOCK_STREAM or SOCK_DGRAM
  int protocol;        // TCP or UDP
  union {
    struct tcp_socket *tcp;
    struct udp_socket *udp;
  };
};
```

**Files to Modify**:
- `kernel/sysnet.c` - Socket system calls
- `kernel/file.h` - Extend file types to include sockets
- `kernel/file.c` - Integrate sockets with file descriptor table

### 9. Network Configuration

**System Calls**:
- `int setipaddr(uint32 ip, uint32 netmask, uint32 gateway)` - Set IP configuration
- `int getipaddr(uint32 *ip, uint32 *netmask, uint32 *gateway)` - Get IP configuration

**User Program**: `ifconfig` - Display/configure network interface

### 10. Application Programs

Implement these user-space network utilities:

**Programs to Implement**:
1. **ping** - ICMP echo client
   ```
   Usage: ping <ip_address>
   ```

2. **echo server** - TCP echo server (listens on port 7)
   ```c
   int main() {
     int sock = socket(AF_INET, SOCK_STREAM, 0);
     bind(sock, "0.0.0.0", 7);
     listen(sock, 5);
     while(1) {
       int client = accept(sock, ...);
       // Read and echo back
       while(read(client, buf, sizeof(buf)) > 0) {
         write(client, buf, n);
       }
       close(client);
     }
   }
   ```

3. **wget** - Simple HTTP client
   ```
   Usage: wget <url>
   Downloads file from URL
   ```

4. **netcat** - TCP/UDP client/server
   ```
   Usage: nc -l <port>  # Listen
          nc <ip> <port> # Connect
   ```

5. **httpd** - Simple HTTP server (optional, advanced)
   ```
   Serve static files on port 80
   ```

## Deliverables

- [ ] virtio-net driver functional
- [ ] Ethernet layer working
- [ ] ARP protocol implemented
- [ ] IP layer with routing
- [ ] ICMP (ping) working
- [ ] UDP sockets functional
- [ ] TCP connection establishment and data transfer
- [ ] TCP connection termination
- [ ] TCP retransmission
- [ ] Complete socket API
- [ ] User programs:
  - `ping` - Working ICMP client
  - `echo` - TCP echo server
  - `echoclient` - TCP echo client
  - `udpecho` - UDP echo server/client
  - `wget` - HTTP GET client
  - `ifconfig` - Network configuration
- [ ] Test suite:
  - Loopback tests (local communication)
  - External tests (ping external host)
  - Data integrity tests (large transfers)
  - Connection handling tests
  - Error condition tests
- [ ] Documentation:
  - Network stack architecture
  - Packet flow diagrams
  - API usage guide
  - Performance characteristics

## Success Criteria

1. **Ping**: Can ping external hosts (e.g., 8.8.8.8)
2. **TCP**: Can establish connection, transfer data, close cleanly
3. **UDP**: Can send/receive UDP packets
4. **Reliability**: TCP delivers data correctly even with packet loss
5. **Performance**: Reasonable throughput (>1 Mbps)
6. **Stability**: No crashes under load

## Testing

### QEMU Network Setup
```bash
# Enable user-mode networking (default)
make qemu

# Or with port forwarding
make qemu QEMUOPTS="-netdev user,id=net0,hostfwd=tcp::8080-:80"
```

### Ping Test
```bash
# In xv6
$ ping 10.0.2.2  # Ping host
$ ping 8.8.8.8   # Ping external
```

### TCP Test
```bash
# Terminal 1 (xv6)
$ echoserver

# Terminal 2 (host)
$ nc localhost 8080
hello
hello  # Echoed back
```

### UDP Test
```bash
# Send and receive UDP packets
$ udpecho 10.0.2.2 12345
```

### HTTP Test
```bash
# In xv6
$ wget http://example.com
```

## Key Concepts to Understand

Study before implementing:
- OSI and TCP/IP layered model
- Ethernet frames and addressing
- ARP protocol operation
- IP addressing, routing, and fragmentation
- TCP state machine and connection management
- TCP sliding window and flow control
- Socket programming interface
- Network byte order (big-endian)
- Checksum algorithms
- Interrupt-driven I/O for networking

## References

- MIT 6.S081: Lecture on Networking, Lab net
- "TCP/IP Illustrated, Volume 1" by Stevens
- RFC 791 (IP), RFC 792 (ICMP), RFC 793 (TCP), RFC 768 (UDP), RFC 826 (ARP)
- Linux kernel networking code (for reference)
- xv6 virtio_disk.c (similar structure for virtio-net)
- QEMU virtio-net device documentation

## Implementation Phases

**Phase 6.1** (2 weeks): Driver + Ethernet + ARP
**Phase 6.2** (1-2 weeks): IP + ICMP + ping
**Phase 6.3** (1-2 weeks): UDP + sockets
**Phase 6.4** (2-3 weeks): TCP + sockets
**Phase 6.5** (1 week): Applications + testing
