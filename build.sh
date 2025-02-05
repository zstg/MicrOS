#!/usr/bin/env  bash
docker run --privileged -it ubuntu
apt update
apt install -y bzip2 git vim make gcc libncurses-dev flex bison bc cpio libelf-dev libssl-dev