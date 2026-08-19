#!/usr/bin/env bash
set -Eeuo pipefail

: "${SERVER:=sqledge}"
: "${PORT:=1433}"
: "${USER:=sa}"
: "${DATABASE:=EprCommonData}"
: "${SOURCE_DIRECTORY:=/cache/epr-data-sqldb}"
: "${SOURCE_COMMIT_FILE:=/cache/resolved-commit}"
: "${SEED_FILE:=/scripts/seed/baseline.sql}"
: "${SCHEMA_MAP_FILE:=/scripts/schema-map.txt}"
: "${SCHEMA_SET:=common-data-api}"
: "${RESTORE_SYNAPSE_DATABASE:=true}"
: "${REBUILD_DATABASE:=false}"
: "${DUMP_FAILED_SQL:=false}"
: "${VIEW_PASSES:=6}"

for boolean_variable in RESTORE_SYNAPSE_DATABASE REBUILD_DATABASE; do
    case "${!boolean_variable}" in
        true|false) ;;
        *)
            echo "${boolean_variable} must be true or false." >&2
            exit 2
            ;;
    esac
done

if [[ "${RESTORE_SYNAPSE_DATABASE}" == "false" ]]; then
    if [[ "${REBUILD_DATABASE}" == "true" ]]; then
        echo "REBUILD_DATABASE=true requires RESTORE_SYNAPSE_DATABASE=true." >&2
        exit 2
    fi

    echo "Local Synapse database restore is disabled."
    exit 0
fi

: "${PASSWORD:?PASSWORD must be set}"

if [[ ! "${DATABASE}" =~ ^[A-Za-z][A-Za-z0-9_]*$ ]]; then
    echo "DATABASE must be a simple SQL Server identifier." >&2
    exit 2
fi

if [[ ! "${VIEW_PASSES}" =~ ^[1-9][0-9]*$ ]]; then
    echo "VIEW_PASSES must be a positive whole number." >&2
    exit 2
fi

if [[ ! -f "${SOURCE_DIRECTORY}/Database.sqlproj" || ! -s "${SOURCE_COMMIT_FILE}" ]]; then
    echo "epr-data-sqldb source is not available. synapse-source-sync must complete first." >&2
    exit 2
fi

if [[ ! -f "${SCHEMA_MAP_FILE}" ]]; then
    echo "Local Synapse schema map is missing: ${SCHEMA_MAP_FILE}" >&2
    exit 2
fi

for candidate in /opt/mssql-tools18/bin/sqlcmd /opt/mssql-tools/bin/sqlcmd; do
    if [[ -x "${candidate}" ]]; then
        SQLCMD="${candidate}"
        break
    fi
done

: "${SQLCMD:=$(command -v sqlcmd || true)}"
if [[ -z "${SQLCMD}" ]]; then
    echo "sqlcmd is not available in this image." >&2
    exit 2
fi

SOURCE_COMMIT=$(tr -d '\r\n' < "${SOURCE_COMMIT_FILE}")

if [[ ! "${SCHEMA_SET}" =~ ^[A-Za-z][A-Za-z0-9_-]*$ ]]; then
    echo "SCHEMA_SET must be a simple schema-set name." >&2
    exit 2
fi

declare -a selected_map_files=()
declare -A selected_map_file_seen=()
declare -a unavailable_api_elements=()
selected_seed_mode="baseline"

