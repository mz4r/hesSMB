
#INSTALL DE PACKAGE A FAIRE:
# terraform
# packer
# ansible
# kubectl
#
##

init:
	sudo modprobe iptable_filter
	sudo modprobe ipt_tcp
	sudo modprobe br_netfilter
	sudo modprobe bridge
	ansible-galaxy collection install community.libvirt
	ansible-galaxy collection install community.general
	echo "Install qemu/libvirt aussi"

download-iso:
	wget https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-13.2.0-amd64-netinst.iso

build:
	cd packer
	packer init .
	rm -rf /var/lib/libvirt/images/base-images/debian13.qcow2
	packer build -var "iso_path=file://${PWD}/packer/iso/debian-13.2.0-amd64-netinst.iso" -var "ssh_pub_key_path=file://${PWD}/keys/id_rsa.pub" debian13.pkr.hcl

deploy:
	ansible-playbook -i ./inventories/inventory.yaml ansible/deploy-vm.yml 
	ansible-playbook -i ./inventories/inventory.yaml ansible/hardening.yml -e "ansible_user=root"
	ansible-playbook -i ./inventories/inventory.yaml ansible/wireguard.yml -e "ansible_user=root"

cluster:
	ansible-playbook -i ./inventories/inventory.yaml ansible/cluster.yml -e "ansible_user=root"
	ansible-playbook -i ./inventories/inventory.yaml ansible/dns.yml -e "ansible_user=root"
	ansible-playbook -i ./inventories/inventory.yaml ansible/networkpolicies.yml -e "ansible_user=root"

argocd:
	terraform -chdir=terraform/argocd init
	terraform -chdir=terraform/argocd apply -auto-approve 

monitoring:
	terraform -chdir=terraform/monitoring init
	terraform -chdir=terraform/monitoring apply -auto-approve
	
kserve:
	terraform -chdir=terraform/kserve init
	terraform -chdir=terraform/kserve apply -auto-approve

services: monitoring kserve

hardening:
	ansible-playbook -i ./inventories/inventory.yaml ansible/hardening.yml -e "ansible_user=root"

networkpolicies:
	ansible-playbook -i ./inventories/inventory.yaml ansible/networkpolicies.yml -e "ansible_user=root"

dns:
	ansible-playbook -i ./inventories/inventory.yaml ansible/dns.yml -e "ansible_user=root"
