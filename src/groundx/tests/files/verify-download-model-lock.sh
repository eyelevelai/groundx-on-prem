#!/usr/bin/env bash
set -euo pipefail

for tool in helm yq docker; do
  if ! command -v "${tool}" >/dev/null 2>&1; then
    echo "FAIL: ${tool} not found on PATH (verify-download-model-lock.sh needs helm, yq and docker)" >&2
    exit 1
  fi
done
if ! docker info >/dev/null 2>&1; then
  echo "FAIL: the docker daemon is not reachable; verify-download-model-lock.sh runs the download-model script in the chart busybox image" >&2
  exit 1
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/../../../.." && pwd)"
src_chart="${repo_root}/src/groundx"
mirror_chart="${repo_root}/helm"
search_credentials_values="${src_chart}/tests/files/values.search-credentials.yaml"
services=(layout-inference ranker-inference summary-inference)
target_service="summary-inference"
label="gx125-download-model-lock-guard"

work="$(mktemp -d "${HOME:?HOME must be set}/.download-model-lock-guard.XXXXXX")"
cleanup() {
  local ids vols
  ids="$(docker ps -aq --filter "label=${label}" 2>/dev/null || true)"
  if [ -n "${ids}" ]; then
    docker rm -f ${ids} >/dev/null 2>&1 || true
  fi
  vols="$(docker volume ls -q --filter "label=${label}" 2>/dev/null || true)"
  if [ -n "${vols}" ]; then
    docker volume rm -f ${vols} >/dev/null 2>&1 || true
  fi
  rm -rf "${work}"
}
trap cleanup EXIT

fail=0
report() {
  local name="$1" result="$2" detail="${3:-}"
  if [ "${result}" = "pass" ]; then
    echo "PASS: ${name}"
  else
    echo "FAIL: ${name}${detail:+: ${detail}}" >&2
    fail=1
  fi
}

render() {
  helm template groundx "$1" -f "$1/values/minikube/values.yaml" \
    -f "${search_credentials_values}" \
    --set summary.inference.enabled=true --set summary.api.enabled=true
}

extract_script() {
  yq -N "select(.kind == \"Deployment\" and .metadata.name == \"$2\") | .spec.template.spec.initContainers[] | select(.name == \"download-model\") | .command[2]" "$1"
}

extract_field() {
  yq -N "select(.kind == \"Deployment\" and .metadata.name == \"$2\") | .spec.template.spec.initContainers[] | select(.name == \"download-model\") | $3" "$1"
}

render "${src_chart}" > "${work}/render-src.yaml"
render "${mirror_chart}" > "${work}/render-mirror.yaml"

mirror_ok=1
for svc in "${services[@]}"; do
  extract_script "${work}/render-src.yaml" "${svc}" > "${work}/${svc}.src.sh"
  extract_script "${work}/render-mirror.yaml" "${svc}" > "${work}/${svc}.mirror.sh"
  if [ ! -s "${work}/${svc}.src.sh" ] || [ "$(cat "${work}/${svc}.src.sh")" = "null" ]; then
    report "mirror: ${svc} has a download-model script" fail "src/groundx render has no download-model script for ${svc}"
    mirror_ok=0
  elif ! cmp -s "${work}/${svc}.src.sh" "${work}/${svc}.mirror.sh"; then
    report "mirror: ${svc} script identical in src/groundx and helm/" fail "rendered download-model scripts differ"
    mirror_ok=0
  fi
done
[ "${mirror_ok}" -eq 1 ] && report "mirror: download-model script identical in src/groundx and helm/ for ${services[*]}" pass

script="${work}/${target_service}.src.sh"
if [ ! -s "${script}" ]; then
  echo "FAIL: no ${target_service} download-model script to run" >&2
  exit 1
