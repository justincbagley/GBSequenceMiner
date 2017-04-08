#!/bin/sh

##########################################################################################
#                         GBSequenceMiner v0.1.0, February 2017                          #
#   SHELL SCRIPT FOR MINING GENBANK NUMBERS (GI/ACCESSION NOs.) AND CORRESPONDING DNA    # 
#   SEQUENCE DATA FROM A GROUP OF PDFs OF PUBLISHED MANUSCRIPTS (LIT REVIEW)             #
#   Copyright (c)2017 Justin C. Bagley, Universidade de Brasília, Brasília, DF, Brazil.  #
#   See the README and license files on GitHub (http://github.com/justincbagley) for     #
#   further information. Last update: February 27, 2017. For questions, please email     #
#   jcbagley@unb.br.                                                                     #
##########################################################################################

echo "
##########################################################################################
#                         GBSequenceMiner v0.1.0, February 2017                          #
##########################################################################################
"

######################################## START ###########################################
echo "INFO      | $(date) | Starting GBSequenceMiner analysis... "
echo "INFO      | $(date) | STEP #1: SETUP AND USER INPUT. "
###### Set paths, environmental variables, and filetypes as different variables:
	MY_PATH=`pwd -P`
echo "INFO      | $(date) |          Setting working directory to: $MY_PATH "
	CR=$(printf '\n')
	calc () { 
	bc -l <<< "$@"; 
}

