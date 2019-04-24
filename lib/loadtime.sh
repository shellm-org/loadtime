## \function __loadtime_set_delta
## \function-brief Set the time delta sum variable to 0.
__loadtime_set_delta() {
  if [ ${#__SHELLM_LIBSTACK[@]} -eq 0 ]; then
    __SHELLM_DELTA_SUM=0
  fi
}

## \function __loadtime_unset_delta
## \function-brief Unset the time delta sum variable.
__loadtime_unset_delta() {
  if [ ${#__SHELLM_LIBSTACK[@]} -eq 0 ]; then
    unset __SHELLM_DELTA_SUM
  fi
}

## \function __loadtime_now
## \function-brief Return a timestamp (seconds since Epoch plus nanoseconds).
## \function-stdout The date and time in seconds since Epoch.
__loadtime_now() {
  date +%s.%N
}

## \function __loadtime_start
## \function-brief Start the timer (store `now` in parent local start variable).
__loadtime_start() {
  start=$(__loadtime_now)
}

## \function __loadtime_end <NAME>
## \function-brief End the timer and update the time delta sum.
## Write-append the time delta for the given source
## in this process' data file.
## \function-argument NAME The source name, e.g. `shellm/home/lib/home.sh`.
__loadtime_end() {
  [ -z "${start}" ] && return
  local retcode="$1"
  local delta delta_sum
  shift
  delta_sum=$(bc -l <<<"$(__loadtime_now) - ${start}")
  delta=$(bc -l <<<"${delta_sum} - ${__SHELLM_DELTA_SUM}")
  __SHELLM_DELTA_SUM=${delta_sum}
  [ "${delta:0:1}" = "." ] && delta="0${delta}"
  ## \file /tmp/shellm-time.PID
  ## Data file used to store loading time per source for given process.
  echo "$1:${delta}" >> "/tmp/shellm-time.$$"
}


## \function loadtime-print [PID]
## \function-brief Pretty-print the loading time for each source for a given shell process.
## \function-argument PID The PID of a shell process (default to $$).
## \function-stdout Loading time for each source and total time.
## \function-return 1 Data file for the given PID does not exist.
loadtime-print() {
  local pid line mfile file seconds total longest

  if [ $# -gt 0 ]; then
    pid="$1"
  else
    pid=$$
  fi

  mfile="/tmp/shellm-time.${pid}"

  if [ ! -f "${mfile}" ]; then
    echo "shellm-print-loadtime: no time data for process ${pid}" >&2
    return 1
  fi

  longest=$(cut -d: -f-1 "${mfile}" | wc -L)
  echo "Measured load time for shell process ${pid}"
  echo
  sort -rt: -k2 "${mfile}" | while read -r line; do
    file="${line%:*}"
    seconds="${line##*:}"
    # shellcheck disable=SC1117
    printf "%${longest}s: %ss\n" "${file}" "${seconds:0:-6}"
  done
  echo
  total="$(cut -d: -f2 "${mfile}" | awk '{s+=$1} END {print s}')"
  total=${total:0:-2}
  echo "Total load time: ${total} seconds"
}

SHELLM_HOOKS_SOURCE_START+=(__loadtime_set_delta)
SHELLM_HOOKS_SOURCE_BEFORE_SOURCE+=(__loadtime_start)
SHELLM_HOOKS_SOURCE_AFTER_SOURCE+=(__loadtime_end)
SHELLM_HOOKS_SOURCE_END+=(__loadtime_unset_delta)
