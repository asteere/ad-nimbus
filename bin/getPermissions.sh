#! /bin/sh

# TODO: figure out how to preserve linux permisions when files are synced to s3 bucket

cd $adNimbusDir

scriptFile=bin/restorePermissions.sh

echo '#! /bin/bash' > "$scriptFile"
echo >> "$scriptFile"
echo 'cd "$adNimbusDir"' >> "$scriptFile"
chmod +x "$scriptFile"

find . -type f| grep -v -e Vagrantfile -e nginx.conf -e insecure_private_key -e .swp -e .vagrant -e .git -e .nfs -e .jmx | xargs stat -f "%p %N" | grep -v 644 | sed -e 's/^100//' -e 's/^40//' -e 's/^/chmod /' >> "$scriptFile"
echo >> $scriptFile

ls -l $scriptFile
echo
cat $scriptFile
