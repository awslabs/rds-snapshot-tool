MAKEFLAGS=--warn-undefined-variables

SRCFOLDER := lambda
LAMBDAS := copy_snapshots_dest_rds copy_snapshots_no_x_account_rds delete_old_snapshots_dest_rds delete_old_snapshots_no_x_account_rds delete_old_snapshots_rds share_snapshots_rds take_snapshots_rds
buildLAMBDAS := $(LAMBDAS)

all: clean build upload

build: $(buildLAMBDAS)
	
$(buildLAMBDAS):
	echo "Build $@"
	mkdir -p output
	cd ${SRCFOLDER}/$@ && zip ../../output/$@.zip *
clean:
	rm -f output/*.zip
upload:
	aws --profile cbc-prod s3 cp  output/ s3://clouds-configuration/clouds/lambda/rds-snapshot-tool/ --recursive

