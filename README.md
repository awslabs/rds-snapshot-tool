# Snapshot Tool for Amazon RDS

The Snapshot Tool for RDS automates the task of creating manual snapshots, copying them into a different account and a different region, and deleting them after a specified number of days. It also allows you to specify the backup schedule (at what times and how often) and a retention period in days. This version will work with all Amazon RDS instances except Amazon Aurora. For a version that works with Amazon Aurora, please visit the [Snapshot Tool for Amazon Aurora](https://github.com/awslabs/aurora-snapshot-tool).

**IMPORTANT** Run the Cloudformation templates on the same **region** where your RDS instances run (both in the source and destination accounts). If that is not possible because AWS Step Functions is not available, you will need to use the **SourceRegionOverride** parameter explained below.


## Getting Started

To deploy on your accounts, you will need to use the Cloudformation templates provided.
* Deploy `snapshot_tool_rds_source.yml` in the source account (the account that runs the RDS instances)
* Deploy `snapshot_tool_rds_dest.yml` in the destination account (the account where you'd like to keep your snapshots)


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
* **BackupSchedule** - at what times and how often to run backups. Set in accordance with **BackupInterval**. For example, set **BackupInterval** to 8 hours and **BackupSchedule** 0 0,8,16 * * ? * if you want backups to run at 0, 8 and 16 UTC. If your backups run more often than **BackupInterval**, snapshots will only be created when the latest snapshot is older than **BackupInterval**. If you set BackupInterval to more than once a day, make sure to adjust BackupSchedule accordingly or backups will only be taken at the times specified in the CRON expression.
* **InstanceNamePattern** - set to the names of the instances you want this tool to back up. You can use a Python regex that will be searched in the instance identifier. For example, if your instances are named *prod-01*, *prod-02*, etc, you can set **InstanceNamePattern** to *prod*. The string you specify will be searched anywhere in the name unless you use an anchor such as ^ or $. In most cases, a simple name like "prod" or "dev" will suffice. More information on Python regular expressions here: https://docs.python.org/2/howto/regex.html
* **DestinationAccount** - the account where you want snapshots to be copied to
* **LogLevel** - The log level you want as output to the Lambda functions. ERROR is usually enough. You can increase to INFO or DEBUG.
* **RetentionDays** - the amount of days you want your snapshots to be kept. Snapshots created more than **RetentionDays** ago will be automatically deleted (only if they contain a tag with Key: CreatedBy, Value: Snapshot Tool for RDS)
* **ShareSnapshots** - Set to TRUE if you are sharing snapshots with a different account. If you set to FALSE, StateMachine, Lambda functions and associated Cloudwatch Alarms related to sharing across accounts will not be created. It is useful if you only want to take backups and manage the retention, but do not need to copy them across accounts or regions.
* **SourceRegionOverride** - if you are running RDS on a region where Step Functions is not available, this parameter will allow you to override the source region. For example, at the time of this writing, you may be running RDS in Northern California (us-west-1) and would like to copy your snapshots to Montreal (ca-central-1). Neither region supports Step Functions at the time of this writing so deploying this tool there will not work. The solution is to run this template in a region that supports Step Functions (such as North Virginia or Ohio) and set **SourceRegionOverride** to *us-west-1*.
**IMPORTANT**: deploy to the closest regions for best results.

* **CodeBucket** - this parameter specifies the bucket where the code for the Lambda functions is located. Leave to DEFAULT_BUCKET to download from an AWS-managed bucket. The Lambda function code is located in the ```lambda``` directory. These files need to be on the **root* of the bucket or the CloudFormation templates will fail.
* **DeleteOldSnapshots** - Set to TRUE to enable functionality that will delete snapshots after **RetentionDays**. Set to FALSE if you want to disable this functionality completely. (Associated Lambda and State Machine resources will not be created in the account). **WARNING** If you decide to enable this functionality later on, bear in mind it will delete **all snapshots**, older than **RetentionDays**, created by this tool; not just the ones created after **DeleteOldSnapshots** is set to TRUE.
* **TaggedInstance** - Set to TRUE to enable functionality that will only take snapshots for RDS Instances with tag CopyDBSnapshot set to True. The settings in InstanceNamePattern and TaggedInstance both need to evaluate successfully for a snapshot to be created (logical AND).

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
* **CrossAccountCopy**  - if you only need to copy snapshots across regions and not to a different account, set this to FALSE. When set to false, the no-x-account version of the Lambda functions will be deployed and will expect snapshots to be in the same account as they run.
* **KmsKeySource** KMS Key to be used for copying encrypted snapshots on the source region. If you are copying to a different region, you will also need to provide a second key in the destination region.
* **KmsKeyDestination** KMS Key to be used for copying encrypted snapshots to the destination region. If you are not copying to a different region, this parameter is not necessary.
* **RetentionDays** - as in the source account, the amount of days you want your snapshots to be kept. **Do not set this parameter to a value lower than the source account.** Snapshots created more than **RetentionDays** ago will be automatically deleted (only if they contain a tag with Key: CopiedBy, Value: Snapshot Tool for RDS)

## How it Works

There are two sets of Lambda Step Functions that take regular snapshots and copy them across. Snapshots can take time, and they do not signal when they're complete. Snapshots are scheduled to *begin* at a certain time using CloudWatch Events. Then different Lambda Step Functions run periodically to look for new snapshots. When they find new snapshots, they do the sharing and the copying functions.

### In the Source Account

A CloudWatch Event is scheduled to trigger Lambda Step Function State Machine named `stateMachineTakeSnapshotsRDS`. That state machine invokes a function named `lambdaTakeSnapshotsRDS`. That function triggers a snapshot and applies some standard tags. It matches RDS instances using a regular expression on their names. 

There are two other state machines and lambda functions. The `statemachineShareSnapshotsRDS` looks for new snapshots created by the `lambdaTakeSnapshotsRDS` function. When it finds them, it shares them with the destination account. This state machine is, by default, run every 10 minutes. (To change it, you need to change the `ScheduleExpression` property of the `cwEventShareSnapshotsRDS` resource in `snapshots_tool_rds_source.json`). If it finds a new snapshot that is intended to be shared, it shares the snapshot.

The other state machine is the `statemachineDeleteOldSnapshotsRDS` and it calls `lambdaDeleteOldSnapshotsRDS` to delete snapshots according to the `RetentionDays` parameter when the stack is launched. This state machine is, by default, run once each hour. (To change it, you need to change the `ScheduleExpression` property of the `cwEventDeleteOldSnapshotsRDS` resource in `snapshots_tool_rds_source.json`). If it finds a snapshot that is older than the retention time, it deletes the snapshot.

### In the Destination Account

There are two state machines and corresponding lambda functions. The `statemachineCopySnapshotsDestRDS` looks for new snapshots that have been shared but have not yet been copied. When it finds them, it creates a copy in the destination account, encrypted with the KMS key that has been stipulated. This state machine is, by default, run every 10 minutes. (To change it, you need to change the `ScheduleExpression` property of the `cwEventCopySnapshotsRDS` resource in `snapshots_tool_rds_dest.json`).

The other state machine is just like the corresponding state machine and function in the source account. The state machine is `statemachineDeleteOldSnapshotsRDS` and it calls `lambdaDeleteOldSnapshotsRDS` to delete snapshots according to the `RetentionDays` parameter when the stack is launched. This state machine is, by default, run once each hour. (To change it, you need to change the `ScheduleExpression` property of the `cwEventDeleteOldSnapshotsRDS` resource in `snapshots_tool_rds_source.json`). If it finds a snapshot that is older than the retention time, it deletes the snapshot.


## Building From Source and Deploying

As published, these CloudFormation templates will pull the zip files for the Lambda functions from an AWS-owned and operated S3 bucket. You can also choose to build from source and deploy to your own bucket in your own account. To build, you need to be on a unix-like system (e.g., macOS or some flavour of Linux) and you need to have `make` and `zip`.

1. Create an S3 bucket to hold the Lambda function zip files. The bucket must be in the same region where the Lambda functions will run. And the Lambda functions must run in the same region as the RDS instances. 

1. Clone the repository

1. Edit the `Makefile` file and set `S3DEST` to be the bucket name where you want the functions to go. Set the `AWSARGS`, `AWSCMD` and `ZIPCMD` variables as well.

1. Type `make` at the command line. It will call `zip` to make the zip files, and then it will call `aws s3 cp` to copy the zip files to the bucket you named.

1. Be sure to use the correct bucket name in the `CodeBucket` parameter when launching the stack in both accounts.

## Updating

This tool is fundamentally stateless. The state is mainly in the tags on the snapshots themselves and the parameters to the CloudFormation stack. If you make changes to the parameters or make changes to the Lambda function code, it is best to delete the stack and then launch the stack again. 

## Authors

* **Marcelo Coronel** - [mrcoronel](https://github.com/mrcoronel)

## License

This project is licensed under the Apache License - see the [LICENSE.txt](LICENSE.txt) file for details
