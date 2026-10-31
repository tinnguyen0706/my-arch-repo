#!/usr/bin/env bash
# RUSTC_WRAPPER script to prevent SIGILL during build.rs / proc-macro execution on GitHub runners
# When compiling host artifacts (build.rs, proc-macros), replace -C target-cpu=x86-64-v4 with x86-64-v3

RUSTC="$1"
shift

is_host_artifact=0
for arg in "$@"; do
  case "$arg" in
    --crate-name=build_script_*|build_script_*|build-script-*)
      is_host_artifact=1
      break
      ;;
  esac
done

# Check if compiling a procedural macro
for ((i=1; i<=$#; i++)); do
  if [[ "${!i}" == "--crate-type" ]]; then
    next_idx=$((i + 1))
    if [[ "${!next_idx:-}" == *"proc-macro"* ]]; then
      is_host_artifact=1
      break
    fi
  elif [[ "${!i}" == *"--crate-type=proc-macro"* ]]; then
    is_host_artifact=1
    break
  fi
done

if (( is_host_artifact == 1 )); then
  NEW_ARGS=()
  for arg in "$@"; do
    case "$arg" in
      *target-cpu=x86-64-v4*)
        NEW_ARGS+=("${arg//target-cpu=x86-64-v4/target-cpu=x86-64-v3}")
        ;;
      *)
        NEW_ARGS+=("$arg")
        ;;
    esac
  done
  exec "$RUSTC" "${NEW_ARGS[@]}"
else
  exec "$RUSTC" "$@"
fi
