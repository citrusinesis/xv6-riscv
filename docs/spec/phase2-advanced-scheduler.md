# Phase 2: Advanced Scheduler Implementation

**Duration**: 4-5 weeks
**Prerequisites**: Phase 1 complete (HAL and modularization in place)
**Next Phase**: Phase 3 (Memory Management Enhancement)

## Overview

Phase 2 builds upon the scheduler interface established in Phase 1 to implement multiple sophisticated scheduling algorithms. This phase focuses on understanding different scheduling policies, their trade-offs, and performance characteristics.

**Core Objective**: Implement three distinct scheduling algorithms (Priority, MLFQ, CFS) as pluggable modules, enable runtime selection, and establish comprehensive benchmarking to validate scheduler characteristics.

## Objectives

### Primary Goals
1. Implement priority-based scheduler with starvation prevention
2. Implement Multi-Level Feedback Queue (MLFQ) scheduler
3. Implement Completely Fair Scheduler (CFS) inspired by Linux
4. Enable scheduler selection via boot parameter or compile-time flag
5. Establish benchmarking infrastructure for scheduler evaluation
6. Measure and validate fairness, latency, and throughput characteristics

### Learning Outcomes
- Deep understanding of scheduling algorithm trade-offs
- Experience with priority management and inversion handling
- Skills in performance measurement and analysis
- Understanding of fairness metrics and evaluation methods

## Functional Requirements

### FR1: Pluggable Scheduler Architecture

**Requirement**: Multiple scheduling algorithms must coexist and be selectable without kernel recompilation.

**Scheduler Interface** (from Phase 1):
The scheduler interface should provide these operations:
- Initialization
- Process enqueueing (when process becomes RUNNABLE)
- Process dequeueing (select next process to run)
- Tick handling (timer interrupt callback)
- Yield handling (voluntary CPU relinquishment)
- Statistics gathering

**Selection Mechanism**:
- Boot parameter: `scheduler=rr|priority|mlfq|cfs`
- Compile-time default if boot parameter not specified
- All scheduler implementations linked into kernel

**Success Criteria**:
- Switching schedulers requires only boot parameter change
- No code changes needed to add new scheduler
- All schedulers use same process structure
- Scheduler-specific data isolated in separate structures

### FR2: Priority-Based Scheduler

**Requirement**: Implement fixed-priority preemptive scheduler with priority inversion handling.

**Priority Management**:
- Priority range: 0 (highest) to 31 (lowest)
- Default priority: 16
- Static priority: base priority set by user
- Dynamic priority: adjusted by system to prevent starvation
- Support UNIX nice values (-20 to +19)

**Priority to Nice Mapping**:
- Nice value -20 maps to priority 0 (highest)
- Nice value 0 maps to priority 16 (default)
- Nice value +19 maps to priority 31 (lowest)
- Formula: `priority = 16 + (nice * 15 / 19)`

**Scheduling Policy**:
- Always run highest priority RUNNABLE process
- Round-robin among equal priority processes
- Preempt lower priority on higher priority wakeup
- Time quantum: configurable, default 10 ticks

**Starvation Prevention**:
- Priority aging: boost priority every N ticks without CPU time
- Age threshold: configurable, default 100 ticks
- Boost amount: +1 priority level per aging event
- Reset to static priority when process runs

**Priority Inversion Handling**:
- Basic priority inheritance: holding a lock temporarily inherits highest priority of waiters
- Ceiling priority: lock has maximum priority of all potential holders
- Deadlock avoidance through priority ordering (optional)

**System Calls Required**:
- `setpriority(pid, priority)` - Set process priority
- `getpriority(pid)` - Get process priority
- `nice(increment)` - Adjust nice value (UNIX compatibility)

**Success Criteria**:
- Higher priority processes always run before lower priority
- No starvation under normal load with aging enabled
- Priority inversion bounded by inheritance mechanism
- Measurable impact of nice values on CPU allocation

### FR3: Multi-Level Feedback Queue (MLFQ)

**Requirement**: Implement adaptive scheduler that learns process behavior and adjusts priority dynamically.

