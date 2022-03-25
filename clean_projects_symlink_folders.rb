# ruby clean_projects_symlink_folders.rb
# ruby clean_projects_symlink_folders.rb -o ~/Documents/ixmedia_projects/
# ruby clean_projects_symlink_folders.rb -o ~/Documents/vm/www/

# Clean linked dirs from projects
# Only compatible with Capistrano configs.

# Get options
require 'optparse'

options = {
  origin: nil,
  quiet: false,
  force_yes: false
}
OptionParser.new do |opts|
  opts.banner = "Usage: ruby #{__FILE__} [options]"

  opts.on('-o', '--origin [STRING]', String, 'Script will check folders in this directory') do |v|
    options[:origin] = v
  end

  opts.on('-q', '--quiet', 'Don\'t print anything') do |v|
    options[:quiet] = true
  end

  opts.on('-y', '--force-yes', 'Force Yes to all prompts') do |v|
    options[:force_yes] = true
  end

  opts.on('-h', '--help', 'Prints this help') do
    puts opts
    exit 0
  end

end.parse!

if !options[:origin]
  system "ruby #{__FILE__} -h"
  exit 1
end

# Make sure we have a trailing slash
if !options[:origin][/\/$/]
  options[:origin] += '/'
end

# Get root of projects folders
# Foreach project
directories_to_delete = []
projects = Dir.entries(options[:origin]).select { |entry| File.directory?(File.join(options[:origin], entry)) && !(entry == '.' || entry == '..') }
puts "Found #{projects.length} projects" if !options[:quiet]
projects.each do |project|
  # Find the deploy.rb file
  # Other possible way :  Dir["#{options[:origin] + project}/**/deploy.rb"]
  # Will find more results but will be slower
  if File.exists?("#{options[:origin] + project}/config/deploy.rb")
    deploy_file_path = "#{options[:origin] + project}/config/deploy.rb"
  elsif File.exists?("#{options[:origin] + project}/deploy.rb")
    deploy_file_path = "#{options[:origin] + project}/deploy.rb"
  else
    next
  end
  # Get the line of linked_dirs from the config/deploy.rb from the root folder
  linked_dirs_line = `cat #{deploy_file_path}`
  linked_dirs_line = linked_dirs_line.split("set :linked_dirs, ")[1]&.strip!
  if !linked_dirs_line || !linked_dirs_line[/^%w/]
    next
  end
  # Get the list marker
  marker = linked_dirs_line[2]
  regex = nil
  if marker == '('
    regex = /^([^\)]+)\)/
  elsif marker == '{'
    regex = /^([^\}]+)\}/
  else
    regex = Regexp.new("^([^\\#{marker}]+)\\#{marker}")
  end
  linked_dirs_line = linked_dirs_line[regex]&.gsub(/\n+/, ' ')&.gsub(/ {2,}/, ' ')

  if !linked_dirs_line
    next
  end
  # Make the array from the string
  # Yes, I know, that's dangerous.
  linked_dirs = eval(linked_dirs_line)

  if linked_dirs.empty?
    next
  end

  # Get all dirnames that have dist or public in their names
  linked_dirs.reject! { |dir| !dir[/^public\/|^dist\//] }

  linked_dirs << 'node_modules'

  if !linked_dirs.empty?
    linked_dirs.each do |dir|
      dirname = options[:origin] + project + '/' + dir
      if File.exists?(dirname) && File.directory?(dirname)
        directories_to_delete << options[:origin] + project + '/' + dir
      end
    end
  end
end

if directories_to_delete.empty?
  puts 'No directories found. Exiting gracefully.' if !options[:quiet]
  exit 0
end

# List all found folders
if !options[:quiet]
  puts "These #{directories_to_delete.length} linked directories have been found and could be deleted : "
  puts "Size | Directory name"
  directories_to_delete.each do |dir|
    puts `du -s #{dir}`
  end
end

# Ask user if he wants to delete them
answer = false
if !options[:force_yes]
  puts "Do you want to delete these #{directories_to_delete.length} folders and all their contents permanently? (Y/n)"
  input = gets.chomp
  if ['Y', 'Yes', 'YES'].include?(input)
    answer = true
  else
    answer = false
  end
else
  answer = true
end

if !answer
  exit 0
end

# Delete them if yes
directories_to_delete.each do |dir|
  if !system("rm -rf #{dir}")
    puts "Failed to remove folder #{dir}"
  end
end

exit 0
