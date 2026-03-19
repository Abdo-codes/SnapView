#!/bin/sh
set -eu

usage() {
  cat <<'EOF'
Usage:
  scripts/integration-smoke.sh --scheme <scheme> (--project <path> | --workspace <path>) [--test-target <target>] [--watch] [--keep-host]
EOF
}

fail_usage() {
  usage 1>&2
  exit 1
}

run_step() {
  step_name=$1
  shift
  printf '==> %s\n' "$step_name"
  "$@"
}

scheme=''
project_path=''
workspace_path=''
test_target=''
watch_requested=0
keep_host=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --scheme)
      shift
      [ "$#" -gt 0 ] || fail_usage
      scheme=$1
      ;;
    --project)
      shift
      [ "$#" -gt 0 ] || fail_usage
      project_path=$1
      ;;
    --workspace)
      shift
      [ "$#" -gt 0 ] || fail_usage
      workspace_path=$1
      ;;
    --test-target)
      shift
      [ "$#" -gt 0 ] || fail_usage
      test_target=$1
      ;;
    --watch|--keep-host)
      if [ "$1" = "--watch" ]; then
        watch_requested=1
      else
        keep_host=1
      fi
      ;;
    *)
      fail_usage
      ;;
  esac
  shift
done

if [ -z "$scheme" ]; then
  fail_usage
fi

if [ -n "$project_path" ] && [ -n "$workspace_path" ]; then
  fail_usage
fi

if [ -z "$project_path" ] && [ -z "$workspace_path" ]; then
  fail_usage
fi

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)
repo_root=$(CDPATH= cd "$script_dir/.." && pwd)
snapview_bin="${SNAPVIEW_BIN:-$repo_root/.build/debug/snapview}"

if [ -n "$project_path" ]; then
  source_root=$(dirname "$project_path")
  input_flag='--project'
  input_path=$project_path
else
  source_root=$(dirname "$workspace_path")
  input_flag='--workspace'
  input_path=$workspace_path
fi

if [ -n "$test_target" ]; then
  run_step doctor "$snapview_bin" doctor "$input_flag" "$input_path" --scheme "$scheme" --test-target "$test_target"
  run_step prepare "$snapview_bin" prepare "$input_flag" "$input_path" --scheme "$scheme" --test-target "$test_target"
  run_step render-all "$snapview_bin" render-all "$input_flag" "$input_path" --scheme "$scheme" --test-target "$test_target"
  run_step gallery "$snapview_bin" gallery "$input_flag" "$input_path" --test-target "$test_target"
else
  run_step doctor "$snapview_bin" doctor "$input_flag" "$input_path" --scheme "$scheme"
  run_step prepare "$snapview_bin" prepare "$input_flag" "$input_path" --scheme "$scheme"
  run_step render-all "$snapview_bin" render-all "$input_flag" "$input_path" --scheme "$scheme"
  run_step gallery "$snapview_bin" gallery "$input_flag" "$input_path"
fi

gallery_path="$source_root/.snapview/gallery.html"
if [ ! -f "$gallery_path" ]; then
  printf 'Expected gallery.html at %s\n' "$gallery_path" >&2
  exit 1
fi

found_png=0
for png in "$source_root/.snapview"/*.png; do
  if [ -f "$png" ]; then
    found_png=1
    break
  fi
done

if [ "$found_png" -eq 0 ]; then
  printf 'Expected at least one .png in %s\n' "$source_root/.snapview" >&2
  exit 1
fi
