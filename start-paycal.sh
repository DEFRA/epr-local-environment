    #!/usr/bin/env bash
    set -euo pipefail

    # =========================================================
    # Pretty Output Helpers
    # =========================================================

    print_header() {
        echo -e "\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "$1"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    }

    success() { echo "✔ $1"; }
    warn()    { echo "⚠ $1"; }
    error()   { echo "❌ $1"; exit 1; }

    # =========================================================
    # Handle "force" argument
    # =========================================================

    FORCE=false
    for arg in "$@"; do
        case "$arg" in
            -f|--force)
                FORCE=true
                ;;
            *)
                ;;
        esac
    done

    if [ "$FORCE" = true ]; then
        print_header "Force restart: stopping Docker and removing volumes"
        docker compose --profile paycal down -v
        success "Docker compose stopped and volumes removed"
    fi

    # =========================================================
    # Start
    # =========================================================

    print_header "Starting Dev Environment"

    # =========================================================
    # Check Git
    # =========================================================

    print_header "Checking Git"

    command -v git >/dev/null 2>&1 || error "Git is not installed"

    branch=$(git rev-parse --abbrev-ref HEAD)
    [ "$branch" = "main" ] || error "You are on branch '$branch'. Please switch to main."

    success "On main branch"

    echo "Fetching latest changes..."
    git fetch origin main >/dev/null 2>&1

    LOCAL=$(git rev-parse HEAD)
    REMOTE=$(git rev-parse origin/main)

    if [ "$LOCAL" != "$REMOTE" ]; then
        warn "Local main is not up to date"
        git pull origin main
    else
        success "Repository up to date"
    fi

    # =========================================================
    # Check Docker
    # =========================================================

    print_header "Checking Docker"

    command -v docker >/dev/null 2>&1 || error "Docker is not installed"
    docker info >/dev/null 2>&1 || error "Docker is not running. Start Docker Desktop."

    success "Docker is running"

    # =========================================================
    # Authenticate with Azure Container Registry
    # =========================================================

    print_header "Logging into Azure Container Registry"

    command -v az >/dev/null 2>&1 || error "Azure CLI (az) is not installed. Install it to access ACR."

    # Optional: ensure user is logged in
    if ! az account show >/dev/null 2>&1; then
        echo "Azure CLI not logged in. Please run: az login"
        exit 1
    fi

    # Set the correct subscription
    az account set --subscription "AZD-RWD-DEV1" >/dev/null 2>&1 || error "Failed to set subscription to AZD-RWD-DEV1"

    # Login to ACR
    if ! az acr login --name devrwdinfac1401 >/dev/null 2>&1; then
        error "Failed to login to ACR devrwdinfac1401. Ensure you have access."
    fi

    success "Successfully logged into Azure Container Registry"

    # =========================================================
    # Check .env file
    # =========================================================

    print_header "Checking Environment File"

    if [ ! -f ".env" ]; then
        warn ".env file not found. Copy from .env.example and populate secrets."
    else
        success ".env file exists"
        warn "Ensure all required keys and secrets are set correctly."
    fi

    # =========================================================
    # Validate SQL Server Image used
    # =========================================================

    if [[ "$(uname)" == "Darwin" ]]; then
        print_header "Validating SQL Server Image in compose.yml"

        MSSQL_LINE=$(grep 'mcr.microsoft.com/mssql/server:2022-latest' compose.yml)
        AZURE_LINE=$(grep 'mcr.microsoft.com/azure-sql-edge:latest' compose.yml)

        if [[ "$MSSQL_LINE" =~ ^[[:space:]]*# ]]; then
            error "On Mac, mcr.microsoft.com/mssql/server:2022-latest must be active (uncommented) in compose.yml"
        else
            success "mssql/server image is active"
        fi

        if [[ ! "$AZURE_LINE" =~ ^[[:space:]]*# ]]; then
            error "On Mac, mcr.microsoft.com/azure-sql-edge:latest must be commented out in compose.yml"
        else
            success "Azure SQL Edge image is correctly commented out"
        fi
    fi

    # =========================================================
    # Start Docker services
    # =========================================================

    print_header "Starting PayCal via Docker Compose"

    docker compose --profile paycal up -d
    success "Docker services started"

    # =========================================================
    # Wait for Service
    # =========================================================
    MAX_RETRIES=20
    RETRY_DELAY=3
    URL="https://localhost:7163"

    echo "Waiting for Service to respond..."

    for ((i=1;i<=MAX_RETRIES;i++)); do
        STATUS=$(curl -k -s -o /dev/null -w "%{http_code}" "$URL" || true)

        # Accept 2xx or 3xx as "service up"
        if [[ "$STATUS" =~ ^2|3 ]]; then
            success "Service responding (HTTP $STATUS)"
            break
        fi

        echo "Attempt $i/$MAX_RETRIES - waiting for service..."
        sleep "$RETRY_DELAY"

        if [ "$i" -eq "$MAX_RETRIES" ]; then
            error "Service did not become ready in time (last status: $STATUS)"
        fi
    done

    # =========================================================
    # Finished
    # =========================================================

    print_header "Dev Environment Ready"

    success "All checks passed"
    echo "You can now access https://localhost:7163 and log in with your @onmicrosoft account."
    echo ""