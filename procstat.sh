#!/bin/bash
#
# procstat.sh
#
# Author: Matteo Cerutti <matteo.cerutti@hotmail.co.uk>
#

function showhelp() {
  echo -n "Usage: `basename $0` <opts> "
  case $1 in
    "cpu")
      echo "$1 <usage>"
      ;;

    "sched")
      echo "$1 <sum_exec_runtime|avg_exec_runtime|nr_involuntary_switches|nr_voluntary_switches|nr_switches|utime|stime|nr_migrations|sleep_max|block_max|wait_max|wait_sum|wait_count|wait_avg|iowait_sum|iowait_count|iowait_avg|nr_wakeups>"
      ;;

    "mem")
      echo "$1 <minflt|majflt|vmpeak|vmsize|vmrss>"
      ;;

    "net")
      case $2 in
        "tcp" | "udp")
          echo "$1 $2 <recv_q|send_q>"
          ;;

        *)
          echo "$1 <tcp|udp>"
      esac
      ;;

    *)
      echo "<sched|mem|net>"
  esac

  echo
  echo "Options:"
  echo "  -p/--pid <N>               Process ID"
  echo "  -f/--pid-file <file>>      File containing Process ID"
  echo

  exit 1
}

while :
do
  case $1 in
    -h | --help | -\?)
      showhelp
      ;;

    -p | --pid)
      pid=$2
      shift 2
      ;;

    -f | --pid-file)
      pid_file=$2
      shift 2
      ;;

    --)
      shift
      break
      ;;

    -*)
      echo "Unknown option '$1'"
      showhelp
      ;;

    *)
      break
  esac
done

[[ -z "$pid" && -z "$pid_file" ]] || [[ -n "$pid" && -n "$pid_file" ]] && { echo "Error: must specify either a PID (--pid) or a file (--pid-file)"; showhelp; }

test -n "$pid_file" && pid=$(cat $pid_file 2>/dev/null)

[[ -z "$pid" || ! -d /proc/$pid ]] && { echo "PID not found" >&2; exit 1; }

