#!/bin/bash

cd $(dirname $0)

vagrant up

ansible-playbook -i vagrant.py -i vagrant-groups.list setDocker_with_swarm.yml
