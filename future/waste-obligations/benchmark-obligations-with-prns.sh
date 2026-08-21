#!/usr/bin/env bash

set -euo pipefail

usage() {
    cat <<'EOF'
Usage:
  benchmark-obligations-with-prns.sh [options]

Options:
  --year <year>              POM reporting year (default: 2025)
  --organisation-id <guid>   Optional organisation ID; defaults to the largest discovered compliance scheme
  --page-size <number>       Page size used for both downstream requests (default: 50000)
  --iterations <number>      Timed future-service calls after one warm-up (default: 3)
  --obligations-url <url>    Future obligations API URL (default: http://localhost:8014)
  --recycling-data-url <url> Recycling Data API URL used for ID discovery (default: http://localhost:8012)
  --help                     Show this help text

The script measures only the future-state flow: the obligations endpoint and its calls to
the future Recycling Data and ReEx services. It does not call the existing PRN backend.
EOF
}

year=2025
organisation_id=
page_size=50000
iterations=3
obligations_url=http://localhost:8014
recycling_data_url=http://localhost:8012

while [[ $# -gt 0 ]]; do
    case "$1" in
        --year)
            year=${2:?A value is required for --year}
            shift 2
            ;;
        --organisation-id)
            organisation_id=${2:?A value is required for --organisation-id}
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
        --obligations-url)
            obligations_url=${2:?A value is required for --obligations-url}
            shift 2
            ;;
        --recycling-data-url)
            recycling_data_url=${2:?A value is required for --recycling-data-url}
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

for command in curl jq awk; do
    command -v "$command" >/dev/null || {
        printf 'Required command is not available: %s\n' "$command" >&2
        exit 1
    }
done

if [[ ! "$year" =~ ^[0-9]{4}$ ]] || (( year < 2024 || year > 2100 )); then
    printf 'year must be an integer between 2024 and 2100.\n' >&2
    exit 2
fi

if [[ ! "$page_size" =~ ^[1-9][0-9]*$ ]] || [[ ! "$iterations" =~ ^[1-9][0-9]*$ ]]; then
    printf 'page-size and iterations must be positive integers.\n' >&2
    exit 2
fi

future_response=$(mktemp)
discovery_response=$(mktemp)
trap 'rm -f "$future_response" "$discovery_response"' EXIT

discover_largest_organisation() {
    curl \
        --fail \
        --silent \
        --show-error \
        --output "$discovery_response" \
        "${recycling_data_url%/}/admin/submitters?year=${year}&take=1&submitterType=ComplianceScheme"

    organisation_id=$(jq -er '.items[0].submitterId' "$discovery_response") || {
        printf 'No recycling submitter was discovered for year %s. Supply --organisation-id or generate data first.\n' "$year" >&2
        exit 1
    }

    printf 'Using largest discovered compliance scheme: %s (%s generated POM rows).\n' \
        "$organisation_id" "$(jq -r '.items[0].generatedPomRowCount' "$discovery_response")"
}

call_future_service() {
    curl \
        --fail \
        --silent \
        --show-error \
        --request POST \
        --output "$future_response" \
        --write-out '%{time_total}' \
        "${obligations_url%/}/organisations/${organisation_id}/calculate-obligations-with-prns?year=${year}&pageSize=${page_size}"
}

print_summary() {
    local summary
    summary=$(printf '%s\n' "$@" | awk '
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
    printf 'Transient calculation: %s\n' "$summary"
}

if [[ -z "$organisation_id" ]]; then
    discover_largest_organisation
fi

printf 'Benchmark: POM year=%s compliance year=%s organisation=%s pageSize=%s iterations=%s\n' \
    "$year" "$((year + 1))" "$organisation_id" "$page_size" "$iterations"
printf 'A warm-up request is excluded. Durations cover only the future-state service flow.\n\n'

call_future_service >/dev/null
durations=()
for ((attempt = 1; attempt <= iterations; attempt++)); do
    durations+=("$(call_future_service)")
done
print_summary "${durations[@]}"
printf 'Result shape: %s material assessments; %s PRNs awaiting acceptance.\n' \
    "$(jq -r '.obligationData | length' "$future_response")" \
    "$(jq -r '.numberOfPrnsAwaitingAcceptance' "$future_response")"
