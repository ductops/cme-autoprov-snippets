#!/bin/bash
aws s3 cp s3://my-cg-bootstrap-bucket/aws/bootstrap-v1.sh /var/tmp/bootstrap-v1.sh
chmod +x /var/tmp/bootstrap-v1.sh
/var/tmp/bootstrap-v1.sh
