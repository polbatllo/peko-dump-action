#!/bin/sh -l
set -eu

THEDATE=`date +%y%m%d%H%M`
FILENAME=$INPUT_IDENTIFIER.$THEDATE.tar.gz
echo "Initial File Identifier ${INPUT_IDENTIFIER}"
echo "Final File Identifier ${FILENAME}"
rm -rf /tmp/${INPUT_IDENTIFIER}
rm -rf /backups
mkdir /tmp/${INPUT_IDENTIFIER}
mkdir /backups

# Define the SSL parameters in a variable
ssl_parameters=""
if [ -n "${INPUT_MYSQL_SSL_CA}" ]; then
  echo "Using SSL CA connection ${INPUT_MYSQL_SSL_CA}"
  ssl_parameters="--ssl-mode=VERIFY_IDENTITY --ssl-ca=${INPUT_MYSQL_SSL_CA}"
fi

if [ "${INPUT_USE_PLANET_SCALE_DDL}" == "true" ]; then
  echo "Using planet scale schema exporter"
  pscale branch schema vapor main --service-token "${INPUT_PS_SERVICE_TOKEN}" --service-token-id "${INPUT_PS_TOKEN_ID}" --org "${INPUT_PS_ORG}" > /tmp/"${INPUT_IDENTIFIER}"/ddl
else
  echo "Using default schema exporter"
  mysqlsh ${INPUT_DB_USERNAME}@${INPUT_DB_HOST} --password=${INPUT_DB_PASSWORD} ${ssl_parameters} -e "util.dumpSchemas([${INPUT_SCHEMAS}], '/tmp/${INPUT_IDENTIFIER}/ddl', {showProgress: true, consistent: false, events: false, routines: false, triggers: false, threads: ${INPUT_THREADS}, bytesPerChunk: '${INPUT_CHUNK_SIZE}', ddlOnly: true})"
fi

echo "Starting data export with ${INPUT_THREADS} threads and a chunk size of ${INPUT_CHUNK_SIZE}"

mysqlsh ${INPUT_DB_USERNAME}@${INPUT_DB_HOST} --password=${INPUT_DB_PASSWORD} ${ssl_parameters} -e "set workload='OLAP';"
mysqlsh ${INPUT_DB_USERNAME}@${INPUT_DB_HOST} --password=${INPUT_DB_PASSWORD} ${ssl_parameters} -e "select @@workload';"

mysqlsh ${INPUT_DB_USERNAME}@${INPUT_DB_HOST} --password=${INPUT_DB_PASSWORD} ${ssl_parameters} -e "util.dumpSchemas([${INPUT_SCHEMAS}], '/tmp/${INPUT_IDENTIFIER}/data', {showProgress: true, consistent: false, events: false, routines: false, triggers: false, threads: ${INPUT_THREADS}, bytesPerChunk: '${INPUT_CHUNK_SIZE}', dataOnly: true, excludeTables: [${INPUT_EXCLUDED_TABLES}]})"
mysqlsh ${INPUT_DB_USERNAME}@${INPUT_DB_HOST} --password=${INPUT_DB_PASSWORD} ${ssl_parameters} -e "util.dumpTables('vapor', ['bookingsync_events'], '/tmp/${INPUT_IDENTIFIER}/data', {'where' : {'vapor.bookingsync_events': 'team_id=1', 'vapor.bookingsync_events': 'created_at > CURRENT_DATE - INTERVAL 1 MONTH'}})"

echo "Compressing dump"
cd /tmp
tar -czf ${FILENAME} ${INPUT_IDENTIFIER}
mv ${FILENAME} /backups
rm -rf /tmp/${INPUT_IDENTIFIER}
cd /backups
FILE_SIZE=$(wc -c "${FILENAME}" | awk '{print $1}')
echo "Finished Dump. File size: ${FILE_SIZE}"
cd /

#S3 parameters
INPUT_S3STORAGE_TYPE="STANDARD"

function putS3
{
  file_path=$1
  aws_path=$2
  bucket="${INPUT_S3_BUCKET}"
  date=$(date -R)
  acl="x-amz-acl:private"
  content_type="application/x-compressed-tar"
  storage_type="x-amz-storage-class:${INPUT_S3STORAGE_TYPE}"
  string="PUT\n\n$content_type\n$date\n$acl\n$storage_type\n/${bucket}/${aws_path}/${file_path##/*/}"
  signature=$(echo -en "${string}" | openssl sha1 -hmac "${INPUT_S3_SECRET}" -binary | base64)
  curl -s --retry 3 --retry-delay 10 -X PUT -T "$file_path" \
       -H "Host: $bucket.s3-${INPUT_AWS_REGION}.amazonaws.com" \
       -H "Date: $date" \
       -H "Content-Type: $content_type" \
       -H "$storage_type" \
       -H "$acl" \
       -H "Authorization: AWS ${INPUT_S3_KEY}:$signature" \
       "https://$bucket.s3-${INPUT_AWS_REGION}.amazonaws.com/${aws_path}/${file_path##/*/}"
}

echo "Sending output to S3: Bucket: ${INPUT_S3_BUCKET}, Path: ${INPUT_AWS_FOLDER_PATH}/${FILENAME}"
putS3 /backups/${FILENAME} ${INPUT_AWS_FOLDER_PATH}
echo "Finished sending output to S3, cleaning up"
rm -rf /backups
echo "All finished"