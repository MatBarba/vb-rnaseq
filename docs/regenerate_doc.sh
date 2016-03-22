if [ -z "$ENSEMBL_ROOT_DIR" ]; then echo "No Ensembl dir" ; exit ; fi
perl $ENSEMBL_ROOT_DIR/ensembl-production/scripts/sql2html.pl -i ../sql/tables.sql -o rnaseqdb_schema.html --sort_headers 0 --sort_tables 0 --include_css --d RNAseqDB --intro rnaseqdb_schema.inc
sed -i 's%<head>%<head>\n<link rel="stylesheet" type="text/css" media="all" href="rnaseqdb_doc.css" />%' rnaseqdb_schema.html
sed -i '/ul.sql_schema_table_column_type li/d' rnaseqdb_schema.html