**Queue Structure**:
- Number of queues: 4 (configurable)
- Queue 0: Highest priority, shortest quantum
- Queue 3: Lowest priority, longest quantum
- Quantum per queue: exponentially increasing
  - Queue 0: 4 ticks
  - Queue 1: 8 ticks
  - Queue 2: 16 ticks
  - Queue 3: 32 ticks

**Scheduling Rules**:
- Rule 1: Schedule from highest non-empty queue
- Rule 2: Round-robin within queue
- Rule 3: New processes start at Queue 0
- Rule 4: Process demoted when quantum expires
- Rule 5: Process promoted when it blocks (I/O or sleep)
- Rule 6: Priority boost all processes to Queue 0 every S ticks (default: 100)

**Anti-Gaming Mechanisms**:
- Track total time at each level, not just current run
- Demotion based on cumulative time in quantum periods
- Prevent gaming by yielding just before quantum expires
- Account I/O time separately from CPU time

**Process Behavior Learning**:
- I/O-bound processes: stay in high queues (short quantum, quick response)
- CPU-bound processes: drift to low queues (long quantum, throughput)
- Interactive processes: benefit from high priority on wakeup
- Batch processes: settle in lowest queue with long quantum

**Statistics Tracking**:
- Time spent at each queue level
- Number of promotions/demotions
- Quantum expirations vs voluntary yields
- Total CPU time vs total elapsed time

**System Calls Required**:
- `getschedinfo(pid, struct schedinfo*)` - Get queue level and statistics

**Success Criteria**:
- Interactive workloads get better response time than CPU-bound
- CPU-bound processes don't starve (priority boost)
- Gaming prevention: yielding doesn't keep process in high queue
- Measurable separation of I/O-bound vs CPU-bound processes

### FR4: Completely Fair Scheduler (CFS)

**Requirement**: Implement scheduler that provides proportional CPU time based on process weights.

**Core Concepts**:
- Virtual runtime (vruntime): measure of CPU time adjusted by weight
- Red-black tree: O(log n) data structure for process selection
- Weight: scheduling importance derived from nice value
- Fairness goal: all processes make equal progress in virtual time

**Virtual Runtime Calculation**:
- `vruntime += delta_time * NICE_0_WEIGHT / weight`
- Where NICE_0_WEIGHT = 1024 (weight of nice 0 process)
- Lower weight → vruntime increases faster → runs less
- Higher weight → vruntime increases slower → runs more

**Weight Table** (based on Linux):
```
Nice value  → Weight
-20         → 88761  (86.75x more CPU than nice 0)
-19         → 71755
...
-10         → 9548
...
0           → 1024   (baseline)
...
+10         → 110
...
+19         → 15     (1/68th CPU of nice 0)
```

**Scheduling Policy**:
- Always select process with minimum vruntime
- Target latency: time period for all processes to run once (default: 20ms)
- Minimum granularity: minimum time slice per process (default: 4ms)
- Time slice = (target_latency / nr_running) * (weight / total_weight)
- Adjust target_latency if needed to maintain minimum granularity

**Sleeper Fairness**:
- Problem: sleeping process has old (small) vruntime, gets priority burst on wakeup
- Solution: adjust woken process vruntime to min_vruntime - threshold
- Threshold: small value to give slight wakeup bonus (responsiveness)
- Balance: enough bonus for interactivity, not enough for gaming

**Red-Black Tree Operations**:
- Insert: O(log n) - add process by vruntime key
- Remove: O(log n) - remove process when it blocks
- Find minimum: O(1) - cached leftmost node
- Rebalancing: maintain red-black tree invariants

**Load Balancing** (foundation for SMP):
- Per-CPU min_vruntime tracking
- Process migration considerations
- Load balancing not required in Phase 2 (single runqueue acceptable)

**System Calls Required**:
- `nice(increment)` - Adjust weight via nice value
- `getschedstat(pid, struct schedstat*)` - Get vruntime and weight