fi
image="$(extract_field "${work}/render-src.yaml" "${target_service}" ".image")"
mount_path="$(extract_field "${work}/render-src.yaml" "${target_service}" ".volumeMounts[0].mountPath")"
marker_name="$(grep -oE 'complete\.[A-Za-z0-9_-]+' "${script}" | head -1 || true)"
parts="$(sed -n 's/^ *echo "\([0-9 ]*\)" | tr .*/\1/p' "${script}" | head -1)"
part_count="$(wc -w <<< "${parts}" | tr -d ' ')"
if [ -z "${image}" ] || [ -z "${mount_path}" ] || [ -z "${marker_name}" ] || [ "${part_count}" -lt 1 ]; then
  echo "FAIL: could not derive image='${image}' mount='${mount_path}' marker='${marker_name}' parts='${part_count}' from the rendered script" >&2
  exit 1
fi

if ! docker image inspect "${image}" >/dev/null 2>&1; then
  docker pull "${image}" >/dev/null 2>&1 || {
    echo "FAIL: chart busybox image ${image} is not present and could not be pulled; run: docker pull ${image}" >&2
    exit 1
  }
fi

stubs="${work}/stubs"
mkdir -p "${stubs}"
cat > "${stubs}/wget" <<'STUB'
#!/bin/sh
out=""
url=""
while [ $# -gt 0 ]; do
  case "$1" in
    -O) out="$2"; shift 2 ;;
    -q) shift ;;
    *) url="$1"; shift ;;
  esac
done
echo "${url}" >> /state/wget.log
if [ -n "${STUB_WGET_SLEEP_UNTIL:-}" ]; then
  while [ ! -f "${STUB_WGET_SLEEP_UNTIL}" ]; do sleep 1; done
fi
if [ -n "${STUB_WGET_SLEEP:-}" ]; then
  sleep "${STUB_WGET_SLEEP}"
fi
case "${STUB_WGET_MODE:-ok}" in
  fail) exit 1 ;;
  garbage) echo "not a tarball" > "${out}"; exit 0 ;;
  *)
    part="$(basename "${out}")"
    d="$(mktemp -d)"
    echo "${part}" > "${d}/${part}.bin"
    tar -czf "${out}" -C "${d}" "${part}.bin"
    rm -rf "${d}"
    ;;
esac
STUB
chmod +x "${stubs}/wget"

flock_bad="${work}/flock-bad"
flock_silent="${work}/flock-silent"
mkdir -p "${flock_bad}" "${flock_silent}"
cat > "${flock_bad}/flock" <<'STUB'
#!/bin/sh
echo "flock: ${2:-?}: Bad file descriptor" >&2
exit 1
STUB
cat > "${flock_silent}/flock" <<'STUB'
#!/bin/sh
exit 1
STUB
chmod +x "${flock_bad}/flock" "${flock_silent}/flock"

noflock="${work}/noflock"
mkdir -p "${noflock}"
for applet in sh tr xargs rm touch date sleep cat mktemp tar; do
  ln -s /bin/busybox "${noflock}/${applet}"
done

base_path="/stubs:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
uid_gid="$(id -u):$(id -g)"
case_seq=0
run_id="$$"

new_volume() {
  docker volume create --label "${label}" "$1" >/dev/null
  docker run --rm --network none -v "$1:/m" "${image}" /bin/sh -c 'chmod 777 /m' >/dev/null
}

new_case_dirs() {
  case_seq=$((case_seq + 1))
  vol="gx125-lock-vol-${run_id}-${case_seq}"
  state="gx125-lock-state-${run_id}-${case_seq}"
  new_volume "${vol}"
  new_volume "${state}"
}

vsh() {
  local volume="$1"
  shift
  docker run --rm --network none -v "${volume}:/m" "${image}" /bin/sh -c "$*"
}

vol_has() {
  vsh "${vol}" "[ -e /m/$1 ]"
}

start_container() {
  local name="$1" path="$2"
  shift 2
  docker run -d --label "${label}" --name "${name}" --network none --user "${uid_gid}" \
    -v "${vol}:${mount_path}" -v "${state}:/state" -v "${stubs}:/stubs:ro" \
    -v "${run_script:-${script}}:/s.sh:ro" \
    -v "${noflock}:/nolock:ro" -v "${flock_bad}:/flockbad:ro" -v "${flock_silent}:/flocksilent:ro" \
    -e "PATH=${path}" "$@" "${image}" /bin/sh /s.sh >/dev/null
}

