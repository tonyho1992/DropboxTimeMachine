path=/System/Library/PrivateFrameworks/GenerationalStorage.framework/Versions/A/Support/
file_ori=revisiond
file_back=revisiond.old
path_db=/.DocumentRevisions-V100/db-V1/db.sqlite
mv $path$file_ori $path$file_back
pid=$(fuser $path_db)
if [[ "$pid" == "" ]]; then
 echo "process not found"
 exit
fi
kill -9 $pid
echo "$pid killed successfully"
