require 'rubygems'
require 'dropbox_sdk'
require 'launchy'
require 'sqlite3'
require 'logger'
require 'fileutils'

# Core Logger init
@log = Logger.new(STDOUT)
@log.level = Logger::DEBUG

APP_KEY = 'd0xovavyvfogdpw'
APP_SECRET = '26tpquugqgz4rlb'

TEMP_DIR = '/tmp'
HISTORY_DIR = 'dbhistory/'
DROPBOX_DIR = '/Users/dev/Dropbox'

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

client = setup_dropbox

cursor = nil

while true
    ret = client.delta(cursor)
    cursor = ret['cursor']
    if (not ret['has_more'])
        break
    end
end

@log.debug "now checking"

while true
    sleep 3.0
    @log.debug "check"
    
    ret = client.delta(cursor)

    entries = ret['entries']
    entries.each do |e|
        meta = e[1]
        if not meta == nil and not meta['is_dir']
            @log.debug meta['path']
            target_path = TEMP_DIR+"/TMPDAT"
            contents = client.get_file meta['path']
            dest_path = DROPBOX_DIR + meta['path']
            File.open(target_path, 'w+') { |f| f.write contents }
            `macruby tmp.rb #{dest_path}`
            # url = NSURL.URLWithString "file://" + DROPBOX_DIR + meta['path']
            # url1 = NSURL.URLWithString "file://" + target_path
            # NSFileVersion.addVersionOfItemAtURL url, withContentsOfURL: url1, options: 0, error: nil
        end
    end

    cursor = ret['cursor']
end
