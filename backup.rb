require 'find'

#
#
# Dumps full paths to existing files and directories specified in 
# configuration file, which can be piped to an archiving utility 
# like pax.
#
# Usage: backup.rb <configuration file>
#
# Example:
#
#  (create a backup archive)
#  root# ruby backup.rb backup.conf | pax -w -d -f archive.pax
#  root# pax -v -f archive.pax 
#  root# gzip archive.pax
#  
#  (restore a backup to system, replacing exsting files)
#  root# gunzip archive.pax.gz
#  root# pax -d -r -v -pe -f archive.pax


# Configuration object: holds references to [[sections]] in configuration file

class Configuration
   attr_accessor :file, :current_section, :sections

   def initialize(filename)
     @file = filename
     @sections = {}
     current_section = nil
   end

   def add(section)
     @sections[section.name.to_sym]=section
     @current_section = section
   end

   def clean(str)
      ret_str = str;
      ret_str.chomp!
      ret_str.lstrip!
      return ret_str
   end

   def read()
     File.open(file,"r").each_line do |line| 
     line.chomp!

     case line

       when /^\s*(#+).*$/

       when /^(\s*\[){2}\s*(.+)(\s*\]){2}\s*$/
         cleaned = clean($2)
         if (cleaned == "roots" || cleaned == "backups" || cleaned == "exclusions")
            add(Section.new(cleaned))
         end

       when /^\s*\[\s*(.+)\s*\]\s*$/
         cleaned = clean($1)
         if FileTest.directory?(cleaned)
            current_section.add(BackableDir.new(cleaned))
         end

       when /\s*(.+)\s*/
         current_section.current_directory.add(BackableFile.new(clean($1)))

       else
         #
      end
   end
end


# Section represents a [[section]] entry in the configuration file.
# Contains a hash of one or more [/directories]

class Section
   attr_accessor :name, :current_directory, :directories

   def initialize(name)
      @name = name
      @directories = Hash.new
      @current_directory = nil
   end

   def add(directory)
     @directories[directory.name.to_sym]=directory
     @current_directory = directory
   end
end


# BackableDir represents a [directory] entry in configuration file
# Contains an array of zero or more files

class BackableDir
   attr_accessor :name, :current_file, :files

   def initialize(directory)
      @name = directory
      @current_file = nil
      @files = Array.new
   end

   def add(file_ref)
     @files << file_ref.name
     @current_file = file_ref
   end

   # based on: http://ruby-doc.org/stdlib-1.9.3/libdoc/find/rdoc/Find.html

   def BackableDir.traverse(root,start_path,exclusions)
     Find.find(root + start_path) do |path|
        if FileTest.directory?(path)
           path.slice!(root)
           if exclusions[path.to_sym] 
              Find.prune
           end
        path.prepend(root)
        end
     PathCheck.display(path)
     end
   end
end

# BackableFile represents a filename in configuration file.

class BackableFile
   attr_accessor :name

   def initialize(name)
      @name = name
   end
end

class PathCheck
   def PathCheck.clean(path)
      path.chomp!
      path.lstrip!
      path.squeeze!("/")
   end

   def PathCheck.display(path)
      PathCheck.clean(path)
      puts path if FileTest.exist?(path)
   end
end


## driver
   if ARGV.size < 1 || ARGV.size > 1 || !FileTest.exist?(ARGV[0]) 
      puts "Usage: backup.rb <configuration file>"
      exit
   end

   conf = Configuration.new(ARGV[0])
   conf.read

   roots = conf.sections[:roots].directories
   backup_dirs = conf.sections[:backups].directories
   exclusions = conf.sections[:exclusions].directories
   exclusions.update(roots)

   roots.each_pair do |r_name,a_root|
      backup_dirs.each_pair do |b_name,a_backup_dir|
         if (a_backup_dir.files.empty?) 
            BackableDir.traverse(a_root.name,b_name.to_s,exclusions) 
         end
         a_backup_dir.files.each do |a_file|
            PathCheck.display(a_root.name + a_backup_dir.name + "/" + a_file)
         end
      end
   end
end
