#!/usr/bin/env bash
# Samples a running AutoClicker's CPU and memory once a second, for SC-6 and SC-11.
#
# Usage: scripts/measure-performance.sh [seconds] [--trace]
#   seconds  how long to sample (default 240)
#   --trace  also record an Instruments Time Profiler trace of the same window
#
# Run it against a build that keeps get-task-allow (`scripts/build-release.sh --profiling`), or `leaks` and
# Instruments cannot attach. It writes a CSV and the `leaks` report to build/profiling/ and prints a summary. CPU is
# computed from the process's cumulative CPU time, so each sample is the exact share of one core used in that second.
set -euo pipefail

duration=240
trace=false
for arg in "$@"; do
    case "$arg" in
        --trace) trace=true ;;
        *) duration="$arg" ;;
    esac
done

pid=$(pgrep -x AutoClicker | head -n 1 || true)
if [[ -z "$pid" ]]; then
    echo "AutoClicker is not running." >&2
    exit 1
fi

out_dir="build/profiling"
mkdir -p "$out_dir"
stamp=$(date +%Y%m%d-%H%M%S)
csv="$out_dir/perf-$stamp.csv"

# `ps -o cputime` prints [[dd-]hh:]mm:ss.cc; this turns it into seconds.
cpu_seconds() {
    ps -o cputime= -p "$pid" | awk '{
        time = $1; days = 0
        if (index(time, "-")) { split(time, halves, "-"); days = halves[1]; time = halves[2] }
        n = split(time, parts, ":"); total = 0
        for (i = 1; i <= n; i++) total = total * 60 + parts[i]
        printf "%.2f\n", days * 86400 + total
    }'
}

if $trace; then
    xcrun xctrace record --template 'Time Profiler' --attach "$pid" --time-limit "${duration}s" \
        --output "$out_dir/time-profiler-$stamp.trace" > "$out_dir/xctrace-$stamp.log" 2>&1 &
fi

echo "Sampling AutoClicker (pid $pid) for ${duration}s into $csv"
echo "elapsed_s,cpu_percent,rss_mb" > "$csv"
previous=$(cpu_seconds)
for ((elapsed = 1; elapsed <= duration; elapsed++)); do
    sleep 1
    kill -0 "$pid" 2> /dev/null || { echo "AutoClicker quit after ${elapsed}s." >&2; break; }
    current=$(cpu_seconds)
    rss_kb=$(ps -o rss= -p "$pid" | tr -d ' ')
    awk -v t="$elapsed" -v a="$previous" -v b="$current" -v r="$rss_kb" \
        'BEGIN { printf "%d,%.2f,%.1f\n", t, (b - a) * 100, r / 1024 }' >> "$csv"
    previous=$current
done

wait

leaks_report="$out_dir/leaks-$stamp.txt"
leaks "$pid" > "$leaks_report" 2>&1 || true

echo
awk -F, 'NR > 1 {
    n++; sum += $2; if ($2 > max) max = $2
    if (n == 1) first = $3; last = $3; if ($3 > peak) peak = $3
} END {
    printf "CPU: mean %.2f%%, max %.2f%% over %d samples\n", sum / n, max, n
    printf "RSS: first %.1f MB, last %.1f MB, peak %.1f MB\n", first, last, peak
}' "$csv"
grep -E "leaks for|Process [0-9]+: [0-9]+ nodes" "$leaks_report" || tail -n 5 "$leaks_report"
echo "CSV: $csv"
echo "Leaks report: $leaks_report"