add_map_file() {
    local relative_path=$1

    if [[ -z "${relative_path}" || "${relative_path}" == /* || "${relative_path}" == *".."* ]]; then
        echo "Invalid schema-map path: ${relative_path}" >&2
        exit 2
    fi

    if [[ ! -f "${SOURCE_DIRECTORY}/${relative_path}" ]]; then
        echo "Schema-map entry is missing from epr-data-sqldb ${SOURCE_COMMIT}: ${relative_path}" >&2
        exit 2
    fi

    if [[ -z "${selected_map_file_seen[${relative_path}]+x}" ]]; then
        selected_map_files+=("${relative_path}")
        selected_map_file_seen[${relative_path}]=1
    fi
}

add_all_source_files() {
    local relative_directory
    local source_file

    for relative_directory in \
        Security \
        rpd/Tables \
        dbo/Tables \
        config/Tables \
        apps/Tables \
        dbo/Functions \
        rpd/Views \
        dbo/Views \
        apps/Views \
        "dbo/Stored Procedures" \
        "apps/Stored Procedures"; do
        [[ -d "${SOURCE_DIRECTORY}/${relative_directory}" ]] || continue
        while IFS= read -r -d '' source_file; do
            add_map_file "${source_file#${SOURCE_DIRECTORY}/}"
        done < <(find "${SOURCE_DIRECTORY}/${relative_directory}" -type f -name '*.sql' -print0 | LC_ALL=C sort -z)
    done
}

read_schema_set() {
    local current_section=""
    local map_line
    local section_found=false

    while IFS= read -r map_line || [[ -n "${map_line}" ]]; do
        map_line=${map_line%$'\r'}
        map_line=${map_line#"${map_line%%[![:space:]]*}"}
        map_line=${map_line%"${map_line##*[![:space:]]}"}

        [[ -z "${map_line}" || "${map_line}" == \#* ]] && continue

        if [[ "${map_line}" =~ ^\[([A-Za-z][A-Za-z0-9_-]*)\]$ ]]; then
            current_section=${BASH_REMATCH[1]}
            [[ "${current_section}" == "${SCHEMA_SET}" ]] && section_found=true
            continue
        fi

        [[ "${current_section}" == "${SCHEMA_SET}" ]] || continue

        case "${map_line}" in
            @all)
                add_all_source_files
                ;;
            @seed=baseline)
                selected_seed_mode="baseline"
                ;;
            @seed=none)
                selected_seed_mode="none"
                ;;
            @seed=*)
                echo "Unsupported seed mode in ${SCHEMA_MAP_FILE}: ${map_line}" >&2
                exit 2
                ;;
            @unavailable=*)
                unavailable_api_element=${map_line#@unavailable=}
                if [[ ! "${unavailable_api_element}" =~ ^[A-Za-z][A-Za-z0-9_]*\.[A-Za-z][A-Za-z0-9_]*$ ]]; then
                    echo "Invalid unavailable API element in ${SCHEMA_MAP_FILE}: ${map_line}" >&2
                    exit 2
                fi
                unavailable_api_elements+=("${unavailable_api_element}")
                ;;
            *)
                add_map_file "${map_line}"
                ;;
        esac
    done < "${SCHEMA_MAP_FILE}"

    if [[ "${section_found}" != "true" ]]; then
        echo "Schema set '${SCHEMA_SET}' was not found in ${SCHEMA_MAP_FILE}." >&2
        exit 2
    fi

    if (( ${#selected_map_files[@]} == 0 )); then
        echo "Schema set '${SCHEMA_SET}' does not contain any source files." >&2
        exit 2
    fi

    if [[ "${selected_seed_mode}" == "baseline" && ! -f "${SEED_FILE}" ]]; then
        echo "Local Synapse seed file is missing: ${SEED_FILE}" >&2
        exit 2
    fi
}

map_hash() {
    if command -v sha256sum >/dev/null 2>&1; then
        printf '%s\n' "${selected_map_files[@]}" | sha256sum | awk '{print $1}'
    elif command -v shasum >/dev/null 2>&1; then
        printf '%s\n' "${selected_map_files[@]}" | shasum -a 256 | awk '{print $1}'
    else
        printf '%s\n' "${selected_map_files[@]}" | cksum | awk '{print $1 "-" $2}'
    fi
}

read_schema_set
SCHEMA_MAP_HASH=$(map_hash)

echo "Schema set '${SCHEMA_SET}': ${#selected_map_files[@]} source SQL file(s); seed=${selected_seed_mode}."
if (( ${#unavailable_api_elements[@]} > 0 )); then
    echo "Warning: epr-data-sqldb ${SOURCE_COMMIT} has no source script for exposed Common Data API element(s):" >&2
    printf '  %s\n' "${unavailable_api_elements[@]}" >&2
fi

run_sqlcmd() {
    "${SQLCMD}" -S "${SERVER},${PORT}" -U "${USER}" -P "${PASSWORD}" -d "${DATABASE}" -I -b "$@"
}

run_master_sqlcmd() {
    "${SQLCMD}" -S "${SERVER},${PORT}" -U "${USER}" -P "${PASSWORD}" -d master -I -b "$@"
}

master_scalar() {
    run_master_sqlcmd -h -1 -W -Q "$1" | tr -d '\r' | sed '/^[[:space:]]*$/d' | tail -n 1
}

database_scalar() {
    run_sqlcmd -h -1 -W -Q "$1" | tr -d '\r' | sed '/^[[:space:]]*$/d' | tail -n 1
}

database_exists=$(master_scalar "SET NOCOUNT ON; SELECT IIF(DB_ID(N'${DATABASE}') IS NULL, 0, 1);")

if [[ "${database_exists}" == "1" ]]; then
    history_exists=$(database_scalar "SET NOCOUNT ON; SELECT IIF(OBJECT_ID(N'dbo.LocalSynapseRestoreHistory', N'U') IS NULL, 0, 1);")

    if [[ "${history_exists}" == "1" ]]; then
        restored_commit=$(database_scalar "SET NOCOUNT ON; SELECT TOP 1 SourceCommit FROM dbo.LocalSynapseRestoreHistory WHERE Status = N'succeeded' ORDER BY Id DESC;")
        history_has_schema_set=$(database_scalar "SET NOCOUNT ON; SELECT IIF(COL_LENGTH(N'dbo.LocalSynapseRestoreHistory', N'SchemaSet') IS NULL, 0, 1);")

        if [[ "${history_has_schema_set}" == "1" ]]; then
            restored_schema_set=$(database_scalar "SET NOCOUNT ON; SELECT TOP 1 SchemaSet FROM dbo.LocalSynapseRestoreHistory WHERE Status = N'succeeded' ORDER BY Id DESC;")
            restored_map_hash=$(database_scalar "SET NOCOUNT ON; SELECT TOP 1 SchemaMapHash FROM dbo.LocalSynapseRestoreHistory WHERE Status = N'succeeded' ORDER BY Id DESC;")
        else
            # Databases restored before schema sets existed were always full restores.
            restored_schema_set="full"
            restored_map_hash=""
        fi

        if [[ "${restored_commit}" == "${SOURCE_COMMIT}" && "${restored_schema_set}" == "${SCHEMA_SET}" && "${REBUILD_DATABASE}" != "true" ]]; then
            if [[ "${restored_map_hash}" == "${SCHEMA_MAP_HASH}" || ( "${SCHEMA_SET}" == "full" && -z "${restored_map_hash}" ) ]]; then
                echo "${DATABASE} already matches epr-data-sqldb ${SOURCE_COMMIT} with schema set '${SCHEMA_SET}'; restore skipped."
                exit 0
            fi
        fi
    fi

    if [[ "${REBUILD_DATABASE}" != "true" ]]; then
        cat >&2 <<EOF
${DATABASE} already exists but does not match the latest restored epr-data-sqldb source.
Refusing to overwrite local data. Stop services using EprCommonData and run the restore
explicitly with REBUILD_DATABASE=true to replace it.
EOF
        exit 3
    fi

    echo "Rebuilding ${DATABASE} from epr-data-sqldb ${SOURCE_COMMIT}"
    run_master_sqlcmd -Q "ALTER DATABASE [${DATABASE}] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [${DATABASE}];"
fi

if [[ "${database_exists}" != "1" || "${REBUILD_DATABASE}" == "true" ]]; then
    echo "Creating ${DATABASE}"
    run_master_sqlcmd -Q "CREATE DATABASE [${DATABASE}];"
fi

transform_sql() {
    local source_file=$1
    local output_file=$2

    tr -d '\r' < "${source_file}" | sed '1s/^\xEF\xBB\xBF//' | awk '
        function flush_buffer() {
            if (buffer !~ /(DISTRIBUTION|CLUSTERED[ \t]+COLUMNSTORE|CLUSTERED[ \t]+INDEX|HEAP|REPLICATE)/) {
                printf "%s", buffer
            }
            buffer = ""
            collecting = 0
        }
        {
            if (!collecting && $0 ~ /^[ \t]*WITH/) {
                collecting = 1
                buffer = $0 ORS
                if ($0 ~ /\)[ \t]*;?[ \t]*$/) {
                    flush_buffer()
                }
                next
            }
            if (collecting) {
                buffer = buffer $0 ORS
                if ($0 ~ /^[ \t]*\)[ \t]*;?[ \t]*$/) {
                    flush_buffer()
                }
                next
            }
            if ($0 ~ /^[ \t]*CREATE[ \t]+VIEW[ \t]+/) {
                sub(/^[ \t]*CREATE[ \t]+VIEW[ \t]+/, "CREATE OR ALTER VIEW ")
            }
            print
        }
        END {
            if (collecting) {
                flush_buffer()
            }
        }
    ' > "${output_file}"
}

process_sql_file() {
    local source_file=$1
    local temporary_file
    temporary_file=$(mktemp)
    transform_sql "${source_file}" "${temporary_file}"

    echo "=== ${source_file#${SOURCE_DIRECTORY}/} ==="
    if ! run_sqlcmd -i "${temporary_file}"; then
        if [[ "${DUMP_FAILED_SQL}" == "true" ]]; then
            echo "--- transformed SQL: ${source_file#${SOURCE_DIRECTORY}/} ---" >&2
            sed -n '1,320p' "${temporary_file}" >&2
        fi
        rm -f "${temporary_file}"
        return 1
    fi
    rm -f "${temporary_file}"
}

process_views() {
    local -a pending_views=("$@")
    (( ${#pending_views[@]} > 0 )) || return 0

    local pass
    for ((pass = 1; pass <= VIEW_PASSES; pass++)); do
        echo "=== Views (pass ${pass}) ==="
        local -a unresolved_views=()

        for sql_file in "${pending_views[@]}"; do
            if ! process_sql_file "${SOURCE_DIRECTORY}/${sql_file}"; then
                unresolved_views+=("${sql_file}")
            fi
        done

        if (( ${#unresolved_views[@]} == 0 )); then
            echo "Views resolved after pass ${pass}."
            return 0
        fi

        if (( pass == VIEW_PASSES )); then
            echo "View dependency resolution failed after ${VIEW_PASSES} passes:" >&2
            printf '  %s\n' "${unresolved_views[@]}" >&2
            return 1
        fi

        echo "${#unresolved_views[@]} view(s) deferred to pass $((pass + 1))."
        pending_views=("${unresolved_views[@]}")
    done
}

declare -a schema_files=()
declare -a table_files=()
declare -a function_files=()
declare -a view_files=()
declare -a stored_procedure_files=()

categorise_schema_files() {
    local source_file

    for source_file in "${selected_map_files[@]}"; do
        case "${source_file}" in
            Security/*.sql)
                schema_files+=("${source_file}")
                ;;
            */Tables/*.sql)
                table_files+=("${source_file}")
                ;;
            */Functions/*.sql)
                function_files+=("${source_file}")
                ;;
            */Views/*.sql)
                view_files+=("${source_file}")
                ;;
            */Stored\ Procedures/*.sql)
                stored_procedure_files+=("${source_file}")
                ;;
            *)
                echo "Schema-map entry has an unsupported source type: ${source_file}" >&2
                exit 2
                ;;
        esac
    done
}

process_file_list() {
    local source_file

    for source_file in "$@"; do
        process_sql_file "${SOURCE_DIRECTORY}/${source_file}"
    done
}

categorise_schema_files

echo "=== Schemas ==="
if (( ${#schema_files[@]} > 0 )); then
    process_file_list "${schema_files[@]}"
fi

echo "=== Tables ==="
if (( ${#table_files[@]} > 0 )); then
    process_file_list "${table_files[@]}"
fi

echo "=== Functions ==="
if (( ${#function_files[@]} > 0 )); then
    process_file_list "${function_files[@]}"
fi

if (( ${#view_files[@]} > 0 )); then
    process_views "${view_files[@]}"
else
    echo "=== Views (none selected) ==="
fi

echo "=== Stored procedures ==="
if (( ${#stored_procedure_files[@]} > 0 )); then
    process_file_list "${stored_procedure_files[@]}"
fi

if [[ "${selected_seed_mode}" == "baseline" ]]; then
    echo "=== Baseline seed ==="
    run_sqlcmd -i "${SEED_FILE}"
else
    echo "=== Baseline seed skipped by schema set ==="
fi

run_sqlcmd -Q "
IF OBJECT_ID(N'dbo.LocalSynapseRestoreHistory', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.LocalSynapseRestoreHistory (
        Id int IDENTITY(1,1) NOT NULL PRIMARY KEY,
        SourceCommit varchar(64) NOT NULL,
        SourceRef varchar(100) NOT NULL,
        SchemaSet varchar(128) NOT NULL,
        SchemaMapHash varchar(128) NOT NULL,
        Status varchar(32) NOT NULL,
        RestoredAt datetime2(7) NOT NULL
    );
END;
INSERT INTO dbo.LocalSynapseRestoreHistory (SourceCommit, SourceRef, SchemaSet, SchemaMapHash, Status, RestoredAt)
VALUES (N'${SOURCE_COMMIT}', N'main', N'${SCHEMA_SET}', N'${SCHEMA_MAP_HASH}', N'succeeded', SYSUTCDATETIME());"

echo "Restored ${DATABASE} from epr-data-sqldb ${SOURCE_COMMIT} with schema set '${SCHEMA_SET}'."