is_running() {
  [ "$(docker inspect -f '{{.State.Running}}' "$1" 2>/dev/null)" = "true" ]
}

wait_exit() {
  local name="$1" limit="$2" waited=0
  while is_running "${name}"; do
    if [ "${waited}" -ge $((limit * 2)) ]; then
      echo "TIMEOUT"
      return 0
    fi
    sleep 0.5
    waited=$((waited + 1))
  done
  docker inspect -f '{{.State.ExitCode}}' "${name}"
}

wget_calls() {
  vsh "${state}" 'if [ -f /m/wget.log ]; then wc -l < /m/wget.log; else echo 0; fi' | tr -d ' \r'
}

unique_wget_calls() {
  vsh "${state}" 'if [ -f /m/wget.log ]; then sort -u /m/wget.log | wc -l; else echo 0; fi' | tr -d ' \r'
}

stub_path_check="$(docker run --rm --network none -v "${stubs}:/stubs:ro" -e "PATH=${base_path}" "${image}" /bin/sh -c 'command -v wget')"
if [ "${stub_path_check}" = "/stubs/wget" ]; then
  report "harness: wget stub intercepts the script's wget" pass
else
  report "harness: wget stub intercepts the script's wget" fail "command -v wget resolved to '${stub_path_check}'"
fi

new_case_dirs
vsh "${vol}" "touch /m/downloading /m/summary.tar.gz.part.00"
start_container gx125-stale "${base_path}"
rc="$(wait_exit gx125-stale 40)"
if [ "${rc}" = "0" ] && vol_has "${marker_name}" && ! vol_has downloading \
  && ! vol_has summary.tar.gz.part.00 && [ "$(wget_calls)" = "${part_count}" ]; then
  report "case 1: stale downloading file with no live holder is taken over and downloaded" pass
else
  report "case 1: stale downloading file with no live holder is taken over and downloaded" fail \
    "exit=${rc} marker=$(vol_has "${marker_name}" && echo yes || echo no) downloading=$(vol_has downloading && echo present || echo gone) wget_calls=$(wget_calls) expected=${part_count}"
fi

new_case_dirs
start_container gx125-failed "${base_path}" -e STUB_WGET_MODE=fail
rc="$(wait_exit gx125-failed 90)"
if [ "${rc}" != "TIMEOUT" ] && [ "${rc}" != "0" ] && ! vol_has "${marker_name}"; then
  report "case 2a: a failed wget exits non-zero and writes no marker" pass
else
  report "case 2a: a failed wget exits non-zero and writes no marker" fail \
    "exit=${rc} marker=$(vol_has "${marker_name}" && echo written || echo absent)"
fi

new_case_dirs
start_container gx125-badtar "${base_path}" -e STUB_WGET_MODE=garbage
rc="$(wait_exit gx125-badtar 40)"
if [ "${rc}" != "TIMEOUT" ] && [ "${rc}" != "0" ] && ! vol_has "${marker_name}"; then
  report "case 2b: a failed tar exits non-zero and writes no marker" pass
else
  report "case 2b: a failed tar exits non-zero and writes no marker" fail \
    "exit=${rc} marker=$(vol_has "${marker_name}" && echo written || echo absent)"
fi

new_case_dirs
start_container gx125-fresh "${base_path}"
rc="$(wait_exit gx125-fresh 40)"
if [ "${rc}" = "0" ] && vol_has "${marker_name}" && [ "$(wget_calls)" = "${part_count}" ]; then
  report "case 3: no lock and no marker starts the download" pass
else
  report "case 3: no lock and no marker starts the download" fail "exit=${rc} wget_calls=$(wget_calls) expected=${part_count}"
fi

new_case_dirs
start_container gx125-holder "${base_path}" -e STUB_WGET_SLEEP_UNTIL=/state/release
holder_up=0
for _ in $(seq 1 40); do
  if [ "$(wget_calls)" -gt 0 ]; then holder_up=1; break; fi
  sleep 0.5