**Success Criteria**:
- CPU time proportional to weights over time period
- Nice -10 process gets ~9.3x CPU of nice 0 process
- Nice +10 process gets ~1/10th CPU of nice 0 process
- Fairness measured by Gini coefficient or standard deviation
- Interactive processes benefit from sleeper fairness

### FR5: Performance Measurement and Benchmarking

**Requirement**: Comprehensive benchmarking infrastructure to validate scheduler characteristics.

**Benchmark Workloads**:

**CPU-Bound Workload**:
- Continuous computation, no I/O
- Measures: throughput, fairness among CPU-bound processes
- Example: prime number calculation, matrix multiplication

**I/O-Bound Workload**:
- Frequent sleep/wake cycles simulating I/O
- Measures: response time, wakeup latency
- Example: sleep N ticks, do small work, repeat

**Interactive Workload**:
- Variable work periods with yields
- Measures: response time, latency distribution
- Example: simulated user input (small work, yield)

**Mixed Workload**:
- Multiple processes with different characteristics
- Measures: fairness across different workload types
- Example: run CPU-bound, I/O-bound, interactive simultaneously

**Metrics to Measure**:

**Latency Metrics**:
- Response time: time from RUNNABLE to RUNNING (avg, p50, p95, p99)
- Turnaround time: time from creation to completion
- Wakeup latency: time from wakeup to first CPU time

**Throughput Metrics**:
- Processes completed per second
- CPU utilization: percentage of time CPU is busy
- Context switches per second

**Fairness Metrics**:
- CPU time distribution: standard deviation across processes
- Gini coefficient: inequality measure (0 = perfect equality, 1 = total inequality)
- Expected vs actual CPU share for different nice values

**Scheduler-Specific Metrics**:
- Priority: priority inversion duration, aging frequency
- MLFQ: queue distribution, promotion/demotion rates
- CFS: vruntime spread, red-black tree depth

**Benchmark Tool Requirements**:
- User-space programs for each workload type
- Kernel instrumentation for statistics collection
- Post-processing scripts for metric calculation
- Visualization of results (optional, can be external)

**Success Criteria**:
- Benchmarks run deterministically (reproducible results)
- Automated execution and reporting
- Clear performance differences between schedulers
- Documentation of scheduler trade-offs based on measurements

### FR6: Statistics and Observability

**Requirement**: Expose scheduler behavior for debugging and analysis.

**Per-Process Statistics**:
- Total CPU time (user + system)
- Number of context switches
- Time spent in each state (RUNNABLE, RUNNING, SLEEPING)
- Scheduler-specific: priority/queue level, vruntime, weights
- Voluntary vs involuntary context switches

**Per-Scheduler Statistics**:
- Total context switches
- Average runqueue length
- Scheduler overhead (time in scheduler code)
- Load balancing operations (if implemented)

**System Calls**:
- `getschedstat(pid, struct schedstat*)` - Get per-process statistics
- `getsystemstats(struct systemstat*)` - Get system-wide statistics

**Debugging Interface**:
- Proc filesystem (optional): `/proc/<pid>/sched`
- Print scheduler state on demand (debug build)
- Trace points for scheduler events (optional)

**Success Criteria**:
- Statistics accurate and useful for debugging
- Minimal overhead from statistics collection
- Easy to verify scheduler behavior matches specification

## Non-Functional Requirements

### NFR1: Performance

**Latency**:
- Scheduling decision time: O(log n) or better for CFS
- Context switch overhead: unchanged from Phase 1
- Scheduler overhead: <5% of total CPU time

**Scalability**:
- Support up to 64 processes (NPROC constant)
- Red-black tree operations must be O(log n)
- Runqueue operations constant or logarithmic time

### NFR2: Correctness

**Invariants**:
- Exactly one process RUNNING per CPU
- All RUNNABLE processes in exactly one runqueue
- No deadlocks in scheduler code
- No priority inversion unbounded in time

**Testing**:
- All original xv6 tests pass with each scheduler
- Scheduler-specific correctness tests
- Stress tests (many processes, rapid fork/exit)

### NFR3: Maintainability

**Code Organization**:
- Each scheduler in separate file
- Common utilities shared across schedulers
- Clear separation between scheduler and process management
- Documented algorithms and design decisions

