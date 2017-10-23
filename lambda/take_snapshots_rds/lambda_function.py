'''
Copyright 2017 Amazon.com, Inc. or its affiliates. All Rights Reserved.

Licensed under the Apache License, Version 2.0 (the "License"). You may not use this file except in compliance with the License. A copy of the License is located at

    http://aws.amazon.com/apache2.0/

or in the "license" file accompanying this file. This file is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.
'''


# take_snapshots_rds
# This lambda function takes a snapshot of RDS instances according to the environment variable PATTERN and INTERVAL
# Set PATTERN to a regex that matches your RDS Instance identifiers
# Set INTERVAL to the amount of hours between backups. This function will list available manual snapshots and only trigger a new one if the latest is older than INTERVAL hours
import boto3
from datetime import datetime
import time
import os
import logging
import re
from snapshots_tool_utils import *

# Initialize everything
LOGLEVEL = os.getenv('LOG_LEVEL').strip()
BACKUP_INTERVAL = int(os.getenv('INTERVAL', '24'))
PATTERN = os.getenv('PATTERN', 'ALL_INSTANCES')

if os.getenv('REGION_OVERRIDE', 'NO') != 'NO':
    REGION = os.getenv('REGION_OVERRIDE').strip()
else:
    REGION = os.getenv('AWS_DEFAULT_REGION')

TIMESTAMP_FORMAT = '%Y-%m-%d-%H-%M'

logger = logging.getLogger()
logger.setLevel(LOGLEVEL.upper())


def lambda_handler(event, context):

    client = boto3.client('rds', region_name=REGION)
    response = paginate_api_call(client, 'describe_db_instances', 'DBInstances')
    now = datetime.now()
    pending_backups = 0
    filtered_instances = filter_instances(PATTERN, response)
    filtered_snapshots = get_own_snapshots_source(PATTERN, paginate_api_call(client, 'describe_db_snapshots', 'DBSnapshots'))

    for db_instance in filtered_instances:

        timestamp_format = now.strftime(TIMESTAMP_FORMAT)

        if requires_backup(BACKUP_INTERVAL, db_instance, filtered_snapshots):

            backup_age = get_latest_snapshot_ts(
                db_instance['DBInstanceIdentifier'],
                filtered_snapshots)

            if backup_age is not None:
                logger.info('Backing up %s. Backed up %s minutes ago' % (
                    db_instance['DBInstanceIdentifier'], ((now - backup_age).total_seconds() / 60)))

            else:
                logger.info('Backing up %s. No previous backup found' %
                            db_instance['DBInstanceIdentifier'])

            snapshot_identifier = '%s-%s' % (
                db_instance['DBInstanceIdentifier'], timestamp_format)

            try:
                response = client.create_db_snapshot(
                    DBSnapshotIdentifier=snapshot_identifier,
                    DBInstanceIdentifier=db_instance['DBInstanceIdentifier'],
                    Tags=[{'Key': 'CreatedBy', 'Value': 'Snapshot Tool for RDS'}, {
                        'Key': 'CreatedOn', 'Value': timestamp_format}, {'Key': 'shareAndCopy', 'Value': 'YES'}]
                )
            except Exception:
                pending_backups += 1
        else:

            backup_age = get_latest_snapshot_ts(
                db_instance['DBInstanceIdentifier'],
                filtered_snapshots)

            logger.info('Skipped %s. Does not require backup. Backed up %s minutes ago' % (
                db_instance['DBInstanceIdentifier'], (now - backup_age).total_seconds() / 60))

    if pending_backups > 0:
        log_message = 'Could not back up every instance. Backups pending: %s' % pending_backups
        logger.error(log_message)
        raise SnapshotToolException(log_message)


if __name__ == '__main__':
    lambda_handler(None, None)