done
if [ "${holder_up}" -eq 1 ]; then
  start_container gx125-waiter "${base_path}" -e STUB_WGET_SLEEP_UNTIL=/state/release
  sleep 8
  waiter_blocked=0
  if is_running gx125-waiter && docker logs gx125-waiter 2>&1 | grep -q "Waiting" && [ "$(wget_calls)" = "${part_count}" ]; then
    waiter_blocked=1
  fi
  vsh "${state}" "touch /m/release"
  holder_rc="$(wait_exit gx125-holder 60)"
  waiter_rc="$(wait_exit gx125-waiter 30)"
  if [ "${waiter_blocked}" -eq 1 ] && [ "${holder_rc}" = "0" ] && [ "${waiter_rc}" = "0" ] \
    && vol_has "${marker_name}" && [ "$(wget_calls)" = "${part_count}" ]; then
    report "case 4: a waiter stays blocked behind a live holder and starts once it finishes, without re-downloading" pass
  else
    report "case 4: a waiter stays blocked behind a live holder and starts once it finishes, without re-downloading" fail \
      "blocked=${waiter_blocked} holder_exit=${holder_rc} waiter_exit=${waiter_rc} wget_calls=$(wget_calls) expected=${part_count}"
  fi
else
  report "case 4: a waiter stays blocked behind a live holder and starts once it finishes, without re-downloading" fail "holder never started downloading"
fi

new_case_dirs
start_container gx125-killed-holder "${base_path}" -e STUB_WGET_SLEEP_UNTIL=/state/release
killed_up=0
for _ in $(seq 1 40); do
  if [ "$(wget_calls)" -gt 0 ]; then killed_up=1; break; fi
  sleep 0.5
done
if [ "${killed_up}" -eq 1 ]; then
  start_container gx125-killed-waiter "${base_path}"
  killed_waiting=0
  for _ in $(seq 1 40); do
    if docker logs gx125-killed-waiter 2>&1 | grep -q "Waiting"; then killed_waiting=1; break; fi
    sleep 0.5
  done
  calls_before_kill="$(wget_calls)"
  docker kill gx125-killed-holder >/dev/null
  rc="$(wait_exit gx125-killed-waiter 60)"
  calls_after_kill=$(( $(wget_calls) - calls_before_kill ))
  if [ "${killed_waiting}" -eq 1 ] && [ "${rc}" = "0" ] && vol_has "${marker_name}" && [ "${calls_after_kill}" = "${part_count}" ]; then
    report "case 8a: killing the holder lets a waiter take the lock, download a full set of parts and write the marker" pass
  else
    report "case 8a: killing the holder lets a waiter take the lock, download a full set of parts and write the marker" fail \
      "waiting=${killed_waiting} exit=${rc} marker=$(vol_has "${marker_name}" && echo yes || echo no) calls_after_kill=${calls_after_kill} expected=${part_count}"
  fi
else
  report "case 8a: killing the holder lets a waiter take the lock, download a full set of parts and write the marker" fail "holder never started downloading"
fi

new_case_dirs
start_container gx125-failing-holder "${base_path}" -e STUB_WGET_SLEEP_UNTIL=/state/release -e STUB_WGET_MODE=fail
failing_up=0
for _ in $(seq 1 40); do
  if [ "$(wget_calls)" -gt 0 ]; then failing_up=1; break; fi
  sleep 0.5
