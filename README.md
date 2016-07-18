This is the utility to compare two big files. Files should be in HDFS


## USAGE:


### bash diff_tool.sh -ip1 hdfs/file/path_1 -ip2 hdfs/file/path_2 


## Additional parameters:


- -ip1 First input file path (-ip1, -input_file1) 

  - Mandatory: Yes

- -ip2 Second input file path (-ip2, -input_file2)

  - Mandatory: Yes

- -l1 Layout of first input (-l1, -layout1)

  - Default: Fixed width file (with no delimiter)

  - It may be one character delimiter(e.g. Ctrl-A, |, 	 etc.) or layout range (e.g. "0-10, 11-20, 21-28")

  - User can pass f, i, s, w along with range (e.g. "1-10f, 11-15i") for intelligent comparison

- -l2 Layout of second input (-l2, -layout2)

  - Default: Fixed width file (with no delimiter)

  - It may be one character delimiter(e.g. Ctrl-A, |, 	 etc.) or layout range (e.g. "0-10, 11-20, 21-28")

  - User can pass f, i, s, w along with range (e.g. "1-10f, 11-15i") for intelligent comparison

- -op Diff report output path (-op, -output)

  - Default: Current user home directory (HDFS)

  - Tool will delete the directory if already exist

- -n Sample report or Full report (-n)

  - Default: Full difference

  - For sample report user has to specify a number which will be used for limiting the number of records in diff files.

- -c Selected columns to compare (-c, columns)

  - Default: Compare all the columns

  - It can be specify like "2, 5, 7, 10" means compare only 3rd, 6th, 8th and 11th columns respectively

  - Options l1 and l2 will become mandatory if user uses this option

  - User can pass f, i, s, w along with range (e.g. "0s, 1f, 11i") for intelligent comparison

  - User also can pass column ranges (e.g. "1, 2-4i, 5s, 7-11" means "1, 2i, 3i, 4i, 5s, 7, 8, 9, 10, 11")

   

## Special options:

  - --ignore_case It is used for ignoring case

  - --skip_spaces It is used for ignoring spaces

  - --non_ascii It is used for non ascii data comparison



## Note:


  - f-Float comparison after rounding it by 2 and ignoring blank spaces from both ends

  - i-Integer comparison after ignoring blank spaces from both ends and ignoring decimal precision

  - s-String comparison after ignoring blank spaces from both ends

  - w-String comparison after ignoring all blanks in the column


