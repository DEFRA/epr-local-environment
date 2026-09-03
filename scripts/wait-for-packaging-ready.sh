#!/usr/bin/env bash
#
# Blocks until epr-packaging-frontend is genuinely ready to serve tests, then exits 0.
# Exits non-zero (with a specific reason) if it cannot get there within the timeout.
#
#   ./scripts/wait-for-packaging-ready.sh [--timeout SECONDS] [--start]
#
#     --start    run `docker compose --profile packaging up -d --wait` first
#     --timeout  overall budget, default 600s (cold start measured ~97s)
#
# Why this exists rather than just `docker compose up -d --wait`:
#
#   1. epr-packaging-frontend registers NO health checks - Program.cs calls
#      services.AddHealthChecks() with nothing added, so /admin/health returns 200 the moment
#      Kestrel is listening. Container health says the process is alive, not that it can serve
#      a page. It is a liveness probe being read as a readiness probe.
#
#   2. The frontend declares depends_on with condition: service_started (not service_healthy)
#      for epr-facade-account-microservice, epr-payment-facade and epr-pom-api-web. It therefore
#      accepts traffic before those are ready - measured, it goes running at 59s while
#      epr-payment-facade is not healthy until 67s.
#
#   3. Container health does not notice cross-service TLS failure. If the certs in
#      compose/certs/https are regenerated while containers are running, services end up on
#      different cert generations and every inter-service HTTPS call fails with
#      "PartialChain" while every container still reports healthy. Requests then take tens of
#      seconds via Polly retries instead of failing fast. Stage 3 below is what catches that.
#
#   4. Docker Desktop's embedded DNS (127.0.0.11 inside every container) can end up unable to
#      resolve one service's name from every other container on the network, even though that
#      service is running and healthy with a valid IP - reproduced by disconnecting/reconnecting
#      a container's network, but has also been seen after ordinary heavy churn during a big
#      cold start (a dozen one-shot migration/init/seed containers plus a dozen services all
#      starting together). `docker restart` on the affected container does NOT fix it; only
#      recreating it does. Stage 3 catches this as "unreachable" with reason "bad address" for
#      every dependency probed from the frontend, and the failure message below names the fix.
#
#   5. Which containers are one-shots has to come from the compose model, not from the container
#      name. This script originally guessed from a *-migrations / *-init / *-seed name pattern,
#      and silently broke the moment synapse-source-sync and synapse-sqlserver-restore were
#      added: neither name matches, so stage 1 waited for them to report healthy, which a
#      container that has already exited 0 never does. The result was a ten-minute timeout on a
#      completely working stack. See is_one_shot() below.
#
set -uo pipefail

TIMEOUT=600
DO_START=0
while [ $# -gt 0 ]; do
  case "$1" in
    --timeout) TIMEOUT="$2"; shift 2 ;;
    --start) DO_START=1; shift ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

cd "$(dirname "$0")/.." || exit 2
# Honours the standard COMPOSE_FILE environment variable, so an override can be layered in, e.g.
#   COMPOSE_FILE=compose.yml:compose.override.yml ./scripts/wait-for-packaging-ready.sh --start
COMPOSE="docker compose --profile packaging"
FRONTEND=epr-local-environment-epr-packaging-frontend-1
START=$(date +%s)

elapsed() { echo $(( $(date +%s) - START )); }
budget_left() { echo $(( TIMEOUT - $(elapsed) )); }
say() { printf '[%3ss] %s\n' "$(elapsed)" "$1"; }
fail() { printf '\n[%3ss] NOT READY: %s\n' "$(elapsed)" "$1" >&2; exit 1; }

# Prints on every change, and at least every HEARTBEAT_SECS even when the message is unchanged,
# so a poll loop that is stuck on the same condition still visibly ticks instead of going silent.
HEARTBEAT_SECS=15
LAST_PROGRESS_MSG=""
LAST_PROGRESS_TIME=-999
say_progress() { # msg
  local msg="$1" now
  now=$(elapsed)
  if [ "$msg" != "$LAST_PROGRESS_MSG" ] || [ $(( now - LAST_PROGRESS_TIME )) -ge "$HEARTBEAT_SECS" ]; then
    say "  $msg"
    LAST_PROGRESS_MSG="$msg"
    LAST_PROGRESS_TIME="$now"
  fi
}

if [ "$DO_START" = "1" ]; then
  say "starting packaging profile"
  up_log=$(mktemp)
  # Note: no --wait. This profile has nine one-shot containers (the *-migrations, *-init and
  # *-seed services) and `docker compose up --wait` treats any container that exits as a failure,
  # even on exit 0 - it bails the moment waste-obligations-seed finishes. The staged checks below
  # wait properly and understand the difference between a one-shot completing and a service dying.
  #
  # Deliberately not `|| true`. If `up` cannot start the stack - most commonly an expired
  # container-registry token, since every service is pull_policy: always - the later stages would
  # otherwise sit and time out with a misleading "not healthy" message instead of the real cause.
  if ! $COMPOSE up -d >"$up_log" 2>&1; then
    echo "--- docker compose up output (last 15 lines) ---" >&2
    tail -15 "$up_log" >&2
    if grep -qiE "authentication required|unauthorized|denied" "$up_log"; then
      echo "--- looks like a registry auth failure: run 'az acr login --name devrwdinfac1401' ---" >&2
    fi
    rm -f "$up_log"
    fail "docker compose up did not complete"
  fi
  rm -f "$up_log"
