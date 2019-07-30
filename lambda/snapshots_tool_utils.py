'''
Copyright 2017 Amazon.com, Inc. or its affiliates. All Rights Reserved.

Licensed under the Apache License, Version 2.0 (the "License"). You may not use this file except in compliance with the License. A copy of the License is located at

    http://aws.amazon.com/apache2.0/

or in the "license" file accompanying this file. This file is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.
'''


# snapshots_tool_utils
# Support module for the Snapshot Tool for RDS

import logging
import os
import re
from datetime import datetime, timedelta

import boto3

# Initialize everything
_LOGLEVEL = os.getenv('LOG_LEVEL', 'ERROR').strip()

_DESTINATION_REGION = os.getenv(
    'DEST_REGION', os.getenv('AWS_DEFAULT_REGION')).strip()

_KMS_KEY_DEST_REGION = os.getenv('KMS_KEY_DEST_REGION', 'None').strip()

_KMS_KEY_SOURCE_REGION = os.getenv('KMS_KEY_SOURCE_REGION', 'None').strip()

_TIMESTAMP_FORMAT = '%Y-%m-%d-%H-%M'

if os.getenv('REGION_OVERRIDE', 'NO') != 'NO':
    _REGION = os.getenv('REGION_OVERRIDE').strip()
else:
    _REGION = os.getenv('AWS_DEFAULT_REGION')

_SUPPORTED_ENGINES = [ 'mariadb', 'sqlserver-se', 'sqlserver-ee', 'sqlserver-ex', 'sqlserver-web', 'mysql', 'oracle-ee', 'postgres' ]


logger = logging.getLogger()
logger.setLevel(_LOGLEVEL.upper())


class SnapshotToolException(Exception):
    pass


def search_tag_copydbsnapshot(response):
    # Takes a list_tags_for_resource response and searches for our CopyDBSnapshot tag
    try:
        for tag in response['TagList']:
            if tag['Key'] == 'CopyDBSnapshot' and tag['Value'] == 'True': return True

    except Exception:
        return False

    else:
        return False


def search_tag_created(response):
    # Takes a describe_db_snapshots response and searches for our CreatedBy tag
    try:
        for tag in response['TagList']:
            if tag['Key'] == 'created_by' and tag['Value'] == 'Snapshot Tool for RDS': return True

    except Exception:
        return False

    else:
        return False


def search_tag_shared(response):
    # Takes a describe_db_snapshots response and searches for our shareAndCopy tag
    try:
        for tag in response['TagList']:
            if tag['Key'] == 'share_snapshot' and tag['Value'] == 'True':
                for tag2 in response['TagList']:
                    if tag2['Key'] == 'created_by' and tag2['Value'] == 'Snapshot Tool for RDS':
                        return True

    except Exception:
        return False

    return False


def search_tag_copied(response):
    # Search for a tag indicating we copied this snapshot
    try:
        for tag in response['TagList']:
            if tag['Key'] == 'CopiedBy' and tag['Value'] == 'Snapshot Tool for RDS':
                return True

    except Exception:
        return False

    return False


def get_own_snapshots_no_x_account(pattern, response, REGION):
    # Filters our own snapshots
    filtered = {}
    for snapshot in response['DBSnapshots']:

        if snapshot['SnapshotType'] == 'manual' and re.search(pattern, snapshot['DBSnapshotIdentifier']) and snapshot['Engine'] in _SUPPORTED_ENGINES:
            client = boto3.client('rds', region_name=REGION)
            response_tags = client.list_tags_for_resource(
                ResourceName=snapshot['DBSnapshotArn'])

            if search_tag_created(response_tags):
                filtered[snapshot['DBSnapshotIdentifier']] = {
                    'Arn': snapshot['DBSnapshotArn'], 'Status': snapshot['Status'], 'DBInstanceIdentifier': snapshot['DBInstanceIdentifier']}
        # Changed the next line to search for ALL_CLUSTERS or ALL_SNAPSHOTS so it will work with no-x-account
        elif snapshot['SnapshotType'] == 'manual' and pattern == 'ALL_SNAPSHOTS' and snapshot['Engine'] in _SUPPORTED_ENGINES:
            client = boto3.client('rds', region_name=REGION)
            response_tags = client.list_tags_for_resource(
                ResourceName=snapshot['DBSnapshotArn'])

            if search_tag_created(response_tags):
                filtered[snapshot['DBSnapshotIdentifier']] = {
                    'Arn': snapshot['DBSnapshotArn'], 'Status': snapshot['Status'], 'DBInstanceIdentifier': snapshot['DBInstanceIdentifier']}

    return filtered


