#!/bin/bash
set -euo pipefail

cd /opt/pairdrop

curl -fsSL "https://raw.githubusercontent.com/AhtishamHussain/PairDrop/master/deploy/docker-compose.yml" -o /opt/pairdrop/docker-compose.yml
curl -fsSL "https://raw.githubusercontent.com/AhtishamHussain/PairDrop/master/deploy/docker-compose.rtc.yml" -o /opt/pairdrop/docker-compose.rtc.yml

TOKEN="$(curl -fsS -X PUT http://169.254.169.254/latest/api/token -H 'X-aws-ec2-metadata-token-ttl-seconds: 60')"
REGION="$(curl -fsS -H "X-aws-ec2-metadata-token: ${TOKEN}" http://169.254.169.254/latest/dynamic/instance-identity/document | python3 -c 'import json,sys; print(json.load(sys.stdin)["region"])')"
ACCOUNT="$(aws sts get-caller-identity --query Account --output text)"
ECR="${ACCOUNT}.dkr.ecr.${REGION}.amazonaws.com"
STABLE="${ECR}/pairdrop:stable"
PREVIOUS="${ECR}/pairdrop:previous"

aws ecr get-login-password --region "$REGION" | docker login --username AWS --password-stdin "$ECR"

if docker image inspect "$STABLE" >/dev/null 2>&1; then
  docker tag "$STABLE" "$PREVIOUS" || true
fi

TAG="$(aws ssm get-parameter --name /pairdrop/image_tag --query Parameter.Value --output text)"
NEW="${ECR}/pairdrop:${TAG}"
docker pull "$NEW"
docker tag "$NEW" "$STABLE"

COMPOSE=(docker compose -f /opt/pairdrop/docker-compose.yml)
if aws ssm get-parameter --name /pairdrop/rtc_config --with-decryption >/dev/null 2>&1; then
  umask 077
  aws ssm get-parameter --name /pairdrop/rtc_config --with-decryption --query Parameter.Value --output text > /opt/pairdrop/rtc_config.json
  chmod 600 /opt/pairdrop/rtc_config.json
  COMPOSE+=( -f /opt/pairdrop/docker-compose.rtc.yml)
else
  rm -f /opt/pairdrop/rtc_config.json
fi

export PAIRDROP_IMAGE="$STABLE"
rollback() {
  if docker image inspect "$PREVIOUS" >/dev/null 2>&1; then
    export PAIRDROP_IMAGE="$PREVIOUS"
    "${COMPOSE[@]}" up -d --remove-orphans --wait
    echo "automatic rollback to previous image"
  fi
}

"${COMPOSE[@]}" up -d --remove-orphans --wait || {
  rollback
  exit 1
}

if ! curl -fsS --max-time 10 http://127.0.0.1/ >/dev/null; then
  rollback
  exit 1
fi

docker image prune -f
echo "deploy ok ${TAG}"
