#!/bin/bash

# Script wrapper to pass fasta files to screen.py using sbatch
# Cnce screen.py results generated then convert these to csv format using g4rna_convert_output.py using ssub

#############################################################################################################################
# Help
#############################################################################################################################
help()
{
# Display Help
   echo "Use this script to pass input fasta files to screen.py and then convert the output tsv files to suitable csv format"
   echo "The csv files are output to a directory within the current working directory"
   echo "A general log file giving some details of the run will also be generated in this directory"
   echo
   echo "Syntax: scriptTemplate [-h|c|e]"
   echo "options:"
   echo "h    Print this Help."
   echo "d    Specify name of output directory, if not given then default dir name of dd-mm-yy_hour-min will be used"
   echo "e    Send emails from sbatch and ssub on job completion" 
}

#############################################################################################################################
# Main Program                                                        
#############################################################################################################################

#### Parsing Options and Arguments ####

#set defaults 
email=0 #there will be no emails sent for completion of batch jobs
# generate a default name for use if -d option not provided
start_time=$(date +'%d%m%y_%H%M')
dir="g4rna_output_"${start_time}

# Get the options
while getopts ":hd:e" option; do
   case $option in
    h) # display Help
        help
        exit;;
    e) # send an email based on the user id from the terminal 
        user=$(id -un)
        email="${user}""@babraham.ac.uk"
        ;;
    d) #name of output directory 
        dir=$OPTARG 
        #inlcude some checks on permissable dir names
        if [[ "${dir}" = *.fasta ]]; then :
            echo "the directory name supplied ends with .fasta
            This is not allowed, did you forget to specify a directory name?"
            exit
        elif [[ "${dir}" = -* ]]; then :
            echo "the directory name supplied starts with -
            This is not allowed, did you forget to specify a directory name?"
            exit
        #check if directory already exists
        elif [ -d "$dir" ]; then
            echo "directory $dir already exists in this location, please choose a different name"
            exit
        fi
        ;;
    :) # If expected argument omitted:
        echo "Error: -${OPTARG} requires an directory name."
        exit;;
    \?) # Invalid option
         echo "Error: Invalid option"
         exit;;
   esac
done

#Having run through options get the fasta input
shift "$((OPTIND-1))" #remove the options that have been passed meaning that the remaining arguments should be our fasta files
#Store the provided files as an array
fasta_files=("$@")
echo "${fasta_files[@]}"

#Preliminary checks that the files provided exist, aren't empty and are fasta files
for file in "${fasta_files[@]}"; do
    if [ ! -f "$file" ]; then
        echo "$file doesn't exist in the current location ($PWD)"
        exit
    elif [ ! -s "$file" ]; then
        echo "$file exists but is empty"
        exit
    elif [ "${file: -6}" != ".fasta" ]; then
        echo "$file doesn't appear to be a fasta file"
    fi
done

#### Initial Setup: Setup workspace, Specify locations of scripts/ packages to use ####
echo "Input files and provided options all look fine, starting initial setup"
#make the output directory in current working directory
mkdir "$dir"
#make a log file to re-direct notes on the run
touch "${dir}"/G4RNA_wrapper_log.txt
printf "'%s'\n" "The start time of this run is ${start_time}" >> "${dir}"/G4RNA_wrapper_log.txt
printf "'%s'\n" "I am working in $(pwd)" >> "${dir}"/G4RNA_wrapper_log.txt
printf "'%s'\n" "In this working directory I am saving output files to ${dir}" >> "${dir}"/G4RNA_wrapper_log.txt
printf "'%s'\n" "I found a total of ${#fasta_files[@]} files to analyse:" >> "${dir}"/G4RNA_wrapper_log.txt
printf "'%s'\n" "${fasta_files[@]}" >> "${dir}"/G4RNA_wrapper_log.txt

#Note this would be more efficient if could give the locations specifically - discuss as an option
#Need to find where conda has been installed in the system
conda_path=$(find ~/ -type d -name miniconda3)"/bin/conda"
printf "'%s'\n" "I'm using this path of conda: ${conda_path}" >> "${dir}"/G4RNA_wrapper_log.txt

#Similarly find the location of screen.py in the users home directory
screen_path=$(find ~/ -type f -name screen.py)
printf "'%s'\n" "I'm using this path for screen.py: ${screen_path}" >> "${dir}"/G4RNA_wrapper_log.txt

#Also find location of python conversion script
csv_converter_path=$(find ~/ -type f -name g4rna_convert_output.py) 
printf "'%s'\n" "I'm using this path for g4rna_convert_output.py: ${csv_converter_path}" >> "${dir}"/G4RNA_wrapper_log.txt

#### Run Screen.py for input files ####

echo "Running G4RNA screener for fasta files"
#Initiate the correct conda environment 
eval "$($conda_path shell.bash hook)" #setup a temporary link to conda in current shell will be necassary depending on how setup conda
conda activate g4rna 

