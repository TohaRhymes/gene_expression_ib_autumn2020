#!/bin/bash

##### Step 1: preparation
# starting with only one sample
# downloading data from SRA

TAG=SRR8193349
DATADIR="/home/USERNAME/data"; mkdir -p "$DATADIR"
date
echo "STARTED DOWNLOADING THE DATA"
fastq-dump -O "$DATADIR" --gzip $TAG
date

##### Step 2: fastqc

ANALYSISDIR="/home/USERNAME/analysis"; mkdir -p "$ANALYSISDIR"
OUTDIR="${ANALYSISDIR}/fastqc/${TAG}"; mkdir -p "$OUTDIR"
fastqc -o "$OUTDIR" "${DATADIR}/${TAG}.fastq.gz" |& tee "$OUTDIR/${TAG}.fastqc.log"

##### Step 3: alignment

HISAT_IDX=/home/USERNAME/index/GRCm38.primary_assembly

# aligning to the genome reference

OUTDIR="${ANALYSISDIR}/hisat2/$TAG"; mkdir -p "$OUTDIR"
date
hisat2 -p 4 --new-summary -x  ${HISAT_IDX} \
  -U "${DATADIR}/${TAG}.fastq.gz" \
  2> "$OUTDIR/$TAG.log" \
  | samtools view -b - > "$OUTDIR/$TAG.raw.bam"
date

ls $OUTDIR
cat $OUTDIR/$TAG.log

##### Step 4: post-processing of alignment

# post-processing the alignments

date
samtools sort -@ 4 -O bam "$OUTDIR/$TAG.raw.bam" > "$OUTDIR/$TAG.bam" && \
  samtools index "$OUTDIR/$TAG.bam" && \
  rm -v "$OUTDIR/$TAG.raw.bam"
date

##### Step 5: generate coverage file

# calculating coverage for vizualization
bamCoverage -b "$OUTDIR/$TAG.bam" -o "$OUTDIR/$TAG.cov.bw" |& tee "$OUTDIR/$TAG.bamcov.log"


##### Step 6: QC

REFGENE_MODEL=/opt/data/reference/mm10_Gencode_VM18.bed
infer_experiment.py -i "$OUTDIR/$TAG.bam" \
  -r $REFGENE_MODEL | tee "$OUTDIR/$TAG.infer_experiment.txt"

REFGENE_MODEL=/opt/data/reference/mm10_Gencode_VM18.bed
read_distribution.py -i "$OUTDIR/$TAG.bam" \
  -r $REFGENE_MODEL | tee "$OUTDIR/$TAG.read_distribution.txt"

REFGENE_MODEL=/opt/data/reference/mm10.HouseKeepingGenes.bed
geneBody_coverage.py \
   -i $OUTDIR/$TAG.bam \
   -o $OUTDIR/$TAG \
   -r $REFGENE_MODEL
  
##### Step 7: counting reads

GTF=/opt/data/reference/gencode.vM20.annotation.gtf

OUTDIR="${ANALYSISDIR}/featureCounts/$TAG"; mkdir -p "$OUTDIR"
date
featureCounts -a "$GTF" -s 2 -o "$OUTDIR/$TAG.fc.txt" \
  "${ANALYSISDIR}/hisat2/$TAG/$TAG.bam" |& tee "$OUTDIR/$TAG.log"
date

head "$OUTDIR/$TAG.fc.txt"
wc -l "$OUTDIR/$TAG.fc.txt"


##### Step 8: Kallisto

KALLISTO_IDX=/home/USERNAME/index/gencode.vM20.transcripts.kalliso.idx

OUTDIR="${ANALYSISDIR}/kallisto/$TAG"; mkdir -p "$OUTDIR"
date
# --single -l and -s option should be set for each dataset separately, 200+-50 is most common for single end
kallisto quant -i $KALLISTO_IDX -t 4 \
   --single -l 200 -s 50 \
   --plaintext \
    -o $OUTDIR \
    ${DATADIR}/${TAG}.fastq.gz |& tee $OUTDIR/$TAG.log
date

head $OUTDIR/abundance.tsv

##### Step 9: multiqc for everything

multiqc -x .Rproj.user -f /home/USERNAME/analysis -o /home/USERNAME/analysis
