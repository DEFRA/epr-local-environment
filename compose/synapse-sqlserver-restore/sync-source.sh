#!/bin/sh
set -eu

: "${SOURCE_URL:=https://github.com/DEFRA/epr-data-sqldb.git}"
: "${SOURCE_REF:=main}"
: "${SOURCE_CACHE_DIRECTORY:=/cache/epr-data-sqldb}"
: "${SOURCE_COMMIT_FILE:=/cache/resolved-commit}"
: "${RESTORE_SYNAPSE_DATABASE:=true}"

case "${RESTORE_SYNAPSE_DATABASE}" in
    true|false) ;;
    *)
        echo "RESTORE_SYNAPSE_DATABASE must be true or false." >&2
        exit 2
        ;;
esac

if [ "${RESTORE_SYNAPSE_DATABASE}" = "false" ]; then
    echo "Local Synapse source synchronisation is disabled."
    exit 0
fi

case "${SOURCE_CACHE_DIRECTORY}" in
    /cache/*) ;;
    *)
        echo "SOURCE_CACHE_DIRECTORY must be within /cache." >&2
        exit 2
        ;;
esac

if [ -d "${SOURCE_CACHE_DIRECTORY}/.git" ]; then
    echo "Refreshing ${SOURCE_URL} (${SOURCE_REF})"
    git -C "${SOURCE_CACHE_DIRECTORY}" remote set-url origin "${SOURCE_URL}"
    git -C "${SOURCE_CACHE_DIRECTORY}" fetch --depth 1 origin "${SOURCE_REF}"
    git -C "${SOURCE_CACHE_DIRECTORY}" checkout --detach --force FETCH_HEAD
    git -C "${SOURCE_CACHE_DIRECTORY}" clean -ffd
else
    echo "Fetching ${SOURCE_URL} (${SOURCE_REF})"
    rm -rf "${SOURCE_CACHE_DIRECTORY}"
    git clone --depth 1 --single-branch --branch "${SOURCE_REF}" "${SOURCE_URL}" "${SOURCE_CACHE_DIRECTORY}"
fi

test -f "${SOURCE_CACHE_DIRECTORY}/Database.sqlproj"
git -C "${SOURCE_CACHE_DIRECTORY}" rev-parse HEAD > "${SOURCE_COMMIT_FILE}"

echo "Resolved epr-data-sqldb $(cat "${SOURCE_COMMIT_FILE}")"
