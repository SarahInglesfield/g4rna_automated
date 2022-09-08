#!/bin/bash

#This script submits the screen.py job to sbatch for each fasta file and then creates a end flag file when finished

#Need to take input from script -location of out dir, name of outfile, email, screen.py path and fasta file

#set variables based on input
dir=$1
out_file=$2
screen_path=$3
file=$4

#run screen.py for the fasta.file and redirect ouput to file in results directory
python "$screen_path" "$file" > "./${dir}/${out_file}.tsv"

#once screen.py has finished end file will be generated for subsequent checks
touch "./${dir}/${out_file}_S2507I_screen_end.txt" 
