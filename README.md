# Snapshot Tool for Amazon RDS 

The Snapshot Tool for RDS automates the task of creating manual snapshots, copying them into a different account and a different region, and deleting them after a specified number of days. It also allows you to specify the backup schedule (at what times and how often) and a retention period in days. This version will work with all Amazon RDS instances except Amazon Aurora. For a version that works with Amazon Aurora, please visit the [Snapshot Tool for Amazon Aurora](https://github.com/awslabs/aurora-snapshot-tool).

**IMPORTANT** Run the Cloudformation templates on the same **region** where your RDS instances run (both in the source and destination accounts). If that is not possible because AWS Step Functions is not available, you will need to use the **SourceRegionOverride** parameter explained below.


## Getting Started

To deploy on your accounts, you will need to use the Cloudformation templates provided.
snapshot_tool_rds_source.json needs to run in the source account (or the account that runs the RDS instances)
snapshot_tool_rds_dest.json needs to run in the destination account (or the account where you'd like to keep your snapshots)


### Source Account
#### Components
The following components will be created in the source account: 
* 3 Lambda functions (TakeSnapshotsRDS, ShareSnapshotsRDS, DeleteOldSnapshotsRDS)
* 3 State Machines (Amazon Step Functions) to trigger execution of each Lambda function (stateMachineTakeSnapshotRDS, stateMachineShareSnapshotRDS, stateMachineDeleteOldSnapshotsRDS)
* 3 Cloudwatch Event Rules to trigger the state functions
* 3 Cloudwatch Alarms and associated SNS Topics to alert on State Machines failures
* A Cloudformation stack containing all these resources

#### Installing in the source account 
Run snapshot_tool_RDS_source.json on the Cloudformation console. 
You wil need to specify the different parameters. The default values will back up all RDS instances in the region at 1AM UTC, once a day. 
If your instances are encrypted, you will need to provide access to the KMS Key to the destination account. You can read more on how to do that here: https://aws.amazon.com/premiumsupport/knowledge-center/share-cmk-account/

Here is a break down of each parameter for the source template:

* **BackupInterval** - how many hours between backup
* **BackupSchedule** - at what times and how often to run backups. Set in accordance with **BackupInterval**. For example, set **BackupInterval** to 8 hours and **BackupSchedule** 0 0,8,16 * * ? * if you want backups to run at 0, 8 and 16 UTC. If your backups run more often than **BackupInterval**, snapshots will only be created when the latest snapshot is older than **BackupInterval**
* **InstanceNamePattern** - set to the names of the instances you want this tool to back up. You can use a Python regex that will be searched in the instance identifier. For example, if your instances are named *prod-01*, *prod-02*, etc, you can set **InstanceNamePattern** to *prod*. The string you specify will be searched anywhere in the name unless you use an anchor such as ^ or $. In most cases, a simple name like "prod" or "dev" will suffice. More information on Python regular expressions here: https://docs.python.org/2/howto/regex.html
* **DestinationAccount** - the account where you want snapshots to be copied to
* **LogLevel** - The log level you want as output to the Lambda functions. ERROR is usually enough. You can increase to INFO or DEBUG. 
* **RetentionDays** - the amount of days you want your snapshots to be kept. Snapshots created more than **RetentionDays** ago will be automatically deleted (only if they contain a tag with Key: CreatedBy, Value: Snapshot Tool for RDS)
* **ShareSnapshots** - Set to TRUE if you are sharing snapshots with a different account. If you set to FALSE, StateMachine, Lambda functions and associated Cloudwatch Alarms related to sharing across accounts will not be created. It is useful if you only want to take backups and manage the retention, but do not need to copy them across accounts or regions.
* **SourceRegionOverride** - if you are running RDS on a region where Step Functions is not available, this parameter will allow you to override the source region. For example, at the time of this writing, you may be running RDS in Northern California (us-west-1) and would like to copy your snapshots to Montreal (ca-central-1). Neither region supports Step Functions at the time of this writing so deploying this tool there will not work. The solution is to run this template in a region that supports Step Functions (such as North Virginia or Ohio) and set **SourceRegionOverride** to *us-west-1*. 
**IMPORTANT**: deploy to the closest regions for best results.

* **CodeBucket** - this parameter specifies the bucket where the code for the Lambda functions is located. Leave to DEFAULT_BUCKET to download from an AWS-managed bucket. The Lambda function code is located in the ```lambda``` directory. These files need to be on the **root* of the bucket or the CloudFormation templates will fail. 
* **DeleteOldSnapshots** - Set to TRUE to enable functionanility that will delete snapshots after **RetentionDays**. Set to FALSE if you want to disable this functionality completely. (Associated Lambda and State Machine resources will not be created in the account). **WARNING** If you decide to enable this functionality later on, bear in mind it will delete **all snapshots**, older than **RetentionDays**, created by this tool; not just the ones created after **DeleteOldSnapshots** is set to TRUE.
* **ShareSnapshots** - Set to TRUE to enable functionality that will share snapshots with **DestAccount**. Set to FALSE to completely disable sharing. (Associated Lambda and State Machine resources will not be created in the account.)

### Destination Account
#### Components
The following components will be created in the destination account: 
* 2 Lambda functions (CopySnapshotsDestRDS, DeleteOldSnapshotsDestRDS)
* 2 State Machines (Amazon Step Functions) to trigger execution of each Lambda function (stateMachineCopySnapshotsDestRDS, stateMachineDeleteOldSnapshotsDestRDS)
* 2 Cloudwatch Event Rules to trigger the state functions
* 2 Cloudwatch Alarms and associated SNS Topics to alert on State Machines failures
* A Cloudformation stack containing all these resources

On your destination account, you will need to run snapshot_tool_RDS_dest.json on the Cloudformation. As before, you will need to run it in a region where Step Functions is available. 
The following parameters are available:

* **DestinationRegion** - the region where you want your snapshots to be copied. If you set it to the same as the source region, the snapshots will be copied from the source account but will be kept in the source region. This is useful if you would like to keep a copy of your snapshots in a different account but would prefer not to copy them to a different region.
* **SnapshotPattern** - similar to InstanceNamePattern. See above
* **DeleteOldSnapshots** - Set to TRUE to enable functionanility that will delete snapshots after **RetentionDays**. Set to FALSE if you want to disable this functionality completely. (Associated Lambda and State Machine resources will not be created in the account). **WARNING** If you decide to enable this functionality later on, bear in mind it will delete ALL SNAPSHOTS older than RetentionDays created by this tool, not just the ones created after **DeleteOldSnapshots** is set to TRUE.
* **CrossAccountCopy**  - if you only need to copy snapshots across regions and not to a different false, set this to FALSE. When set to false, the no-x-account version of the Lambda functions will be deployed and will expect snapshots to be in the same account as they run. 
* **KmsKeySource** KMS Key to be used for copying encrypted snapshots on the source region. If you are copying to a different region, you will also need to provide a second key in the destination region. 
* **KmsKeyDestination** KMS Key to be used for copying encrypted snapshots to the destination region. If you are not copying to a different region, this parameter is not necessary. 
* **RetentionDays** - as in the source account, the amount of days you want your snapshots to be kept. **Do not set this parameter to a value lower than the source account.** Snapshots created more than **RetentionDays** ago will be automatically deleted (only if they contain a tag with Key: CopiedBy, Value: Snapshot Tool for RDS)

## Authors

* **Marcelo Coronel** - [mrcoronel](https://github.com/mrcoronel)

## License

This project is licensed under the Apache License - see the [LICENSE.txt](LICENSE.txt) file for details
