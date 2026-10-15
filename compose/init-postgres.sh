#!/bin/sh
set -eu

# Creates each service's database in the shared postgres instance. Safe to re-run: a database
# that already exists is left as it is, so adding a service here also works on an existing volume.

create_database() {
    database_name="$1"

    exists="$(psql -tA -c "SELECT 1 FROM pg_database WHERE datname = '$database_name'")"

    if [ "$exists" = "1" ]; then
        echo "Database $database_name already exists"
    else
        psql -c "CREATE DATABASE \"$database_name\""
        echo "Created database $database_name"
    fi
}

create_database waste_organisations
