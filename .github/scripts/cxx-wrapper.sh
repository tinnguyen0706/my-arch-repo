#!/usr/bin/env bash
# C/C++ compiler wrapper to prevent SIGILL during build-time generator execution on GitHub runners
# When compiling or linking generator/tool binaries executed on the host, replace -march=x86-64-v4 with x86-64-v3

REAL_COMPILER="$1"
shift

is_host_generator=0

for ((i=1; i<=$#; i++)); do
  arg="${!i}"
  case "$arg" in
    *howdy_config_generator*|*docs_generator*|*config_generator*)
      is_host_generator=1
      break
      ;;
  esac
done

if (( is_host_generator == 1 )); then
  NEW_ARGS=()
  for arg in "$@"; do
    case "$arg" in
      *march=x86-64-v4*)
        NEW_ARGS+=("${arg//march=x86-64-v4/march=x86-64-v3}")
        ;;
      *)
        NEW_ARGS+=("$arg")
        ;;
    esac
  done
  exec "$REAL_COMPILER" "${NEW_ARGS[@]}"
else
  exec "$REAL_COMPILER" "$@"
fi
