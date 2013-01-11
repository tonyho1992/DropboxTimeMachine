from dropbox import client, rest, session
import os, sys, shutil, time, datetime, calendar
from datetime import datetime
from datetime import timedelta
from datetime import tzinfo
from sqlalchemy import *

ZERO = timedelta(0)

# A UTC class.

class UTC(tzinfo):
    """UTC"""
    def utcoffset(self, dt):
        return ZERO
    def tzname(self, dt):
        return "UTC"
    def dst(self, dt):
        return ZERO

def getUnixTime(meta):
    print meta['modified']
    modtime = datetime(*(time.strptime(meta['modified'], "%a, %d %b %Y %H:%M:%S\
 +0000")[0:6]), tzinfo=UTC())
    return calendar.timegm(modtime.utctimetuple())

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

CURSOR_KEY = "cursor.txt"

while True:
    time.sleep(5)
    print "check"
    cursor = None
    if (os.path.isfile(CURSOR_KEY)):
        f = open(CURSOR_KEY, 'r')
        cursor = f.read()
        f.close()
    ret = client.delta(cursor)
    cursor = ret['cursor']
    f = open(CURSOR_KEY, 'w')
    f.write(cursor)
    f.close()

    entries = ret['entries']
    for e in entries:
        meta = e[1]
        if not meta is None:
            print meta['path'] + " modified"