**Extensibility**:
- Easy to add new scheduler implementation
- Scheduler parameters configurable (quantum, weights, etc.)
- Statistics framework extensible

### NFR4: Educational Value

**Understanding**:
- Clear implementation of classic algorithms
- Comments explaining key decisions
- Traceability to textbook descriptions
- Performance results match theoretical predictions

## Design Constraints

### DC1: Single Runqueue (Simplification)

For Phase 2, multi-core load balancing is NOT required:
- All CPUs share single runqueue with locking
- Foundation for per-CPU runqueues in future (Phase 10 optimization)
- Focus on algorithm correctness, not SMP scalability

**Rationale**: Load balancing is complex and distracts from learning scheduler algorithms. Can be added later if desired.

### DC2: No Preemption Points Modification

**Constraint**: Do not change when preemption can occur.
- Maintain existing timer interrupt preemption
- Do not add preemption points in kernel code
- Scheduler only invoked at existing points: timer, yield, sleep, exit

**Rationale**: Adding preemption points throughout kernel requires extensive locking review. Out of scope for Phase 2.

### DC3: Fixed Quantum for Priority and MLFQ

**Constraint**: Time quantum defined at compile time or boot, not runtime adjustable per-process.

**Rationale**: Dynamic quantum adjustment adds complexity without significant educational benefit.

### DC4: Simplified Priority Inheritance

**Constraint**: Basic priority inheritance for spinlocks only, not full priority ceiling protocol.

**Rationale**: Full priority ceiling requires extensive modification of sleep locks and semaphores. Basic inheritance sufficient to demonstrate concept.

### DC5: No Real-Time Guarantees

**Constraint**: None of these schedulers provide hard real-time guarantees.

**Rationale**: Real-time scheduling requires different kernel architecture (preemptible kernel, bounded interrupt latency). xv6 is not a real-time OS.

## Testing Requirements

### Test Suite

**Functional Tests**:

**Priority Scheduler Tests**:
- `test_priority_order`: Verify higher priority runs first
- `test_priority_aging`: Verify starvation prevention
- `test_priority_inheritance`: Verify priority inversion handling
- `test_nice_values`: Verify nice to priority mapping
- `test_priority_preemption`: Higher priority preempts lower

**MLFQ Tests**:
- `test_mlfq_demotion`: CPU-bound process demoted to lower queues
- `test_mlfq_promotion`: I/O-bound process promoted on sleep
- `test_mlfq_boost`: Priority boost prevents starvation
- `test_mlfq_anti_gaming`: Yielding doesn't prevent demotion
- `test_mlfq_queue_distribution`: Processes settle in expected queues

**CFS Tests**:
- `test_cfs_fairness`: CPU time proportional to weights
- `test_cfs_nice_weights`: Verify weight table and calculations
- `test_cfs_sleeper_fairness`: Waking process gets appropriate vruntime
- `test_cfs_rbtree`: Red-black tree maintains correct order
- `test_cfs_proportional`: Nice -10 gets ~10x CPU of nice +10

**Stress Tests**:
- `test_many_processes`: 50+ processes, all schedulers
- `test_rapid_fork_exit`: Fast creation/destruction
- `test_long_run`: Hours of continuous operation
- `test_all_cpus`: Multi-CPU stress (4-8 CPUs)

**Benchmark Tests**:
- Run all benchmark workloads with all schedulers
- Verify results match expected characteristics
- Regression tests: performance not worse than round-robin baseline

### Success Criteria

**Functional Correctness**:
- [ ] All three schedulers implemented
- [ ] All functional tests pass for each scheduler
- [ ] No crashes or hangs in stress tests
- [ ] Original xv6 usertests pass with all schedulers

**Performance Validation**:
- [ ] Priority: measurable priority ordering in CPU allocation
- [ ] MLFQ: I/O-bound processes get better response time than round-robin
- [ ] CFS: CPU time within 5% of expected based on weights
- [ ] Context switch overhead <5% increase from baseline

