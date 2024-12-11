#!/bin/bash

# Strict error handling
set -euo pipefail

# Logging and error handling functions
log_message() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" >&2
}

error_handle() {
    log_message "ERROR: $*"
    exit 1
}

# Pause and continue function
pause_and_continue() {
    read -p "$1 Press Enter to continue..." continue_input
}

# Safe command existence check
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Reconfigure all partially installed packages and fix dpkg state issues
# This is essential if package installations or upgrades were interrupted
log_message "Running dpkg to reconfigure packages..."
sudo dpkg --configure -a || error_handle "Failed to run dpkg --configure -a"
pause_and_continue "Reconfigured all partially installed packages and fix dpkg state issues"

# Utility function for safe package installation
safe_package_install() {
    local package="$1"
    if ! dpkg -s "$package" >/dev/null 2>&1; then
        log_message "Installing $package..."
        sudo apt-get install -y "$package" || error_handle "Failed to install $package"
    else
        log_message "$package is already installed."
    fi
    pause_and_continue "Package $package installation completed."
}

# Dependency Installation Process
install_dependencies() {
    log_message "Starting Dependency Installation"

    # Verify system compatibility
    [[ -x "$(command -v apt-get)" ]] || error_handle "This script requires a Debian/Ubuntu-based system"

    # Update and upgrade system
    sudo apt-get update && sudo apt-get upgrade -y || error_handle "System update failed"
    pause_and_continue "System update completed."

    # Essential build tools
    safe_package_install software-properties-common
    safe_package_install build-essential
    safe_package_install curl
    safe_package_install wget
    safe_package_install jq

    # Add Python 3.10 PPA
    if ! grep -q "deadsnakes" /etc/apt/sources.list /etc/apt/sources.list.d/*; then
        sudo add-apt-repository ppa:deadsnakes/ppa -y
        sudo apt-get update
        pause_and_continue "Deadsnakes PPA added successfully."
    fi

    # Install Python 3.10 and related packages
    safe_package_install python3.10
    safe_package_install python3.10-venv
    safe_package_install python3.10-dev
    safe_package_install python3.10-distutils

    # Install pip for Python 3.10
    curl -sS https://bootstrap.pypa.io/get-pip.py | sudo python3.10
    pause_and_continue "Python 3.10 and pip installation completed."

    # Setup virtual environment
    local VENV_DIR=~/python3.10-env
    [[ -d "$VENV_DIR" ]] || python3.10 -m venv "$VENV_DIR"
    pause_and_continue "Virtual environment created at $VENV_DIR."

    # Explicitly set debian_chroot only if not already set
    if [ -z "${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
        debian_chroot=$(cat /etc/debian_chroot)
    fi

    # Ensure PS1 is set
    export PS1="${PS1:-\u@\h:\w\$ }"

    # Check and install Poetry
    if ! command -v poetry &> /dev/null; then
        echo "Installing Poetry..."
        curl -sSL https://install.python-poetry.org | python3 - || error_handle "Failed to install Poetry"

        # Add Poetry to PATH
        export PATH="$HOME/.local/bin:$PATH"
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
    fi

    # Update to specific version
    poetry self update 1.5.1 || error_handle "Failed to update Poetry"
    # Verify Poetry version
    current_version=$(poetry --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+')
    if [ "$current_version" == "1.5.1" ]; then
        pause_and_continue "Poetry 1.5.1 installed successfully."
    else
        error_handle "Poetry installation failed or the version is incorrect. Expected version 1.5.1, got $current_version."
    fi

    # Install GNU Make 4.3
    if ! command_exists make; then
        echo "GNU Make is not installed. Installing version 4.3..."
        # Download and install make 4.3
        wget https://ftp.gnu.org/gnu/make/make-4.3.tar.gz -P /tmp
        cd /tmp
        tar -xzvf make-4.3.tar.gz
        cd make-4.3
        ./configure
        make
        sudo make install
        # Update PATH to prioritize /usr/local/bin
        export PATH="/usr/local/bin:$PATH"
        echo 'export PATH="/usr/local/bin:$PATH"' >> ~/.bashrc

        # Reload bash configuration
        source ~/.bashrc
    elif [[ $(make --version | head -n 1) != *"4.3"* ]]; then
        pause_and_continue "GNU Make version is not 4.3. Updating to version 4.3..."
        # Download and install make 4.3
        wget https://ftp.gnu.org/gnu/make/make-4.3.tar.gz -P /tmp
        cd /tmp
        tar -xzvf make-4.3.tar.gz
        cd make-4.3
        ./configure
        make
        sudo make install
        # Update PATH to prioritize /usr/local/bin
        export PATH="/usr/local/bin:$PATH"
        echo 'export PATH="/usr/local/bin:$PATH"' >> ~/.bashrc

        # Reload bash configuration
        source ~/.bashrc
    else
        pause_and_continue "GNU Make version 4.3 is already installed."
    fi

    # This script installs dependencies for the project
    echo "Installing all dependencies..."
    sudo make install

    #echo "Installing development dependencies..."
    #make install_dev

    log_message "Dependency Installation Completed Successfully"
    pause_and_continue "All dependencies have been installed."
}

# Azure Setup
configure_azure() {
    #log_message "Configuring Azure Setup"

    # Install Azure CLI
    #safe_package_install azure-cli
    #az login
    #pause_and_continue "Azure CLI login completed."

    # Retrieve Azure VM details
    local region=$(curl -s -H "Metadata: true" "http://169.254.169.254/metadata/instance/compute?api-version=2021-02-01" | jq -r '.location')
    local profile=$(az account show --query name -o tsv)

    # Retrieve Azure VM details
    local region=$(curl -s -H "Metadata: true" "http://169.254.169.254/metadata/instance/compute?api-version=2021-02-01" | jq -r '.location')
    local profile=$(az account show --query name -o tsv)

    # Print detailed information about the variables
    echo "==================== Azure VM Details ===================="
    echo "The following details are retrieved from the Azure VM instance and account:"
    echo ""
    echo "Azure Region (location where the VM is deployed): $region"
    echo "Azure Profile (currently active Azure account): $profile"
    echo ""
    echo "==========================================================="

    # Update .env file with Azure credentials
    cat <<EOL >> .env

# Azure Credentials
export AZURE_REGION="$region"
export AZURE_PROFILE="$profile"
EOL

    log_message "Azure configuration completed"
    pause_and_continue "Azure credentials added to .env file."
}

# Docker Setup and Build
configure_docker() {
    log_message "Configuring Docker"

    # Build Docker image
    make build
    pause_and_continue "Docker image built successfully."

    # Run the pipeline in Docker container (real-time mode)
    make run_real_time_docker
    pause_and_continue "Pipeline ran in Docker container."
}

# Azure Deployment
deploy_to_azure() {
    log_message "Deploying to Azure"

    # Deploy the pipeline to Azure
    make deploy_azure
    pause_and_continue "Deployment to Azure initiated."

    # Check deployment status
    make info_azure
    pause_and_continue "Azure deployment information retrieved."
}

# Main Execution
main() {

    pause_and_continue "if your .env file not ready, fix it, and come back"

    install_dependencies
    configure_azure

    # Run pipeline in batch mode
    make run_batch
    pause_and_continue "Batch pipeline run completed."

    # Run streaming pipeline
    make run_real_time
    pause_and_continue "Real-time streaming pipeline run completed."

    # Sanity checks
    local QUERY="What is the latest financial news about Tesla?"
    local QUERY_RESULT=$(make search PARAMS="--query_string \"$QUERY\"")

    [[ -n "$QUERY_RESULT" ]] || error_handle "Qdrant query failed"
    pause_and_continue "Sanity check query successful."

    # Code quality checks
    make lint_check
    make lint_fix
    make format_check
    make format_fix
    pause_and_continue "Code quality checks and fixes completed."

    # Optional Docker and Azure deployment
    read -p "Do you want to build Docker image and deploy to Azure? (y/n): " docker_azure_choice
    if [[ "$docker_azure_choice" == "y" ]]; then
        configure_docker
        deploy_to_azure
    fi

    log_message "Pipeline setup and verification completed successfully!"
    pause_and_continue "All tasks completed. Press Enter to exit."
}

# Execute main function
main