fi

# One-shot containers are expected to run to completion; everything else is expected to stay up.
# Distinguishing the two matters: if `exited` were accepted for any container, a long-running
# service that had crashed or been stopped would be reported ready.
#
# The set is read out of the compose model, which already states it: a service that another
# service waits on with `condition: service_completed_successfully` is by definition expected to
# finish, not to stay up. That makes this self-maintaining - a new one-shot service is picked up
# without touching this script, which is what bullet 5 at the top is about.
declare -A ONE_SHOT=()
if command -v jq >/dev/null 2>&1; then
  while read -r svc; do
    [ -n "$svc" ] && ONE_SHOT["$svc"]=1
  done < <($COMPOSE config --format json 2>/dev/null | jq -r '
    [ .services | to_entries[] | .value.depends_on // {} | to_entries[]
      | select(.value.condition == "service_completed_successfully") | .key ] | unique[]' 2>/dev/null)
fi
[ "${#ONE_SHOT[@]}" -eq 0 ] && \
  echo "note: could not read one-shot services from compose (is jq installed?) - falling back to name patterns" >&2

is_one_shot() { # compose service name
  [ -n "${ONE_SHOT[$1]+x}" ] && return 0
  # Belt and braces, and the only thing left on a machine without jq. A one-shot that is the last
  # link in its chain is nobody's dependency and so does not appear above - waste-obligations-seed
  # is the current example - so the naming convention still counts. The two synapse services are
  # named here as well because they follow no convention, and leaving them out would put a
  # jq-less machine straight back into the timeout this whole mechanism exists to prevent.
  case "$1" in
    *-migrations|*-init|*-seed) return 0 ;;
    synapse-source-sync|synapse-sqlserver-restore) return 0 ;;
    *) return 1 ;;
  esac
}

# Name plus compose service name for every container in the project. The service name comes from
# the label compose stamps on the container rather than from trimming the container name, so it
# stays correct regardless of project name or replica suffix.
containers() {
  docker ps -a --filter "name=epr-local-environment" \
    --format '{{.Names}}|{{.Label "com.docker.compose.service"}}'
}
service_of() { # container-name label-value -> service name
  if [ -n "$2" ]; then printf '%s\n' "$2"; else printf '%s\n' "${1#epr-local-environment-}" | sed 's/-[0-9][0-9]*$//'; fi
}

# ---------------------------------------------------------------- stage 1: containers
# Long-running services must be healthy (or running, if they declare no healthcheck).
say "stage 1/4  container health"
while :; do
  not_ready=""
  while IFS='|' read -r name label; do
    [ -z "$name" ] && continue
    is_one_shot "$(service_of "$name" "$label")" && continue
    read -r status health <<<"$(docker inspect -f \
      '{{.State.Status}} {{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$name" 2>/dev/null)"
    case "$status:$health" in
      running:healthy|running:none) ;;
      *) not_ready="$not_ready ${name#epr-local-environment-}($status${health:+/$health})" ;;
    esac
  done < <(containers)

  [ -z "$not_ready" ] && break
  say_progress "waiting on:$not_ready"
  [ "$(budget_left)" -le 0 ] && fail "services not healthy:$not_ready"
  sleep 3
done
say "stage 1/4  ok - all long-running services healthy"

# ---------------------------------------------------------------- stage 2: migrations & seeds
# A migration or seed container that did not complete successfully leaves a half-populated
# database. Tests then fail in ways that look like application bugs, so treat it as fatal.
#
# This waits rather than sampling once. Stage 1 no longer gates on one-shots at all, and the
# slowest of them - synapse-sqlserver-restore, which replays the whole epr-data-sqldb schema and
# then seeds it - can still be working long after everything it does not block is healthy. A
# single sample here would report "still running" and fail a run that was simply not finished.
say "stage 2/4  migration and seed containers"
while :; do
  pending=""
  bad=""
  bad_containers=""
  while IFS='|' read -r name label; do
    [ -z "$name" ] && continue
    svc=$(service_of "$name" "$label")
    is_one_shot "$svc" || continue
    read -r status code <<<"$(docker inspect -f '{{.State.Status}} {{.State.ExitCode}}' "$name" 2>/dev/null)"
    if [ "$status" != "exited" ]; then
      pending="$pending ${name#epr-local-environment-}($status)"
    elif [ "$code" != "0" ]; then
      bad="$bad ${name#epr-local-environment-}(exit $code)"
      bad_containers="$bad_containers $name"
      # The restore refuses to overwrite an EprCommonData that does not match the resolved
      # epr-data-sqldb commit. Its own message names REBUILD_DATABASE, which is the variable
      # inside the container - this is the one the caller actually has to set.
      if [ "$svc" = "synapse-sqlserver-restore" ] && [ "$code" = "3" ]; then
        bad="$bad[local EprCommonData is stale: re-run with EPR_LOCAL_REBUILD_SYNAPSE_DATABASE=true]"
      fi
    fi
  done < <(containers)

  if [ -n "$bad" ]; then
    for name in $bad_containers; do
      echo "--- ${name#epr-local-environment-} (last 15 lines) ---" >&2
      docker logs --tail 15 "$name" 2>&1 | sed 's/^/  /' >&2
    done
    fail "migration/seed did not complete cleanly:$bad"
  fi

  [ -z "$pending" ] && break
  say_progress "still running:$pending"
  [ "$(budget_left)" -le 0 ] && fail "migration/seed containers never finished:$pending"
  sleep 3
