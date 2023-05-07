#!/bin/bash

INSTANCE_ID="i-00f01b384c16b66e7"

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 {start|stop}"
    exit 1
fi

ACTION="$1"

# Get the instance state
INSTANCE_STATE=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID --query "Reservations[].Instances[].[State.Name]" --output text --no-cli-pager)
echo "Current instance state: $INSTANCE_STATE"

if [[ $INSTANCE_STATE == "stopping" ]]; then
    echo "Instance is in the stopping mode. Please wait until it is stopped before starting or stopping again."
else
    case $ACTION in
        start)
            # Start the instance if it is stopped
            if [[ $INSTANCE_STATE == "stopped" ]]; then
                aws ec2 start-instances --instance-ids $INSTANCE_ID --no-cli-pager
                aws ec2 wait instance-running --instance-ids $INSTANCE_ID
            elif [[ $INSTANCE_STATE == "running" ]]; then
                aws ec2 reboot-instances --instance-ids $INSTANCE_ID --no-cli-pager
                aws ec2 wait instance-status-ok --instance-ids $INSTANCE_ID
            fi

            # Fetch the public IP address
            PUBLIC_IP=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID --query "Reservations[].Instances[].[PublicIpAddress]" --output text --no-cli-pager)

            # Replace the IP address for the target host in the SSH config file
            sed -i.bak "/^Host aws$/,/^$/s/HostName .*/HostName $PUBLIC_IP/" ~/.ssh/config

            # Replace the contents of the known_hosts_aws file with the public IP address and the corresponding SSH key
            echo "$PUBLIC_IP ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJli4aohdcJWewkTN3zxDPDofq8yLgJ6m1oaD8tpf3PG" > ~/.ssh/known_hosts_aws

            echo "Instance started/rebooted, and the public IP address ($PUBLIC_IP) has been updated in the SSH config file and known_hosts_aws file."
            ;;

        stop)
            # Stop the instance
            aws ec2 stop-instances --instance-ids $INSTANCE_ID --no-cli-pager
            echo "Instance stopping."
            ;;

        *)
            echo "Invalid argument. Usage: $0 {start|stop}"
            exit 1
            ;;
    esac
fi