#Run through the fasta files that have been provided
for file in "${fasta_files[@]}" ; do
    #Extract the unique file names - essentially everything before the .fasta file extension
    name=$(echo "$file" | cut -d "." -f 1 | cut -d "/" -f 2)
    #append as required for subsequent filenames
    out_file=${name}"_screen_output.tsv"

    #store each out_file to an array for later use
    output_files+=("${dir}/$out_file")

    #submit to sbatch depending on whether email option is included 
    if [ "$email" != 0 ] ; then
        sbatch --mem=2G -c1 -o"./${dir}/${out_file}" -Jpython --mail-user="${email}" --mail-type=END,FAIL --wrap="python $screen_path ./$file"
        
    else 
        sbatch --mem=2G -c1 -o"./${dir}/${out_file}" -Jpython --wrap="python $screen_path $file"
    fi

done

#Force the script to wait until all sbatch jobs have compelted before moving on to next stage
#don't want to deactivate conda environment if its still in use
#Test before can move on = are the number of output tsv files the same as the number of input files
#Are the sizes of the tsv files the same as the last time you checked 

screener_done_checka=0
screener_done_checkb=0
touch "${dir}"/tsv_files_prev.txt
touch "${dir}"/tsv_files_now.txt

while [ $screener_done_checkb -lt 4 ]; do

    while [ "$screener_done_checka" -lt 1 ]; do 
        #check the number of tsv files present in the directory
        #first check there are more than 3 files in the directory (2 touch files and log file)
        dir_check=$(ls "$dir"/*|wc -l)

        if [ "$dir_check" -gt 3 ]; then
            no_output=$(ls "$dir"/*.tsv|wc -l)
        else
            sleep 5
        fi

        #Now check that tsv files match the input fasta files
        if [ ${#fasta_files[@]} = "$no_output" ] && [ $screener_done_checka = 0 ]; then
            printf "'%s'\n" "There are now the expected number (${#fasta_files[@]}) of output tsv files, check one complete" >> "${dir}"/G4RNA_wrapper_log.txt
            screener_done_checka=1
        fi

    done
    
    #Now that all the files have been made check whether they have been modified
    if [ $screener_done_checka = 1 ]; then

        ls -ltrh "${dir}"/*_screen_output.tsv > "${dir}"/tsv_files_now.txt
        
        if cmp -s "${dir}/tsv_files_now.txt" "${dir}/tsv_files_prev.txt"; then
            #add one to screener_done_checkb
            ((screener_done_checkb+=1))
            printf "'%s'\n" "There have been no changes to the output files, consequtive times this condition has been met: $screener_done_checkb times" >> "${dir}"/G4RNA_wrapper_log.txt
            printf "'%s'\n" "I will wait approx. 20 seconds and check again" >> "${dir}"/G4RNA_wrapper_log.txt

            if [ $screener_done_checkb = 3 ]; then
                printf "'%s'\n" "There have been no new changes the last $screener_done_checkb times I checked so looks like screen.py is finished" >> "${dir}"/G4RNA_wrapper_log.txt
                screener_done_checkb=5
            else       
                sleep 20
            fi

        else
            printf "'%s'\n" "The files are different from previous check, reset count and continue to monitor" >> "${dir}"/G4RNA_wrapper_log.txt
            screener_done_checkb=0
            mv "${dir}"/tsv_files_now.txt "${dir}"/tsv_files_prev.txt 
        fi
    fi

done

#### Run g4rna_convert_output.py for all tsv files ####

#Now that generation of all the tsv output files is complete move on to converting these file to csv format 
echo "G4RNA screener has finished, now going to convert the tsv output files to a csv format"
#Deactivate conda environment
conda deactivate 

#load regular python
module load python
module load ssub

#submit job using ssub 
ssub --email python "$csv_converter_path" -files "${output_files[@]}"

#Wait for conversion to finish then unload python and ssub (necassary if you want to run the script in full again)
    #g4rna_convert_output.py, creates a file g4rna_convert_done.txt in ${dir} once it's finished with csv conversion
    #Therefore check for the existance of the file and until it exists don't exit the while loop
convert_check_a=0

while [ $convert_check_a == 0 ]; do
    #check if file exists
    if [ -f "${dir}/g4rna_convert_done.txt" ]; then
        echo "File \"${dir}/g4rna_convert_done.txt\" exists" >> "${dir}"/G4RNA_wrapper_log.txt
        module unload ssub
        module unload python
        convert_check_a=1
    else
        sleep 5
    fi
done

#Need to delete the un-necassary tsv output, also need to remove our check files
rm "${dir}"/*screen_output.tsv
rm "${dir}"/g4rna_convert_done.txt                              
rm "${dir}"/tsv_files_now.txt
rm "${dir}"/tsv_files_prev.txt

# Closing echo
echo "All tsv output files converted to csv format"
echo "G4RNA_wrapper is all finished, see ${dir} for the output csv.files and log file for the run"