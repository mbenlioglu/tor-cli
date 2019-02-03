mkdir tor-cli-local tor-cli-remote

cp -rf {gpg_gen_template.txt,local.sh} tor-cli-local/
cp -rLf bin/local/. tor-cli-local/bin/
cp -rf {gpg_gen_template.txt,remote.sh} tor-cli-remote/
cp -rLf bin/remote/. tor-cli-remote/bin/

tar -czhf tor-cli-local.tgz tor-cli-local
tar -czhf tor-cli-remote.tgz tor-cli-remote

rm -rf tor-cli-local tor-cli-remote

