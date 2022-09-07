# g4rna_automated
Scripts for automating the running of g4rna_screener to generate csv output files on the cluster

## Using g4rna_wrapper.sh
The g4rna_wrapper.sh takes input filename.fasta files and for each one: 
* Runs screen.py using default settings (see https://github.com/scottgroup/g4rna_screener for more detail)
* Runs g4rna_convert_output.py, to convert screen.py tsv output to a csv format, with appropriate column formmating
* Saves the filename_screen_output.csv in a new directory within the current working directory

### Command Line Usage:
``` 
path/to/G4RNA_wrapper.sh [-e] [-d directory_name] [-h] path/to/files.fasta
```

### Options
```
-e                    send emails to user on completion of sbatch and ssub on jobs

-d  directory name    specify name of output directory
                      If -d is not supplied then default name of g4rna_output_dd-mm-yy_hour-min will be used
                      Non-permissible directories: begin with "-", end with ".fasta" or already exist in the current working directory
    
-h                    brings up the help for the wrapper script and exits
```
