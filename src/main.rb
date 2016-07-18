#!/usr/bin/ruby

# This is the main class used for command line parameter verification and
# running Map/Reduce jobs for finding the differences.
class Main

  EXTRA_RECORDS_IP1               = "extra_records_in_ip1"
  EXTRA_RECORDS_IP1_MSG           = "Records available in ip1 but not in ip2:"
  EXTRA_RECORDS_IP2               = "extra_records_in_ip2"
  EXTRA_RECORDS_IP2_MSG           = "Records available in ip2 but not in ip1:"
  COUNT_DIFF_FOR_SAME_RECORDS     = "count_diff_for_same_records"
  COUNT_DIFF_FOR_SAME_RECORDS_MSG = "Redundant records with different counts in files:"

  # Constructor
  def initialize
    @usage = <<USAGE
    USAGE:
-ip1 First input file path (-ip1, -input_file1) 
  -Mandatory: Yes
-ip2 Second input file path (-ip2, -input_file2)
  -Mandatory: Yes
-l1 Layout of first input (-l1, -layout1)
  -Default: Fixed width file (with no delimiter)
  -It may be one character delimiter(e.g. Ctrl-A, |, \t etc.) or layout range (e.g. "0-10, 11-20, 21-28")
  -User can pass f, i, s, w along with range (e.g. "1-10f, 11-15i") for intelligent comparison
-l2 Layout of second input (-l2, -layout2)
  -Default: Fixed width file (with no delimiter)
  -It may be one character delimiter(e.g. Ctrl-A, |, \t etc.) or layout range (e.g. "0-10, 11-20, 21-28")
  -User can pass f, i, s, w along with range (e.g. "1-10f, 11-15i") for intelligent comparison
-op Diff report output path (-op, -output)
  -Default: Current user home directory (HDFS)
  -Tool will delete the directory if already exist
-n Sample report or Full report (-n)
  -Default: Full difference
  -For sample report user has to specify a number which will be used for limiting the number of records in diff files.
-c Selected columns to compare (-c, columns)
  -Default: Compare all the columns
  -It can be specify like "2, 5, 7, 10" means compare only 3rd, 6th, 8th and 11th columns respectively
  -Options l1 and l2 will become mandatory if user uses this option
  -User can pass f, i, s, w along with range (e.g. "0s, 1f, 11i") for intelligent comparison
  -User also can pass column ranges (e.g. "1, 2-4i, 5s, 7-11" means "1, 2i, 3i, 4i, 5s, 7, 8, 9, 10, 11")
   
  Special options:
  --ignore_case It is used for ignoring case
  --skip_spaces It is used for ignoring spaces
  --non_ascii It is used for non ascii data comparison
  
  Note:
  f-Float comparison after rounding it by 2 and ignoring blank spaces from both ends
  i-Integer comparison after ignoring blank spaces from both ends and ignoring decimal precision
  s-String comparison after ignoring blank spaces from both ends
  w-String comparison after ignoring all blanks in the column
