#!/bin/bash
# Guy Leonard MMXVI

##
# This is just a suggested workflow, it works on our servers...you will have
# to adapt it to your location.

## This script uses CEGMA - notoriously difficult to install and now unsupported
# You might not want to use it, you are safe to comment it out

## It also uses BUSCO
# I still don't trust BUSCO hence also using CEGMA
# If you see something like this:
# Error: Sequence file ./run_testing//augustus_proteins/64334.fas is empty or misformatted
# just ignore it, BUSCO is 'working' it's an error from hmmer and there are no gene predictions
# for the SCOs

# Number of Cores to Use
THREADS=8

## Change these to your server's directory locations

## NCBI Databases
# NCBI 'nt' Database Location
NCBI_NT=/storage/ncbi/nt/nt
# NCBI Taxonomy
NCBI_TAX=/storage/ncbi/taxdump

## CEGMA Environment Variables
# CEGMA DIR
export CEGMA=/home/cs02gl/programs/CEGMA_v2
export PERL5LIB=$PERL5LIB:/home/cs02gl/programs/CEGMA_v2/lib
# This is a pretty important one not to forget
# else you get this error
# FATAL ERROR when running local map 6400: "No such file or directory"
export WISECONFIGDIR=/usr/share/wise/
## Ammend PATH for CEGMA bin
export PATH=$PATH:/home/cs02gl/programs/CEGMA_v2/bin

## BUSCO Environment Variables
# BUSCO Lineage Location
BUSCO_DB=/storage/databases/BUSCO/eukaryota
# Augustus Config Path
export AUGUSTUS_CONFIG_PATH=~/programs/augustus-3.0.2/config/

## Locations of binaries, if not in path
# and tests to make sure they can be called
#PIGz
command -v pigz >/dev/null 2>&1 || { echo "I require pigz but it's not installed.  Aborting." >&2; exit 1;}
#TRIM_GALORE
command -v trim_galore >/dev/null 2>&1 || { echo "I require Trim Galore! but it's not installed.  Aborting." >&2; exit 1;}
#PEAR
command -v pear >/dev/null 2>&1 || { echo "I require PEAR but it's not installed.  Aborting." >&2; exit 1;}
#SPAdes
SPADES=/home/cs02gl/programs/SPAdes-3.7.0-Linux/bin/
command -v $SPADES/spades.py >/dev/null 2>&1 || { echo "I require SPAdes but it's not installed.  Aborting." >&2; exit 1;}
#QUAST
QUAST=/home/cs02gl/programs/quast-3.2
command -v $QUAST/quast.py >/dev/null 2>&1 || { echo "I require QUAST but it's not installed.  Aborting." >&2; exit 1;}
#CEGMA
CEGMA_DIR=/home/cs02gl/programs/CEGMA_v2/bin
command -v $CEGMA_DIR/cegma >/dev/null 2>&1 || { echo "I require CEGMA but it's not installed.  Aborting." >&2; exit 1;}
#BUSCO
BUSCO=/home/cs02gl/programs/BUSCO_v1.1b1
command -v $BUSCO/BUSCO_v1.1b1.py >/dev/null 2>&1 || { echo "I require BUSCO but it's not installed.  Aborting." >&2; exit 1;}
#BWA
command -v bwa >/dev/null 2>&1 || { echo "I require bwa but it's not installed.  Aborting." >&2; exit 1;}
#SAMTOOLS1.3
command -v samtools1.3 >/dev/null 2>&1 || { echo "I require Samtools 1.3 but it's not installed.  Aborting." >&2; exit 1;}
#BLASTN
command -v blastn >/dev/null 2>&1 || { echo "I require BLASTn but it's not installed.  Aborting." >&2; exit 1;}
#BLOBTOOLS
BLOBTOOLS=/home/cs02gl/programs/blobtools
command -v $BLOBTOOLS/blobtools >/dev/null 2>&1 || { echo "I require BLOBTOOLS but it's not installed.  Aborting." >&2; exit 1;}
#MultiQC
command -v multiqc >/dev/null 2>&1 || { echo "I require MultiQC but it's not installed.  Aborting." >&2; exit 1;}

## Try not change below here...
# Working Directory
WD=`pwd`
echo "$WD"