**Fairness Validation**:
- [ ] CFS Gini coefficient <0.1 for equal-weight processes
- [ ] MLFQ prevents starvation (all processes make progress)
- [ ] Priority aging prevents starvation in priority scheduler

## Implementation Guidance

### Phase 2 Implementation is NOT Provided

This specification describes WHAT to build, not HOW:

**What You Should Figure Out**:
- How to structure the red-black tree
- How to calculate vruntime efficiently
- How to implement priority inheritance
- How to track queue levels in MLFQ
- How to handle edge cases (process exit, sleep, fork)

**What You Should Research**:
- Linux CFS implementation and documentation
- Operating Systems textbooks (OSTEP, Modern Operating Systems)
- Academic papers on MLFQ and fair scheduling
- Red-black tree algorithms (CLRS, Wikipedia)

**What You Should Design**:
- Data structure layout for each scheduler
- Algorithms for enqueue/dequeue operations
- Testing strategy and workload design
- Benchmark interpretation methodology

### Recommended Implementation Order

1. **Week 1**: Implement priority scheduler (simplest)
   - Extend process structure with priority fields
   - Implement priority-based runqueue (array of lists)
   - Add system calls
   - Test and benchmark

2. **Week 2**: Implement MLFQ
   - Add queue level tracking to process structure
   - Implement multiple runqueues
   - Implement promotion/demotion logic
   - Implement priority boost
   - Test and benchmark

3. **Week 3**: Implement red-black tree
   - Study red-black tree algorithm
   - Implement insert/delete/find operations
   - Write unit tests for tree operations
   - Verify correctness with assertions

4. **Week 4**: Implement CFS
   - Add vruntime to process structure
   - Implement vruntime calculation
   - Integrate red-black tree
   - Implement sleeper fairness
   - Test and benchmark

5. **Week 5**: Benchmarking and analysis
   - Write comprehensive benchmark suite
   - Run all benchmarks with all schedulers
   - Analyze results
   - Document findings and trade-offs

### Common Pitfalls

**Pitfall 1: Incorrect vruntime overflow handling**
- vruntime is 64-bit but can overflow
- Use signed comparison for vruntime (wrapping arithmetic)

**Pitfall 2: Priority inversion without bounded latency**
- Must implement some form of inheritance or ceiling
- Document maximum inversion duration

**Pitfall 3: MLFQ gaming through yielding**
- Must track cumulative time, not reset on yield
- Prevent gaming while allowing legitimate I/O behavior

**Pitfall 4: Red-black tree invariant violation**
- Tree must maintain red-black properties after insert/delete
- Use assertions to verify invariants

**Pitfall 5: Fairness over too-short time windows**
- CFS provides fairness over target latency period, not instantly
- Don't expect perfect fairness in milliseconds

## References

### Scheduling Algorithms

**Classic Papers**:
- "Lottery Scheduling: Flexible Proportional-Share Resource Management" (Waldspurger & Weihl, 1994)
- "Stride Scheduling: Deterministic Proportional-Share Resource Management" (Waldspurger & Weihl, 1995)
- "A Proportional Share Resource Allocation Algorithm for Real-Time, Time-Shared Systems" (Stoica et al., 1996)

**Linux CFS**:
- "CFS Scheduler" - Linux kernel documentation
- "Inside the Linux 2.6 Completely Fair Scheduler" (Wong et al., 2008)
- Linux kernel source: `kernel/sched/fair.c`

**Textbooks**:
- "Operating Systems: Three Easy Pieces" - Chapters 7, 8, 9 (Scheduling)
- "Modern Operating Systems" (Tanenbaum) - Chapter 2 (Processes and Threads)
- "Operating System Concepts" (Silberschatz) - Chapter 5 (CPU Scheduling)

**MIT 6.S081**:
- Lecture on Scheduling
- Lab: Threads (context switching)

### Red-Black Trees

**Algorithm References**:
- "Introduction to Algorithms" (CLRS) - Chapter 13 (Red-Black Trees)
- Wikipedia: Red-Black Tree (excellent visualizations)
- Linux kernel `lib/rbtree.c` - production implementation

### xv6 Scheduler