done
if [ "${failing_up}" -eq 1 ]; then
  start_container gx125-failing-waiter "${base_path}"
  failing_waiting=0
  for _ in $(seq 1 40); do
    if docker logs gx125-failing-waiter 2>&1 | grep -q "Waiting"; then failing_waiting=1; break; fi
    sleep 0.5
  done
  vsh "${state}" "touch /m/release"
  holder_rc="$(wait_exit gx125-failing-holder 90)"
  waiter_rc="$(wait_exit gx125-failing-waiter 60)"
  expected_calls=$(( part_count * 4 ))
  if [ "${failing_waiting}" -eq 1 ] && [ "${holder_rc}" != "TIMEOUT" ] && [ "${holder_rc}" != "0" ] \
    && [ "${waiter_rc}" = "0" ] && vol_has "${marker_name}" && [ "$(wget_calls)" = "${expected_calls}" ]; then
    report "case 8b: a holder whose download fails leaves no marker and the waiter downloads the full set itself" pass
  else
    report "case 8b: a holder whose download fails leaves no marker and the waiter downloads the full set itself" fail \
      "waiting=${failing_waiting} holder_exit=${holder_rc} waiter_exit=${waiter_rc} marker=$(vol_has "${marker_name}" && echo yes || echo no) wget_calls=$(wget_calls) expected=${expected_calls}"
  fi
else
  report "case 8b: a holder whose download fails leaves no marker and the waiter downloads the full set itself" fail "holder never started downloading"
fi

new_case_dirs
start_container gx125-deadline-holder "${base_path}" -e STUB_WGET_SLEEP_UNTIL=/state/release
deadline_up=0
for _ in $(seq 1 40); do
  if [ "$(wget_calls)" -gt 0 ]; then deadline_up=1; break; fi
  sleep 0.5
done
if [ "${deadline_up}" -eq 1 ]; then
  short_script="${work}/short-deadline.sh"
  sed 's/^\( *\)wait_limit=3600$/\1wait_limit=4/' "${script}" > "${short_script}"
  if grep -qE '^ *wait_limit=4$' "${short_script}"; then
    run_script="${short_script}" start_container gx125-deadline-waiter "${base_path}"
    rc="$(wait_exit gx125-deadline-waiter 40)"
    waiter_logs="$(docker logs gx125-deadline-waiter 2>&1)"
    if [ "${rc}" != "TIMEOUT" ] && [ "${rc}" != "0" ] && grep -q "Timed out after 4s" <<< "${waiter_logs}" \
      && ! vol_has "${marker_name}" && [ "$(wget_calls)" = "${part_count}" ]; then
      report "case 9: a waiter behind a held lock fails at the deadline with the timeout message and no marker" pass
    else
      report "case 9: a waiter behind a held lock fails at the deadline with the timeout message and no marker" fail \
        "exit=${rc} marker=$(vol_has "${marker_name}" && echo yes || echo no) wget_calls=$(wget_calls)"
    fi
  else
    report "case 9: a waiter behind a held lock fails at the deadline with the timeout message and no marker" fail "could not shorten wait_limit in the rendered script"
  fi
  vsh "${state}" "touch /m/release"
else
  report "case 9: a waiter behind a held lock fails at the deadline with the timeout message and no marker" fail "holder never started downloading"
fi

new_case_dirs
start_container gx125-race-a "${base_path}" -e STUB_WGET_SLEEP=2
start_container gx125-race-b "${base_path}" -e STUB_WGET_SLEEP=2
rc_a="$(wait_exit gx125-race-a 60)"
rc_b="$(wait_exit gx125-race-b 60)"
unique_calls="$(unique_wget_calls)"
if [ "${rc_a}" = "0" ] && [ "${rc_b}" = "0" ] && vol_has "${marker_name}" \
  && [ "$(wget_calls)" = "${part_count}" ] && [ "${unique_calls}" = "${part_count}" ]; then
  report "case 5: two concurrent starts on an empty volume download once" pass
else
  report "case 5: two concurrent starts on an empty volume download once" fail \
    "exit_a=${rc_a} exit_b=${rc_b} wget_calls=$(wget_calls) unique=${unique_calls} expected=${part_count}"
fi

path_form_flock_lines() {
  grep -E '(^|[^[:alnum:]_.-])flock([[:space:]]|$)' "$1" \
    | grep -vE '^[[:space:]]*echo ' \
    | grep -v 'command -v flock' \
    | grep -vE 'flock -n 9([[:space:]]|$)' || true
}

static_ok=1
static_detail=""
if ! grep -qE '^[[:space:]]*exec 9>>"\$lock"' "${script}"; then
  static_ok=0
  static_detail="no write-opened fd (exec 9>>\"\$lock\")"
