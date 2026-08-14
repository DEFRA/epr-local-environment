#!/bin/bash

# Different image builds bundle different sqlcmd versions at different paths (older builds:
# /opt/mssql-tools/bin/sqlcmd - ODBC 13, has a known "Invalid cursor state" bug against SQL
# Server 2025; newer builds: /opt/mssql-tools18/bin/sqlcmd - ODBC 18, fixed). Detect whichever
# is actually present instead of hardcoding one, so this script works against either.
# -C (trust server cert) is an mssql-tools18/ODBC 18 flag - ODBC 18 defaults to requiring a
# trusted TLS cert, which sqledge's self-signed cert fails without it. The older sqlcmd doesn't
# have or need this flag, so it's only added when that's the binary in use.
if [[ -x /opt/mssql-tools18/bin/sqlcmd ]]; then
    SQLCMD=/opt/mssql-tools18/bin/sqlcmd
    TRUST_CERT_FLAG=-C
else
    SQLCMD=/opt/mssql-tools/bin/sqlcmd
    TRUST_CERT_FLAG=
fi

convert_line_endings() {
    local file_path=$1
    local temp_file=$(mktemp)

    # Remove BOM and convert CRLF to LF
    sed '1s/^\xEF\xBB\xBF//' "$file_path" | tr -d '\r' > "$temp_file"

    echo "$temp_file"
}

process_sql_file() {
    local file_path=$1
    if [[ -s "$file_path" ]]; then
        echo "Processing file: $file_path"

        # Convert line endings using built-in tools
        local converted_file=$(convert_line_endings "$file_path")
        echo "Using converted file: $converted_file"

        # Execute the SQL file
        $SQLCMD -S $SERVER,$PORT -U $USER -P $PASSWORD -d $DATABASE -i "$converted_file" -I $TRUST_CERT_FLAG

        # Clean up temporary file
        rm "$converted_file"
    else
        echo "The file \"$file_path\" is empty or does not exist. No update has been triggered."
    fi
}

$SQLCMD -S $SERVER,$PORT -U $USER -P $PASSWORD -Q "IF NOT EXISTS (SELECT * FROM sys.databases WHERE name = N'$DATABASE') CREATE DATABASE [$DATABASE]" -I $TRUST_CERT_FLAG

process_sql_file "$1"

if [[ -n "$2" ]]; then
    process_sql_file "$2"
fi
