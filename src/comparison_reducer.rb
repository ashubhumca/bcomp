#!/usr/bin/ruby
DELIMITER = "\t"
PART = ENV["mapred_task_partition"]
EXTRA_RECORDS_IP1 = "extra_records_in_ip1#{PART}"
EXTRA_RECORDS_IP2 = "extra_records_in_ip2#{PART}"
COUNT_DIFF_FOR_SAME_RECORDS = "count_diff_for_same_records#{PART}"

$records = {}
$records['ip1'] = []
$records['ip2'] = []
current_key = nil
prev_key = nil

# Return record count if it is greater than 1
def get_record_count(keys_from)
  ((count = $records[keys_from].length) > 1) ? "#{DELIMITER}#{count}" : ''
end

# Processing of same keys from both files
def combine
  if $records['ip1'].empty?
    puts "#{EXTRA_RECORDS_IP2}#{DELIMITER}#{$records['ip2'][0]}#{get_record_count('ip1')}"
  elsif $records['ip2'].empty?
    puts "#{EXTRA_RECORDS_IP1}#{DELIMITER}#{$records['ip1'][0]}#{get_record_count('ip2')}"
  elsif (l1 = $records['ip1'].length) != (l2 = $records['ip2'].length)
    puts "#{COUNT_DIFF_FOR_SAME_RECORDS}#{DELIMITER}#{$records['ip1'][0]}#{DELIMITER}#{l1}#{DELIMITER}#{l2}"
  end
  $records['ip1'] = []
  $records['ip2'] = []
end

# Iterating each record from STDIN
STDIN.each_line do |line|
  next if line.nil? || line.chomp.empty?
  begin
    key, file, val = line.chomp.split(DELIMITER, 3)
    current_key = key
    #Ignore null keys
    if file.eql?('ip1') || file.eql?('ip2')
      if prev_key && (prev_key != current_key)
        combine()
      end
      prev_key = current_key
      $records[file] << val
    else
      STDERR.puts 'Error:Input data format.'
    end  
  rescue Exception => e
    STDERR.puts e.backtrace
    STDERR.puts e.message
    break
  end
end

#Handling last key
combine()
