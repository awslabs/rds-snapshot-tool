'''
Copyright 2017  Amazon.com, Inc. or its affiliates. All Rights Reserved.

Licensed under the Apache License, Version 2.0 (the "License"). You may not use this file except in compliance with the License. A copy of the License is located at

    http://aws.amazon.com/apache2.0/

or in the "license" file accompanying this file. This file is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.
'''

# copy_snapshots_dest_rds
# This lambda function will copy shared RDS snapshots that match the regex specified in the environment variable PATTERN, into the account where it runs. If the snapshot is shared and exists in the local region, it will copy it to the region specified in the environment variable DEST_REGION. If it finds that the snapshots are shared, exist in the local and destination regions, it will delete them from the local region. Copying snapshots cross-account and cross-region need to be separate operations. This function will need to run as many times necessary for the workflow to complete.
# Set PATTERN to a regex that matches your RDS Instance identifiers 
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
PATTERN = os.getenv('PATTERN', 'ALL_SNAPSHOTS')
KMS_KEY_COPY = os.getenv('KMS_KEY_COPY').strip()

if os.getenv('REGION_OVERRIDE', 'NO') != 'NO':
    REGION = os.getenv('REGION_OVERRIDE').strip()
else:
    REGION = os.getenv('AWS_DEFAULT_REGION')

TIMESTAMP_FORMAT = '%Y-%m-%d-%H-%M'

logger = logging.getLogger()
logger.setLevel(LOGLEVEL.upper())


def lambda_handler(event, context):
    # Describe all snapshots
    pending_snapshots = 0
    client = boto3.client('rds', region_name=REGION)
    response = paginate_api_call(client, 'describe_db_snapshots', 'DBSnapshots')
    filtered = get_own_snapshots_source(PATTERN, response)
    now = datetime.now()

    # Search all snapshots for the correct tag
    for snapshot_identifier,snapshot_object in filtered.items():
        snapshot_arn = snapshot_object['Arn']
        response_tags = client.list_tags_for_resource(
            ResourceName=snapshot_arn)

        timestamp_format = now.strftime(TIMESTAMP_FORMAT)

        copySnapshotIdentifier = 'copy-' + snapshot_identifier

        if snapshot_object['Status'].lower() == 'available' and search_tag_copy(response_tags) and copySnapshotIdentifier not in filtered.keys():
            try:
                # copy snapshot using new key
                response_copy = client.copy_db_snapshot(
                    SourceDBSnapshotIdentifier = snapshot_object['Arn'],
                    TargetDBSnapshotIdentifier = copySnapshotIdentifier,
                    KmsKeyId = KMS_KEY_COPY,
                    Tags = [{'Key': 'CopiedBy', 'Value': 'Snapshot Tool for RDS'},
                        {'Key': 'CreatedBy', 'Value': 'Snapshot Tool for RDS'},
                        {'Key': 'CreatedOn', 'Value': timestamp_format },
                        {'Key': 'shareAndCopy', 'Value': 'YES'}]
                    )

            except Exception as e:
                logger.error('Exception sharing %s' % snapshot_identifier)
                logger.exception('Exception detail: ')
                pending_snapshots += 1

    if pending_snapshots > 0:
        log_message = 'Could not copy all snapshots. Pending: %s' % pending_snapshots
        logger.error(log_message)
        raise SnapshotToolException(log_message)


if __name__ == '__main__':
    lambda_handler(None, None)