##--Read in the PDF files. We assume that the current working directory contains **ONLY** 
##--PDF files for manuscripts we want to analyze/extract sequences from, plus this shell 
##--script. Furthermore, the PDF filenames should begin by providing reference information 
##--in one of the following three formats: "Author1_YEAR_", "Author1_and_Author2_YEAR_", 
##--or "Author1_et_al_YEAR_".
echo "INFO      | $(date) |          Reading in input PDF file(s)... "
	MY_PDF_FILES=./*.pdf

echo "INFO      | $(date) | STEP #2: EXTRACT POTENTIAL GENBANK NUMBER DATA FROM PDF FILES AND ORGANIZE INTO ONE FOLDER PER FILE. "
###### Ideally, the PDF files being analyzed will have only letters, numbers, and underscores 
##--in their names, _and no spaces_. However, it may be impractical to screen PDF filenames 
##--for spaces beforehand (e.g. when working with a larget number of PDFs). Thus, as a 
##--preliminary step, we test for spaces within the PDF filenames and fill in the spaces
##--with underscores, using a (non-recursive) for loop (from the following URL:
##--http://stackoverflow.com/questions/2709458/how-to-replace-spaces-in-file-names-using-a-bash-script).
echo "INFO      | $(date) |          Checking and fixing any spaces within PDF filenames... "
	pattern=" |'"
	if [[ $MY_PDF_FILES =~ $pattern ]]; then
		(
			for f in *\ *; do
				mv "$f" "${f// /_}"
			done
		)
	fi
	
echo "INFO      | $(date) |          Extracting PDF lines with putative GenBank numbers into a new file named 'pGBnos.txt'. "
###### Next, we combine find and pdfgrep (an *IMPORTANT* dependency of this script; see 
##--README for more information) to extract every line containing something like a GenBank
##--(GI/accession) number to one 'putative GB numbers' file named "pGBnos.txt":

	find . -iname '*.pdf' -exec pdfgrep "[A-Z]{2}[0-9]{6,}" {} + > ./pGBnos.txt

###### Next, we move lines from each PDF/manuscript to a new '.txt' file and place that 
##--file into a sub-folder in the current working directory ($MY_PATH). Each new text file 
##--and folder pair are given names beginning with the first 20 characters of the
##--corresponding PDF file/manuscript, which we also move into the newly created folder.
##--We complete these steps using a for loop, as follows:
echo "INFO      | $(date) |          Organizing putative GenBank numbers extracted from each of the PDFs into sub-folders. The "
echo "INFO      | $(date) |          new file and sub-folder names are taken from the first 20 characters of the original PDFs, "
echo "INFO      | $(date) |          and area as follows: "
	(
		for i in $MY_PDF_FILES; do
			AUTHOR_AND_YEAR="$(echo $i | sed 's/\.\///g; s/\(\_[0-9]\{4\}\).*$/\1/g')"
			
			basename="$(echo $i | awk '{print substr($0,0,22)}' | sed 's/\.\///g')"
			grep "$basename" ./pGBnos.txt > ${AUTHOR_AND_YEAR}.pGBnos.txt
	
			echo "INFO      | $(date) |          - $AUTHOR_AND_YEAR "
	
			mkdir $AUTHOR_AND_YEAR
			mv $i ./$AUTHOR_AND_YEAR/
			mv ${AUTHOR_AND_YEAR}.pGBnos.txt ./$AUTHOR_AND_YEAR/	
		done
	)


echo "INFO      | $(date) | STEP #3: IN EACH FOLDER, CLEAN PUTATIVE GB NUMBER FILES BY DELETING ALL CONTENT NOT RESEMBLING A "
echo "INFO      | $(date) |          GB NUMBER, THEN ORGANIZING HYPHENATED RANGES VS. SINGLE OCCURRENCES INTO SEPARATE FILES. "
###### Here, we loop through the PDF sub-folders and modify 'putative GB numbers' files 
##--(*.pGBnos.txt) to contain only GI-like numbers, with two uppercase letters followed by
##--six or more numbers (XX######). An issue is that other 'pseudo-GenBank' number strings 
##--with alphanumeric makeup similar to GenBank numbers, such as grant numbers, might also
##--match our GI format criteria. So, we first identify those numbers and break them up. We
##--then do various modifications and checks, and we use some basic calculations and flow
##--control to guide sets of commands attempting to isolate and work with putative GB 
##--numbers in hyphenated range format, versus those given in single occurrence format. 
##--Hyphenated vs. single-occurrence GB numbers are saved into separate files.
	(
		for j in ./*/; do
			cd $j;
	
				MY_PGBNOS_FILE=./*.pGBnos.txt
				basename="$(echo $MY_PGBNOS_FILE | sed 's/\.\///g; s/\.txt//g')"
				CURRENT_PDF_FILE=$(ls . | grep "\.pdf")
				
				###### A. Non-GB numbers. Attempt to solve pseudo-GenBank number problem by breaking up long 
				##--alphanumeric strings... (we want GB numbers with 6 digits, so we look for strings with 7 
				##--digits or more; need to test to make sure this works in variety of cases, but it should 
				##--work since grant numbers are not like repetitive GB nos). Note: the second part of the 
				##--following lines will either break up pseudo-GenBank number matches, or, in the case that 
				##--none are present, it will do nothing and .prep1.tmp will be identical to the original file.
				sed 's/^\.\/.*\.pdf://g' $MY_PGBNOS_FILE | \
				sed 's/\([A-Z]\{2\}[0-9]\{7,\}\)//g' > ./prep1.tmp

				###### B. Text modifications. Do several things at once here: 1) Get only lines containing 
				##--putative GenBank numbers, 2) clean up front of lines (delete PDF filenames), 3) fix any
				##--hyphenated ranges so that there are no spaces around hyphens, i.e. so they're always of the 
				##--form "XX######-XX######"; and 4) remove potentially problematic dot, parenthesis, comma, or 
				##--bracket characters from the text.
				grep -h "[A-Z]\{2\}[0-9]\{6\}" ./prep1.tmp | \
				sed 's/\ \–\ /\-/g; s/\ \-\ /\-/g; s/\–/\-/g; s/\ to\ /\-/g; s/\.//g; s/\,//g; s/\;//g; s/(//g; s/)//g; s/\[//g; s/\]//g; s/\%//g' > ./prep2.tmp

				###### C. Attempt to get sets of putative GB numbers on separate lines using a long one-liner:
##				sed 's/\([A-Z]\{2\}[0-9]\{6\}\)\,/\1'$CR'/g' ./prep2.tmp | \
##				sed 's/\([A-Z]\{2\}[0-9]\{6\}\)\./\1'$CR'/g' | \
##				sed 's/\([A-Z]\{2\}[0-9]\{6\}\)\;/\1'$CR'/g' | \
##				sed 's/\([A-Z]\{2\}[0-9]\{6\}\)\ /\1'$CR'/g' | \
##				sed 's/\([A-Z]\{2\}[0-9]\{6\}\)e\([A-Z]\{2\}[0-9]\{6\}\)/\1\-\2/g' > ./prep3.tmp

				perl -pe 's/([A-Z]{2}[0-9]{6})\,/$1\n/g' ./prep2.tmp | \
				perl -pe 's/([A-Z]{2}[0-9]{6})\./$1\n/g' | \
				perl -pe 's/([A-Z]{2}[0-9]{6})\;/$1\n/g' | \
				perl -pe 's/([A-Z]{2}[0-9]{6})\ /$1\n/g' | \
				perl -pe 's/([A-Z]{2}[0-9]{6})e([A-Z]{2}[0-9]{6})/$1\-$2/g' > ./prep3.tmp

				###### CHECK NUM LINES TO MAKE SURE ALL INSTACES OF GB RANGES ARE ON SEPARATE LINES
				##--Count the number of occurrences of ranges of putative GB numbers and place in variable:
				NUM_RANGE_OCCURRENCES="$(cat ./prep2.tmp | grep -o '[A-Z]\{2\}[0-9]\{6\}[\-]*[A-Z]\{2\}[0-9]\{6\}\|[A-Z]\{2\}[0-9]\{6\}[\ \-]*[A-Z]\{2\}[0-9]\{6\}\|[A-Z]\{2\}[0-9]\{6\}\–[A-Z]\{2\}[0-9]\{6\}\|[A-Z]\{2\}[0-9]\{6\}e[A-Z]\{2\}[0-9]\{6\}' | wc -l )"
				NUM_PREP3_LINES="$(cat ./prep3.tmp | wc -l)"
				if [[ "$NUM_PREP3_LINES" -ge "$NUM_RANGE_OCCURRENCES" ]]; then
					echo "INFO      | $(date) |          $basename : PASSED first check on number of lines. "
				else
					echo "WARNING!  | $(date) |          $basename : Something went wrong. FAILED first check on number of lines. "
					echo $basename | sed 's/\.pGBnos//g' >> $MY_PATH/lineCheckFail.log.txt
				fi


				###### FILE SIZE CHECK: CHECK TO SEE IF A PDF HAD NO GENBANK NUMBERS (e.g. A MICROSAT-BASED 
				##--STUDY) AND LOG FINDINGS IF NO SEQS FOUND.
				NUM_PGBNOS_LINES="$(wc -l $MY_PGBNOS_FILE | sed 's/\.\/.*//g')"

				if [[ "$NUM_PGBNOS_LINES" -eq "0" ]]; then
					echo "WARNING!  | $(date) |          $basename : FAILED first file size check, indicating no GenBank numbers. " 
					echo $basename | sed 's/\.pGBnos//g' >> $MY_PATH/sizeCheckFail.log.txt
				else
					echo "INFO      | $(date) |          $basename : PASSED first file size check. "
				fi
					
									
				if [[ "$NUM_RANGE_OCCURRENCES" -gt "0" ]]; then

				###### WORKING WITH PUTATIVE GB NUMBERS IN RANGE FORMAT, OR COMBINED RANGE AND SINGLE FORMAT:													
				##--Try to pull out ranges of PGBs into separate file(s), but only if the count for number of 
				##--range occurrences (see first check on number of lines above) is greater than zero.

					## RANGES
					##--If there are one or more occurrences of PGBnos as ranges, then do the following:
					sed 's/.*\([A-Z]\{2\}[0-9]\{6\}\)\-\([A-Z]\{2\}[0-9]\{6\}\).*/\1\-\2/g' ./prep3.tmp > ./prep4_ranges.tmp
					grep -h "[A-Z]\{2\}[0-9]\{6\}\-[A-Z]\{2\}[0-9]\{6\}" ./prep4_ranges.tmp > ./prep4_ranges2.tmp
					head -n$NUM_RANGE_OCCURRENCES ./prep4_ranges2.tmp > ./pGBnos_ranges.txt

				
						## ODD RANGE WARNING LOG. Identify potential instances of odd 'XX123456-458'-type 
						##--range reportings, and log basenames to a file that the user can use to go back
						##--and check those folders/PDFs by hand and extract the GB numbers:
						grep "[A-Z]\{2\}[0-9]\{6,\}\-[0-9]\{2,4\}" ./prep3.tmp > ./oddRanges.txt
						NUM_ODDRANGE_LINES="$(wc -l ./oddRanges.txt | sed 's/\.\/.*//g')"
					
						if [[ "$NUM_ODDRANGE_LINES" -gt "0" ]]; then
							echo "WARNING!  | $(date) |          - Potential issues due to odd hyphenated-range GB numbers... " 
							echo "WARNING!  | $(date) |            see 'oddRanges.txt' and '../potentialOddRanges.log.txt'. " 
							echo $basename | sed 's/\.pGBnos//g' >> $MY_PATH/potentialOddRanges.log.txt
						else
							rm ./oddRanges.txt
						fi

					
					## SINGLES
					sed 's/\([A-Z]\{2\}[0-9]\{6,\}\)/'$CR'\1'$CR'/g' ./prep3.tmp | \
					sed 's/[A-Z]\{2\}[0-9]\{6,\}\-[A-Z]\{2\}[0-9]\{6,\}//g' | \
					grep -o "[A-Z]\{2\}[0-9]\{6,\}" > ./pGBnos_singles.txt
					
						##--Test and remove the singles file if it is empty, because that means there was either 
						##--a problem with multi-line ranges, or there were no single instances of putative GB
						##--numbers.
						if [ ! -s ./pGBnos_singles.txt ]; then
							rm ./pGBnos_singles.txt 
						fi

					
				else
	
				###### WORKING WITH PUTATIVE GB NUMBERS POSSIBLY IN SINGLE FORMAT *ONLY*:
					
					## SINGLES
					sed 's/\([A-Z]\{2\}[0-9]\{6,\}\)/'$CR'\1'$CR'/g' ./prep3.tmp | \
					grep -o "[A-Z]\{2\}[0-9]\{6,\}" > ./pGBnos_singles.txt


				fi
				
				rm ./*.tmp		##--Removing temporary files from local sub-folders, leaving only 'final' GB range 
								##--files, single-GB files, and other files we may want to check later.

			cd ..;
		done
	)



			### **NOTE: EXISTING BUG!!! - BUG #2**: FILES WITH RANGES OF GB NUMBERS THAT 
			##--BREAK ACROSS LINES (ONE COLUMN TO NEXT, OR ONE LINE TO NEXT WITHIN SAME
			##--COLUMN) CAUSE A PROBLEM WHERE THE RANGE NUMBERS 1) ARE IDENTIFIED AS SINGLE
			##--GB NUMBERS, RATHER THAN A RANGE, AND 2) NONE OF THE NUMBERS IN THE MULTI-
			##--LINE RANGE(S) ARE SAVED IN FINAL TXT FILES FROM STEP #3 ABOVE (i.e. they
			##--are not present in the "pGBnos_singles.txt" or "pGBnos_ranges.txt" files).
			#
			##--THE MAIN EXAMPLE OF BUG #2 THAT I AM AWARE OF IS Li_et_al_2016_Gymnod,
			##--IN THE FISH PHYLOGEOGRAPHY DATASET, WHERE THE RESULTING "..._singles.txt" 
			##--FILE HAS ZERO BYTES.
			#
			##--THIS NEEDS TO BE FIXED!!
			#
			##--HOWEVER, I ADDED A CONDITIONAL AT LINES 182-187 THAT REMOVES EMPTY
			##--"..._singles.txt" FILES.



echo "INFO      | $(date) | STEP #4: IN EACH FOLDER, IDENTIFY AND MODIFY RANGES OF PUTATIVE GB NUMBERS THAT WERE SPLIT OUT TO FILE "
echo "INFO      | $(date) |          ABOVE, SO THAT CONSECUTIVE GB NUMBERS ARE PRESENT ON SEPARATE LINES. "
###### Here, we loop through the sub-folders and A) check and remove any duplicate ranges
##--of GB numbers from the "./pGBnos_ranges.txt" files; B) modify the same files of GB 
##--number ranges by expanding each range into a list of consecutive numbers; fix any 
##--range file in which leading zeros have been (potentially) cut off during range expansion; 
##--and D) create the final output/format as a file with one GB accession number per line.
	(
		for k in ./*/; do
			echo $k;
			cd $k;
			
				MY_PGBNOS_FILE=./*.pGBnos.txt
				basename="$(echo $MY_PGBNOS_FILE | sed 's/\.\///g; s/\.txt//g')"
				CURRENT_PDF_FILE=$(ls . | grep "\.pdf")
				MY_PGBNOS_RANGES_FILE=./pGBnos_ranges.txt

				
				## IF THERE IS A RANGES FILE PRESENT IN THE SUB-FOLDER, CONDUCT A NUMBER 
				## OF OPERATIONS AS FOLLOWS TO MODIFY THOSE AND COLLATE WITH SINGLE NUMBERS.
				## OTHERWISE, SKIP TO JUST ANALYZING SINGLE NUMBERS FILE.				
				if [ -s $MY_PGBNOS_RANGES_FILE ]; then
				
						###### A. CHECK AND REMOVE DUPLICATE RANGES, IF ANY.
						sort -u $MY_PGBNOS_RANGES_FILE > ./pGBnos_uniqueRanges.txt
				
						###### B. MODIFY RANGES FILE: DO RANGE EXPANSION, ORGANIZE CONSECUTIVE GB
						###### NUMBERS.
						## B1. Split each range to a separate file (basenames will be range01, range02, range03, etc.):
						split -l 1 ./pGBnos_uniqueRanges.txt
						(
							ls x[a-z][a-z] | while read file; do			## Modified from code found at the following URL: http://www.unix.com/shell-programming-and-scripting/171141-renaming-default-output-name-split-command.html/.
								let c++;
								mv $file range$(printf "%02d" $c)".txt";
							done
						)
						## rm ./pGBnos_uniqueRanges.txt
				
						## B2. Go into each range file and capture the two-letter codes of the first
						##     GB number of the range into separate variable:
						## B3. Go into each range file and capture the numbers--the 6-7 integers @ end
						##     of first GB number and end of second GB number into separate variables:
						## B4. Use for loop to do range expansion by echoing the two-letter code,
						##     followed by each consecutive number in the set formed by the range,
						##     with each GB number echoed to a separate line of a new file. Do this
						##     for each range file created during step B1 above:

						MY_NUM_RANGEFILES="$(ls . | grep -o 'range0' | wc -l)"
						echo $MY_NUM_RANGEFILES > numRangeFiles.txt
				
						(
							for m in $(seq 1 $MY_NUM_RANGEFILES); do 
								MY_RANGE_TXT_PREFIX="$(cat ./range0${m}.txt | sed 's/\([A-Z]\{2\}\)[0-9]\{6,\}.*/\1/g')"; 
								MY_FIRST_RANGE_NUMBER="$(cat ./range0${m}.txt | sed 's/^[A-Z]\{2\}\([0-9]\{6,\}\).*/\1/g')"; 
								MY_SECOND_RANGE_NUMBER="$(cat ./range0${m}.txt | sed 's/^[A-Z]\{2\}[0-9]\{6,\}\-[A-Z]\{2\}\([0-9]\{6,\}\).*/\1/g')";	
						
									for n in $(seq $MY_FIRST_RANGE_NUMBER $MY_SECOND_RANGE_NUMBER); do
										echo $MY_RANGE_TXT_PREFIX$n >> ./range0${m}_PREP1.txt
									done
							done
						)

						##--I checked the ./range0${m}_PREP1.txt files resulting from the loop above and found two 
						##--potential sources of errors: 1) if GB numbers in a given range file contained leading zeros
						##--(XX0#####), those zeros were omitted/removed during creation of consecutive numbers for the
						##--corresponding prefix; and/or 2) if GB numbers were reported as "XX######.#" (e.g. XX######.1),
						##--then they were given the range file as having seven numbers instead of six (the dot simply was
						##--not being removed), causing the numbers to be incorrect. 
						#
						##--I wrote the if-elif-fi loop below to solve these two issues by looping through the range files
						##--in the currently active/looped sub-folder and 1) adding a zero after the prefix if the number 
						##--was five digits long, and 2) deleting the final digit if the number was seven digits long. Here 
						##--we require the final output file to be named "./range0*_FINAL.txt" to match section "C" below.
						##--Of course, the loop also accomplishes the critical goal of _also_ cat-ing _PREP1.txt files that 
						##--do _NOT_have errors to an appropriately named _FINAL.txt file. I cleanup by removing the 
						##--_PREP1.txt files as I go.
						MY_NUM_PREP1_RANGEFILES="$(ls ./*_PREP1.txt | wc -l)"
						(
							for m in $(seq 1 $MY_NUM_PREP1_RANGEFILES); do 
								MY_PREP1_RANGE_TXT_PREFIX="$(cat ./range0${m}_PREP1.txt | sed 's/\([A-Z]\{2\}\)[0-9]\{5,\}.*/\1/g')";  
								MY_PREP1_FIRST_RANGE_NUMBER="$(cat ./range0${m}_PREP1.txt | head -n1 | sed 's/^[A-Z]\{2\}\([0-9]\{5,\}\).*/\1/g')"; 
						
								if [[ "$(echo ${#MY_PREP1_FIRST_RANGE_NUMBER})" -eq "5" ]]; then  
									echo "Fixing leading zeros (_fixed Bug #3_) error in rangefiles... ";
									sed 's/.\{2\}\([0-9]\{5,\}\)/&0\1/g; s/^\([A-Z]\{2\}\).\{5\}/\1/g' ./range0${m}_PREP1.txt > ./range0${m}_FINAL.txt
									rm ./range0${m}_PREP1.txt
									rm ./range0${m}.txt
								elif [[ "$(echo ${#MY_PREP1_FIRST_RANGE_NUMBER})" -eq "6" ]]; then 
									cat ./range0${m}_PREP1.txt > ./range0${m}_FINAL.txt  
									rm ./range0${m}_PREP1.txt
									rm ./range0${m}.txt
								elif [[ "$(echo ${#MY_PREP1_FIRST_RANGE_NUMBER})" -eq "7" ]]; then 
									echo "Fixing seven-integer problem (_fixed Bug #4_) error in rangefiles... "; 
									sed 's/.$//g' ./range0${m}_PREP1.txt > ./range0${m}_FINAL.txt  
									rm ./range0${m}_PREP1.txt
									rm ./range0${m}.txt
								fi 
							done
						)
						

						###### C. CREATE FINAL FILE WITH CONSECUTIVE GB NUMBERS ON SEPARATE LINES.
						##--For this step, it is important to remember to merge both the range and single putative
						##--GB numbers, and not just one or the other class. That way, we are able to put all of 
						##--the numbers gleaned from each PDF into a single final file.
