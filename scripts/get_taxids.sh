#!/usr/bin/env bash

set -un
MYSQL=$1
VERSION=$2
CORES=$($MYSQL -e 'SHOW DATABASES LIKE "%_core_'$VERSION'%"' -N)

keys="
species.scientific_name
species.production_name
species.taxonomy_id
species.strain
assembly.name
assembly.accession
sample.location_param
"

for DB in $CORES; do
  for KEY in $keys; do
    VALUE=$( $MYSQL $DB -N -e 'SELECT meta_value FROM meta WHERE meta_key="'${KEY}'";' )
    echo -n "$VALUE	"
  done
  echo
done

set +un
