#!/usr/bin/env bash
# Regression check for dbo.sp_GetApprovedSubmissionsMyc (obligated days and the data around them).
#
#   run-myc-days-regression.sh --candidate <changed procedure .sql> [--baseline <original procedure .sql>]
#
# Installs both procedures under temporary names inside one transaction, seeds the fixture, compares
# baseline vs candidate (L1) and each vs hand-written expectations (L2), then rolls everything back.
# Exit code 0 = passed, 1 = findings, 2 = could not run.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
env_root="$(cd "$here/../../../.." && pwd)"

baseline="$env_root/.cache/synapse-source/epr-data-sqldb/dbo/Stored Procedures/sp_GetApprovedSubmissionsMyc.sql"
candidate=""
database="${MYC_REG_DATABASE:-EprCommonData}"
password="${MYC_REG_SQL_PASSWORD:-s4usag3s!}"

usage() { sed -n '2,9p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 2; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --candidate) candidate="$2"; shift 2 ;;
    --baseline)  baseline="$2"; shift 2 ;;
    --database)  database="$2"; shift 2 ;;
    -h|--help)   usage ;;
    *) echo "Unknown argument: $1" >&2; usage ;;
  esac
done

[[ -n "$candidate" ]] || { echo "--candidate is required" >&2; usage; }
[[ -f "$candidate" ]] || { echo "Candidate not found: $candidate" >&2; exit 2; }
[[ -f "$baseline" ]]  || { echo "Baseline not found: $baseline (pass --baseline)" >&2; exit 2; }

# How to reach sqlcmd. Override with MYC_REG_SQL_EXEC, e.g. "docker exec -i my-sql".
if [[ -n "${MYC_REG_SQL_EXEC:-}" ]]; then
  # shellcheck disable=SC2206
  sql_exec=(${MYC_REG_SQL_EXEC})
else
  sql_exec=(docker compose -f "$env_root/compose.yml" exec -T sqledge)
fi
sqlcmd_bin="${MYC_REG_SQLCMD:-/opt/mssql-tools18/bin/sqlcmd}"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# Re-create a procedure source under a temporary name: drop everything before CREATE PROC and rename it.
rename_proc() {
  python3 -I - "$1" "$2" <<'PY'
import re, sys
path, suffix = sys.argv[1], sys.argv[2]
text = open(path, encoding="utf-8-sig").read().replace("\r\n", "\n")
m = re.search(r"CREATE\s+PROC(?:EDURE)?\s", text, re.IGNORECASE)
if not m:
    sys.exit("no CREATE PROCEDURE found in " + path)
body = text[m.start():]
body, n = re.subn(r"\bsp_GetApprovedSubmissionsMyc\b", "sp_GetApprovedSubmissionsMyc" + suffix, body)
if n == 0:
    sys.exit("procedure name sp_GetApprovedSubmissionsMyc not found in " + path)
print(body.rstrip() + "\n")
PY
}

if cmp -s <(tr -d '\r' < "$baseline") <(tr -d '\r' < "$candidate"); then
  echo "Note: candidate is identical to baseline, so L1 is trivially clean; L2 still checks the expectations." >&2
fi

{
  echo "SET XACT_ABORT ON;"
  echo "GO"
  echo "BEGIN TRANSACTION;"
  echo "GO"
  rename_proc "$baseline"  "_regr_baseline"
  echo "GO"
  rename_proc "$candidate" "_regr_candidate"
  echo "GO"
  cat "$here/myc-days-fixture.sql"
  echo "GO"
  cat "$here/myc-days-expectations.sql"
  echo "GO"
  cat "$here/myc-days-compare.sql"
  echo "GO"
} > "$work/run.sql"

echo "Database : $database"
echo "Baseline : $baseline"
echo "Candidate: $candidate"
echo "Everything runs in one transaction that is rolled back."
echo

# -I turns QUOTED_IDENTIFIER on, as a deployed procedure would have; -b makes SQL errors exit non-zero.
set +e
"${sql_exec[@]}" "$sqlcmd_bin" -C -S localhost -U sa -P "$password" -d "$database" -I -b -W -s '|' < "$work/run.sql"
status=$?
set -e

if [[ $status -ne 0 ]]; then
  echo
  echo "Regression check did not pass (sqlcmd exit $status). Nothing is left in the database: the transaction was rolled back." >&2
  exit 1
fi
