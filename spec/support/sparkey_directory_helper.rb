module SparkeyDirectoryHelper

  def self.directory_count(path)
    dirs = 0
    Dir.glob(File.join(path, '*')) do |f|
      dirs += 1 if File.directory?(f) && !File.symlink?(f)
    end
    dirs
  end

  def self.has_current_symlink?(path)
    File.symlink?(File.join(path, 'current'))
  end

  def self.has_unknown_files?(path)
    unknown_files = false
    Dir.glob(File.join(path, '*')) do |file|
      next if File.directory?(file)
      next if File.basename(file) == 'current' && File.symlink?(file)
      next if File.basename(file) == 'hammerspace.lock' && File.file?(file)
      unknown_files = true
    end
    unknown_files
  end

end