def get_shared_snapshots(pattern, response):
    # Returns a dict with only shared snapshots filtered by pattern,
    # with DBSnapshotIdentifier as key and the response as attribute
    filtered = {}
    for snapshot in response['DBSnapshots']:
        if snapshot['SnapshotType'] == 'shared' and re.search(pattern, get_snapshot_identifier(snapshot)) and snapshot['Engine'] in _SUPPORTED_ENGINES:
            filtered[get_snapshot_identifier(snapshot)] = {
                'Arn': snapshot['DBSnapshotIdentifier'], 'Encrypted': snapshot['Encrypted'], 'DBInstanceIdentifier': snapshot['DBInstanceIdentifier']}
            if snapshot['Encrypted'] is True:
                filtered[get_snapshot_identifier(snapshot)]['KmsKeyId'] = snapshot['KmsKeyId']

        elif snapshot['SnapshotType'] == 'shared' and pattern == 'ALL_SNAPSHOTS' and snapshot['Engine'] in _SUPPORTED_ENGINES:
            filtered[get_snapshot_identifier(snapshot)] = {
                'Arn': snapshot['DBSnapshotIdentifier'], 'Encrypted': snapshot['Encrypted'], 'DBInstanceIdentifier': snapshot['DBInstanceIdentifier']}
            if snapshot['Encrypted'] is True:
                filtered[get_snapshot_identifier(snapshot)]['KmsKeyId'] = snapshot['KmsKeyId']
    return filtered


def get_snapshot_identifier(snapshot):
    # Function that will return the RDS Snapshot identifier given an ARN
    match = re.match('arn:aws:rds:.*:.*:snapshot:(.+)',
                     snapshot['DBSnapshotArn'])
    return match.group(1)


def get_own_snapshots_dest(pattern, response):
    # Returns a dict  with local snapshots, filtered by pattern,
    # with DBSnapshotIdentifier as key and Arn, Status as attributes
    filtered = {}
    for snapshot in response['DBSnapshots']:

        if snapshot['SnapshotType'] == 'manual' and re.search(pattern, snapshot['DBSnapshotIdentifier']) and snapshot['Engine'] in _SUPPORTED_ENGINES:
            filtered[snapshot['DBSnapshotIdentifier']] = {
                'Arn': snapshot['DBSnapshotArn'], 'Status': snapshot['Status'], 'Encrypted': snapshot['Encrypted'], 'DBInstanceIdentifier': snapshot['DBInstanceIdentifier']}

            if snapshot['Encrypted'] is True:
                filtered[snapshot['DBSnapshotIdentifier']]['KmsKeyId'] = snapshot['KmsKeyId']

        elif snapshot['SnapshotType'] == 'manual' and pattern == 'ALL_SNAPSHOTS' and snapshot['Engine'] in _SUPPORTED_ENGINES:
            filtered[snapshot['DBSnapshotIdentifier']] = {
                'Arn': snapshot['DBSnapshotArn'], 'Status': snapshot['Status'], 'Encrypted': snapshot['Encrypted'], 'DBInstanceIdentifier': snapshot['DBInstanceIdentifier'] }

            if snapshot['Encrypted'] is True:
                filtered[snapshot['DBSnapshotIdentifier']]['KmsKeyId'] = snapshot['KmsKeyId']

    return filtered


def filter_instances(taggedinstance, pattern, instance_list):
    # Takes the response from describe-db-instances and filters according to pattern in DBInstanceIdentifier
    filtered_list = []

    for instance in instance_list['DBInstances']:

        if taggedinstance == 'TRUE':
            client = boto3.client('rds', region_name=_REGION)
            response = client.list_tags_for_resource(ResourceName=instance['DBInstanceArn'])

        if pattern == 'ALL_INSTANCES' and instance['Engine'] in _SUPPORTED_ENGINES:
            if (taggedinstance == 'TRUE' and search_tag_copydbsnapshot(response)) or taggedinstance == 'FALSE':
                filtered_list.append(instance)

        else:
            match = re.search(pattern, instance['DBInstanceIdentifier'])

            if match and instance['Engine'] in _SUPPORTED_ENGINES:
                if (taggedinstance == 'TRUE' and search_tag_copydbsnapshot(response)) or taggedinstance == 'FALSE':
                    filtered_list.append(instance)

    return filtered_list


def get_own_snapshots_source(pattern, response, backup_interval=None):
    # Filters our own snapshots
    filtered = {}
    for snapshot in response['DBSnapshots']:
        # No need to get tags for snapshots outside of the backup interval
        if backup_interval and snapshot['SnapshotCreateTime'].replace(tzinfo=None) < datetime.utcnow().replace(tzinfo=None) - timedelta(hours=backup_interval):
            continue

        if snapshot['SnapshotType'] == 'manual' and re.search(pattern, snapshot['DBSnapshotIdentifier']) and snapshot['Engine'] in _SUPPORTED_ENGINES:
            client = boto3.client('rds', region_name=_REGION)
            response_tags = client.list_tags_for_resource(
                ResourceName=snapshot['DBSnapshotArn'])

            if search_tag_created(response_tags):
                filtered[snapshot['DBSnapshotIdentifier']] = {
                    'Arn': snapshot['DBSnapshotArn'], 'Status': snapshot['Status'], 'DBInstanceIdentifier': snapshot['DBInstanceIdentifier']}

        elif snapshot['SnapshotType'] == 'manual' and (pattern == 'ALL_CLUSTERS' or pattern == 'ALL_SNAPSHOTS' or pattern == 'ALL_INSTANCES') and snapshot['Engine'] in _SUPPORTED_ENGINES:
            client = boto3.client('rds', region_name=_REGION)
            response_tags = client.list_tags_for_resource(
                ResourceName=snapshot['DBSnapshotArn'])

            if search_tag_created(response_tags):
                filtered[snapshot['DBSnapshotIdentifier']] = {
                    'Arn': snapshot['DBSnapshotArn'], 'Status': snapshot['Status'], 'DBInstanceIdentifier': snapshot['DBInstanceIdentifier']}

    return filtered