done
say "stage 2/4  ok - all one-shot containers exited 0"

# ---------------------------------------------------------------- stage 3: reachability
# Probed from inside the frontend container, so this exercises the same DNS, TLS trust store and
# network path the application itself uses. Catches the stale-certificate class of failure that
# container health is blind to.
say "stage 3/4  frontend -> dependency reachability (from inside the container)"
# curl is not present in the epr-packaging-frontend image (Alpine, wget/BusyBox only) - see the
# compose.yml healthcheck comment for this service. wget -S dumps response headers to stderr;
# the HTTP status line is pulled out of that instead of curl's -w '%{http_code}'.
#
# Deliberately no --no-check-certificate: the other services' own healthchecks validate against
# the trusted CA the same way (see epr-facade-account-microservice / epr-pom-api-web in
# compose.yml), and this is the one check in the whole script that is supposed to notice a stale
# or mismatched cert (bullet 3 at the top) - skipping validation here would blind it to exactly
# that failure.
probe_raw() { # url -> full wget output (headers + any error) on stdout
  docker exec "$FRONTEND" wget -S -O /dev/null --timeout=15 "$1" 2>&1
}
probe_code() { printf '%s\n' "$1" | grep -o 'HTTP/[0-9.]\+ [0-9]\+' | tail -1 | awk '{print $2}'; }
# wget's last output line is always a human-readable reason when there was no HTTP response at
# all - "download timed out", "bad address 'host'", "can't connect ... Connection refused", a
# certificate error, etc. Surfacing it is what turns a bare "unreachable" into something
# actionable without having to shell into the container to find out why.
probe_reason() { printf '%s\n' "$1" | tail -1; }
declare -a DEPS=(
  "epr-pom-api-web|https://epr-pom-api-web:8081/admin/health"
  "epr-facade-account-microservice|https://epr-facade-account-microservice:8081/admin/health"
  "epr-payment-facade|https://epr-payment-facade:8081/admin/health"
)
while :; do
  unreachable=""
  reached=""
  dns_failed=""
  for d in "${DEPS[@]}"; do
    n="${d%%|*}"; u="${d##*|}"
    raw=$(probe_raw "$u")
    code=$(probe_code "$raw")
    # No status line at all means the connection/TLS handshake never got an HTTP response back.
    # Anything the service answers - including 401/404 - proves the connection and certificate
    # chain are good, which is what this stage is testing.
    if [ -z "$code" ]; then
      reason=$(probe_reason "$raw")
      unreachable="$unreachable $n(${reason:-no response})"
      case "$reason" in
        *"bad address"*) dns_failed="$dns_failed $n" ;;
      esac
    else
      reached="$reached $n:$code"
    fi
  done
  [ -z "$unreachable" ] && break
  say_progress "unreachable:$unreachable${reached:+ | reachable:$reached}"
  if [ "$(budget_left)" -le 0 ]; then
    hint="often a stale cert - see the note at the top of this script"
    [ -n "$dns_failed" ] && hint="looks like Docker's embedded DNS lost these - see bullet 4 at the top; fix with:$(
      for n in $dns_failed; do printf ' docker compose --profile packaging up -d --force-recreate %s;' "$n"; done
    )"
    fail "frontend cannot reach:$unreachable ($hint)"
  fi
  sleep 3
done
say "stage 3/4  ok - all dependencies reachable over TLS from the frontend ($reached)"

# ---------------------------------------------------------------- stage 4: serves a real page
# The end-to-end check. An unauthenticated request to the entry point must redirect to B2C;
# that only happens once auth config, Redis-backed session and the MVC pipeline are all live.
say "stage 4/4  frontend serves its entry page"
while :; do
  raw=$(probe_raw "https://localhost:8081/report-data")
  code=$(probe_code "$raw")
  case "$code" in
    302|200) break ;;
  esac
  reason=$(probe_reason "$raw")
  say_progress "last status: ${code:-${reason:-none}}"
  [ "$(budget_left)" -le 0 ] && fail "frontend never served /report-data (last status: ${code:-${reason:-none}})"
  sleep 3
done
say "stage 4/4  ok - /report-data responded $code"

printf '\nREADY in %ss - epr-packaging-frontend and all %s dependencies are up\n' \
  "$(elapsed)" "$(docker ps -a --filter 'name=epr-local-environment' --format '{{.Names}}' | wc -l | tr -d ' ')"
