# This tool is used for comparing big files
export DIFF_TOOL_PATH=`dirname $0`

# Including properties file
. $DIFF_TOOL_PATH/tool.properties
$RUBY_PATH $DIFF_TOOL_PATH/src/main.rb "$@"
