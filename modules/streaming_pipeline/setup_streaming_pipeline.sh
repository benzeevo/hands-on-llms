#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to pause and wait for user to press Enter
pause_and_continue() {
    read -p "$1 Press Enter to continue..." continue_input
}

# Function to log messages
log_message() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

# Function to handle errors
error_handle() {
    log_message "Error: $*"
    exit 1
}

# ----------------------------------------------
# 1. Install Dependencies
# ----------------------------------------------

log_message "Starting Dependency Installation Process"
pause_and_continue "This script will update your system and install various dependencies."

# Verify system package manager
if ! command_exists apt; then
    error_handle "apt command not found. This script requires a Debian/Ubuntu-based system."
fi

# Update system packages with error handling
log_message "Updating system packages..."
sudo apt update || error_handle "Failed to update package lists"
sudo apt upgrade -y || error_handle "Failed to upgrade packages"
pause_and_continue "System packages have been updated."

# Install software-properties-common
if ! dpkg -s software-properties-common >/dev/null 2>&1; then
    log_message "Installing software-properties-common..."
    sudo apt-get install -y software-properties-common || error_handle "Failed to install software-properties-common"
    pause_and_continue "software-properties-common has been installed."
else
    log_message "software-properties-common is already installed."
    pause_and_continue "software-properties-common is already installed."
fi

