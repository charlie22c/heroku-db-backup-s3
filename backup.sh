#!/bin/bash

PYTHONHOME=/app/vendor/awscli/
DB_ALIAS=""
GREEN='\033[0;32m'
EC='\033[0m'
DATE=`date +%Y_%m_%d`

# terminate script on any fails
set -e

while [[ $# -gt 1 ]]
do
key="$1"

case $key in
    -dbalias|--dbalias)
    DB_ALIAS="$2"
    shift
    ;;
esac
shift
done

if [[ -z "$DB_ALIAS" ]]; then
  echo "Missing DB_ALIAS variable"
  exit 1
fi

if [[ -z "$DB_BACKUP_AWS_ACCESS_KEY_ID" ]]; then
  echo "Missing DB_BACKUP_AWS_ACCESS_KEY_ID variable"
  exit 1
fi
if [[ -z "$DB_BACKUP_AWS_SECRET_ACCESS_KEY" ]]; then
  echo "Missing DB_BACKUP_AWS_SECRET_ACCESS_KEY variable"
  exit 1
fi
if [[ -z "$DB_BACKUP_AWS_DEFAULT_REGION" ]]; then
  echo "Missing DB_BACKUP_AWS_DEFAULT_REGION variable"
  exit 1
fi
if [[ -z "$DB_BACKUP_ENC_KEY" ]]; then
  echo "Missing DB_BACKUP_ENC_KEY variable"
  exit 1
fi
if [[ -z "$DB_BACKUP_ENC_KEY_VERSION" ]]; then
  echo "Missing DB_BACKUP_ENC_KEY_VERSION variable"
  exit 1
fi

# set bucket path and db url based on alias
case $DB_ALIAS in
    analytics)
    echo "analytics detected"
    DB_URL_FOR_BACKUP=$ANALYTICS_DATABASE_URL
    DB_BACKUP_S3_BUCKET_PATH="pi-analytics-production-backups"
    DB_NAME="analytics"
    ;;
    primary)
    echo "primary detected"
    DB_URL_FOR_BACKUP=$PRIMARY_DATABASE_URL
    DB_BACKUP_S3_BUCKET_PATH="pi-primary-production-backups"
    DB_NAME="primary"
    ;;
    *)
    echo "DB_ALIAS does not match"
    exit 1
    ;;
esac

if [[ -z "$DB_BACKUP_S3_BUCKET_PATH" ]]; then
  echo "Missing DB_BACKUP_S3_BUCKET_PATH variable"
  exit 1
fi
if [[ -z "$DB_URL_FOR_BACKUP" ]] ; then
  echo "Missing DB_URL_FOR_BACKUP variable"
  exit 1
fi

printf "${GREEN}Start dump${EC}"

FILENAME="${DB_NAME}_${DATE}_KEY_${DB_BACKUP_ENC_KEY_VERSION}.dump.gz.enc"
pg_dump -Fc --compress=9 $DB_URL_FOR_BACKUP | openssl enc -aes-256-cbc -e -pass "env:DB_BACKUP_ENC_KEY" > /tmp/$FILENAME

printf "${GREEN}Move dump to AWS${EC}"
AWS_ACCESS_KEY_ID=$DB_BACKUP_AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY=$DB_BACKUP_AWS_SECRET_ACCESS_KEY /app/vendor/bin/aws --region $DB_BACKUP_AWS_DEFAULT_REGION s3 cp /tmp/$FILENAME s3://$DB_BACKUP_S3_BUCKET_PATH/$FILENAME

# cleaning after all
rm -rf /tmp/$FILENAME
