#!/bin/bash

apply_sed_transform() {
    local file_path=$1
    local sed_command=$2
    local temp_file=$(mktemp)

    sed "$sed_command" "$file_path" > "$temp_file"

    echo "$temp_file"
}

convert_line_endings() {
    local file_path=$1
    local temp_file=$(mktemp)

    # Remove BOM and convert CRLF to LF
    sed '1s/^\xEF\xBB\xBF//' "$file_path" | tr -d '\r' > "$temp_file"

    echo "$temp_file"
}

clean_sql_file() {
    local file_path=$1
    local temp_file="$file_path"

    # Remove any WITH blocks (specific to Synapse syntax)
    temp_file=$(apply_sed_transform "$temp_file" '/^[[:space:]]*WITH[[:space:]]*$/,/^[[:space:]]*)[[:space:]]*;*[[:space:]]*$/d')
    temp_file=$(apply_sed_transform "$temp_file" '/^[[:space:]]*WITH[[:space:]]*(/,/^[[:space:]]*)[[:space:]]*;*[[:space:]]*$/d')

    # Specific file mods (currently procedures from epr-common-data-api-migrations are not required)
    # GREATEST(ss.RegistrationDecisionDate, ss.RegulatorDecisionDate) AS RegulatorDecisionDate
    # temp_file=$(apply_sed_transform "$temp_file" 's/GREATEST(ss\.RegistrationDecisionDate, ss\.RegulatorDecisionDate) AS RegulatorDecisionDate/CASE\n                WHEN ss.RegistrationDecisionDate > ss.RegulatorDecisionDate THEN ss.RegistrationDecisionDate\n                ELSE ss.RegulatorDecisionDate\n            END AS RegulatorDecisionDate/g')

    echo "$temp_file"
}

exec_sql_file() {
    local file_path=$1
    local filter_errors=${2:-true}

    if [[ -s "$file_path" ]]; then
        local converted_file=$(convert_line_endings "$file_path")

        # Execute the SQL file
        if [[ "$filter_errors" == true ]]; then
            /opt/mssql-tools/bin/sqlcmd -S $SERVER,$PORT -U $USER -P $PASSWORD -d $DATABASE -i "$converted_file" -I 2>&1 | grep -v -E "(Msg 208|Msg 2714|Msg 2759|There is already an object)"
        else
            /opt/mssql-tools/bin/sqlcmd -S $SERVER,$PORT -U $USER -P $PASSWORD -d $DATABASE -i "$converted_file" -I
        fi

        rm "$converted_file"
    else
        echo "The file \"$file_path\" is empty or does not exist."
    fi
}

process_sql_file() {
    local file_path=$1

    if [[ -s "$file_path" ]]; then
        echo "=== $file_path ==="
        local cleaned_file=$(clean_sql_file "$file_path")

        if [[ "$file_path" == *"file_name"* ]]; then
            cat "$cleaned_file"
        fi

        exec_sql_file "$cleaned_file"
        rm "$cleaned_file"
    else
        echo "The file \"$file_path\" is empty or does not exist."
    fi
}

process_sql_files() {
    local folder_path=$1

    if [[ -d "$folder_path" ]]; then
        for sql_file in "$folder_path"/*.sql; do
            if [[ -f "$sql_file" ]]; then
                echo "=== $sql_file ==="
                local cleaned_file=$(clean_sql_file "$sql_file")

                if [[ "$sql_file" == *"file_name"* ]]; then
                    cat "$cleaned_file"
                fi

                exec_sql_file "$cleaned_file"
                rm "$cleaned_file"
            fi
        done
    else
        echo "The directory \"$folder_path\" does not exist."
    fi
}

echo "-------------"
echo "- Ensure DB -"
echo "-------------"

/opt/mssql-tools/bin/sqlcmd -S $SERVER,$PORT -U $USER -P $PASSWORD -Q "IF NOT EXISTS (SELECT * FROM sys.databases WHERE name = N'$DATABASE') CREATE DATABASE [$DATABASE]" -I

echo ""
echo "Schemas"
process_sql_files "./scripts/compose/schemas"

echo ""
echo "Tables"
process_sql_files "./scripts/compose/tables" false
process_sql_files "./scripts/tables" false

# order in which views are processed might mean a dependent view doesn't exist
# therefore do 3 passes to try and eventually catch everything
echo ""
echo "Views (pass 1)"
process_sql_files "./scripts/compose/views"
process_sql_files "./scripts/views"

echo ""
echo "Views (pass 2)"
process_sql_files "./scripts/compose/views"
process_sql_files "./scripts/views"

echo ""
echo "Views (pass 3)"
process_sql_files "./scripts/compose/views" false
process_sql_files "./scripts/views" false

echo ""
echo "Functions"
process_sql_files "./scripts/compose/functions" false
process_sql_files "./scripts/functions" false

echo ""
echo "Procedures (only specific ones added for specific functionality)"
process_sql_file "./scripts/procedures/get-approved-submissions_myc.sql"