def get_timestamp_no_minute(snapshot_identifier, snapshot_list):
    # Get a timestamp from the name of a snapshot and strip out the minutes
    pattern = '%s-(.+)-\d{2}' % snapshot_list[snapshot_identifier]['DBInstanceIdentifier']
    timestamp_format = '%Y-%m-%d-%H'
    date_time = re.search(pattern, snapshot_identifier)

    if date_time is not None:
        return datetime.strptime(date_time.group(1), timestamp_format)


def get_timestamp(snapshot_identifier, snapshot_list):
    # Searches for a timestamp on a snapshot name
    pattern = '%s-(.+)' % snapshot_list[snapshot_identifier]['DBInstanceIdentifier']
    date_time = re.search(pattern, snapshot_identifier)

    if date_time is not None:

        try:
            return datetime.strptime(date_time.group(1), _TIMESTAMP_FORMAT)

        except Exception:
            return None

    return None


def get_latest_snapshot_ts(instance_identifier, filtered_snapshots):
    # Get latest snapshot for a specific DBInstanceIdentifier
    timestamps = []

    for snapshot,snapshot_object in filtered_snapshots.items():

        if snapshot_object['DBInstanceIdentifier'] == instance_identifier:
            timestamp = get_timestamp_no_minute(snapshot, filtered_snapshots)

            if timestamp is not None:
                timestamps.append(timestamp)

    if len(timestamps) > 0:
        return max(timestamps)

    else:
        return None


def requires_backup(backup_interval, instance, filtered_snapshots):
    # Returns True if latest snapshot is older than INTERVAL
    latest = get_latest_snapshot_ts(instance['DBInstanceIdentifier'], filtered_snapshots)

    if latest is not None:
        backup_age = datetime.now() - latest

        if backup_age.total_seconds() >= (backup_interval * 60 * 60):
            return True

        else:
            return False

    elif latest is None:
        return True


def paginate_api_call(client, api_call, objecttype, *args, **kwargs):
    # Takes an RDS boto client and paginates through api_call calls and returns a list of objects of objecttype
    response = {}
    kwargs_string = ','.join(['%s=%s' % (arg, value) for arg,value in kwargs.items() ])

    if kwargs:
        temp_response = eval('client.%s(%s)' % (api_call, kwargs_string))
    else:
        temp_response = eval('client.%s()' % api_call)
    response[objecttype] = temp_response[objecttype][:]

    while 'Marker' in temp_response:
        if kwargs:
            temp_response = eval('client.%s(Marker="%s",%s)' % (api_call, temp_response['Marker'], kwargs_string))
        else:
            temp_response = eval('client.%s(Marker="%s")' % (api_call, temp_response['Marker']))
        for obj in temp_response[objecttype]:
            response[objecttype].append(obj)

    return response


def copy_local(snapshot_identifier, snapshot_object):
    client = boto3.client('rds', region_name=_REGION)

    tags = [{
            'Key': 'CopiedBy',
            'Value': 'Snapshot Tool for RDS'
            }]

    if snapshot_object['Encrypted']:
        logger.info('Copying encrypted snapshot {} locally'.format(snapshot_identifier))
        response = client.copy_db_snapshot(
            SourceDBSnapshotIdentifier = snapshot_object['Arn'],
            TargetDBSnapshotIdentifier = snapshot_identifier,
            KmsKeyId = _KMS_KEY_SOURCE_REGION,
            Tags = tags)

    else:
        logger.info('Copying snapshot {} locally'.format(snapshot_identifier))
        response = client.copy_db_snapshot(
            SourceDBSnapshotIdentifier = snapshot_object['Arn'],
            TargetDBSnapshotIdentifier = snapshot_identifier,
            Tags = tags)

    return response


def copy_remote(snapshot_identifier, snapshot_object):
    client = boto3.client('rds', region_name=_DESTINATION_REGION)

    if snapshot_object['Encrypted']:
        logger.info('Copying encrypted snapshot %s to remote region %s' % (snapshot_object['Arn'], _DESTINATION_REGION))
        response = client.copy_db_snapshot(
            SourceDBSnapshotIdentifier = snapshot_object['Arn'],
            TargetDBSnapshotIdentifier = snapshot_identifier,
            KmsKeyId= _KMS_KEY_DEST_REGION,
            SourceRegion= _REGION,
            CopyTags= True)

    else:
        logger.info('Copying snapshot %s to remote region %s' % (snapshot_object['Arn'], _DESTINATION_REGION))
        response = client.copy_db_snapshot(
            SourceDBSnapshotIdentifier = snapshot_object['Arn'],
            TargetDBSnapshotIdentifier = snapshot_identifier,
            SourceRegion = _REGION,
            CopyTags= True)

    return response
