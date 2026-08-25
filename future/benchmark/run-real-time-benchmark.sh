#!/usr/bin/env bash

set -euo pipefail

usage() {
    cat <<'EOF'
Usage:
  run-real-time-benchmark.sh [options]

Options:
  --year <year>              POM reporting year (default: 2025)
  --scenario <name>          all (default), scheme-small, scheme-medium, scheme-large,
                             scheme-very-large, direct-one, direct-small, or direct-large
  --page-size <number>       Override the downstream default page size for every call
  --max-concurrency <number> Concurrent downstream page requests for calculation calls (1-8)
  --record-waste-packaging-url <url>       Record Waste Packaging API URL (default: http://localhost:8016)
  --rrepw-url <url>                        RREPW API URL (default: http://localhost:8017)
  --waste-packaging-obligations-url <url>  Waste Packaging Obligations API URL (default: http://localhost:8018)
  --help                     Show this help text

Runs exactly one real-time call to each future endpoint for each selected scenario. Without
--page-size the endpoint defaults are used: page=1 and pageSize=100. The Markdown output makes the
two end-to-end calculation durations the primary metrics; row/page counts explain the input volume.
The calculation calls follow the direct service calls, so they may observe a warmed local database
cache. Omit --max-concurrency for the sequential default; 4 is the recommended initial comparison.
It does not call the existing PRN backend.
EOF
}

year=2025
scenario=all
page_size=
max_concurrency=
record_waste_packaging_url=http://localhost:8016
rrepw_url=http://localhost:8017
waste_packaging_obligations_url=http://localhost:8018

while [[ $# -gt 0 ]]; do
    case "$1" in
        --year)
            year=${2:?A value is required for --year}
            shift 2
            ;;
        --scenario)
            scenario=${2:?A value is required for --scenario}
            shift 2
            ;;
        --page-size)
            page_size=${2:?A value is required for --page-size}
            shift 2
            ;;
        --max-concurrency)
            max_concurrency=${2:?A value is required for --max-concurrency}
            shift 2
            ;;
        --record-waste-packaging-url)
            record_waste_packaging_url=${2:?A value is required for --record-waste-packaging-url}
            shift 2
            ;;
        --rrepw-url)
            rrepw_url=${2:?A value is required for --rrepw-url}
            shift 2
            ;;
        --waste-packaging-obligations-url)
            waste_packaging_obligations_url=${2:?A value is required for --waste-packaging-obligations-url}
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

if [[ -n "$page_size" && ! "$page_size" =~ ^[1-9][0-9]*$ ]]; then
    printf 'page-size must be a positive integer when supplied.\n' >&2
    exit 2
fi

if [[ -n "$max_concurrency" && ( ! "$max_concurrency" =~ ^[1-9][0-9]*$ || "$max_concurrency" -gt 8 ) ]]; then
    printf 'max-concurrency must be an integer from 1 to 8 when supplied.\n' >&2
    exit 2
fi

scenario_details() {
    case "$1" in
        scheme-small) printf 'ComplianceScheme|1|100|Compliance scheme: 1-100 producers' ;;
        scheme-medium) printf 'ComplianceScheme|101|500|Compliance scheme: 101-500 producers' ;;
        scheme-large) printf 'ComplianceScheme|501|2000|Compliance scheme: 501-2,000 producers' ;;
        scheme-very-large) printf 'ComplianceScheme|2001|999999999|Compliance scheme: 2,001+ producers' ;;
        direct-one) printf 'DirectRegistrant|1|1|Direct registrant: 1 producer' ;;
        direct-small) printf 'DirectRegistrant|2|5|Direct registrant: 2-5 producers' ;;
        direct-large) printf 'DirectRegistrant|6|20|Direct registrant: 6-20 producers' ;;
        *) return 1 ;;
    esac
}

if [[ "$scenario" == all ]]; then
    scenarios=(scheme-small scheme-medium scheme-large scheme-very-large direct-one direct-small direct-large)
elif scenario_details "$scenario" >/dev/null; then
    scenarios=("$scenario")
else
    printf 'Unknown scenario: %s\n' "$scenario" >&2
    usage >&2
    exit 2
fi

scheme_discovery=$(mktemp)
direct_discovery=$(mktemp)
recycling_response=$(mktemp)
rrepw_response=$(mktemp)
calculation_response=$(mktemp)
calculation_with_prns_response=$(mktemp)
trap 'rm -f "$scheme_discovery" "$direct_discovery" "$recycling_response" "$rrepw_response" "$calculation_response" "$calculation_with_prns_response"' EXIT

check_health() {
    curl --fail --silent --show-error --output /dev/null "${record_waste_packaging_url%/}/health"
    curl --fail --silent --show-error --output /dev/null "${rrepw_url%/}/health"
    curl --fail --silent --show-error --output /dev/null "${waste_packaging_obligations_url%/}/health"
}

discover_submitters() {
    curl --fail --silent --show-error --output "$scheme_discovery" \
        "${record_waste_packaging_url%/}/admin/submitters?year=${year}&take=1000&submitterType=ComplianceScheme"
    curl --fail --silent --show-error --output "$direct_discovery" \
        "${record_waste_packaging_url%/}/admin/submitters?year=${year}&take=1000&submitterType=DirectRegistrant"
}

