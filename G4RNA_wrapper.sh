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
   echo "Syntax: /path/to/G4RNA_wrapper.sh [-h|d {dir_name}|e] fasta file(s)"
   echo "options:"
   echo "h    Print this Help."
   echo "d    Specify name of output directory, if not given then default name of g4rna_output_dd-mm-yy_hour-min will be used"
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
screen_path=$(find ~/ -type f -wholename "*/g4rna_screener/screen.py")
printf "'%s'\n" "I'm using this path for screen.py: ${screen_path}" >> "${dir}"/G4RNA_wrapper_log.txt

#Also find location of python conversion script
csv_converter_path=$(find ~/ -type f -wholename "*/g4rna_automated/g4rna_convert_output.py") 
printf "'%s'\n" "I'm using this path for g4rna_convert_output.py: ${csv_converter_path}" >> "${dir}"/G4RNA_wrapper_log.txt

#Finally also find location of submit_screener script
sub_screener_path=$(find ~/ -type f -wholename "*/g4rna_automated/submit_screener.sh") 
printf "'%s'\n" "I'm using this path for submit_screener.sh: ${sub_screener_path}" >> "${dir}"/G4RNA_wrapper_log.txt

#### Run Screen.py for input files ####

echo "Running G4RNA screener for fasta files"
printf "'%s'\n" "Running G4RNA screener for fasta files" >> "${dir}"/G4RNA_wrapper_log.txt

#Initiate the correct conda environment 
eval "$($conda_path shell.bash hook)" #setup a temporary link to conda in current shell
conda activate g4rna 

#Run through the fasta files that have been provided and submit them to screen.py via submit_screener.sh

for file in "${fasta_files[@]}" ; do
    #Extract the unique file names - essentially everything before the .fasta file extension
    name=$(echo "$file" | cut -d "." -f 1 | rev | cut -d "/" -f 1 | rev)

    #append as required for subsequent filenames
    out_file=${name}"_screen_output"

    #store each out_file to an array for later use (put the .tsv on the name here so will be recognised later)
    output_files+=("${dir}/${out_file}.tsv")

    #submit to sbatch via the submit_screener.sh, with option to send email based on user input
    if [ "$email" != 0 ] ; then
        sbatch --mem=2G -c1 -o"./${dir}/out_file_log.txt" -Jbash --mail-user="${email}" --mail-type=END,FAIL --wrap="bash $sub_screener_path $dir $out_file $screen_path $file"
    else
        sbatch --mem=2G -c1 -o"./${dir}/out_file_log.txt" -Jbash --wrap="bash $sub_screener_path $dir $out_file $screen_path $file"
    fi

done

# Now check that screen.py has finished for all of the input files before moving on
screen_py_done=0

while [ $screen_py_done == 0 ]; do
    
    #Look for the S2507I_screen_end.txt files that are generated at the end of submit_screener.sh
    #If the number of end files matches the number of input fasta files then exit while loop. If not then sleep and try check again
    dir_check=$(ls "$dir"/*S2507I_screen_end.txt 2>/dev/null|wc -l)

    if [ ${#fasta_files[@]} = "$dir_check" ] ; then
        printf "'%s'\n" "There are now the expected number (${#fasta_files[@]}) of S2507I_screen_end.txt flag files"
        screen_py_done=1
    else
        echo "There are only ${dir_check} end flag files therefore screen.py is not done, sleeping for 30s before checking again"
        sleep 30
    fi  
done

#Force the script to wait until all sbatch jobs have compelted before moving on to next stage


#### Run g4rna_convert_output.py for all tsv files ####

#Now that generation of all the tsv output files is complete move on to converting these file to csv format 
echo "screen.py has finished for all files, now going to convert the tsv output files to a csv format"
printf "'%s'\n" "screen.py has finished, now going to convert the tsv output files to a csv format" >> "${dir}"/G4RNA_wrapper_log.txt

#Deactivate conda environment
conda deactivate 
#load regular python
module load python
module load ssub

#submit job using ssub
for output in "${output_files[@]}" ; do
    echo "$output"
    if [ "$email" != 0 ] ; then
        ssub --email python "$csv_converter_path" -files "$output"    
    else 
        ssub python "$csv_converter_path" -files "$output"
    fi
done


#Wait for conversion to finish then unload python and ssub (necassary if you want to run the script in full again)

convert_py_done=0

while [ $convert_py_done == 0 ]; do

    #Look for the S2507I_convert_end.txt files that are generated at the end of submit_screener.sh
    #If the number of end files matches the number of input tsv output files then exit while loop. If not then sleep and try check again
    dir_check=$(ls "$dir"/*S2507I_g4rna_convert_end.txt 2>/dev/null|wc -l)
    echo "$dir_check"

    if [ ${#output_files[@]} = "$dir_check" ] ; then
        printf "'%s'\n" "There are now the expected number (${#output_files[@]}) of S2507I_g4rna_convert_end.txt flag files"
        module unload ssub
        module unload python
        convert_py_done=1
    else
        echo "There are only ${dir_check} end flag files therefore g4rna_convert_output.py is not done, sleeping for 30s before checking again"
        sleep 30
    fi  
done

echo "g4rna_convert_output.py has finished for all files, now just cleaning up the directory"

#Need to delete the un-necassary tsv output, also need to remove our check files
rm "${dir}"/*screen_output.tsv
rm "${dir}"/*S2507I_screen_end.txt
rm "${dir}"/*S2507I_g4rna_convert_end.txt                              

# Closing echo
echo "G4RNA_wrapper is all finished, see ${dir} for the output csv.files and log file for the run"