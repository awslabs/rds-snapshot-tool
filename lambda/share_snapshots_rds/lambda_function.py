"""
This Lambda function shares snapshots created by aurora_take_snapshot with the account set in the environment variable DEST_ACCOUNT
It will only share snapshots tagged with share_snapshot and a value of True
"""


import logging
import os
from datetime import datetime

import boto3
from snapshots_tool_utils import *

# Initialize from environment variable
LOGLEVEL = os.getenv('LOG_LEVEL', 'ERROR').strip()
DEST_ACCOUNTID = str(os.getenv('DEST_ACCOUNT')).strip()
PATTERN = os.getenv('PATTERN', 'ALL_INSTANCES')
TIMESTAMP_FORMAT = '%Y-%m-%d-%H-%M'
KMS_KEY_ID = str(os.getenv('KMS_KEY_ID')).strip()

if os.getenv('REGION_OVERRIDE', 'NO') != 'NO':
    REGION = os.getenv('REGION_OVERRIDE').strip()
else:
    REGION = os.getenv('AWS_DEFAULT_REGION')

SUPPORTED_ENGINES = [ 'mariadb', 'sqlserver-se', 'sqlserver-ee', 'sqlserver-ex', 'sqlserver-web', 'mysql', 'oracle-ee', 'postgres' ]

logger = logging.getLogger()
logger.setLevel(LOGLEVEL.upper())


def lambda_handler(event, context):
    pending_snapshots = 0
    client = boto3.client('rds', region_name=REGION)
    response = paginate_api_call(client, 'describe_db_snapshots', 'DBSnapshots')
    filtered = get_own_snapshots_source(PATTERN, response)
    now = datetime.now()

    # Search all snapshots for the correct tag
    for snapshot_identifier,snapshot_object in filtered.items():
        try:
            timestamp_format = now.strftime(TIMESTAMP_FORMAT)
            snapshot_arn = snapshot_object['Arn']
            response_tags = client.list_tags_for_resource(ResourceName=snapshot_arn)

            if snapshot_object['Status'].lower() == 'available':
                share_snapshot = False
                requires_reencryption = False
                for tag in response_tags['TagList']:
                    if tag['Key'] == 'share_snapshot' and tag['Value'] == 'True':
                        share_snapshot = True
                    elif tag['Key'] == 'requires_reencryption' and tag['Value'] == 'True':
                        requires_reencryption = True

                # If the snapshot requires reencryption, make a copy of the snapshot with the non-default RDS key
                if requires_reencryption:
                    logger.info('Snapshot requires reencryption: {}'.format(snapshot_identifier))
                    client.copy_db_snapshot(
                        SourceDBSnapshotIdentifier=snapshot_identifier,
                        TargetDBSnapshotIdentifier='reencrypted-'+snapshot_identifier,
                        KmsKeyId=KMS_KEY_ID,
                        Tags=[{'Key': 'created_by', 'Value': 'Snapshot Tool for RDS'},
                              {'Key': 'created_on', 'Value': timestamp_format},
                              {'Key': 'share_snapshot', 'Value': 'True'},
                              {'Key': 'requires_reencryption', 'Value': 'False'}])
                    # Delete share_snapshot tag from the original snapshot so it will be skipped on the next run
                    client.remove_tags_from_resource(ResourceName=snapshot_arn, TagKeys=['share_snapshot',
                                                                                         'requires_reencryption'])

                # If the snapshot has the non-default key, share it with the destination account
                elif share_snapshot:
                    logger.info('Sharing {} with destination account'.format(snapshot_identifier))
                    client.modify_db_snapshot_attribute(
                        DBSnapshotIdentifier=snapshot_identifier,
                        AttributeName='restore',
                        ValuesToAdd=[
                            DEST_ACCOUNTID
                        ]
                    )
                    client.remove_tags_from_resource(ResourceName=snapshot_arn, TagKeys=['share_snapshot'])
                else:
                    logger.info('Snapshot {} does not need to be shared'.format(snapshot_identifier))

        except Exception as e:
            logger.error('Exception sharing {}'.format(snapshot_identifier))
            logger.error(e)
            pending_snapshots += 1

    if pending_snapshots > 0:
        log_message = 'Could not share all snapshots. Pending: %s' % pending_snapshots
        logger.error(log_message)
        raise SnapshotToolException(log_message)


if __name__ == '__main__':
    lambda_handler(None, None)
