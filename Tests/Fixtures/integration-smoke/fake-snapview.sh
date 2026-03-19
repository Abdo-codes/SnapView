#!/bin/sh
set -eu

log_path="${SMOKE_COMMAND_LOG:?SMOKE_COMMAND_LOG is required}"
project_root="${SMOKE_PROJECT_ROOT:?SMOKE_PROJECT_ROOT is required}"
expected_input_flag="${SMOKE_EXPECT_INPUT_FLAG:?SMOKE_EXPECT_INPUT_FLAG is required}"
expected_input_path="${SMOKE_EXPECT_INPUT_PATH:?SMOKE_EXPECT_INPUT_PATH is required}"
expected_scheme="${SMOKE_EXPECT_SCHEME:?SMOKE_EXPECT_SCHEME is required}"
expected_test_target="${SMOKE_EXPECT_TEST_TARGET:-}"
create_gallery="${SMOKE_CREATE_GALLERY:-1}"
create_png="${SMOKE_CREATE_PNG:-1}"
watch_exit_after_seconds="${SMOKE_WATCH_EXIT_AFTER_SECONDS:-5}"
watch_requires_tty="${SMOKE_WATCH_REQUIRES_TTY:-0}"
fail_render_all="${SMOKE_FAIL_RENDER_ALL:-0}"

log_invocation() {
  for arg in "$@"; do
    printf '%s\0' "$arg" >> "$log_path"
  done
  printf '\0' >> "$log_path"
}

expect_arg() {
  actual=$1
  expected=$2
  label=$3
  if [ "$actual" != "$expected" ]; then
    printf 'unexpected %s: expected %s, got %s\n' "$label" "$expected" "$actual" >&2
    exit 64
  fi
}

expect_exact_args_without_test_target() {
  command_name=$1
  shift
  if [ "$#" -ne 4 ]; then
    printf '%s expected 4 arguments, got %s\n' "$command_name" "$#" >&2
    exit 64
  fi
  expect_arg "$1" "$expected_input_flag" "$command_name input flag"
  expect_arg "$2" "$expected_input_path" "$command_name input path"
  expect_arg "$3" "--scheme" "$command_name scheme flag"
  expect_arg "$4" "$expected_scheme" "$command_name scheme"
}

expect_exact_args_with_test_target() {
  command_name=$1
  shift
  if [ "$#" -ne 6 ]; then
    printf '%s expected 6 arguments, got %s\n' "$command_name" "$#" >&2
    exit 64
  fi
  expect_arg "$1" "$expected_input_flag" "$command_name input flag"
  expect_arg "$2" "$expected_input_path" "$command_name input path"
  expect_arg "$3" "--scheme" "$command_name scheme flag"
  expect_arg "$4" "$expected_scheme" "$command_name scheme"
  expect_arg "$5" "--test-target" "$command_name test-target flag"
  expect_arg "$6" "$expected_test_target" "$command_name test target"
}

expect_gallery_args_without_test_target() {
  command_name=$1
  shift
  if [ "$#" -ne 2 ]; then
    printf '%s expected 2 arguments, got %s\n' "$command_name" "$#" >&2
    exit 64
  fi
  expect_arg "$1" "$expected_input_flag" "$command_name input flag"
  expect_arg "$2" "$expected_input_path" "$command_name input path"
}

expect_gallery_args_with_test_target() {
  command_name=$1
  shift
  if [ "$#" -ne 4 ]; then
    printf '%s expected 4 arguments, got %s\n' "$command_name" "$#" >&2
    exit 64
  fi
  expect_arg "$1" "$expected_input_flag" "$command_name input flag"
  expect_arg "$2" "$expected_input_path" "$command_name input path"
  expect_arg "$3" "--test-target" "$command_name test-target flag"
  expect_arg "$4" "$expected_test_target" "$command_name test target"
}

expect_host_stop_args_without_test_target() {
  command_name=$1
  shift
  if [ "$#" -ne 2 ]; then
    printf '%s expected 2 arguments, got %s\n' "$command_name" "$#" >&2
    exit 64
  fi
  expect_arg "$1" "$expected_input_flag" "$command_name input flag"
  expect_arg "$2" "$expected_input_path" "$command_name input path"
}

expect_host_stop_args_with_test_target() {
  command_name=$1
  shift
  if [ "$#" -ne 4 ]; then
    printf '%s expected 4 arguments, got %s\n' "$command_name" "$#" >&2
    exit 64
  fi
  expect_arg "$1" "$expected_input_flag" "$command_name input flag"
  expect_arg "$2" "$expected_input_path" "$command_name input path"
  expect_arg "$3" "--test-target" "$command_name test-target flag"
  expect_arg "$4" "$expected_test_target" "$command_name test target"
}

command="${1:-}"
shift || true

case "$command" in
  doctor)
    if [ -n "$expected_test_target" ]; then
      expect_exact_args_with_test_target doctor "$@"
    else
      expect_exact_args_without_test_target doctor "$@"
    fi
    log_invocation "$command" "$@"
    printf 'doctor ok\n'
    ;;
  prepare)
    if [ -n "$expected_test_target" ]; then
      expect_exact_args_with_test_target prepare "$@"
    else
      expect_exact_args_without_test_target prepare "$@"
    fi
    log_invocation "$command" "$@"
    printf 'prepare ok\n'
    ;;
  render-all)
    if [ -n "$expected_test_target" ]; then
      expect_exact_args_with_test_target render-all "$@"
    else
      expect_exact_args_without_test_target render-all "$@"
    fi
    log_invocation "$command" "$@"
    if [ "$fail_render_all" = "1" ]; then
      printf 'render-all failed intentionally\n' >&2
      exit 70
    fi
    if [ "$create_png" = "1" ]; then
      mkdir -p "$project_root/.snapview"
      : > "$project_root/.snapview/Smoke.png"
    fi
    printf 'render-all ok\n'
    ;;
  gallery)
    if [ -n "$expected_test_target" ]; then
      expect_gallery_args_with_test_target gallery "$@"
    else
      expect_gallery_args_without_test_target gallery "$@"
    fi
    log_invocation "$command" "$@"
    mkdir -p "$project_root/.snapview"
    if [ "$create_gallery" = "1" ]; then
      : > "$project_root/.snapview/gallery.html"
    fi
    printf 'Gallery: %s/.snapview/gallery.html\n' "$project_root"
    ;;
  watch)
    if [ -n "$expected_test_target" ]; then
      expect_exact_args_with_test_target watch "$@"
    else
      expect_exact_args_without_test_target watch "$@"
    fi
    log_invocation "$command" "$@"
    if [ "$watch_requires_tty" = "0" ] || [ -t 1 ]; then
      printf '[watch] Updated 3 preview(s) in 1.0s.\n'
    fi
    sleep "$watch_exit_after_seconds"
    ;;
  host)
    subcommand="${1:-}"
    shift || true
    case "$subcommand" in
      stop)
        if [ -n "$expected_test_target" ]; then
          expect_host_stop_args_with_test_target "host stop" "$@"
        else
          expect_host_stop_args_without_test_target "host stop" "$@"
        fi
        log_invocation "$command" "$subcommand" "$@"
        printf 'Persistent host stopped.\n'
        ;;
      *)
        printf 'unknown host subcommand: %s\n' "$subcommand" >&2
        exit 64
        ;;
    esac
    ;;
  *)
    printf 'unknown command: %s\n' "$command" >&2
    exit 64
    ;;
esac
