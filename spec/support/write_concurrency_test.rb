module WriteConcurrencyTest

  # Initialize n hashes (of joyful nonsense), fork one process for each. Have them
  # madly write their hash, and flush (repeat many, many times). Now join on their
  # timely demise. Read from the resulting hammerspace, it should contain one of
  # the n original hashes. Though which one I shall never tell. Also, at the
  # end of the test, there should be one directory and one symlink.
  def run_write_concurrency_test(path, options, concurrency = 10, iterations = 10, size = 10)
    pids = []
    concurrency.times do |id|
      pids << fork do
        iterations.times do
          hash = Hammerspace.new(path, options)
          size.times { |i| hash[i.to_s] = id.to_s }
          hash.close
        end
      end
    end

    pids.each { |pid| Process.wait(pid) }

    hash = Hammerspace.new(path, options)
    raise "hash.size == #{hash.size}, expected #{size}" unless hash.size == size
    size.times do |i|
      unless hash[i.to_s] == hash['0']
        raise "hash[#{i.to_s}] == #{hash[i.to_s]}, expected #{hash['0']}"
      end
    end
    hash.close

    current_exists = false
    dirs = []
    Dir.glob(File.join(path, '*')) do |file|
      if File.basename(file) == 'hammerspace.lock' && File.file?(file)
        next
      end

      if File.basename(file) == 'current' && File.symlink?(file)
        current_exists = true
        next
      end

      if File.directory?(file)
        dirs << file
        next
      end

      raise "unexpected #{File.ftype(File.join(path, file))} #{file}"
    end
    raise "dirs.size == #{dirs.size}, expected 1" unless dirs.size == 1
  end

end