# Get filenames for current Single Cell Library
# Locations of FASTQs = Sample_**_***/raw_illumina_reads/
for DIRS in */ ; do
	echo "Working in $DIRS"
	cd $DIRS/raw_illumina_reads

	# GZIP FASTQs
	# saving space down the line, all other files will be gzipped
	echo "gzipping *.fastq files"
	time pigz -9 -R *.fastq

	# Get all fastq.gz files
	FASTQ=(*.fastq.gz)

	# Run Trim Galore!
	# minimum length of 150
	# minimum quality of Q20
	# run FASTQC on trimmed
	# GZIP output
	echo "Running Trimming"
	time trim_galore -q 20 --fastqc --gzip --length 150 \
	--paired $WD/$DIRS/raw_illumina_reads/${FASTQ[0]} $WD/$DIRS/raw_illumina_reads/${FASTQ[1]}

        # Get all fq.gz files - these are the default names from Trim Galore!
	# Making it nice and easy to distinguish from our original .fastq inputs
        FILENAME=(*.fq.gz)

	# Run PEAR
	# default settings
	# output: pear_overlap
	mkdir -p PEAR
	cd PEAR
	echo "Running PEAR"
	time pear -f $WD/$DIRS/raw_illumina_reads/${FILENAME[0]} \
        -r $WD/$DIRS/raw_illumina_reads/${FILENAME[1]} \
        -o pear_overlap -j $THREADS | tee pear.log

	# Lets GZIP these too!
	echo "gzipping fastq files"
	pigz -9 -R *.fastq
	cd ../

	# Run SPAdes
	# single cell mode - default kmers 21,33,55
	# careful mode - runs mismatch corrector
	mkdir -p SPADES
	cd SPADES
	echo "Running SPAdes"
	time $SPADES/spades.py --sc --careful -t $THREADS \
	--s1 $WD/$DIRS/raw_illumina_reads/PEAR/pear_overlap.assembled.fastq.gz \
	--pe1-1 $WD/$DIRS/raw_illumina_reads/PEAR/pear_overlap.unassembled.forward.fastq.gz \
	--pe1-2 $WD/$DIRS/raw_illumina_reads//PEAR/pear_overlap.unassembled.reverse.fastq.gz \
	-o overlapped_and_paired | tee spades.log
	cd ../

	# Run QUAST
	# eukaryote mode
	# glimmer protein predictions
	mkdir -p QUAST
	cd QUAST
	echo "Running QUAST"
	time python $QUAST/quast.py -o quast_reports -t $THREADS \
	--min-contig 100 -f --eukaryote --scaffolds \
	--glimmer $WD/$DIRS/raw_illumina_reads/SPADES/overlapped_and_paired/scaffolds.fasta | tee quast.log
	cd ../

	# Run CEGMA
	# Genome mode
	echo "Running CEGMA"
	mkdir -p CEGMA
	cd CEGMA
	time $CEGMA_DIR/cegma -T $THREADS -g $WD/$DIRS/raw_illumina_reads/SPADES/overlapped_and_paired/scaffolds.fasta -o cegma
	cd ../

	# Run BUSCO
	echo "Running BUSCO"
	mkdir -p BUSCO
	cd BUSCO
	python3 $BUSCO/BUSCO_v1.1b1.py \
        -g $WD/$DIRS/raw_illumina_reads/SPADES/overlapped_and_paired/scaffolds.fasta \
	-c $THREADS -l $BUSCO_DB -o busco -f
	cd ../

	# Run BlobTools
	mkdir -p BLOBTOOLS
	cd BLOBTOOLS
	mkdir -p MAPPING
	cd MAPPING
	# index assembly (scaffolds.fa) with BWA
	echo "Indexing Assembly"
	time bwa index -a bwtsw $WD/$DIRS/raw_illumina_reads/SPADES/overlapped_and_paired/scaffolds.fasta | tee bwa.log

	# map original reads to assembly with BWA MEM
	echo "Mapping reads to Assembly"
	time bwa mem -t $THREADS $WD/$DIRS/raw_illumina_reads/SPADES/overlapped_and_paired/scaffolds.fasta $WD/$DIRS/raw_illumina_reads/${FILENAME[0]} \
	$WD/$DIRS/raw_illumina_reads/${FILENAME[1]} > $WD/$DIRS/raw_illumina_reads/BLOBTOOLS/MAPPING/scaffolds_mapped_reads.sam | tee -a bwa.log

	# sort and convert sam to bam with SAMTOOLS
	echo "Sorting SAM File and Converting to BAM"
	time samtools1.3 sort -@ $THREADS -o $WD/$DIRS/raw_illumina_reads/BLOBTOOLS/MAPPING/scaffolds_mapped_reads.bam \
	$WD/$DIRS/raw_illumina_reads/BLOBTOOLS/MAPPING/scaffolds_mapped_reads.sam | tee -a samtools.log

	echo "Indexing Bam"
	time samtools1.3 index $WD/$DIRS/raw_illumina_reads/BLOBTOOLS/MAPPING/scaffolds_mapped_reads.bam | tee -a samtools.log

	if [ ! -f $WD/$DIRS/raw_illumina_reads/BLOBTOOLS/MAPPING/scaffolds_mapped_reads.bam.bai]
	then
		echo -e "[ERROR]\t[$DIRS]: No index file was created for your BAM file. !?" >> $WD/$DIRS/raw_illumina_reads/errors.txt
		# blobtools create will crash without this file, so we might as well move on to the next library...
		break
	fi

	# delete sam file - save some disk space, we have the bam now
	rm *.sam
	cd ../

	# run blast against NCBI 'nt'
	mkdir -p BLAST
	cd BLAST
	echo "Running BLAST"
	time blastn -task megablast \
	-query $WD/$DIRS/raw_illumina_reads/SPADES/overlapped_and_paired/scaffolds.fasta \
	-db $NCBI_NT \
	-evalue 1e-10 \
	-num_threads $THREADS \
	-outfmt '6 qseqid staxids bitscore std sscinames sskingdoms stitle' \
	-culling_limit 5 \
	-out $WD/$DIRS/raw_illumina_reads/BLOBTOOLS/BLAST/scaffolds_vs_nt_1e-10.megablast | tee blast.log
	cd ../

	# run blobtools create
	echo "Running BlobTools CREATE - slow"
	cd $WD/$DIRS/raw_illumina_reads/BLOBTOOLS/
	time $BLOBTOOLS/blobtools create -i $WD/$DIRS/raw_illumina_reads/SPADES/overlapped_and_paired/scaffolds.fasta \
	--nodes $NCBI_TAX/nodes.dmp --names $NCBI_TAX/names.dmp \
	-t $WD/$DIRS/raw_illumina_reads/BLOBTOOLS/BLAST/scaffolds_vs_nt_1e-10.megablast \
	-b $WD/$DIRS/raw_illumina_reads/BLOBTOOLS/MAPPING/scaffolds_mapped_reads.bam \
	-o scaffolds_mapped_reads_nt_1e-10_megablast_blobtools | tee -a $WD/$DIRS/raw_illumina_reads/BLOBTOOLS/blobtools.log

	if  [ ! -f $WD/$DIRS/raw_illumina_reads/BLOBTOOLS/scaffolds_mapped_reads_nt_1e-10_megablast_blobtools.BlobDB.json]
	then
		echo -e "[ERROR]\t[$DIRS]: Missing blobtools JSON, no tables or figures produced." >> $WD/$DIRS/raw_illumina_reads/errors.txt
	else
		# run blobtools view - table output
		# Standard Output - Phylum
		echo "Running BlobTools View"
		time $BLOBTOOLS/blobtools view -i $WD/$DIRS/raw_illumina_reads/BLOBTOOLS/scaffolds_mapped_reads_nt_1e-10_megablast_blobtools.BlobDB.json \
		--out $WD/$DIRS/raw_illumina_reads/BLOBTOOLS/scaffolds_mapped_reads_nt_1e-10_megablast_blobtools_phylum_table.csv | tee -a blobtools.log
		# Other Output - Species
		time $BLOBTOOLS/blobtools view -i $WD/$DIRS/raw_illumina_reads/BLOBTOOLS/scaffolds_mapped_reads_nt_1e-10_megablast_blobtools.BlobDB.json \
		--out $WD/$DIRS/raw_illumina_reads/BLOBTOOLS/scaffolds_mapped_reads_nt_1e-10_megablast_blobtools_superkingdom_table.csv \
		--rank superkingdom | tee -a blobtools.log

		# run blobtools plot - image output
		# Standard Output - Phylum, 7 Taxa
		echo "Running BlobTools Plots - Standard + SVG"
		time $BLOBTOOLS/blobtools plot -i $WD/$DIRS/raw_illumina_reads/BLOBTOOLS/scaffolds_mapped_reads_nt_1e-10_megablast_blobtools.BlobDB.json
		time $BLOBTOOLS/blobtools plot -i $WD/$DIRS/raw_illumina_reads/BLOBTOOLS/scaffolds_mapped_reads_nt_1e-10_megablast_blobtools.BlobDB.json \
		--format svg | tee -a blobtools.log

		# Other Output - Species, 15 Taxa
		echo "Running BlobTools Plots - SuperKingdom + SVG"
		time $BLOBTOOLS/blobtools plot -i $WD/$DIRS/raw_illumina_reads/BLOBTOOLS/scaffolds_mapped_reads_nt_1e-10_megablast_blobtools.BlobDB.json \
		-r superkingdom
		time $BLOBTOOLS/blobtools plot -i $WD/$DIRS/raw_illumina_reads/BLOBTOOLS/scaffolds_mapped_reads_nt_1e-10_megablast_blobtools.BlobDB.json \
		-r superkingdom \
		--format svg | tee -a blobtools.log
	fi

	# Run MultiQC for some extra, nice stats reports on QC etc
	cd ../
        multiqc $WD/$DIRS/raw_illumina_reads/

	# Finish up.
	cd ../../
	echo "`pwd`"
	echo "Complete Run, Next or Finish."
done
