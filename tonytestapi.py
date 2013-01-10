from dropbox import client, rest, session
import os, sys, shutil, time, datetime
from datetime import datetime
from sqlalchemy import *

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

recentf, recentmeta = client.get_file_and_metadata(FILE_PATH)

revisions = client.revisions(FILE_PATH)

print "files/revisions obtained"

DAT_PATH = "/.DocumentRevisions-V100/DAT/"
TRUNCDAT_PATH = "/DAT/"

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

def getUnixTime(meta):
    print meta['modified']
    modtime = datetime.strptime(meta['modified'], "%a, %d %b %Y %H:%M:%S +0000\
")
    print modtime
    return int(time.mktime(modtime.timetuple()))
"""
sqlscript.write("INSERT INTO files VALUES(NULL, '"+FILE_NAME+"', "+str(parID)+", '"+ACTUAL_PATH+"', "+str(inodeID)+", "+str(getUnixTime(recentmeta))+", 1, 1);\n")
for i in revisions:
	rev = i['rev']
	fileloc = rev + "_dat.txt"
	filepath = DAT_PATH + fileloc
	sqlscript.write("INSERT INTO generations VALUES(NULL, 1, '"+fileloc+"', 'com.apple.documentVersions', '"+filepath+"', 1, 1, "+str(getUnixTime(i))+", "+str(os.stat(filepath).st_size)+");\n")
sqlscript.close()
"""

engine = create_engine('sqlite:///'+DB_PATH)

engine.echo = False

metadata = MetaData(engine)

sqlite_seq = Table('sqlite_sequence', metadata, autoload=True)

row = sqlite_seq.select().execute().fetchone()

id = int(row['seq'])

id_inc = 3

seq_update = sqlite_seq.update()

seq_update.execute(seq=id_inc);

sqlite_storage = Table('storage', metadata, autoload=True)

storage_ins = sqlite_storage.insert()

storage_ins.execute(storage_id=id_inc, storage_options=1, storage_status=1)

files = Table('files', metadata, autoload=True)

files_ins = files.insert()

generations = Table('generations', metadata, autoload=True)

generations_ins = generations.insert()

files_ins.execute(file_name=FILE_NAME, file_parent_id=parID, file_path=ACTUAL_PATH, file_inode=inodeID, file_last_seen=getUnixTime(recentmeta), file_status=1, file_storage_id=id_inc)

revisions.reverse()

for i in revisions:
    rev = i['rev']
    fileloc = rev + "_dat.txt"
    filepath = DAT_PATH + fileloc
    truncpath = TRUNCDAT_PATH + fileloc
    generations_ins.execute(generation_storage_id=id_inc, generation_name=fileloc, generation_client_id='com.apple.documentVersions', generation_path=truncpath, generation_options=1, generation_status=1, generation_add_time=getUnixTime(i), generation_size=os.stat(filepath).st_size)
