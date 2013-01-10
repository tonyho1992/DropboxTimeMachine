from dropbox import client, rest, session
import os, sys, shutil

print os.environ.get('SUDO_USER')

TOKEN_FILE = "token.txt"

DROPBOX_PATH = "/Users/"+os.environ.get('SUDO_USER')+"/Dropbox/"
FILE_NAME = "temp.txt"
FOLDER_PATH = "Hacking/"
FILE_PATH = FOLDER_PATH+FILE_NAME
ACTUAL_FOLDER = DROPBOX_PATH+FOLDER_PATH
ACTUAL_PATH = DROPBOX_PATH+FILE_PATH

token_key = None
token_secret = None

if os.path.isfile(TOKEN_FILE):
    print "found old token"
    f = open(TOKEN_FILE)
    token_key, token_secret = f.read().split('|')
    f.close()

APP_KEY = "i4n7mjo20xiiimo"
APP_SECRET = "wir0dklqx1ccdjq"

ACCESS_TYPE = "dropbox"

sess = session.DropboxSession(APP_KEY, APP_SECRET, ACCESS_TYPE)

if token_key is None:
    print "requesting new token"
    request_token = sess.obtain_request_token()
    url = sess.build_authorize_url(request_token)
    print "url:", url
    print "Please visit this website and press the 'Allow' button, then hit 'Enter' here."
    raw_input()
    access_token = sess.obtain_access_token(request_token)
    
    token_key = access_token.key
    token_secret = access_token.secret
    
    f = open(TOKEN_FILE, 'w')
    f.write("%s|%s" % (token_key, token_secret) )
    f.close()
    print "wrote new token"
else:
    sess.set_token(token_key, token_secret)

client = client.DropboxClient(sess)

print "client constructed"

revisions = client.revisions(FILE_PATH)

DAT_PATH = "/.DocumentRevisions-V100/DAT/"

if not os.path.exists(DAT_PATH):
    os.makedirs(DAT_PATH)

for i in revisions:
    rev = i['rev']
    print "revision", rev, "obtained"
    f = client.get_file(FILE_PATH, rev)
    outfile = open(DAT_PATH + rev + "_dat.txt", 'w')
    outfile.write(f.read())
    f.close()
    outfile.close()

DB_PATH = "/.DocumentRevisions-V100/db-V1/db.sqlite"
TMP_PATH = "tmp.db"
SQL_PATH = "tmp.sql"

shutil.copy2(DB_PATH, TMP_PATH)

parID = os.stat(ACTUAL_FOLDER).st_ino
inodeID = os.stat(ACTUAL_PATH).st_ino
print "ids:", parID, inodeID

sqlscript = open(SQL_PATH, "w")
sqlscript.write("INSERT INTO files VALUES(NULL, '"+FILE_NAME+"', "+str(parID)+", '"+ACTUAL_PATH+"', "+str(inodeID)+", 1357604095, 1, 1);\n")
for i in revisions:
	rev = i['rev']
	fileloc = rev + "_dat.txt"
	filepath = DAT_PATH + fileloc
	sqlscript.write("INSERT INTO generations VALUES(NULL, 1, '"+fileloc+"', 'com.apple.documentVersions', '"+filepath+"', 1, 1, 1357604095, "+str(os.stat(filepath).st_size)+");\n")
sqlscript.close()
