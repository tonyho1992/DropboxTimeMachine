framework 'Cocoa'

TEMP_DIR = '/tmp'
target_path = TEMP_DIR+"/TMPDAT"

puts "hi"

ARGV.each do |a|
	puts target_path
	puts a
	url1 = NSURL.URLWithString "file://" + target_path
	url = NSURL.URLWithString "file://" + a
	NSFileVersion.addVersionOfItemAtURL url, withContentsOfURL: url1, options: 0, error: nil
end
