#!/usr/bin/env ruby

# Quick and dirty script to do some testing. 

# ruby -Ilib:test ./bd_metrics/finditem_measure.rb

require 'borrow_direct'
require 'borrow_direct/find_item'

key = "isbn"
sourcefile = ARGV[0] || File.expand_path("../isbn-bd-test-200.txt", __FILE__)

# How long to wait n BD before giving up. 
timeout = 20

# Range of how long to wait between requests, in seconds. Actual
# delay each time randomly chosen from this range. 
# wait one to 7 minutes. 
delay = 60..420

puts "#{ENV['BD_LIBRARY_SYMBOL']}: #{key}: #{sourcefile}"

identifiers = File.readlines(sourcefile)   #.shuffle
 
puts "  #{identifiers.count} total input identifiers"

times     = []
errors    = []
timeouts  = []

finder = BorrowDirect::FindItem.new(ENV["BD_PATRON"], ENV["BD_LIBRARY_SYMBOL"])
finder.timeout = timeout

i = 0

stats = lambda do |times|
  h = OpenStruct.new

  h.min       = times[0]
  h.tenth     = times[(times.count / 10) - 1]
  h.median    = times[(times.count / 2) - 1]
  h.seventyfifth = times[(times.count - (times.count / 4)) - 1]
  h.ninetieth = times[(times.count - (times.count / 10)) - 1]
  h.ninetyninth = times[(times.count - (times.count / 100)) - 1]
  h.max       = times[times.count - 1]

  # now without the ones that were timeouts
  times1 = times.delete_if {|t| t >= timeout}
  h1 = OpenStruct.new
  h1.min       = times[0]
  h1.tenth     = times[(times.count / 10) - 1]
  h1.median    = times[(times.count / 2) - 1]
  h1.seventyfifth = times[(times.count - (times.count / 4)) - 1]
  h1.ninetieth = times[(times.count - (times.count / 10)) - 1]
  h1.ninetyninth = times[(times.count - (times.count / 100)) - 1]
  h1.max       = times[times.count - 1]

  return [h, h1]
end

printresults = lambda do
  times.sort!

  (t, t1) = stats.call(times)

  

  puts "\n\n"
  puts "tested #{i} identifiers, with timeout #{timeout}s, delaying #{delay} seconds between FindItem api requests"
  puts "timing distribution (inc. timeouts) min: #{t.min.round(1)}s; 10th %ile: #{t.tenth.round(1)}s; median: #{t.median.round(1)}s; 75th %ile: #{t.seventyfifth.round(1)}s; 90th %ile: #{t.ninetieth.round(1)}s; 99th %ile: #{t.ninetyninth.round(1)}s; max: #{t.max.round(1)}s"
  puts "timing distribution (W/O timeouts) min: #{t1.min.round(1)}s; 10th %ile: #{t1.tenth.round(1)}s; median: #{t1.median.round(1)}s; 75th %ile: #{t1.seventyfifth.round(1)}s; 90th %ile: #{t1.ninetieth.round(1)}s; 99th %ile: #{t1.ninetyninth.round(1)}s; max: #{t1.max.round(1)}s"  
  puts "    error count: #{errors.count}"
  puts "    timeout count: #{timeouts.count}"
end


at_exit do
  printresults.call

  puts "\n\n\nAll errors: "
  errors.each do |arr|
    puts arr.inspect
  end

  puts "\n\n\nAll timeouts: "
  timeouts.each do |arr|
    puts arr.inspect
  end

  puts "\n\n\n"

end

identifiers.each do |id|
  print "."
  id = id.chomp
  i = i + 1

  start = Time.now

  begin
    finder.find_item_request(key => id)
  rescue BorrowDirect::HttpTimeoutError => e
    timeouts << [key, id, e]
  rescue BorrowDirect::Error => e
    errors << [key, id, e]
  end
  elapsed = Time.now - start

  times << elapsed

  if i % 10 == 0
    printresults.call
  end

  print "w"
  sleep rand(delay)

end

