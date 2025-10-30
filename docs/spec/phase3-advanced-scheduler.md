# Phase 3: Advanced Scheduler Implementation

**Duration**: 4-5 weeks
**Prerequisites**: Phase 1 and 2

## Objectives

Implement multiple scheduling algorithms and compare their performance.

## Schedulers to Implement

### 1. Priority Scheduler

**Features**:
- Static priority scheduling (0 = highest, 31 = lowest)
- Preemptive scheduling based on priority
- Priority inheritance to prevent priority inversion

**System Calls**:
- `int setpriority(int pid, int priority)` - Set process priority
- `int getpriority(int pid)` - Get process priority
- `int nice(int increment)` - Adjust priority using UNIX nice values

**Requirements**:
- Add to `struct proc`:
  - `int priority` - Current priority (0-31)
  - `int static_priority` - Base priority
  - `int nice` - Nice value (-20 to +19)
- Always run highest priority RUNNABLE process
- Implement priority inheritance for locks
- Support priority aging to prevent starvation

**Nice to Priority Mapping**:
- Nice -20 → Priority 0 (highest)
- Nice 0 → Priority 20 (default)
- Nice +19 → Priority 39 (lowest)

### 2. Multi-Level Feedback Queue (MLFQ)

**Features**:
- 4 priority queues with different time quantums
- Processes move between queues based on behavior
- Interactive processes stay in high-priority queues
- CPU-bound processes drift to low-priority queues

**Requirements**:
- Define 4 queues with exponentially increasing quantums:
  - Queue 0: 4 ticks (highest priority)
  - Queue 1: 8 ticks
  - Queue 2: 16 ticks
  - Queue 3: 32 ticks (lowest priority)
- Add to `struct proc`:
  - `int queue_level` - Current queue (0-3)
  - `int time_in_queue` - Time spent at current level
  - `uint64 total_time_at_level` - Prevent gaming
- Scheduler picks from highest non-empty queue
- Move to lower queue when quantum expires
- Move to higher queue on I/O (wakeup from sleep)
- Priority boost every 100 ticks (prevent starvation)
- Anti-gaming: track total time at level, not just current run

**System Call**:
- `int getschedinfo(int pid, struct schedinfo *info)` - Get queue level and stats

### 3. Completely Fair Scheduler (CFS)

**Features**:
- Virtual runtime (vruntime) based scheduling
- Weight-based time allocation
- Red-black tree for O(log n) process selection

**Requirements**:
- Add to `struct proc`:
  - `uint64 vruntime` - Virtual runtime
  - `uint64 exec_start` - Execution start time
  - `int weight` - Scheduling weight from nice value
  - `struct rb_node rb_node` - For red-black tree
- Implement red-black tree in `kernel/rbtree.c`
- vruntime calculation: `delta_vruntime = delta_time * 1024 / weight`
- Always schedule process with lowest vruntime
- Sleeper fairness: adjust vruntime on wakeup to min_vruntime

**Weight Table** (based on Linux):
```c
// Index by (nice + 20), range 0-39
const int prio_to_weight[40] = {
  88761, 71755, 56483, 46273, 36291,  // nice -20 to -16
  29154, 23254, 18705, 14949, 11916,  // nice -15 to -11
  9548, 7620, 6100, 4904, 3906,       // nice -10 to -6
  3121, 2501, 1991, 1586, 1277,       // nice -5 to -1
  1024, 820, 655, 526, 423,           // nice 0 to 4
  335, 272, 215, 172, 137,            // nice 5 to 9
  110, 87, 70, 56, 45,                // nice 10 to 14
  36, 29, 23, 18, 15                  // nice 15 to 19
};
```

**Red-Black Tree Operations**:
- `rb_insert()` - Insert process by vruntime
- `rb_delete()` - Remove process
- `rb_minimum()` - Get leftmost (minimum vruntime)
- `rb_rotate_left()`, `rb_rotate_right()` - Balancing

### 4. Multi-Core Support

**Features**:
- Per-CPU run queues
- Load balancing across CPUs
- CPU affinity support

**System Calls**:
- `int sched_setaffinity(int pid, uint64 cpumask)` - Set CPU affinity
- `int sched_getaffinity(int pid)` - Get CPU affinity

