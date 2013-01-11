require 'rubygems'
require 'dropbox_sdk'
require 'launchy'
require 'sqlite3'
require 'logger'

# Core Logger init
log = Logger.new(STDOUT)
log.level = Logger::DEBUG

APP_KEY = 'd0xovavyvfogdpw'
APP_SECRET = '26tpquugqgz4rlb'

TEMP_DIR = '/tmp/'
HISTORY_DIR = '~/.dbhistory/'
DROPBOX_DIR = '~/Dropbox/'

## History collection ##
tmp_db_path = TEMP_DIR+'db.sqlite'

# Ready the client

def setup_dropbox()
    log.debug "Setting up Dropbox"

    ## Dropbox Setup ##
    session = DropboxSession.new(APP_KEY, APP_SECRET)
    log.debug "Session created"

    # Auth
    session.get_request_token
    log.debug "Got session request token"

    authorize_url = session.get_authorize_url
    log.debug "Got session auth url"

    # make the user sign in and authorize this token
    log.info "Allow the app at ", authorize_url
    Launchy.open authorize_url
    log.info "ENTER to continue..."
    # Wait for auth
    gets

    session.get_access_token
    log.debug "Dropbox ready"

    return DropboxClient.new(session, :dropbox)
end

## Version Database initialization ##
def acquire_database(temp_path)
    log.debug "Acquiring revision database"

    # Clone the existing version database
    `sudo cp /.DocumentRevision-V100/db-V1/db.sqlite #{temp_path}`
    `sudo chmod 777 #{temp_path}`

    log.debug "Copied revision database"
    return SQLite3::Database.new tmp_db_path
end

def plant_database(temp_path)
    # Manipulation of Revisiond
    # Launchctl stops revisiond to release fd on db-v1 (version database)
    log.debug "Stopping revisiond"
    `sudo launchctl stop com.apple.revisiond`

    # Move the modded db into place
    log.debug "Moving new revision database"
    `sudo mv #{temp_path} /.DocumentRevision-V100/db-V1/db.sqlite`
    `sudo chmod 644 #{temp_path}`

    # Restart the revisiond process
    log.debug "Restarting revisiond"
    `sudo launchctl start com.apple.revisiond`
end

# Pull history from dropbox
def get_revisions(file_path, sequence_number, client, db)
    log.debug "Getting revisions of", div

    revisions = client.revisions file_path
    revisions.each do |rev|
        # File blobs (versions) from dropbox to the history store
        contents = client.get_file file_path, rev.rev

        # Make sure the parent directories all exist
        target_path = HISTORY_DIR+file_path
        parent_dir_path = File.dirname(target_path)
        FileUtils.mkdir_p(parent_dir_path)

        add_time = (Time.parse(rev.modified).to_f * 1000.0).to_i

        log.debug "Writing file", target_path
        # Write this out
        File.open(target_path, 'w+') { |f| f.write contents }
        # Change the creation/mod time on the file
        FileUtils.touch target_path { :mtime => add_time }

        # Insertion of records into version database
        # generation_id,  (auto incremented)
        # generation_storage_id, (row # of file)
        # generation_name, (rev id)
        # generation_client_id, (com.apple.DocumentVersions for versions, com.apple.ubiquity for icloud) 
        # generation_path, (file path)
        # generation_options, (1, 7, 9 ?)
        # generation_status, (1 ?)
        # generation_add_time, (creation datetime)
        # generation_size (filesize)
        file_size = File.size target_path

        db.execute "insert into generations values (NULL, ?, ?, ?, ?, 1, 1, ?, ?);", [sequence_number, rev.rev, 'com.apple.DocumentVersions', target_path, add_time, file_size] 
    end
end

# Walk across Dropbox file tree
def traverse(dir, client, db)
    log.debug "Getting metadata for", dir
    metadata = client.metadata dir

    log.debug "Traversing", dir
    # For each file in dropbox
    metadata.contents.each do |file| 
        if file.is_dir
            traverse file.path, client, db
        else    
            # Create a file entry for the file
            # Location in dropbox
            dropbox_file_path = DROPBOX_DIR + file.path
            file_inode = File.stat(dropbox_file_path).ino
            parent_inode = File.stat(File.dirname(dropbox_file_path)).ino

            # Increment sequence number
            db.execute "update sqlite_sequence set seq=seq+1;"

            # Query for the sequence number
            result = db.execute("select * from sqlite_sequence")
            sequence_number = result.next()['seq']
            result.close

            # Storage table
            # storage_id (counter?) <- sequence number
            # storage_options (1)
            # storage_status (1)
            db.execute "insert into storage values (?, ?, ?);", [sequence_number, 1, 1]

            # file_row_id (auto incremented)
            # file_name (file name)
            file_name = File.basename file.path
            # file_parent_id (inode of parent dir)
            # file_path (file path)
            # file_inode (file inode)
            # file_lastseen (file modification date)
            last_mod = (Time.parse(file.modified).to_f * 1000.0).to_i
            # file_status (1)
            # file_storage_id <- sequence number

            db.execute "insert into files values (?, ?, ?, ?, ?, ?, 1, ?);", [sequence_number, file_name, parent_inode, dropbox_file_path, file_inode, last_mod, sequence_number]
            # Else if file -> get path & revs
            get_revisions file.path, sequence_number, client, db
        end
    end
end

client = setup_dropbox

db = acquire_database tmp_db_path

# Root dir
traverse '/', client, db

plant_database tmp_db_path

