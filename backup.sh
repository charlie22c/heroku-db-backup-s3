#!/bin/bash

PYTHONHOME=/app/vendor/awscli/
DB_ALIAS=""
Green='\033[0;32m'
EC='\033[0m'
FILENAME=`date +%Y-%m-%d_%H-%M`
echo $FILENAME
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

# set bucket path and db url based on alias
case $DB_ALIAS in
    analytics)
    DB_URL_FOR_BACKUP=$ANALYTICS_DATABASE_URL
    DB_BACKUP_S3_BUCKET_PATH="pi-analytics-production-backups"
    DB_NAME="analytics"
    echo "analytics detected"
    ;;
    primary)
    echo "primary detected"
    DB_URL_FOR_BACKUP="replace_me"
    DB_BACKUP_S3_BUCKET_PATH="pi-primary-production-backups"
    DB_NAME="primary"
    ;;
    *)
    echo "DB_ALIAS does not match"
    exit 1
    ;;
esac

echo "test"
echo $DB_URL_FOR_BACKUP
echo "test end"

if [[ -z "$DB_BACKUP_S3_BUCKET_PATH" ]]; then
  echo "Missing DB_BACKUP_S3_BUCKET_PATH variable"
  exit 1
fi
if [[ -z "$DB_URL_FOR_BACKUP" ]] ; then
  echo "Missing DB_URL_FOR_BACKUP variable"
  exit 1
fi

printf "${Green}Start dump${EC}"

pg_dump $DB_URL_FOR_BACKUP | gzip | openssl enc -aes-256-cbc -e -pass "env:DB_BACKUP_ENC_KEY" > /tmp/"${DB_NAME}_${FILENAME}".gz.enc

printf "${Green}Move dump to AWS${EC}"
AWS_ACCESS_KEY_ID=$DB_BACKUP_AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY=$DB_BACKUP_AWS_SECRET_ACCESS_KEY /app/vendor/bin/aws --region $DB_BACKUP_AWS_DEFAULT_REGION s3 cp /tmp/"${DB_NAME}_${FILENAME}".gz.enc s3://$DB_BACKUP_S3_BUCKET_PATH/"${DB_NAME}_${FILENAME}".gz.enc

# cleaning after all
rm -rf /tmp/"${DB_NAME}_${FILENAME}".gz.enc
