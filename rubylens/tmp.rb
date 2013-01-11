framework 'Cocoa'

TEMP_DIR = '/tmp'

puts "hi"

ARGV.each do |a|
	target_path = TEMP_DIR+"/"+(File.basename a)
	puts target_path
	puts a
	url1 = NSURL.URLWithString "file://" + target_path
	url = NSURL.URLWithString "file://" + a
	NSFileVersion.addVersionOfItemAtURL url, withContentsOfURL: url1, options: 0, error: nil
end
