'''
Copyright 2017 Amazon.com, Inc. or its affiliates. All Rights Reserved.

Licensed under the Apache License, Version 2.0 (the "License"). You may not use this file except in compliance with the License. A copy of the License is located at

    http://aws.amazon.com/apache2.0/

or in the "license" file accompanying this file. This file is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.
'''

# share_snapshots_rds
# This Lambda function shares snapshots created by aurora_take_snapshot with the account set in the environment variable DEST_ACCOUNT
# It will only share snapshots tagged with shareAndCopy and a value of YES
import boto3
from datetime import datetime
import time
import os
import logging
import re
from snapshots_tool_utils import *


# Initialize from environment variable
LOGLEVEL = os.getenv('LOG_LEVEL', 'INFO').strip()
DEST_ACCOUNTID = str(os.getenv('DEST_ACCOUNT','000000000000')).strip()
PATTERN = os.getenv('PATTERN', 'ALL_INSTANCES')

if os.getenv('REGION_OVERRIDE', 'NO') != 'NO':
    REGION = os.getenv('REGION_OVERRIDE').strip()
else:
    REGION = os.getenv('AWS_DEFAULT_REGION')
BACKUP_KMS = os.getenv('BACKUP_KMS','arn:aws:kms:eu-west-1:500154599841:key/bf4df85d-5c43-4e76-b171-74f5b820de9e')

SUPPORTED_ENGINES = [ 'mariadb', 'sqlserver-se', 'sqlserver-ee', 'sqlserver-ex', 'sqlserver-web', 'mysql', 'oracle-se', 'oracle-se1', 'oracle-se2', 'oracle-ee', 'postgres' ]

logger = logging.getLogger()
logger.setLevel(LOGLEVEL.upper())



def lambda_handler(event, context):
    now = datetime.now()
    pending_snapshots = 0
    client = boto3.client('rds', region_name=REGION)
    response = paginate_api_call(client, 'describe_db_snapshots', 'DBSnapshots', SnapshotType='manual')
    filtered = get_own_snapshots_source(PATTERN, response)

    # Search all snapshots for the correct tag
    for snapshot_identifier,snapshot_object in filtered.items():
        snapshot_arn = snapshot_object['Arn']
        response_tags = client.list_tags_for_resource(
            ResourceName=snapshot_arn)

        if snapshot_object['Status'].lower() == 'available' and search_tag_shared(response_tags):
            
            snapshot_info = client.describe_db_snapshots(
                DBSnapshotIdentifier=snapshot_arn
            )
            timestamp_format = now.strftime('%Y-%m-%d-%H-%M')
            targetSnapshot = snapshot_info['DBSnapshots'][0]['DBInstanceIdentifier'] + '-' + timestamp_format
            logger.info('snapshot_info:{}'.format(snapshot_info))
            
            if snapshot_info['DBSnapshots'][0]['Encrypted'] == True:
                kms = get_kms_type(snapshot_info['DBSnapshots'][0]['KmsKeyId'],REGION)
            else:
                kms = False
                
           
            logger.info('Checking Snapshot: {}'.format(snapshot_identifier))
            
            
            if kms is True and BACKUP_KMS is not '':
                try:
                    copy_status = client.copy_db_snapshot(
                    SourceDBSnapshotIdentifier=snapshot_arn,
                    TargetDBSnapshotIdentifier=targetSnapshot,
                    KmsKeyId=BACKUP_KMS,
                    CopyTags=True
                )
                    pass
                except Exception as e:
                    logger.error('Exception copy {}: {}'.format(snapshot_arn, e))
                    pending_snapshots += 1
                    pass
                else:
                    modify_status = client.add_tags_to_resource(
                    ResourceName=snapshot_arn,
                    Tags=[
                        {
                            'Key': 'shareAndCopy',
                            'Value': 'No'
                        }
                        ]
                        )
                    
            
            try:
                # Share snapshot with dest_account
                logger.info('Sharing snapshot: {}'.format(snapshot_identifier))
                response_modify = client.modify_db_snapshot_attribute(
                    DBSnapshotIdentifier=snapshot_identifier,
                    AttributeName='restore',
                    ValuesToAdd=[
                        DEST_ACCOUNTID
                    ]
                )
            except Exception as e:
                logger.error('Exception sharing %s (%s)' % (snapshot_identifier, e))
                pending_snapshots += 1

    if pending_snapshots > 0:
        log_message = 'Could not share all snapshots. Pending: %s' % pending_snapshots
        logger.error(log_message)
        raise SnapshotToolException(log_message)


if __name__ == '__main__':
    lambda_handler(None, None)
