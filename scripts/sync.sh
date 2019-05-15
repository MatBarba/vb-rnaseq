
RES_DIR=$1
FINAL_DIR=$2

set -ue
if [ "$RES_DIR" == "" ]; then echo "Result_dir needed"; exit; fi
if [ "$FINAL_DIR" == "" ]; then echo "Final_dir needed"; exit; fi

for sp in $(ls $RES_DIR); do
  echo $sp
  rsync -av $RES_DIR/$sp/*.bam* $FINAL_DIR/bam/$sp/
  rsync -av $RES_DIR/$sp/*.bw $FINAL_DIR/bigwig/$sp/
  rsync -av $RES_DIR/$sp/*.cmds.json $FINAL_DIR/cmds/$sp/
done
