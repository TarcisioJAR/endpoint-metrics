#!/bin/bash

if [ "$(id -u)" -ne 0 ]; then
        echo 'This script must be run by root' >&2
        exit 1
fi

echo 'Checking python pip'
apt update -qqq
apt install python3-pip -y -qqq
mkdir -p $HOME/instance-metrics/
cd $HOME/instance-metrics/
echo "psutil
boto3
netifaces
py-cpuinfo" >> requirements.txt
echo "Installing Python dependencies"
python3 -m pip install -r requirements.txt -q
echo "import requests
import platform
import psutil
import netifaces
import boto3
from datetime import datetime
import cpuinfo

def main():
    # SecretsManager secret name that stores the API endpoint to send the metrics
    INSTANCE_METRICS_URL_SECRET_NAME = 'INSTANCE_METRICS_URL'
    # SecretsManager secret name that stores the API Key for the API Gateway
    INSTANCE_METRICS_APIKEYSECRET_SECRET_NAME = 'INSTANCE_METRICS_APIKEYSECRET'
    # Region where the Secret is stored in Secret Manager
    REGION = 'us-east-1'

    # Collect system information
    system_info = {}
    system_info['processor'] = cpuinfo.get_cpu_info()['brand_raw']
    system_info['running_processes'] = [p.info for p in psutil.process_iter(['pid', 'name'])]
    system_info['users'] = [ {'user': user[0],
                            'terminal': user[1],
                            'host': user[2],
                            'started': datetime.fromtimestamp(user[3]).strftime('%Y-%m-%d %H:%M:%S'),
                            'pid': user[4] } for user in psutil.users()]
    system_info['os_name'] = platform.system()
    system_info['os_version'] = platform.version()
    system_info['ip'] = get_ip_address()

    # Create a Secrets Manager client
    client = boto3.client('secretsmanager', region_name=REGION)

    # Get Endpoint URL and API Key stored in Secret Manager
    API_ENDPOINT = client.get_secret_value(SecretId=INSTANCE_METRICS_URL_SECRET_NAME)['SecretString']
    API_KEY = client.get_secret_value(SecretId=INSTANCE_METRICS_APIKEYSECRET_SECRET_NAME)['SecretString']

    # Send data to API
    headers = {
        'x-api-key': API_KEY
    }
    response = requests.post(API_ENDPOINT, json=system_info, headers=headers)

    return response.json()

# Return the first non-loopback interface IP
def get_ip_address():
    interfaces = netifaces.interfaces()

    for iface in interfaces:
        if iface.startswith('lo'):
            continue
        addresses = netifaces.ifaddresses(iface)
        if netifaces.AF_INET in addresses:
            ip_address = addresses[netifaces.AF_INET][0]['addr']
            break
    return ip_address

main()" >> instance-metrics.py
echo "Creating a Cron Job"
echo "* * * * * /usr/bin/python3 $HOME/instance-metrics/instance-metrics.py" | crontab -
echo "Done"