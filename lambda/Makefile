#
# Copyright 2018 Amazon.com, Inc. or its affiliates. All Rights Reserved.
# Licensed under the Apache License, Version 2.0 (the "License"). You may not use this file except in compliance with the License. A copy of the License is located at
#    http://aws.amazon.com/apache2.0/
# or in the "license" file accompanying this file. This file is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

# Makefile for generating zip files for lambda functions and then copying them
# to S3 for deployment. This Makefile will NOT WORK unless you fill in the S3DEST
# and AWSARGS variables below. Once those parameters are established, simply type
# 'make' or 'gmake' (depending on your UNIX-like OS) and it will build. 
#
# Behaviour: 
# Creates a file named ._foo.whatever based on foo.whatever.Uploads foo.whatever to
# the S3 bucket. The ._ file is a hack to figure out whether the file has
# been modified since the last time we uploaded to s3.

# Override S3 destination by changing this variable or setting it in the
# environment
S3DEST?=[YOUR BUCKET HERE]

# Set these if, for example, you use profiles on the AWS command line
# or if your 'aws' executable is in a weird place.
AWSARGS=--region [YOUR REGION] --profile [YOUR PROFILE, or 'default', or remove this]
AWSCMD=aws
ZIPCMD=zip

# disable all implicit make rules
.SUFFIXES:

# if you define "._foo" as a file on this line, then it will zip up a
# folder called foo, adding a standard file into it to make foo.zip.
all:	._copy_snapshots_dest_rds \
	._copy_snapshots_no_x_account_rds \
	._delete_old_snapshots_dest_rds \
	._delete_old_snapshots_no_x_account_rds \
	._delete_old_snapshots_rds \
	._share_snapshots_rds \
	._take_snapshots_rds

clean:
	rm -f ._*
	rm -rf package/*

._%: %.zip
	"$(AWSCMD)" $(AWSARGS) s3 cp "$<" "s3://$(S3DEST)" \
		--grants read=uri=http://acs.amazonaws.com/groups/global/AllUsers
	cp "$<" "$@"

# This rule is a BSD make style rule that says "to make foo.zip, call
# 'zip -jqr foo snapshot_tool_utils.py'"
%.zip: %.install
	$(ZIPCMD) -jqr "$@" "$<" snapshots_tool_utils.py
	cd package; $(ZIPCMD) -r9 "../$@"  .

%.install:
	pip install --target ./package retry==0.9.1

