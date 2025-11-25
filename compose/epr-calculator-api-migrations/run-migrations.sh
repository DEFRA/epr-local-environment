#!/bin/bash

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
        /opt/mssql-tools/bin/sqlcmd -S $SERVER,$PORT -U $USER -P $PASSWORD -d $DATABASE -i "$converted_file" -I

        # Clean up temporary file
        rm "$converted_file"
    else
        echo "The file \"$file_path\" is empty or does not exist. No update has been triggered."
    fi
}

/opt/mssql-tools/bin/sqlcmd -S $SERVER,$PORT -U $USER -P $PASSWORD -Q "IF NOT EXISTS (SELECT * FROM sys.databases WHERE name = N'$DATABASE') CREATE DATABASE [$DATABASE]" -I

process_sql_file "$1"

if [[ -n "$2" ]]; then
    process_sql_file "$2"
fi