# Add Deadsnakes PPA safely
if ! grep -q "deadsnakes" /etc/apt/sources.list /etc/apt/sources.list.d/*; then
    log_message "Adding Deadsnakes PPA..."
    sudo add-apt-repository ppa:deadsnakes/ppa -y || error_handle "Failed to add Deadsnakes PPA"
    sudo apt-get update || error_handle "Failed to update after adding PPA"
    pause_and_continue "Deadsnakes PPA has been added."
else
    log_message "Deadsnakes PPA is already added."
    pause_and_continue "Deadsnakes PPA is already added."
fi

# Install Python 3.10 without changing system default
if ! command_exists python3.10; then
    log_message "Installing Python 3.10..."
    sudo apt install -y python3.10 python3.10-venv python3.10-dev python3.10-distutils || error_handle "Failed to install Python 3.10"

    # Install pip for Python 3.10
    curl -sS https://bootstrap.pypa.io/get-pip.py | python3.10 || error_handle "Failed to install pip for Python 3.10"
    pause_and_continue "Python 3.10 has been installed."
else
    log_message "Python 3.10 is already installed."
    pause_and_continue "Python 3.10 is already installed."
fi

# Define the virtual environment directory
VENV_DIR=~/python3.10-env

# Check if the virtual environment already exists
if [ ! -d "$VENV_DIR" ]; then
    log_message "Creating Python 3.10 virtual environment..."
    python3.10 -m venv "$VENV_DIR" || error_handle "Failed to create virtual environment"
    pause_and_continue "Python 3.10 virtual environment created at $VENV_DIR"
else
    log_message "Python 3.10 virtual environment already exists at $VENV_DIR"
    pause_and_continue "Virtual environment already exists at $VENV_DIR"
fi

# Verify Python 3.10 installation
python3.10 --version || error_handle "Python 3.10 installation verification failed"
pause_and_continue "Python 3.10 version verified."

# Install pip for Python 3.10 (if not already installed)
if ! command_exists pip3; then
    log_message "Installing pip for Python 3.10..."
    sudo apt-get install -y curl
    curl -sS https://bootstrap.pypa.io/get-pip.py | python3.10
    export PATH=$PATH:$HOME/.local/bin
    echo 'export PATH=$PATH:$HOME/.local/bin' >> ~/.bashrc
    source ~/.bashrc
    pause_and_continue "pip for Python 3.10 has been installed."
else
    log_message "pip is already installed."
    pause_and_continue "pip is already installed."
fi

# Verify pip installation
pip --version
pause_and_continue "pip installation verified."

# Install Poetry (if not already installed)
if ! command_exists poetry; then
    log_message "Installing Poetry 1.5.1..."
    curl -sSL https://install.python-poetry.org | python3.10 -
    poetry self update 1.5.1
    pause_and_continue "Poetry 1.5.1 has been installed."
else
    log_message "Poetry is already installed."
    poetry --version
    pause_and_continue "Poetry is already installed."
fi

# Install GNU Make 4.3 (with version check)
if ! command_exists make || [[ $(make --version | head -n 1) != *"4.3"* ]]; then
    log_message "Installing GNU Make 4.3..."

    # Ensure build dependencies are installed
    sudo apt update
    sudo apt install -y build-essential autoconf automake libtool wget

    # Install Make 4.3 if not already installed or if the version is incorrect
    sudo apt install -y make=4.3* || {
        log_message "GNU Make 4.3 not found in the repository. Attempting manual installation..."
        sudo apt remove -y make

        # Download and extract Make 4.3
        wget http://ftp.gnu.org/gnu/make/make-4.3.tar.gz
        tar -xvzf make-4.3.tar.gz
        cd make-4.3 || exit

        # Run configure with --disable-dependency-tracking to bypass dependency issues
        ./configure --disable-dependency-tracking
        make
        sudo make install

        # Clean up the extracted files
        cd ..
        rm -rf make-4.3 make-4.3.tar.gz

        # Update alternatives to make sure the correct version of make is used
        sudo update-alternatives --install /usr/bin/make make /usr/local/bin/make 1
        sudo update-alternatives --set make /usr/local/bin/make
    }

    # Confirm successful installation
    pause_and_continue "GNU Make 4.3 has been installed."
else
    log_message "GNU Make 4.3 is already installed."
    pause_and_continue "GNU Make 4.3 is already installed."
fi

# Verify GNU Make installation
make --version
pause_and_continue "GNU Make installation verified."

# Install project dependencies
log_message "Installing project dependencies..."
if command_exists make; then
    make install
    pause_and_continue "Project dependencies have been installed."
else
    error_handle "Make is not available to run project dependencies installation."
fi

log_message "Dependency installation process completed."
pause_and_continue "Dependency installation process completed. Press Enter to continue with the next steps."

# Install development dependencies if you're working on the pipeline locally
#echo "Installing development dependencies..."
#make install_dev

# ----------------------------------------------
# 2. Setup External Services (Alpaca, Qdrant, etc.)
# ----------------------------------------------
echo "Setting up the .env file with your credentials..."

# Pause for user to review
echo "Make sure the env. file is updated with the credentials to Alpaca and Qdrant and pres ENTER"
read -p ""

# Get Azure VM region and profile
sudo apt install -y jq
sudo apt install azure-cli
az login

region=$(curl -s -H "Metadata: true" "http://169.254.169.254/metadata/instance/compute?api-version=2021-02-01" | jq -r '.location')
profile=$(az account show --query name -o tsv)

# Append Azure credentials to the .env file with a blank line
cat <<EOL >> .env

# Azure credentials
export AZURE_REGION="$region"
export AZURE_PROFILE="$profile"
EOL

echo ".env file has been successfully updated."

# Pause for user to review setup
echo "Press Enter to continue after verifying the environment setup..."
read -p ""

# ----------------------------------------------
# 3. Optional: Run the Pipeline in Batch Mode
# ----------------------------------------------
echo "Running the streaming pipeline in batch mode..."

# Run the pipeline in batch mode to ingest historical data (last 8 days)
make run_batch

# Pause after running the batch pipeline
echo "Press Enter to continue after running the batch pipeline..."
read -p ""

# ----------------------------------------------
# 4. Run the Streaming Pipeline
# ----------------------------------------------
echo "Running the streaming pipeline in real-time mode..."

# Run the pipeline in real-time mode
make run_real_time

# Pause after running the real-time pipeline
echo "Press Enter to continue after running the streaming pipeline..."
read -p ""

# ----------------------------------------------
# 5. Sanity Check - Verify that Pipeline works
# ----------------------------------------------
echo "Starting sanity checks..."

# Run a sanity check query on Qdrant to ensure embeddings are stored
echo "Running sanity check query on Qdrant..."
QUERY="What is the latest financial news about Tesla?"
QUERY_RESULT=$(make search PARAMS="--query_string \"$QUERY\"")

# Print the query results for inspection
echo "Sanity check query results: "
echo "$QUERY_RESULT"

# Check the result of the query
if [ $? -eq 0 ]; then
    echo "Sanity check query was successful. Results returned from Qdrant."
else
    echo "Error: Query to Qdrant failed."
    exit 1
fi

# Pause after query check
echo "Press Enter to continue after verifying the query results..."
read -p ""

# ----------------------------------------------
# 6. Docker Mode (Optional)
# ----------------------------------------------
#echo "Building Docker image..."

# Build Docker image
#make build

#echo "Running the streaming pipeline in Docker container..."

# Run the pipeline in Docker container (real-time mode)
#make run_real_time_docker

# Pause after Docker mode
#echo "Press Enter to continue after running in Docker..."
#read -p ""

# ----------------------------------------------
# 7. Deploy to Azure (Replaced AWS with Azure)
# ----------------------------------------------
#echo "Deploying to Azure..."

# Deploy the pipeline to Azure (adjust to your specific Azure environment)
#make deploy_azure

# Check deployment status
#make info_azure

# To undeploy (destroy the Azure deployment)
# make undeploy_azure

# Pause after Azure deployment
#echo "Press Enter to continue after deploying to Azure..."
#read -p ""

# ----------------------------------------------
# 8. Linting & Formatting (Optional)
# ----------------------------------------------
echo "Running lint check on the code..."

# Check the code for linting issues
make lint_check

# Fix linting issues
make lint_fix

echo "Running format check on the code..."

# Check the code for formatting issues
make format_check

# Fix formatting issues
make format_fix

# ----------------------------------------------
# Final Check
# ----------------------------------------------
echo "All tasks completed. Pipeline is set up, sanity checks passed, and everything is running!"