select_submitter() {
    local scenario_name=$1
    local details
    local submitter_type
    local minimum
    local maximum
    local source=$scheme_discovery
    details=$(scenario_details "$scenario_name")
    IFS='|' read -r submitter_type minimum maximum _ <<< "$details"
    if [[ "$submitter_type" == DirectRegistrant ]]; then
        source=$direct_discovery
    fi

    jq -cer \
        --argjson minimum "$minimum" \
        --argjson maximum "$maximum" \
        '.items
         | map(select(.producerCount >= $minimum and .producerCount <= $maximum))
         | sort_by([.generatedPomRowCount, .producerCount])
         | last // empty' \
        "$source"
}

call_json() {
    local response_file=$1
    shift
    curl --fail --silent --show-error --output "$response_file" --write-out '%{http_code}|%{time_total}' "$@"
}

parse_metric() {
    IFS='|' read -r metric_status metric_seconds <<< "$1"
}

format_duration() {
    awk -v seconds="$1" 'BEGIN {
        if (seconds > 2) {
            printf "🟠 **%ss**", seconds
        } else {
            printf "**%ss**", seconds
        }
    }'
}

page_query() {
    if [[ -n "$page_size" ]]; then
        printf '&pageSize=%s' "$page_size"
    fi
}

rrepw_page_query() {
    if [[ -n "$page_size" ]]; then
        printf '?pageSize=%s' "$page_size"
    fi
}

concurrency_query() {
    if [[ -n "$max_concurrency" ]]; then
        printf '&maxConcurrency=%s' "$max_concurrency"
    fi
}

check_health
discover_submitters

page_description='default (page=1, pageSize=100)'
if [[ -n "$page_size" ]]; then
    page_description="override (pageSize=${page_size})"
fi

concurrency_description='1 (sequential default)'
if [[ -n "$max_concurrency" ]]; then
    concurrency_description=$max_concurrency
fi

printf '# Future-state real-time benchmark\n\n'
printf 'POM year: %s | Compliance year: %s | Downstream paging: %s | Page concurrency: %s\n\n' \
    "$year" "$((year + 1))" "$page_description" "$concurrency_description"
printf 'Each value is one end-to-end HTTP call. The calculation calls follow the direct service calls '
printf 'and can observe their warmed local database cache. `calculate-obligations` and '
printf '`calculate-obligations-with-prns` always retrieve every downstream page before responding.\n\n'
printf 'Read the two right-most columns first: they are the real-time endpoint durations. The input columns '
printf 'show how much source data each calculation traversed.\n\n'
printf '`🟠` marks a response time above the 2-second warning threshold.\n\n'
printf '| Scenario | Producer associations | Record Waste Packaging (pages) | PRNs (pages) | Calculate obligations | Calculate with PRNs |\n'
printf '| --- | ---: | ---: | ---: | ---: | ---: |\n'

for scenario_name in "${scenarios[@]}"; do
    scenario_details_value=$(scenario_details "$scenario_name")
    IFS='|' read -r scenario_submitter_type scenario_minimum scenario_maximum scenario_display_name <<< "$scenario_details_value"
    if ! submitter=$(select_submitter "$scenario_name"); then
        printf '| %s | _No generated submitter in this band_ | - | - | - | - |\n' "$scenario_display_name"
        continue
    fi

    submitter_id=$(jq -r '.submitterId' <<< "$submitter")
    producer_count=$(jq -r '.producerCount' <<< "$submitter")
    generated_pom_rows=$(jq -r '.generatedPomRowCount' <<< "$submitter")

    recycling_metric=$(call_json "$recycling_response" \
        "${record_waste_packaging_url%/}/recycling-data?year=${year}&submitterId=${submitter_id}$(page_query)")
    parse_metric "$recycling_metric"
    recycling_seconds=$metric_seconds
    recycling_total=$(jq -r '.totalItems' "$recycling_response")
    recycling_page_size=$(jq -r '.pageSize' "$recycling_response")
    recycling_page_count=$(( (recycling_total + recycling_page_size - 1) / recycling_page_size ))

    rrepw_metric=$(call_json "$rrepw_response" \
        "${rrepw_url%/}/organisations/${submitter_id}/prns$(rrepw_page_query)")
    parse_metric "$rrepw_metric"
    rrepw_total=$(jq -r '.totalItems' "$rrepw_response")
    rrepw_page_size=$(jq -r '.pageSize' "$rrepw_response")
    rrepw_page_count=$(( (rrepw_total + rrepw_page_size - 1) / rrepw_page_size ))

    calculation_metric=$(call_json "$calculation_response" \
        "${waste_packaging_obligations_url%/}/organisations/${submitter_id}/calculate-obligations?year=${year}$(page_query)$(concurrency_query)")
    parse_metric "$calculation_metric"
    calculation_seconds=$metric_seconds

    calculation_with_prns_metric=$(call_json "$calculation_with_prns_response" \
        "${waste_packaging_obligations_url%/}/organisations/${submitter_id}/calculate-obligations-with-prns?year=${year}$(page_query)$(concurrency_query)")
    parse_metric "$calculation_with_prns_metric"
    calculation_with_prns_seconds=$metric_seconds

    calculation_duration=$(format_duration "$calculation_seconds")
    calculation_with_prns_duration=$(format_duration "$calculation_with_prns_seconds")

    printf '| %s | %s | %s (%s) | %s (%s) | %s | %s |\n' \
        "$scenario_display_name" \
        "$producer_count" \
        "$recycling_total" "$recycling_page_count" \
        "$rrepw_total" "$rrepw_page_count" \
        "$calculation_duration" \
        "$calculation_with_prns_duration"
done

printf '\nThe two calculation durations are the primary benchmark result. Do not compare them with the '
printf 'current PRN backend: this runner exercises future services only.\n'