fi
if ! grep -qE 'flock -n 9( |$)' "${script}"; then
  static_ok=0
  static_detail="${static_detail:+${static_detail}; }no fd-based flock -n 9"
fi
if [ -n "$(path_form_flock_lines "${script}")" ]; then
  static_ok=0
  static_detail="${static_detail:+${static_detail}; }path-form flock found"
fi
if ! grep -qE 'wait_limit=3600' "${script}"; then
  static_ok=0
  static_detail="${static_detail:+${static_detail}; }no 60-minute wait limit (wait_limit=3600)"
fi
bad_fixture="${script_dir}/download-model-path-form-flock.bad.sh"
if [ ! -s "${bad_fixture}" ]; then
  static_ok=0
  static_detail="${static_detail:+${static_detail}; }missing known-bad fixture ${bad_fixture}"
else
  bad_total="$(wc -l < "${bad_fixture}" | tr -d ' ')"
  bad_caught="$(path_form_flock_lines "${bad_fixture}" | wc -l | tr -d ' ')"
  if [ "${bad_caught}" != "${bad_total}" ]; then
    static_ok=0
    static_detail="${static_detail:+${static_detail}; }path-form check caught ${bad_caught} of ${bad_total} known-bad lines"
  fi
fi
if [ "${static_ok}" -eq 1 ]; then
  report "case 6: locks a write-opened fd and never uses the flock <path> <cmd> form" pass
else
  report "case 6: locks a write-opened fd and never uses the flock <path> <cmd> form" fail "${static_detail}"
fi

new_case_dirs
start_container gx125-noflock /nolock
rc="$(wait_exit gx125-noflock 20)"
if [ "${rc}" != "TIMEOUT" ] && [ "${rc}" != "0" ] && docker logs gx125-noflock 2>&1 | grep -qi "flock" \
  && ! vol_has "${marker_name}" && [ "$(wget_calls)" = "0" ]; then
  report "case 7a: a missing flock with no marker exits non-zero at once naming flock" pass
else
  report "case 7a: a missing flock with no marker exits non-zero at once naming flock" fail "exit=${rc}"
fi

new_case_dirs
vsh "${vol}" "touch /m/${marker_name}"
start_container gx125-noflock-done /nolock
rc="$(wait_exit gx125-noflock-done 20)"
if [ "${rc}" = "0" ] && vol_has "${marker_name}" && [ "$(wget_calls)" = "0" ]; then
  report "case 7d: a missing flock with the complete marker present exits 0 without downloading" pass
else
  report "case 7d: a missing flock with the complete marker present exits 0 without downloading" fail "exit=${rc} wget_calls=$(wget_calls)"
fi

new_case_dirs
start_container gx125-badflock "/flockbad:${base_path}"
rc="$(wait_exit gx125-badflock 20)"
if [ "${rc}" != "TIMEOUT" ] && [ "${rc}" != "0" ] && docker logs gx125-badflock 2>&1 | grep -qi "flock" \
  && ! vol_has "${marker_name}" && [ "$(wget_calls)" = "0" ]; then
  report "case 7b: a flock that prints an error is fatal at once, not retried until the deadline" pass
else
  report "case 7b: a flock that prints an error is fatal at once, not retried until the deadline" fail "exit=${rc}"
fi

new_case_dirs
start_container gx125-silentflock "/flocksilent:${base_path}"
sleep 8
if is_running gx125-silentflock && docker logs gx125-silentflock 2>&1 | grep -q "Waiting" && [ "$(wget_calls)" = "0" ]; then
  report "case 7c: a silent rc=1 flock is treated as contention and keeps waiting" pass
else
  report "case 7c: a silent rc=1 flock is treated as contention and keeps waiting" fail "container exited or never reported waiting"
fi
docker rm -f gx125-silentflock >/dev/null 2>&1 || true

if [ "${fail}" -ne 0 ]; then
  echo "FAIL: download-model lock guard found one or more failing cases" >&2
  exit 1
fi
echo "download-model lock guard passed"
