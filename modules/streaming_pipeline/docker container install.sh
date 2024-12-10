#!/bin/bash

# Function to check if a command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# Function to install Docker if not installed
install_docker() {
    echo "Docker is not installed. Installing Docker..."
    sudo apt update
    sudo apt install -y docker.io
    sudo systemctl start docker
    sudo systemctl enable docker
    echo "Docker installation complete."
}

# Pause and wait for user confirmation
pause_and_continue() {
    read -p "$1 Press Enter to continue..."
}

# Check if Docker is installed, if not install it
if ! command_exists docker; then
    install_docker
else
    echo "Docker is already installed."
    pause_and_continue "Docker is installed. Press Enter to continue with pulling the Ubuntu image..."
fi

# Pull the latest Ubuntu image
echo "Pulling the latest Ubuntu Docker image..."
sudo docker pull ubuntu:20.04
pause_and_continue "Ubuntu Docker image has been pulled. Press Enter to start the container..."

# Run the container interactively
echo "Starting a new Ubuntu container..."
sudo docker run -it ubuntu:20.04 /bin/bash

# Optionally, you can add any testing commands here, like installing packages:
# sudo docker exec -it <container_id> apt update
# sudo docker exec -it <container_id> apt install -y curl wget git

# Cleanup instructions
echo "To exit the container, type 'exit'."
echo "To remove the container, run 'sudo docker rm <container_id>' after exiting."
pause_and_continue "Press Enter to finish the script and clean up."

# End of the script
