mkdir tor-cli-local tor-cli-remote

cp -rf {bin,gpg_gen_template.txt,install_prereqs.sh,local.sh} tor-cli-local/
cp -rf {bin,gpg_gen_template.txt,install_prereqs.sh,remote.sh} tor-cli-remote/
rm -rf tor-cli-remote/bin/local
rm -rf tor-cli-local/bin/remote

tar -czf tor-cli-local.tgz tor-cli-local
tar -czf tor-cli-remote.tgz tor-cli-remote

rm -rf tor-cli-local tor-cli-remote

