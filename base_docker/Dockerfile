FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    wget curl gnupg apt-transport-https software-properties-common \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://www.virtualbox.org/download/oracle_vbox_2016.asc | gpg --dearmor \
    | tee /usr/share/keyrings/oracle_vbox_2016-archive-keyring.gpg > /dev/null

RUN echo "deb [arch=amd64 signed-by=/usr/share/keyrings/oracle_vbox_2016-archive-keyring.gpg] \
  https://download.virtualbox.org/virtualbox/debian jammy contrib" \
  > /etc/apt/sources.list.d/virtualbox.list

RUN apt-get update && apt-get install -y virtualbox-7.1

# After this step, need to do the following steps manually to install Vbox Extension Pack.
# The purpose of this step is to view the Qubic output from running inside the docker to the host,
# using the Vbox Extension Pack.

# Build this docker locally:
# cd base_docker && docker build -f Dockerfile -t vbox-base .

# Start a container from vbox-base in interactive mode:
# docker run -it --privileged vbox-base bash

# Download the exact Extension Pack matching your VirtualBox version
# VBoxManage --version
# wget https://download.virtualbox.org/virtualbox/......
# VBoxManage extpack install --replace Oracle_VM_VirtualBox_Extension_Pack-....
# You will see the license text. At the end, type y (or yes) to accept.

# Verify that it’s installed:
# VBoxManage list extpacks
# Should show something like:
# Extension Packs: 1
# Pack no. 0:   Oracle VM VirtualBox Extension Pack
# Version:   ....