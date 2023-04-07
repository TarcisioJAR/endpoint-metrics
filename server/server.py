import datetime
import random
import json
import boto3

bucket_name = 'endpoint-monitor-logs-fc23ae9cf'

def lambda_handler(event, context):
    print(event)
    try:
        ip = event['ip']
        processor = event['processor']
        running_processes = event['running_processes']
        users = event['users']
        os_name = event['os_name']
        os_version = event['os_version']

        data = {
            'ip': ip,
            'processor': processor,
            'running_processes': running_processes,
            'users': users,
            'os_name': os_name,
            'os_version': os_version
        }

        # Build filename for CSV file
        now = datetime.datetime.now()
        random_hex = ''.join(random.choice('0123456789abcdef') for _ in range(16))
        filename = f"{ip}_{now.strftime('%Y-%m-%d')}_{random_hex}.json"
        path = f"{now.strftime('%Y/%m/%d/')}"

        s3 = boto3.client('s3')

        json_string = json.dumps(data)
        
        # Write the JSON string to S3
        s3.put_object(Bucket=bucket_name, Key=path + filename, Body=json_string)

        return {
            'status_code': 200
        }

    except Exception as e:
        print(e)
        return {
            'status_code': 400
        }
