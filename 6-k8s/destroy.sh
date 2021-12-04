#!/usr/bin/env bash
export NAME=latency.${1-teticio.co.uk}
export KOPS_STATE_STORE=s3://clusters.${1-teticio.co.uk}
export AWS_REGION=${2-eu-west-2}
export AWS_ACCESS_KEY_ID=$(aws configure get default.aws_access_key_id)
export AWS_SECRET_ACCESS_KEY=$(aws configure get default.aws_secret_access_key)

kops delete cluster --name ${NAME} --yes
read -p "Press any key to continue..." -n1 -s
