module WriteConcurrencyTest

  # Initialize n hashes (of joyful nonsense), fork one process for each. Have
  # them madly write their hash, and flush (repeat many, many times). While
  # this is happening, read from the hammerspace. It should contain one of the
  # n original hashes. Though which one I shall never tell.
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

    # Wait for first hash to be written, otherwise our hash.size expectations will fail.
    sleep(0.5)

    iterations.times do
      hash = Hammerspace.new(path, options)
      hash_size = hash.size
      raise "hash.size == #{hash_size}, expected #{size}" unless hash_size == size
      size.times do |i|
        unless hash[i.to_s] == hash['0']
          raise "hash[#{i.to_s}] == #{hash[i.to_s]}, expected #{hash['0']}"
        end
      end
      hash.close
    end

    pids.each { |pid| Process.wait(pid) }
  end

end
