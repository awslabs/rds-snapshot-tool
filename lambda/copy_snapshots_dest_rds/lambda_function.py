'''
Copyright 2017  Amazon.com, Inc. or its affiliates. All Rights Reserved.

Licensed under the Apache License, Version 2.0 (the "License"). You may not use this file except in compliance with the License. A copy of the License is located at

    http://aws.amazon.com/apache2.0/

or in the "license" file accompanying this file. This file is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.
'''

# copy_snapshots_dest_rds
# This lambda function will copy shared RDS snapshots that match the regex specified in the environment variable SNAPSHOT_PATTERN, into the account where it runs. If the snapshot is shared and exists in the local region, it will copy it to the region specified in the environment variable DEST_REGION. If it finds that the snapshots are shared, exist in the local and destination regions, it will delete them from the local region. Copying snapshots cross-account and cross-region need to be separate operations. This function will need to run as many times necessary for the workflow to complete.
# Set SNAPSHOT_PATTERN to a regex that matches your RDS Instance identifiers
# Set DEST_REGION to the destination AWS region
import boto3
from datetime import datetime
import time
import os
import logging
import re
from snapshots_tool_utils import *

# Initialize everything
LOGLEVEL = os.getenv('LOG_LEVEL', 'ERROR').strip()
PATTERN = os.getenv('SNAPSHOT_PATTERN', 'ALL_SNAPSHOTS')
DESTINATION_REGION = os.getenv('DEST_REGION').strip()
RETENTION_DAYS = int(os.getenv('RETENTION_DAYS'))

if os.getenv('REGION_OVERRIDE', 'NO') != 'NO':
    REGION = os.getenv('REGION_OVERRIDE').strip()
else:
    REGION = os.getenv('AWS_DEFAULT_REGION')


logger = logging.getLogger()
logger.setLevel(LOGLEVEL.upper())


def lambda_handler(event, context):
    # Describe all snapshots
    pending_copies = 0
    client = boto3.client('rds', region_name=REGION)
    response = paginate_api_call(client, 'describe_db_snapshots', 'DBSnapshots', IncludeShared=True)

    shared_snapshots = get_shared_snapshots(PATTERN, response)
    own_snapshots = get_own_snapshots_dest(PATTERN, response)

    # Get list of snapshots in DEST_REGION
    client_dest = boto3.client('rds', region_name=DESTINATION_REGION)
    response_dest = paginate_api_call(client_dest, 'describe_db_snapshots', 'DBSnapshots')
    own_dest_snapshots = get_own_snapshots_dest(PATTERN, response_dest)

    for shared_identifier, shared_attributes in shared_snapshots.items():

        if shared_identifier not in own_snapshots.keys() and shared_identifier not in own_dest_snapshots.keys():
            # Check date
            creation_date = get_timestamp(shared_identifier, shared_snapshots)
            if creation_date:
                time_difference = datetime.now() - creation_date
                days_difference = time_difference.total_seconds() / 3600 / 24

                # Only copy if it's newer than RETENTION_DAYS
                if days_difference < RETENTION_DAYS:

                    # Copy to own account
                    try:
                        copy_local(shared_identifier, shared_attributes)

                    except Exception:
                        pending_copies += 1
                        logger.error('Local copy pending: %s' % shared_identifier)

                    else:
                        if REGION != DESTINATION_REGION:
                            pending_copies += 1
                            logger.error('Remote copy pending: %s' % shared_identifier)

                else:
                    logger.info('Not copying %s locally. Older than %s days' % (shared_identifier, RETENTION_DAYS))

            else:
                logger.info('Not copying %s locally. No valid timestamp' % shared_identifier)

        # Copy to DESTINATION_REGION
        elif shared_identifier not in own_dest_snapshots.keys() and shared_identifier in own_snapshots.keys() and REGION != DESTINATION_REGION:
            if own_snapshots[shared_identifier]['Status'] == 'available':
                try:
                    copy_remote(shared_identifier, own_snapshots[shared_identifier])

                except Exception:
                    pending_copies += 1
                    logger.error('Remote copy pending: %s: %s' % (
                        shared_identifier, own_snapshots[shared_identifier]['Arn']))
            else:
                pending_copies += 1
                logger.error('Remote copy pending: %s: %s' % (
                    shared_identifier, own_snapshots[shared_identifier]['Arn']))

        # Delete local snapshots
        elif shared_identifier in own_dest_snapshots.keys() and shared_identifier in own_snapshots.keys() and own_dest_snapshots[shared_identifier]['Status'] == 'available' and REGION != DESTINATION_REGION:

            response = client.delete_db_snapshot(
                DBSnapshotIdentifier=shared_identifier
            )

            logger.info('Deleting local snapshot: %s' % shared_identifier)

    if pending_copies > 0:
        log_message = 'Copies pending: %s. Needs retrying' % pending_copies
        logger.error(log_message)
        raise SnapshotToolException(log_message)


if __name__ == '__main__':
    lambda_handler(None, None)
