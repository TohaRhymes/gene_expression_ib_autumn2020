#!/bin/bash

cd ~ && mkdir index
cd index

# Creating hisat index
hisat2-build -p 4 /opt/data/reference/GRCm38.primary_assembly.genome.fa GRCm38.primary_assembly

# Creating kallisto index
kallisto index -i gencode.vM20.transcripts.kalliso.idx /opt/data/reference/gencode.vM20.transcripts.fa.gz