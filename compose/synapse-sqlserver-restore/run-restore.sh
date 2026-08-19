#!/usr/bin/env bash
set -Eeuo pipefail

: "${SERVER:=sqledge}"
: "${PORT:=1433}"
: "${USER:=sa}"
: "${DATABASE:=EprCommonData}"
: "${SOURCE_DIRECTORY:=/cache/epr-data-sqldb}"
: "${SOURCE_COMMIT_FILE:=/cache/resolved-commit}"
: "${SEED_FILE:=/scripts/seed/baseline.sql}"
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

if [[ ! -f "${SEED_FILE}" ]]; then
    echo "Local Synapse seed file is missing: ${SEED_FILE}" >&2
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
        if [[ "${restored_commit}" == "${SOURCE_COMMIT}" && "${REBUILD_DATABASE}" != "true" ]]; then
            echo "${DATABASE} already matches epr-data-sqldb ${SOURCE_COMMIT}; restore skipped."
            exit 0
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

process_directory() {
    local directory=$1
    [[ -d "${directory}" ]] || return 0

    local sql_file
    while IFS= read -r -d '' sql_file; do
        process_sql_file "${sql_file}"
    done < <(find "${directory}" -type f -name '*.sql' -print0 | LC_ALL=C sort -z)
}

process_views() {
    local -a pending_views=()
    local directory
    local sql_file

    for directory in \
        "${SOURCE_DIRECTORY}/rpd/Views" \
        "${SOURCE_DIRECTORY}/dbo/Views" \
        "${SOURCE_DIRECTORY}/apps/Views"; do
        [[ -d "${directory}" ]] || continue
        while IFS= read -r -d '' sql_file; do
            pending_views+=("${sql_file}")
        done < <(find "${directory}" -type f -name '*.sql' -print0 | LC_ALL=C sort -z)
    done

    local pass
    for ((pass = 1; pass <= VIEW_PASSES; pass++)); do
        echo "=== Views (pass ${pass}) ==="
        local -a unresolved_views=()

        for sql_file in "${pending_views[@]}"; do
            if ! process_sql_file "${sql_file}"; then
                unresolved_views+=("${sql_file}")
            fi
        done

        if (( ${#unresolved_views[@]} == 0 )); then
            echo "Views resolved after pass ${pass}."
            return 0
        fi

        if (( pass == VIEW_PASSES )); then
            echo "View dependency resolution failed after ${VIEW_PASSES} passes:" >&2
            printf '  %s\n' "${unresolved_views[@]#${SOURCE_DIRECTORY}/}" >&2
            return 1
        fi

        echo "${#unresolved_views[@]} view(s) deferred to pass $((pass + 1))."
        pending_views=("${unresolved_views[@]}")
    done
}

echo "=== Schemas ==="
process_directory "${SOURCE_DIRECTORY}/Security"

echo "=== Tables ==="
process_directory "${SOURCE_DIRECTORY}/rpd/Tables"
process_directory "${SOURCE_DIRECTORY}/dbo/Tables"
process_directory "${SOURCE_DIRECTORY}/config/Tables"
process_directory "${SOURCE_DIRECTORY}/apps/Tables"

echo "=== Functions ==="
process_directory "${SOURCE_DIRECTORY}/dbo/Functions"

process_views

echo "=== Stored procedures ==="
process_directory "${SOURCE_DIRECTORY}/dbo/Stored Procedures"
process_directory "${SOURCE_DIRECTORY}/apps/Stored Procedures"

echo "=== Baseline seed ==="
run_sqlcmd -i "${SEED_FILE}"

run_sqlcmd -Q "
IF OBJECT_ID(N'dbo.LocalSynapseRestoreHistory', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.LocalSynapseRestoreHistory (
        Id int IDENTITY(1,1) NOT NULL PRIMARY KEY,
        SourceCommit varchar(64) NOT NULL,
        SourceRef varchar(100) NOT NULL,
        Status varchar(32) NOT NULL,
        RestoredAt datetime2(7) NOT NULL
    );
END;
INSERT INTO dbo.LocalSynapseRestoreHistory (SourceCommit, SourceRef, Status, RestoredAt)
VALUES (N'${SOURCE_COMMIT}', N'main', N'succeeded', SYSUTCDATETIME());"

echo "Restored ${DATABASE} from epr-data-sqldb ${SOURCE_COMMIT}."
