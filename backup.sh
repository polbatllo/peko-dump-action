#!/bin/sh -l
set -eu

echo "Mysql username $INPUT_DB_USERNAME"
echo "Mysql host $INPUT_DB_HOST"
THEDATE=`date +%d%m%y%H%M`
FILENAME=$INPUT_IDENTIFIER.$THEDATE.tar.gz
echo "Initial File Identifier ${INPUT_IDENTIFIER}"
echo "Final File Identifier ${FILENAME}"
rm -rf /tmp/${INPUT_IDENTIFIER}
rm -rf /backups/${INPUT_IDENTIFIER}.tar.gz
mkdir /tmp/${INPUT_IDENTIFIER}
mysqlsh ${INPUT_DB_USERNAME}@${INPUT_DB_HOST} --password=${INPUT_DB_PASSWORD} -e "util.dumpSchemas([${INPUT_SCHEMAS}], '/tmp/${INPUT_IDENTIFIER}/ddl', {showProgress: true, consistent: false, events: false, routines: false, triggers: false, threads: 30, bytesPerChunk: '100M', ddlOnly: true})"
mysqlsh ${INPUT_DB_USERNAME}@${INPUT_DB_HOST} --password=${INPUT_DB_PASSWORD} -e "util.dumpSchemas([${INPUT_SCHEMAS}], '/tmp/${INPUT_IDENTIFIER}/data', {showProgress: true, consistent: false, events: false, routines: false, triggers: false, threads: 30, bytesPerChunk: '100M', dataOnly: true, excludeTables: [${INPUT_EXCLUDED_TABLES}]})"
echo "Compressing dump"
tar -czf /tmp/${FILENAME} /tmp/${INPUT_IDENTIFIER}
mv /tmp/${FILENAME} /backups
rm -rf /tmp/${INPUT_IDENTIFIER}
echo "Finished Dump."