**Requirements**:
- Add to `struct cpu`:
  - Per-CPU run queue (separate for each scheduler type)
  - `int nr_running` - Number of processes on this CPU
  - `uint64 min_vruntime` - For CFS
- Add to `struct proc`:
  - `uint64 cpu_affinity` - Bitmask of allowed CPUs
  - `int last_cpu` - Last CPU where process ran
- Implement load balancing:
  - Trigger every 100 ticks
  - Move processes from overloaded to underloaded CPUs
  - Respect CPU affinity constraints
- Process migration respects affinity mask

## Scheduler Selection

**Compile-Time Configuration**:
```c
// kernel/param.h
#define SCHED_RR    0  // Round-robin (default)
#define SCHED_PRIO  1  // Priority-based
#define SCHED_MLFQ  2  // Multi-level feedback queue
#define SCHED_CFS   3  // Completely fair scheduler

#define SCHEDULER SCHED_CFS  // Choose scheduler
```

**Or Runtime Selection** (Optional):
- `int setsched(int policy)` - Switch scheduler
- Requires migrating all processes to new scheduler's data structures

## Deliverables

- [ ] Four schedulers implemented:
  - Priority scheduler with nice values
  - MLFQ with 4 queues and anti-gaming
  - CFS with red-black tree
  - Multi-core support for all schedulers
- [ ] CPU affinity system calls
- [ ] Scheduler statistics system call
- [ ] Benchmark suite:
  - `cpubench` - CPU-intensive workload
  - `iobench` - I/O-intensive workload
  - `mixbench` - Mixed workload
  - `interactivebench` - Simulated interactive tasks
- [ ] Performance comparison report:
  - Response time (time from runnable to running)
  - Turnaround time (creation to completion)
  - Fairness metric (standard deviation of CPU time)
  - Context switch overhead
- [ ] Documentation:
  - Each scheduler's design and trade-offs
  - Performance analysis
  - Tuning recommendations

## Success Criteria

1. **Correctness**: All schedulers select processes correctly
2. **No Starvation**: No process starves under normal conditions
3. **Performance**:
   - MLFQ: Better response time for I/O-bound processes
   - CFS: Fair CPU distribution based on weights
   - Priority: Strict priority enforcement
4. **Scalability**: Multi-core support scales with CPU count
5. **Compatibility**: All existing tests pass with each scheduler

## Benchmark Workloads

### CPU-Bound
```c
// Compute-intensive, minimal I/O
while(1) {
  for(int i = 0; i < 1000000; i++)
    sum += i * i;
}
```

### I/O-Bound
```c
// Frequent sleep/wake cycles
while(1) {
  sleep(1);  // Simulates I/O wait
  // Small amount of work
}
```

### Interactive
```c
// Variable work, frequent yielding
while(1) {
  work_small_amount();
  yield();  // Simulates user input wait
}
```

### Mixed
- Run multiple processes with different behaviors
- Measure fairness and response times

## Performance Metrics

For each scheduler, measure:
1. **Average response time** - RUNNABLE → RUNNING
2. **Average turnaround time** - Creation → completion
3. **CPU utilization** - % time CPU is busy
4. **Throughput** - Processes completed per second
5. **Fairness** - Standard deviation of CPU time allocation
6. **Context switch rate** - Switches per second

Compare across:
- Different workload types
- Different nice values (for CFS/Priority)
- Different CPU counts (1, 2, 4, 8 CPUs)

## Key Concepts to Understand

Study before implementing:
- Scheduling algorithms: FCFS, SJF, RR, Priority, MLFQ, CFS
- Priority inversion and priority inheritance
- Starvation and aging
- Red-black tree properties and operations
- Load balancing strategies
- Cache affinity and CPU migration costs

## References

- MIT 6.S081: Lecture on Scheduling, Lab threads
- "Operating Systems: Three Easy Pieces" - Scheduling chapters
- Linux CFS documentation
- "Inside the Linux Scheduler" by Gorman
- xv6 Book: Chapter 7 (Scheduling)
- Source files: `kernel/proc.c`, `kernel/swtch.S`
