#!/usr/bin/ruby
$LOAD_PATH << "."
ip1_path = ARGV[0].chomp.strip
ip2_path = ARGV[1].chomp.strip
layout1 = ARGV[2]
layout2 = ARGV[3]
cols_to_compare = ARGV[4]
skip_spaces = ARGV[5]
ignore_case = ARGV[6]
non_ascii = ARGV[7]

DELIMITER = "\t"
SUPPORTED_FORMAT_TYPE = ['f', 'i', 's', 'w']
table_file = ENV['map_input_file'].chomp.strip

# Used for splitting a row into columns based on provided range
# Param String line
# Param String arr its layout
# Return Array output_cols
def get_splitted_row(line, arr)
  output_col =[]
  split_col = arr
  begin
    split_col.length.times do |col|
      split_col_range = split_col[col].split("-")
      output_col << line.slice(split_col_range[0].to_i..split_col_range[1].to_i)
    end
  rescue Exception => e
    puts e.message
  end
  return output_col
end

# Use to ignore non ascii chars from key
# Param String Key
# Param Boolean non_ascci If user wants to compare non ascii characters
# Return String Sanitized key
def key_sanitizer(key_str, non_ascii)
  cleaned = ""
  key_str = key_str.gsub(/\t/, '')
  return key_str if non_ascii == "true"
  key_str.each_byte do |c|
    unless c > 127
      cleaned << c
    else
      cleaned << ' '
    end
  end
  return cleaned
end

# Ignoring format types and spaces from string (range or columns)
def cols_and_layout_sanitizer(str)
  return str if str.nil?
  return str.gsub(/[ifsw ]+/, '')
end

# Use to get formatted value of an individual column
# Param String col
# Param Character format_type e.g i, f, s etc.
# Return String updated_col_val
def format_col(col, format_type)
  return '' if col.nil?
  return col unless SUPPORTED_FORMAT_TYPE.include?(format_type)
  format_type = format_type.strip.downcase
  updated_col_val = col
  if format_type.eql?('i')
    updated_col_val = col.to_i
  elsif format_type.eql?('f')
    updated_col_val = col.to_f.round(2)
  elsif format_type.eql?('s')
    updated_col_val = col.strip
  elsif format_type.eql?('w')
    updated_col_val = col.gsub(/[ ]+/, '')
  end
  return updated_col_val
end

# Used to parse given format types from layout or cols_to_compare
# Param Array cols
# Param String cols_to_format it may be layout or cols_to_compare
# Return Array cols
def update_cols_with_formatted_vals(cols, cols_to_format)
  cols_to_format = cols_to_format.gsub(/[ ]+/, '')
  cols_to_format.split(',').each_with_index do |col, index|
    # If format conversion required
    if col.match(/[a-z]$/i)
      format_type = col[-1]
      cols[index] = format_col(cols[index], format_type)
    end
  end
  return cols
end

# Used for getting formatted column array for given column array
# Param Array cols
# Param String layout e.g "0-2, 3-8, 9-22" or "0-2f, 3-8s, 9-22" or "\t"
# Param String cols_to_compare e.g "0, 3, 7, 11" or "0s, 3w, 7f, 11"
# Return Array formatted column array for single row
def get_formatted_cols(cols, layout, cols_to_compare)
  return cols if layout.nil?
  return cols if cols_to_compare.nil? && layout.length == 1
  if !cols_to_compare.nil?
    cols = update_cols_with_formatted_vals(cols, cols_to_compare)
  elsif !layout.nil?
    cols = update_cols_with_formatted_vals(cols, layout)
  end
  return cols
end

# Splitting given line by layout or cols_to_compare
# Param String line
# Param String layout
# Param String cols_to_compare
# Return Array column array for single row
def get_cols(line, layout, cols_to_compare)
  key_cols = []
  # In this case layout info is not provided
  # So, whole line will be taken as key
  if (layout.nil? || layout.empty?)
    key_cols = [line]
    # In this case the layout info is provided
  elsif layout.length > 1
    key_cols = get_splitted_row(line, layout.split(','))
    # In this case the input is a delimited input
  elsif layout.length == 1
    key_cols = line.split(layout)
  end
  # Returning all columns as columns to compare aren't specified
  return key_cols if (cols_to_compare.nil? || cols_to_compare.empty?)  
  req_cols = []
  cols_to_compare.split(',').each{|index| req_cols << key_cols[index.to_i]}
  # Returning selected columns to compare as specified
  return req_cols
end

# Special formation e.g skip_spaces, ignore_case
def special_formatter(key, skip_spaces, ignore_case)
  key = key.gsub(/[ ]+/, '') if skip_spaces == 'true'
  key = key.downcase if ignore_case == 'true'
  return key
end

# Used for flattening cols_to_compare option.
# Param String cols_to_compare "2, 3-5i, 11s, 12-16, 19-20s"
# Return String splitted_str "2,3i,4i,5i,11s,12,13,14,15,16,19s,20s"
def sanitize_cols_to_compare(cols_to_compare)
  return nil if cols_to_compare == 'false'
  cols_to_compare = cols_to_compare.gsub(/[ ]+/, '')
  splitted_str = cols_to_compare.split(",")
  splitted_str.each_with_index do |val, index|
    tmp_output = []
    if !val.nil? && val.include?("-")
      range = val.split("-")
      tmp_str = range[1].match(/\D/)
      tmp_str = "" if tmp_str.nil?
      for x in range[0].to_i..range[1].to_i
      tmp_output << "#{x}#{tmp_str.to_s}"
    end
    splitted_str[index] = tmp_output.join(",")
  end
end
return splitted_str.join(",")
end

# If one file has common pattern like second one
if (ip1_path.length > ip2_path.length)
  input = (table_file.match(/#{ip1_path}/)) ? 'ip1' : 'ip2'
else
  input = (table_file.match(/#{ip2_path}/)) ? 'ip2' : 'ip1'
end
layout = (input == 'ip1') ? layout1 : layout2
layout = nil if layout == 'false'
cols_to_compare = sanitize_cols_to_compare(cols_to_compare)

STDIN.each_line do |line|
  next if (line.nil? || line.chomp.strip.empty?)
  begin
    cols = get_cols(line.chomp, cols_and_layout_sanitizer(layout), 
    cols_and_layout_sanitizer(cols_to_compare))
    cols = get_formatted_cols(cols, layout, cols_to_compare)
    key = key_sanitizer(cols.join, non_ascii)
    key = special_formatter(key, skip_spaces, ignore_case)
    puts "#{key}#{DELIMITER}#{input}#{DELIMITER}#{line}"
  rescue Exception => e
    STDERR.puts e.message
    STDERR.puts e.backtrace
    break
  end
end
