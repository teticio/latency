#!/usr/bin/env bash
export NAME=latency.${1-teticio.co.uk}
export KOPS_STATE_STORE=s3://clusters.${1-teticio.co.uk}
export AWS_REGION=${2-eu-west-2}
export AWS_ACCESS_KEY_ID=$(aws configure get default.aws_access_key_id)
export AWS_SECRET_ACCESS_KEY=$(aws configure get default.aws_secret_access_key)

kops create cluster \
  --zones=${AWS_REGION}a \
  --node-count=1 \
  --master-size="t2.micro" \
  --node-size="t2.micro" \
  ${NAME}
kops update cluster ${NAME} --yes --admin
kops validate cluster ${NAME} --wait 20m

kubectl apply -f 8-k8s/deployment.yaml
echo http://`kubectl get svc latency-service -o jsonpath="{.status.loadBalancer.ingress[0].hostname}"`
read -p "Press any key to continue..." -n1 -s
