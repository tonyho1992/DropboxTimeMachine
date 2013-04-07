require 'rubygems'
require 'dropbox_sdk'
require 'launchy'
require 'sqlite3'
require 'logger'
require 'fileutils'
require 'date'

# Core Logger init
@log = Logger.new(STDOUT)
@log.level = Logger::DEBUG

APP_KEY = 'd0xovavyvfogdpw'
APP_SECRET = '26tpquugqgz4rlb'

TEMP_DIR = '/Users/tonyho/Dropbox2/Dropbox'
HISTORY_DIR = 'dbhistory/'
DROPBOX_DIR = '/Users/tonyho/Dropbox'

class FileRev
    attr_accessor :file_loc, :timestamp, :is_deleted, :rev

    def <=>(other)
        [self.timestamp] <=> [other.timestamp]
    end

    include Comparable
end

## History collection ##
# Ready the client

def setup_dropbox()
    @log.debug "Setting up Dropbox"

    ## Dropbox Setup ##
    session = DropboxSession.new(APP_KEY, APP_SECRET)
    @log.debug "Session created"

    # Auth
    session.get_request_token
    @log.debug "Got session request token"

    authorize_url = session.get_authorize_url
    @log.debug "Got session auth url"

    # make the user sign in and authorize this token
    @log.info "Allow the app at "
    Launchy.open authorize_url
    @log.info "ENTER to continue..."
    # Wait for auth
    gets

    session.get_access_token
    @log.debug "Dropbox ready"

    return DropboxClient.new(session, :dropbox)
end

# Pull history from dropbox
def get_revisions(file_path, client)
    @log.debug "Getting revisions of " + file_path
    revs = []
    revisions = client.revisions file_path
    revisions.each do |rev|
        fileRev = FileRev.new
        if rev['is_deleted']
            fileRev.file_loc = rev["path"]
            fileRev.is_deleted = true
            fileRev.timestamp = DateTime.parse(rev['modified'])
            fileRev.rev = rev["rev"]
            @log.debug rev["path"] + ' deleted ' + rev["rev"] + ' ' + rev['modified']
        else 
            fileRev.file_loc = rev["path"]
            fileRev.is_deleted = false
            fileRev.timestamp = DateTime.parse(rev['modified'])
            fileRev.rev = rev["rev"]
            @log.debug rev["path"] + ' ' + rev["rev"] + ' ' + rev['modified']
        end
        revs.push(fileRev)
    end
    return revs
end

def recurseDirs(dir, client, list)
    @log.debug "Recursing " + dir
    file_metadata = client.metadata(dir, 25000, true, nil, nil, include_deleted=true)
    file_metadata['contents'].each do |content|
        if content['is_dir']
            list = list + recurseDirs(content['path'], client, list)
        else
            list = list + get_revisions(content['path'], client)
        end
    end
    return list
end

client = setup_dropbox

allRevs = recurseDirs('/', client, [])

allRevs.sort.each do |rev|
    @log.info rev
    if rev.is_deleted
        `rm "#{TEMP_DIR}#{rev.file_loc}"`
    else
        contents = client.get_file rev.file_loc, rev.rev
        FileUtils.mkdir_p(File.dirname(TEMP_DIR + rev.file_loc))
        File.open(TEMP_DIR + rev.file_loc, 'w+') { |f| f.write contents }
    end
    `tmutil startbackup --block`
    sleep(90)
end