case $1 in
  "cpu")
    case $2 in
       "usage")
          stime=$(cat /proc/$pid/stat 2>/dev/null | cut -d ' ' -f 14)
          utime=$(cat /proc/$pid/stat 2>/dev/null | cut -d ' ' -f 15)
          cutime=$(cat /proc/$pid/stat 2>/dev/null | cut -d ' ' -f 16)
          cstime=$(cat /proc/$pid/stat 2>/dev/null | cut -d ' ' -f 17)
          start_time=$(cat /proc/$pid/stat 2>/dev/null | cut -d ' ' -f 22)
          uptime=$(cat /proc/uptime | cut -d ' ' -f 1)
          hz=$(getconf CLK_TCK)

          total_time=$((stime+utime+cutime+cstime))
          elapsed_time=$(echo "scale=2;$uptime - ($start_time / $hz)" | bc)
          cpu_usage=$(echo "scale=2;100 * (($total_time / $hz) / $elapsed_time)" | bc)

          echo $cpu_usage
          ;;

        *)
          showhelp $1
    esac
    ;;

  "sched")
    case $2 in
      "sum_exec_runtime" | "nr_involuntary_switches" | "nr_voluntary_switches" | "nr_switches" | "nr_migrations" | "sleep_max" | "block_max" | "wait_max" | "wait_sum" | "wait_count" | "iowait_sum" | "iowait_count" | "nr_wakeups")
        cat /proc/$pid/sched 2>/dev/null | sed -r -e 's/\s+//g' | sed -r  -e 's/^se\.(statistics\.)?//' | egrep "^$2:" | cut -d ':' -f 2
        ;;

      "avg_exec_runtime")
        cat /proc/$pid/sched 2>/dev/null | sed -r -e 's/\s+//g' | egrep '^se\.statistics\.(sum_exec_runtime|nr_switches)' | cut -d ':' -f 2 | xargs | tr ' ' '/' | bc
        ;;

      "wait_avg")
        wait_count=$(cat /proc/$pid/sched 2>/dev/null | egrep '^se\.statistics\.wait_count' | cut -d ':' -f 2)
        if [ $wait_count -gt 0 ]; then
          cat /proc/$pid/sched 2>/dev/null | sed -r -e 's/\s+//g' | egrep '^se\.statistics\.(wait_sum|wait_count)' | cut -d ':' -f 2 | xargs | tr ' ' '/' | bc
        else
          echo 0
        fi
        ;;

      "iowait_avg")
        iowait_count=$(cat /proc/$pid/sched 2>/dev/null | egrep '^se\.statistics\.iowait_count' | cut -d ':' -f 2)
        if [ $iowait_count -gt 0 ]; then
          cat /proc/$pid/sched 2>/dev/null | sed -r -e 's/\s+//g' | egrep '^se\.statistics\.(iowait_sum|iowait_count)' | cut -d ':' -f 2 | xargs | tr ' ' '/' | bc
        else
          echo 0
        fi
        ;;

      *)
        showhelp $1
    esac
    ;;

  "mem")
    case $2 in
      "minflt")
        cat /proc/$pid/stat 2>/dev/null | cut -d ' ' -f 10
        ;;

      "majflt")
        cat /proc/$pid/stat 2>/dev/null | cut -d ' ' -f 12
        ;;

      # expressed in kB
      "vmpeak" | "vmsize" | "vmrss")
        val=$(cat /proc/$pid/status 2>/dev/null | sed -r -e 's/\s+//g' | egrep -i "^$2:" | cut -d ':' -f 2 | sed -e 's/kB//')
        test -n "$val" && echo $(echo "$val * 1000" | bc)
        ;;

      *)
        showhelp $1
    esac
    ;;

  "net")
    case $2 in
      "tcp")
        # find sockets first
        sockets=$(find /proc/$pid/fd/* -maxdepth 0 -type l -exec readlink {} \; 2>/dev/null | grep 'socket' | cut -d ':' -f 2 | sed -r -e 's/\[([0-9]+)\]/\1/' | xargs)

        case $3 in
          "recv_q")
            rx_queue_sum=0
            if [ -n "$sockets" ]; then
              sockets="^$(echo "$sockets" | tr ' ' '|')$"

              while read rx_queue_hex; do
                # convert hex to dec
                rx_queue_dec=$((16#$rx_queue_hex))
                rx_queue_sum=$((rx_queue_sum+rx_queue_dec))
              done <<EOF
$(cat /proc/net/tcp | awk -v sockets=$sockets '$10 ~ sockets { print $5 }' | cut -d ':' -f 2)
EOF
            fi

            echo $rx_queue_sum

            # old way, too heavy
            #ss --tcp --numeric --process | grep 'ESTAB' | awk -v pid=$pid 'BEGIN { sum = 0 } $NF ~ "users:\\(\\(\".+?\","pid"," { sum += $2 } END { print sum }'
            ;;

          "send_q")
            tx_queue_sum=0
            if [ -n "$sockets" ]; then
              sockets="^$(echo "$sockets" | tr ' ' '|')$"

              while read tx_queue_hex; do
                # convert hex to dec
                tx_queue_dec=$((16#$tx_queue_hex))
                tx_queue_sum=$((tx_queue_sum+tx_queue_dec))
              done <<EOF
$(cat /proc/net/tcp | awk -v sockets=$sockets '$10 ~ sockets { print $5 }' | cut -d ':' -f 1)
EOF
            fi

            echo $tx_queue_sum

            # old way, too heavy
            #ss --tcp --numeric --process | grep 'ESTAB' | awk -v pid=$pid 'BEGIN { sum = 0 } $NF ~ "users:\\(\\(\".+?\","pid"," { sum += $3 } END { print sum }'
            ;;

          *)
            showhelp $1 $2
        esac
        ;;

      "udp")
        case $3 in
          "recv_q")
            rx_queue_sum=0
            if [ -n "$sockets" ]; then
              sockets="^$(echo "$sockets" | tr ' ' '|')$"

              while read rx_queue_hex; do
                # convert hex to dec
                rx_queue_dec=$((16#$rx_queue_hex))
                rx_queue_sum=$((rx_queue_sum+rx_queue_dec))
              done <<EOF
$(cat /proc/net/udp | awk -v sockets=$sockets '$10 ~ sockets { print $5 }' | cut -d ':' -f 2)
EOF
            fi

            echo $rx_queue_sum
            # old way, too heavy
            #ss --udp --numeric --process | awk -v pid=$pid 'BEGIN { sum = 0 } $NF ~ "users:\\(\\(\".+?\","pid"," { sum += $2 } END { print sum }'
            ;;

          "send_q")
            tx_queue_sum=0
            if [ -n "$sockets" ]; then
              sockets="^$(echo "$sockets" | tr ' ' '|')$"

              while read tx_queue_hex; do
                # convert hex to dec
                tx_queue_dec=$((16#$tx_queue_hex))
                tx_queue_sum=$((tx_queue_sum+tx_queue_dec))
              done <<EOF
$(cat /proc/net/udp | awk -v sockets=$sockets '$10 ~ sockets { print $5 }' | cut -d ':' -f 1)
EOF
            fi

            echo $tx_queue_sum

            # old way, too heavy
            #ss --udp --numeric --process | awk -v pid=$pid 'BEGIN { sum = 0 } $NF ~ "users:\\(\\(\".+?\","pid"," { sum += $3 } END { print sum }'
            ;;

          *)
            showhelp $1 $2
        esac
        ;;

      *)
        showhelp "net"
    esac
    ;;

  *)
    showhelp
esac

exit 0