USAGE
 
    @input_file1 = nil
    @input_file2 = nil
    @layout1 = false
    @layout2 = false
    @output_dir = "/tmp/diff_output_#{Time.now.to_i}"
    @temp_output_dir = "/tmp/diff_tool_#{Time.now.to_i}"
    @cols_to_compare = false
    @record_count_in_reports = nil
    @ignore_case = false
    @skip_spaces = false
    @non_ascii = false
    @result = {}
  end

  # Ending process for some error
  def end_process(msg)
    puts msg
    puts @usage
    exit 1
  end

  # Generate report_header
  def get_report_header
    "\n\n" + "*"*80 + "\n" + "*"*31 + " COMPLETE REPORT " + "*"*32 + "\n" + "*"*80 + "\n\n"
  end

  # Validating command line parameters. It only validates the correct switches
  # and their possible combinations.
  def validate_params
    ARGV.each_with_index do |param, index|
      next if (param.index('-') != 0)
      param = param.downcase
      value = ARGV[index + 1]
      if ((param == '-ip1') || (param == '-input_file1'))
        @input_file1 = value
      elsif ((param == '-ip2') || (param == '-input_file2'))
        @input_file2 = value
      elsif ((param == '-l1') || (param == '-layout1'))
        @layout1 = value
      elsif ((param == '-l2') || (param == '-layout2'))
        @layout2 = value
      elsif ((param == '-op') || (param == '-output'))
        @output_dir = value
      elsif ((param == '-c') || (param == '-columns'))
        @cols_to_compare = value
      elsif ((param == '-n'))
        @record_count_in_reports = value
      elsif (param == '--ignore_case')
        @ignore_case = true
      elsif (param == '--skip_spaces')
        @skip_spaces = true
      elsif (param == '--non_ascii')
        @non_ascii = true
      elsif ((param == '-h') || (param == '-help'))
        puts @usage
        exit 0
      else
        end_process "Oops!! Invalid parameter: #{param}"
      end
    end
    # Both input files are mandatory options
    if @input_file1.nil? || @input_file2.nil?
      end_process "Oops!! Mandatory options -ip1 and -ip2 are missing"
    end
    # Layouts are mandatory for -c option
    if @cols_to_compare && (!@layout1 || !@layout2)
      end_process "Oops!! -l1 and -l2 options are mandatory for -c option"
    end
  end

  # Check if given path is directory then append /* to use cat command
  # Param String hdfs_file HDFS path
  # Return String hdfs_file Updated path
  def check_dir(hdfs_file)
    cmd = "hadoop fs -test -d #{hdfs_file}"
    if system(cmd)
      hdfs_file += "/*"
    end
    return hdfs_file
  end

  # Finding HDFS file record count and return 0 if file does not exist.
  # If input path doest not exist then exit the process.
  # Param String hdfs_file HDFS path
  # Param Boolean is_input If it's input path
  # Return Integer record count in the given file
  def get_record_count(hdfs_file, is_input = true)
    # File existance check
    cmd = "hadoop fs -ls #{hdfs_file} | wc -l"
    part_file_count = `#{cmd}`
    if (part_file_count.to_i == 0)
      if is_input
        end_process "File #{hdfs_file} does not exist"
      else
        return 0
      end
    end
    hdfs_file = check_dir(hdfs_file)
    cmd = "hadoop fs -cat #{hdfs_file} | wc -l"
    record_count = `#{cmd}`
    return record_count
  end

  # Used for showing reports.
  # It includes record counts of given input paths, ip1 - ip2, ip2 - ip1 and
  # same records with different counts
  def show_report
    count_ip1 = get_record_count(@input_file1)
    count_ip2 = get_record_count(@input_file2)
    puts get_report_header
    # Finding record count in first input file
    puts "First Input file \"#{@input_file1}\" record count: #{count_ip1}\n"
    # Finding record count in second input file
    puts "Second Input file \"#{@input_file2}\" record count: #{count_ip2}\n\n"
    # Showing result
    @result.each do |type, vals|
      puts "\n#{vals[1]} #{vals[0]}"
      puts "And corresponding records path: #{vals[2]}\n\n"
    end  
  end

  # Running all the map reduce required to find difference
  def run_map_reduce  
    puts "Please wait!! Map reduce process for finding difference has started and it will take a while\n"
    if system(get_diff_mr_cmd)
      generate_diff_reports
    else
      end_process "Oops!! Map-Reduce job failed. Please check the cause"
    end
    show_report
  end

  # Used for getting Hadoop streaming command for finding diff
  def get_diff_mr_cmd
    params_to_mapper = [@input_file1, @input_file2, "\"#{@layout1}\"", "\"#{@layout2}\"", "\"#{@cols_to_compare}\"", @skip_spaces, @ignore_case, @non_ascii].join(' ')
    cmd = "hadoop jar #{ENV['HADOOP_STREAMING_JAR']} "
    cmd += "-D mapred.job.name='Diff tool job' "
    cmd += "-D mapred.reduce.tasks=#{ENV['REDUCERS']} "
    cmd += "-libjars #{ENV['MULTI_OUTPUT_FORMAT_JAR']} "
    cmd += "-outputformat #{ENV['MULTI_OUTPUT_FORMAT']} "
    cmd += "-output #{@temp_output_dir} "
    cmd += "-input #{@input_file1} "
    cmd += "-input #{@input_file2} "
    cmd += "-mapper '#{ENV['RUBY_PATH']} comparison_mapper.rb #{params_to_mapper}' "
    cmd += "-reducer '#{ENV['RUBY_PATH']} comparison_reducer.rb' "
    cmd += "-file #{ENV['DIFF_TOOL_PATH']}/src/comparison_mapper.rb "
    cmd += "-file #{ENV['DIFF_TOOL_PATH']}/src/comparison_reducer.rb "
    return cmd
  end

  # Used for splitting M/R output into required reports.
  # If user wants to see sample report then it will generate only specified
  # number of records (-n option) in the reports.
  # Param String type It's one of report types mentioned above
  # Param String msg Message to be displayed while report generation
  # Return 
  def report_data_movement(type, msg)
    # HDFS directories
    part_file = "#{@temp_output_dir}/part-#{type}*"
    report = "#{@output_dir}/#{type}"
    # Linux directory
    report_temp = "#{@temp_output_dir}_#{type}"
    record_count = get_record_count(part_file, false)
    if(record_count.to_i != 0)
      # User wants sample record diff or full record diff
      unless @record_count_in_reports.nil?
        cmd = "hadoop fs -cat #{part_file} | head -#{@record_count_in_reports.to_i} > #{report_temp}"
        `#{cmd}`
        cmd = "hadoop fs -copyFromLocal #{report_temp} #{report} "
        `#{cmd}`
      else
        cmd = "hadoop fs -mkdir #{report}"
        `#{cmd}`
        cmd = "hadoop fs -mv #{part_file} #{report}/"
        `#{cmd}`
      end
    end
    @result[type] = [record_count, msg, report]
    # Cleaning linux temp directory after process completion
    cmd = "rm -rf #{report_temp}"
    `#{cmd}`
  end

  # Used for generating diff report.
  # It deletes the existing output directory and creates new one, then call
  # report_data_movement for all diff reports and then delete the temp direcotory.
  def generate_diff_reports
    # Creating report output directory if not exist
    cmd = "hadoop fs -rm -r #{@output_dir}"
    `#{cmd}`
    cmd = "hadoop fs -mkdir #{@output_dir}"
    `#{cmd}`
    report_data_movement(EXTRA_RECORDS_IP1, EXTRA_RECORDS_IP1_MSG)
    report_data_movement(EXTRA_RECORDS_IP2, EXTRA_RECORDS_IP2_MSG)
    report_data_movement(COUNT_DIFF_FOR_SAME_RECORDS, COUNT_DIFF_FOR_SAME_RECORDS_MSG)
    # Cleaning hdfs temp directory after process completion
    cmd = "hadoop fs -rm -r #{@temp_output_dir}"
    `#{cmd}`
  end
end

# Main method call
obj = Main.new
obj.validate_params
puts "Process started..."
puts "Command line parameters verified"
obj.run_map_reduce
