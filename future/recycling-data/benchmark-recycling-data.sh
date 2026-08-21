#!/usr/bin/env bash

set -euo pipefail

usage() {
    cat <<'EOF'
Usage:
  benchmark-recycling-data.sh [options]

Options:
  --year <year>          Reporting year (default: 2025)
  --submitter-id <guid>  Optional submitter ID; defaults to the largest discovered submitter
  --page-size <number>   Requested page size (default: 100)
  --iterations <number>  Timed calls per SQL mode, after one warm-up (default: 3)
  --base-url <url>       Recycling Data API URL (default: http://localhost:8012)
  --help                 Show this help text

The script runs the same request through both paths:
  false  baseline source-query behaviour, without local SQL Server predicates
  true   local SQL Server optimisation
EOF
}

year=2025
submitter_id=
page_size=100
iterations=3
base_url=http://localhost:8012

while [[ $# -gt 0 ]]; do
    case "$1" in
        --year)
            year=${2:?A value is required for --year}
            shift 2
            ;;
        --submitter-id)
            submitter_id=${2:?A value is required for --submitter-id}
            shift 2
            ;;
        --page-size)
            page_size=${2:?A value is required for --page-size}
            shift 2
            ;;
        --iterations)
            iterations=${2:?A value is required for --iterations}
            shift 2
            ;;
        --base-url)
            base_url=${2:?A value is required for --base-url}
            shift 2
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            printf 'Unknown option: %s\n\n' "$1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

for command in curl jq awk shasum; do
    command -v "$command" >/dev/null || {
        printf 'Required command is not available: %s\n' "$command" >&2
        exit 1
    }
done

temporary_response=$(mktemp)
trap 'rm -f "$temporary_response"' EXIT

discover_largest_submitter() {
    curl \
        --fail \
        --silent \
        --show-error \
        --output "$temporary_response" \
        "${base_url%/}/admin/submitters?year=${year}&take=1&submitterType=ComplianceScheme"

    submitter_id=$(jq -er '.items[0].submitterId' "$temporary_response") || {
        printf 'No recycling submitter was discovered for year %s. Supply --submitter-id or generate data first.\n' "$year" >&2
        exit 1
    }

    printf 'Using largest discovered compliance scheme: %s (%s generated POM rows).\n' \
        "$submitter_id" "$(jq -r '.items[0].generatedPomRowCount' "$temporary_response")"
}

call_api() {
    local mode=$1

    curl \
        --fail \
        --silent \
        --show-error \
        --output "$temporary_response" \
        --write-out '%{time_total}' \
        "${base_url%/}/recycling-data?year=${year}&submitterId=${submitter_id}&page=1&pageSize=${page_size}&useLocalSqlOptimisation=${mode}"
}

response_hash() {
    # Omit the mode indicator, which is intentionally different between the two paths.
    jq -c 'del(.useLocalSqlOptimisation)' "$temporary_response" | shasum -a 256 | awk '{print $1}'
}

print_summary() {
    local mode=$1
    shift
    local durations=("$@")
    local summary

    summary=$(printf '%s\n' "${durations[@]}" | awk '
        { values[NR] = $1; total += $1 }
        END {
            for (i = 1; i <= NR; i++) {
                for (j = i + 1; j <= NR; j++) {
                    if (values[i] > values[j]) {
                        temporary = values[i]
                        values[i] = values[j]
                        values[j] = temporary
                    }
                }
            }
            median = values[int((NR + 1) / 2)]
            if (NR % 2 == 0) {
                median = (values[NR / 2] + values[(NR / 2) + 1]) / 2
            }
            printf "min=%.3fs median=%.3fs mean=%.3fs max=%.3fs", values[1], median, total / NR, values[NR]
        }')

    printf '  %s: %s\n' "$mode" "$summary"
}

if [[ -z "$submitter_id" ]]; then
    discover_largest_submitter
fi

printf 'Benchmark: year=%s submitter=%s page=1 pageSize=%s iterations=%s\n' \
    "$year" "$submitter_id" "$page_size" "$iterations"
printf 'A warm-up request is excluded from each result. Durations are end-to-end HTTP times.\n\n'

baseline_hash=
optimised_hash=
for mode in false true; do
    label='baseline/source-style'
    if [[ "$mode" == true ]]; then
        label='local SQL Server optimisation'
    fi

    # Establish the response shape and warm both the API and this command-text's SQL plan.
    call_api "$mode" >/dev/null
    total_items=$(jq -r '.totalItems' "$temporary_response")
    item_count=$(jq -r '.items | length' "$temporary_response")
    returned_mode=$(jq -r '.useLocalSqlOptimisation' "$temporary_response")
    if [[ "$mode" == false ]]; then
        baseline_hash=$(response_hash)
    else
        optimised_hash=$(response_hash)
    fi

    durations=()
    for ((attempt = 1; attempt <= iterations; attempt++)); do
        durations+=("$(call_api "$mode")")
    done

    printf '%s (useLocalSqlOptimisation=%s): totalItems=%s itemsInPage=%s\n' \
        "$label" "$returned_mode" "$total_items" "$item_count"
    print_summary "$label" "${durations[@]}"
done

if [[ "$baseline_hash" == "$optimised_hash" ]]; then
    printf '\nResult check: equivalent payloads (excluding useLocalSqlOptimisation).\n'
else
    printf '\nResult check: payloads differ; investigate before comparing timings.\n' >&2
    exit 1
fi
