#!/usr/bin/env bash
# RUSTC_WRAPPER script to prevent SIGILL during build.rs / proc-macro execution on GitHub runners
# When compiling host artifacts (build.rs, proc-macros), replace -C target-cpu=x86-64-v4 with x86-64-v3

RUSTC="$1"
shift

has_explicit_target=0
is_host_artifact=0

for ((i=1; i<=$#; i++)); do
  arg="${!i}"
  case "$arg" in
    --target|--target=*)
      has_explicit_target=1
      ;;
    --crate-name)
      next_idx=$((i + 1))
      next_arg="${!next_idx:-}"
      if [[ "$next_arg" == "build_script_"* || "$next_arg" == *"build_script"* || "$next_arg" == "autocfg"* ]]; then
        is_host_artifact=1
      fi
      ;;
    --crate-name=build_script_*|--crate-name=autocfg*|*"/build.rs"|"build.rs")
      is_host_artifact=1
      ;;
    --crate-type)
      next_idx=$((i + 1))
      if [[ "${!next_idx:-}" == *"proc-macro"* ]]; then
        is_host_artifact=1
      fi
      ;;
    *--crate-type=proc-macro*)
      is_host_artifact=1
      ;;
  esac
done

# Nếu Cargo không truyền --target, toàn bộ artifact đó đang được build cho máy host
if (( has_explicit_target == 0 )); then
  is_host_artifact=1
fi
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
