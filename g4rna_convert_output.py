#! python
import argparse
import pathlib
import os
def main():
  file_list = read_options()

  for file in file_list.files:
    csv_base_name = convert_output(file)

    print(csv_base_name + "_S2507I_g4rna_convert_end.txt")
    flag_done(csv_base_name)

def flag_done(csv_name):
  done_path = csv_name + "_S2507I_g4rna_convert_end.txt"
  pathlib.Path(done_path).touch()

def convert_output(file):
  header = []
  #extract the name prior to the .tsv ending
  csv_base_name = file[:-4]
  csv_name = csv_base_name + ".csv"
  with open(file, 'r') as input_tsv:
    with open(csv_name, 'w') as output_csv:
      for line in input_tsv:
        line_data = line.strip().split("\t")
        #Need to store header as this contains correct number of fields
        if not header: #if header is empty (aka first line) then store this line as header
            #need to swap header field 2&3
            line_data[1],line_data[2] = line_data[2],line_data[1]
            header = line_data
            print(",".join(header),file= output_csv)
            continue

        #Need to remove the first field
        line_data = line_data[1:]
      
        #Now need to swap 2nd and 3rd field
        line_data[1],line_data[2] = line_data[2],line_data[1]

        #Print out to csv file
        print(",".join(line_data),file= output_csv)
  return(csv_base_name)

def read_options(): #command line prompt
    parser = argparse.ArgumentParser(description="""
    Input: tsv files
    Function: converts tsv files to csv format and modifies order of columns
    Output: csv file (same name as the input tsv file) """)
    
    parser.add_argument("-files", help="A list of G4RNA output tsv files", type=str, nargs="+")
    
    options = parser.parse_args()
    return options

if (__name__ == "__main__"):
    main()