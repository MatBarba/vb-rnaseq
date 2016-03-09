# This script regenerates the DBIx classes for the RNAseqDB

# Necessary arguments
# $HOST_COMMAND must be something like mysql-prod-vb
HOST_COMMAND=$1
# The name of the RNAseq database to get the schema from
DB_NAME=$2

if [ -z "$HOST_COMMAND" ]; then echo "Host command needed as argument 1"; exit; fi
if [ -z "$DB_NAME" ]; then echo "Database name needed ar argument 2"; exit; fi

# Get database credentials, and store them in $DB_HOST, etc.
eval $($HOST_COMMAND details env_DB_)

# DBIx (re)generation
perl -MDBIx::Class::Schema::Loader=make_schema_at,dump_to_dir:./modules/ \
  -e "make_schema_at(\"RNAseqDB::Schema\",{ debug => 1} , [ \"dbi:mysql:host=$DB_HOST:port=$DB_PORT:database=$DB_NAME\", $DB_USER, $DB_PASS ])"

