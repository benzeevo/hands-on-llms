#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to pause and wait for user to press Enter
pause_and_continue() {
    read -p "$1 Press Enter to continue..."
}

# ----------------------------------------------
# 1. Install Dependencies
# ----------------------------------------------

echo "Starting Dependency Installation Process"
pause_and_continue "This script will update your system and install various dependencies."

# Update system packages
if command_exists apt; then
    echo "Updating system packages..."
    sudo apt update && sudo apt upgrade -y
else
    echo "apt command not found. This script requires a Debian/Ubuntu-based system."
    exit 1
fi

pause_and_continue "System packages updated."

# Install software-properties-common (if not already installed)
if ! dpkg -s software-properties-common >/dev/null 2>&1; then
    echo "Installing software-properties-common..."
    sudo apt-get install -y software-properties-common
else
    echo "software-properties-common is already installed."
fi

# Add Deadsnakes PPA (if not already added)
if ! grep -q "deadsnakes" /etc/apt/sources.list /etc/apt/sources.list.d/*; then
    echo "Adding Deadsnakes PPA..."
    sudo add-apt-repository ppa:deadsnakes/ppa -y
    sudo apt-get update
else
    echo "Deadsnakes PPA is already added."
fi

pause_and_continue "PPA repository setup complete."


# Install Python 3.10 (if not already installed)
if ! command_exists python3.10; then
    echo "Installing Python 3.10..."
    sudo apt install -y python3.10 python3.10-venv python3.10-distutils
    
    # Set Python 3.10 as default
    sudo update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.10 1
    sudo update-alternatives --set python3 /usr/bin/python3.10
else
    echo "Python 3.10 is already installed."
fi

# Verify Python version
python3 --version
pause_and_continue "Python 3.10 installation complete."

# Install pip for Python 3.10 (if not already installed)
if ! command_exists pip3; then
    echo "Installing pip for Python 3.10..."
    curl -sS https://bootstrap.pypa.io/get-pip.py | python3.10
	export PATH=$PATH:/home/student/.local/bin
	echo 'export PATH=$PATH:/home/student/.local/bin' >> ~/.bashrc
	source ~/.bashrc
else
    echo "pip is already installed."
fi

# Verify pip installation
pip --version
pause_and_continue "pip installation complete."

# Install Poetry (if not already installed)
if ! command_exists poetry; then
    echo "Installing Poetry 1.5.1..."
    curl -sSL https://install.python-poetry.org | python3.10 -
    poetry self update 1.5.1
else
    echo "Poetry is already installed. Checking version..."
    poetry --version
fi

pause_and_continue "Poetry installation complete."

# Install GNU Make 4.3 (with version check)
if ! command_exists make || [[ $(make --version | head -n 1) != *"4.3"* ]]; then
    echo "Installing GNU Make 4.3..."
    sudo apt update
    sudo apt install -y make=4.3* || {
        echo "GNU Make 4.3 not found in the repository. Attempting manual installation..."
        sudo apt remove -y make
        wget http://ftp.gnu.org/gnu/make/make-4.3.tar.gz
        tar -xvzf make-4.3.tar.gz
        cd make-4.3 || exit
        ./configure
        make
        sudo make install
        cd ..
        rm -rf make-4.3 make-4.3.tar.gz
    }
else
    echo "GNU Make 4.3 is already installed."
fi

# Verify GNU Make installation
make --version
pause_and_continue "GNU Make installation complete."

# Install project dependencies
echo "Installing project dependencies..."
if command_exists make; then
    make install
else
    echo "Error: Make is not available to run project dependencies installation."
fi

pause_and_continue "Dependency installation process completed."

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

