#!/usr/bin/env ruby

require "psych"
require 'net/ftp'

config_file = '.ftp-upload-configuration.yml'

# Load configuration from configuration file
config = Psych.load_file(config_file)

# Get a list of all modified files since the last upload, ignore configuration file and .git folders
files = Dir["**/*"].reject { |fn| File.directory?(fn) } \
                   .reject { |fn| File.mtime(fn) < Time.at(config['last_upload_date']) } \
                   .reject { |fn| File.basename(fn) == config_file } \
                   .reject { |fn| File.path(fn).include? '.git' }

# Save the current time to last_upload_date in the configuration file
config['last_upload_date'] = Time.now.to_i
File.open(config_file, 'w') do |file|
  file.write(Psych.dump(config))
end

# Open FTP connection and upload the files
Net::FTP.open(config['ftp']['server'], config['ftp']['username'], config['ftp']['password']) do |ftp|
  files.each {|file|
    dirname = File.dirname(file)

    # Set dirname based on local path and the project directory in configuration file
    if dirname != '.'
      dir = config['ftp']['project_dir'] ++ dirname
    else
      dir = config['ftp']['project_dir']
    end

    # Check if directory path exists, otherwise create it
    # TODO: Check for folders with whitespace in folder name
    folders = dir.split('/')
    existing_path = '/'
    folders.each { |folder|
      ftp.mkdir("#{existing_path}#{folder}") if !ftp.list("#{existing_path}").any?{|dir| dir.match(/\s#{Regexp.quote(folder)}$/)}
      existing_path = "#{existing_path}#{folder}/"
    }

    # Change directory and upload the file
    ftp.chdir("/#{dir}")
    ftp.putbinaryfile(file)

    # Puts information about the uploaded file to console
    puts "Upload #{file} to #{dir}/#{File.basename(file)}"
  }
end
