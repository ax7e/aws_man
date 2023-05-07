#!/bin/bash

INSTANCE_ID="i-00f01b384c16b66e7"

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 {start|stop}"
    exit 1
fi

ACTION="$1"

case $ACTION in
    start)
        # Get the instance state
        INSTANCE_STATE=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID --query "Reservations[].Instances[].[State.Name]" --output text)
        echo "Current instance state: $INSTANCE_STATE"

        # Start the instance if it is stopped
        if [[ $INSTANCE_STATE == "stopped" ]]; then
            aws ec2 start-instances --instance-ids $INSTANCE_ID
            aws ec2 wait instance-running --instance-ids $INSTANCE_ID
        elif [[ $INSTANCE_STATE == "running" ]]; then
            aws ec2 reboot-instances --instance-ids $INSTANCE_ID
            aws ec2 wait instance-status-ok --instance-ids $INSTANCE_ID
        fi

        # Fetch the public IP address
        PUBLIC_IP=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID --query "Reservations[].Instances[].[PublicIpAddress]" --output text)

        # Replace the IP address for the target host in the SSH config file
        sed -i.bak "/^Host aws$/,/^$/s/HostName .*/HostName $PUBLIC_IP/" ~/.ssh/config

        echo "Instance started/rebooted, and the public IP address ($PUBLIC_IP) has been updated in the SSH config file."
        ;;

    stop)
        # Stop the instance
        aws ec2 stop-instances --instance-ids $INSTANCE_ID
        echo "Instance stopping."
        ;;

    *)
        echo "Invalid argument. Usage: $0 {start|stop}"
        exit 1
        ;;
esac

