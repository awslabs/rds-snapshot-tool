#
# Copyright 2018 Amazon.com, Inc. or its affiliates. All Rights Reserved.
# Licensed under the Apache License, Version 2.0 (the "License"). You may not use this file except in compliance with the License. A copy of the License is located at
#    http://aws.amazon.com/apache2.0/
# or in the "license" file accompanying this file. This file is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

# Makefile for generating zip files for lambda functions and then copying them
# to S3 for deployment.
#
# Behaviour: 
# Creates a file named ._foo.whatever based on foo.whatever.Uploads foo.whatever to
# the S3 bucket. The ._ file is a hack to figure out whether the file has
# been modified since the last time we uploaded to s3.

# Override S3 destination by changing this variable or setting it in the
# environment
S3DEST?=re17-gd-cfn

# Set these if, for example, you use profiles on the AWS command line
# or if your 'aws' executable is in a weird place.
AWSARGS=--region us-east-1 --profile re17Admin
AWSCMD=aws
ZIPCMD=zip

# disable all implicit make rules
.SUFFIXES:

# if you define "._foo.zip" as a file on this line, then it will look for
# a folder called foo, copy the standard files into it, and then make foo.zip.
all:	._copy_snapshots_dest_rds.zip \
	._copy_snapshots_no_x_account_rds.zip \
	._delete_old_snapshots_dest_rds.zip \
	._delete_old_snapshots_no_x_account_rds.zip \
	._delete_old_snapshots_rds.zip \
	._share_snapshots_rds.zip \
	._take_snapshots_rds.zip

clean:
	rm -f ._*

._%: %
	"$(AWSCMD)" $(AWSARGS) s3 cp "$<" "s3://$(S3DEST)" \
		--grants read=uri=http://acs.amazonaws.com/groups/global/AllUsers
	cp "$<" "$@"

%.zip: %
	$(ZIPCMD) -jr "$@" "$<" snapshots_tool_utils.py

install: 
	"$(AWSCMD)" $(AWSARGS) cloudformation create-stack --template-url \
		"https://$(S3DEST).s3.amazonaws.com/challenge-2-cfn.yaml" \
		 --capabilities CAPABILITY_IAM --stack-name gd-re17-C