#! python
import argparse
import pathlib
import os
def main():
  file_list = read_options()
  #print(file_list)
  #checks()
  convert_output(file_list.files)
  flag_done(file_list.files)
  print(f"All done!")

def flag_done(files):
  dir = os.path.dirname(files[0])
  done_path = dir +'/g4rna_convert_done.txt'
  pathlib.Path(done_path).touch()

def convert_output(file_list):
  for file in file_list:
    header = []
    #extract the name prior to the .tsv ending
    csv_name = file[:-4]
    csv_name = csv_name + ".csv"
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

def read_options(): #command line prompt
    parser = argparse.ArgumentParser(description="""
    Input:  
    Function:
    Output: """)
    
    parser.add_argument("-files", help="A list of G4RNA output tsv files", type=str, nargs="+")
    
    options = parser.parse_args()
    return options

if (__name__ == "__main__"):
    main()