**Study Files**:
- `kernel/proc.c` - Current round-robin scheduler
- `kernel/proc.h` - Process structure
- `kernel/trap.c` - Timer interrupt and yield
- xv6 Book Chapter 7 - Scheduling

### Benchmarking

**Metrics References**:
- "The Gini coefficient: A new way to express selectivity of kinase inhibitors against a family of kinases" (Graczyk, 2007) - general Gini coefficient
- Linux perf tools documentation
- "Systems Performance: Enterprise and the Cloud" (Gregg, 2013)

## Appendix: Data Structure Examples

**Note**: These are EXAMPLES for understanding, not complete implementations.

### Example: Process Structure Additions

```c
// In kernel/include/proc.h

struct proc {
  // ... existing fields ...

  // Scheduler-specific data (only one active based on selected scheduler)
  union {
    struct {
      int priority;           // Current dynamic priority (0-31)
      int static_priority;    // Base priority
      int nice;              // UNIX nice value (-20 to +19)
      uint64 aging_ticks;    // Ticks without CPU for aging
    } priority_sched;

    struct {
      int queue_level;       // Current queue (0-3)
      uint64 time_in_queue;  // Time spent at current level
      uint64 quantum_used;   // Quantum used at this level
    } mlfq_sched;

    struct {
      uint64 vruntime;       // Virtual runtime
      uint64 exec_start;     // When process last started running
      int weight;            // Scheduling weight
      struct rb_node rb_node; // Red-black tree node
    } cfs_sched;
  } sched_data;
};
```

### Example: Scheduler Operations Structure

```c
// In kernel/core/proc/include/sched.h

typedef struct {
  const char *name;

  void (*init)(void);
  void (*enqueue)(struct proc *p);
  struct proc *(*dequeue)(void);
  void (*tick)(struct proc *p);
  void (*yield)(struct proc *p);
  void (*fork)(struct proc *parent, struct proc *child);
  void (*exit)(struct proc *p);

  // Statistics
  void (*get_stats)(struct proc *p, struct schedstat *stats);
} SchedOps;

extern SchedOps *g_sched_ops;  // Current scheduler
```

### Example: Red-Black Tree Node

```c
// In kernel/include/rbtree.h

enum rb_color {
  RB_RED,
  RB_BLACK
};

struct rb_node {
  struct rb_node *parent;
  struct rb_node *left;
  struct rb_node *right;
  enum rb_color color;
  uint64 key;  // vruntime for CFS
};

struct rb_root {
  struct rb_node *root;
  struct rb_node *leftmost;  // Cached minimum
};
```

## Appendix: Benchmark Output Example

**Example Output** (illustrative, not prescriptive):

```
Scheduler Benchmark Results
============================

Workload: CPU-bound (4 processes, 10 seconds)
Scheduler: CFS, Nice values: 0, 0, -10, +10

Process  Nice  CPU Time (ms)  Expected %  Actual %  Deviation
------------------------------------------------------------
1        0     3200           25.0%       25.6%     +0.6%
2        0     3180           25.0%       25.4%     +0.4%
3        -10   5950           46.7%       47.6%     +0.9%
4        +10   195            3.3%        1.6%      -1.7%

Metrics:
  Total CPU time: 12525 ms
  Context switches: 1284
  Gini coefficient: 0.15
  Scheduling overhead: 4.2%

Workload: Interactive (10 processes, 5 seconds)
Scheduler: MLFQ

Queue Distribution:
  Queue 0: 6 processes (avg 125ms response time)
  Queue 1: 3 processes (avg 240ms response time)
  Queue 2: 1 process (avg 510ms response time)
  Queue 3: 0 processes

Response time p50: 140ms, p95: 480ms, p99: 620ms
```

---

**Phase Status**: Ready for Implementation
**Estimated Effort**: 80-120 hours over 4-5 weeks
**Prerequisites**: Phase 1 complete (scheduler interface exists)
**Outputs**: 3 schedulers, benchmark suite, performance analysis
**Next Phase**: [Phase 3: Memory Management Enhancement](phase3-memory-management.md)
