require 'dropbox_sdk'
require 'launchy'
require 'sqlite3'

APP_KEY = 'INSERT-APP-KEY-HERE'
APP_SECRET = 'INSERT-APP-SECRET-HERE'

TEMP_DIR = '/tmp/'
HISTORY_DIR = '~/.dbhistory/'

## Dropbox Setup ##
session = DropboxSession.new(APP_KEY, APP_SECRET)

# Auth
session.get_request_token
authorize_url = session.get_authorize_url

# make the user sign in and authorize this token
puts "Allow the app at ", authorize_url
Launchy.open authorize_url
puts "ENTER to continue..."
# Wait for auth
gets

session.get_access_token

# Ready the client
client = DropboxClient.new(session, :dropbox)

## Version Database initialization ##
def acquire_database(temp_path)
    # Clone the existing version database
    `sudo cp /.DocumentRevision-V100/db-V1/db.sqlite #{temp_path}`
end

def plant_database(temp_path)
    # Manipulation of Revisiond
    # Launchctl stops revisiond to release fd on db-v1 (version database)
    `sudo launchctl stop com.apple.revisiond`

    # Move the modded db into place
    `sudo mv #{temp_path} /.DocumentRevision-V100/db-V1/db.sqlite`

    # Restart the revisiond process
    `sudo launchctl start com.apple.revisiond`
end

# Pull history from dropbox
def get_revisions(file_path)
    revisions = client.revisions file_path
    revisions.each do |rev|
        # File blobs (versions) from dropbox to the history store
        contents = client.get_file file_path, rev.rev

        # Make sure the parent directories all exist
        target_path = HISTORY_DIR+file_path
        parent_dir_path = File.dirname(target_path)
        FileUtils.mkdir_p(parent_dir_path)

        # Write this out
        File.open(target_path, 'w+') { |f| f.write contents }

        # Get the file inode
        target_inode = File.stat(target_path).ino
        # Get the parent inode
        parent_inode = File.stat(parent_dir_path).ino

        # Insertion of records into version database
        # TODO
    end
end

# Walk across Dropbox file tree
def traverse(dir)
    metadata = client.metadata dir

    # For each file in dropbox
    metadata.contents.each do |file| 
        if file.is_dir
            traverse file.path    
        else    
            # Else if file -> get path & revs
            get_revisions file.path
        end
    end
end

## History collection ##
acquire_database '/tmp/db.sqlite'

# Root dir
traverse '/'

plant_database '/tmp/db.sqlite'