##						MY_FINAL_RANGEFILES=./range0*_FINAL.txt 
						MY_FINAL_RANGEFILES=./*_FINAL.txt 
										
						if [ -s ./pGBnos_singles.txt ]; then
							cat $MY_FINAL_RANGEFILES ./pGBnos_singles.txt > ALL.${basename}.txt
						else
							cat $MY_FINAL_RANGEFILES > ALL.${basename}.txt
						fi						
				
				else

					##--This is the case where there are only singles files present in the sub-folder, so we do:
					cat ./pGBnos_singles.txt > ALL.${basename}.txt

				fi

				## rm ./pGBnos_ranges.txt

			cd ..;
		done
	)



echo "INFO      | $(date) | STEP #5: IN EACH FOLDER, PULL DOWN AND ORGANIZE THE DNA SEQUENCES AND GENBANK DATA FOR EACH "
echo "INFO      | $(date) | ACCESSION NUMBER EXTRACTED ABOVE. "
###### Now, inside each sub-folder, we have a final .txt file containing the accession 
##--numbers from the PDF (or at least our estimation thereof). So, we need to go to GenBank 
##--and download the coding sequence (CDS) and GenBank data for each accession. To do this,
##--we'll use the "fetch_accession.py" Python script from https://www.biostars.org/p/120078/ 
##--attributed to Chrispin Chaguza (https://www.biostars.org/u/12810/; Institute of Infection 
##--and Global Health, University of Liverpool, UK). This script must be moved to the user's 
##--local machine and placed in a location in the PATH (and thus available from the command 
##--line). Once fetch_accession.py is available from the CLI, we will use it to loop through 
##--the sub-folders and execute the Python script inside each sub-folder.
	(
		for o in ./*/; do
			cd $o;
	
				MY_PDF_FILENAME=./*.pdf
				MY_FOLDERNAME="$(echo $o | sed 's/\.\///g; s/\/$//g')"
				MY_ALL_PGBNOS_FILE=./ALL.${MY_FOLDERNAME}.pGBnos.txt
				MY_FINAL_NUM_SEQUENCES="$(cat $MY_ALL_PGBNOS_FILE | wc -l)"
				AUTHOR_AND_YEAR="$(echo $MY_PDF_FILENAME | sed 's/\.\///g; s/\(\_[0-9]\{4\}\).*$/\1/g')"
				
				echo "Fetching $MY_FINAL_NUM_SEQUENCES DNA sequences from $AUTHOR_AND_YEAR using GenBank accession numbers... "
				fetch_accession.py -a ./ALL.${MY_FOLDERNAME}.pGBnos.txt

				###### After "fetching" the accessions above, each sub-folder now contains one ".gb" file
				##--with information about each accession record, and one ".fasta" file with the coding
				##--sequence. This is not a usable format for the data, although it is well-structured. In 
				##--order to make the data useful, we will concatenate the fasta sequences in each sub-folder 
				##--into a single file containing the full or partial name of the original manuscript PDF.
					cat *.gb > ./ALL.${MY_FOLDERNAME}.gb.txt
					cat *.fasta > ./ALL.${MY_FOLDERNAME}.fasta
					cat *.fasta > ./ALL.${MY_FOLDERNAME}.fasta.txt

				###### Now let's organize the .gb files into a new directory named "genbank", and also
				##--place the .fasta files into a new directory named "fasta":
				mkdir genbank fasta
				mv ./*.gb ./genbank/; mv ./*.fasta;
				cp ./fasta/ALL.${MY_FOLDERNAME}.fasta ../;

				###### Now let's split the fasta data out by different sequence types... by genome and then by 
				##--type of sequence submission. To divide sequences by genome, simply first split out all sequences
				##--containing the word "mitochondrial" in the name, then the nuclear are all the rest, and you can
				##--get them by simply searching for the inverse of the "mitochondrial" search with grep's -v option.
				#
				##--For splitting by sequence/submission type, categories are given at the end of sequence names
				##--but generally include _only_ one of the following: "mitochondrial.", "genomic sequence.", "partial
				##--cds.", "partial sequence.", "complete cds.", and "mitochondrial product." *** FOR NOW, THIS WILL
				##--HAVE TO WAIT, BUT I'D LIKE TO CODE IT UP LATER!! *** 
					
					##--First, get fasta sequences all on one line per sequence:
					perl -pe 's/\n/\ /g' ./ALL.${MY_FOLDERNAME}.fasta | perl -pe 's/\>/\n\>/g' | \
					sed 's/\([ACGTUWYMKSBHDVNR]\{30\}\)\ /\1/g' | sed '1d' > ./prep1.tmp
					
					##--Next, split the lines according to genome, and we delete the mitochondrial or nuclear files
					##--if they are empty (meaning there are no mtDNA or nDNA sequences, respectively):
					grep "mitochondrial" ./prep1.tmp > ./mitochondrial_seqs.txt
					grep -v "mitochondrial" ./prep1.tmp | sed '1d' > ./nuclear_seqs.txt
					if [ ! -s ./mitochondrial_seqs.txt ]; then rm ./mitochondrial_seqs.txt; fi
					if [ ! -s ./nuclear_seqs.txt ]; then rm ./nuclear_seqs.txt; fi
					
					##--We can pull out full sequence names (long description with spaces) from the original .fasta file
					##--and save them, in original order of course (do this just in case we need them later, e.g. for testing). 
					perl -pe 's/(\.)$/$1\n/g' ./ALL.${MY_FOLDERNAME}.fasta | \
					grep "[A-Z]\{2\}[0-9]\{6,\}"  > ./full_sequence_names.txt
					
					##--Next, if it exists, modify the mitochondrial alignment so that you only keep the first 10 letters
					##--of the sequence name, corresponding to the full GenBank number. Also do the same for the nuclear
					##--alignment, if it exists.
					if [ -s ./mitochondrial_seqs.txt ]; then
						sed 's/\ .*\(\ [ACGTUWYMKSBHDVNR]\{30\}\)/\1/g' ./mitochondrial_seqs.txt | \
						sed 's/\ $//g' | perl -pe 's/\ /\n/g' > alignable_mtDNA.fasta
					fi
					if [ -s ./nuclear_seqs.txt ]; then
						sed 's/\ .*\(\ [ACGTUWYMKSBHDVNR]\{30\}\)/\1/g' ./nuclear_seqs.txt | \
						sed 's/\ $//g' | perl -pe 's/\ /\n/g' > alignable_nuclear.fasta
					fi
					
					##--Next, align the align-able fasta files in MAFFT (or another MSA program) and group sequences that align
					##--together without gaps into their own alignments. From there, you can save the separate groups of
					##--sequences in different formats (e.g. .phy, .nex) that are useful for different phylogenetic or 
					##--population genetics software programs.
					#
					##  *** FOR NOW, WE DO THIS BY HAND!! *** 				

					rm ./prep1.tmp
			cd ..;
		done
	)



echo "INFO      | $(date) |          Cleaning up: removing temporary files from local machine..."
	rm $MY_PATH/pGBnos.txt


echo "INFO      | $(date) | Done mining GenBank accession/GI numbers from a group of publication PDFs, fetching the corresponding "
echo "INFO      | $(date) | DNA sequences, and organizing the sequences, using GBSequenceMiner."
echo "INFO      | $(date) | Bye.
"
#
#
#
######################################### END ############################################

exit 0

