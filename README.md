# Unix process performance monitoring tool
procstat allows to monitor per process statistics including:

* CPU usage
* Scheduling
* Memory
* TCP/UDP rx/tx queues

You would normally call this script from a monitoring system that allows to collect metrics over time (e.g. Zabbix, collectd etc.)

See the usage section for more details.

## Usage
The PID of the process to monitor can be passed directly on the command line (--pid <pid>) or by reading a file containing the Process ID (--pid-file <file>)

The following metrics are currently supported:

| Metric | Description |
| ------------- | ------------- |
| cpu usage | Process CPU usage since it has started, calculated as 100 * ((total_time / tick rate) / elapsed time) |
| sched sum_exec_runtime | Accumulated amount of time spent on the CPU |
| sched nr_involuntary_switches | Total number of involuntary context switches |
| sched nr_voluntary_switches | Total number of voluntary context switches |
| sched nr_switches | Total number of context switches |
| sched utime | Amount of time that this process has been scheduled in user mode, measured in clock ticks |
| sched stime | Amount of time that this process has been scheduled in kernel mode, measured in clock ticks |
| sched nr_migrations | Total number of times the scheduler migrated the process from one CPU core to another |
| sched sleep_max | Maximum time the task spent sleeping voluntarily |
| sched block_max | Maximum involutary delay the task experienced (e.g. waiting for disk IO) |
| sched wait_max | Maximum delay that task saw from the point it got on the run queue to the point it actually started executing its first instruction |
| sched wait_sum | Accumulated amount of time the process had to wait from run queue to execution |
| sched wait_count | Total number of times the process had to wait from run queue to execution |
| sched wait_avg | Average waiting time (calculated as wait_sum/wait_count)
| sched iowait_sum | Accumulated amount of time spent waiting for IO |
| sched iowait_count | Total number of times the process had to wait for IO |
| sched iowait_avg | Average IO waiting time (calculated as iowait_sum/iowait_count) |
| sched nr_wakeups | Total number of times the process was woken up by the scheduler |
| mem minflt | The number of minor faults the process has made which have not required loading a memory page from disk |
| mem majflt | The number of major faults the process has made which have required loading a memory page from disk |
| mem vmpeak | Peak virtual memory size |
| mem vmsize | Virtual memory size in bytes |
| mem vmrss | Resident Set Size: number of pages the process has in real memory |
| net tcp recv_q | Sum of the outstanding data in the TCP receive queue (for all TCP sockets) in bytes |
| net tcp send_q | Sum of the outstanding data in the TCP send queue (for all TCP sockets) in bytes |
| net udp recv_q | Sum of the outstanding data in the UDP receive queue (for all UDP sockets) in bytes |
| net udp send_q | Sum of the outstanding data in the UDP send queue (for all UDP sockets) in bytes |

Example:

```
./procstat.sh --pid 31337 net tcp recv_q
```

## Contact
Matteo Cerutti - matteo.cerutti@hotmail.co.uk
