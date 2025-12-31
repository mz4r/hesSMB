
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
	cd packer
	packer init .

download-iso:
	wget https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-13.2.0-amd64-netinst.iso

build:
	cd packer
	packer init .
	rm -rf /var/lib/libvirt/images/base-images/debian13.qcow2
	packer build -var "iso_path=file://${PWD}/packer/iso/debian-13.2.0-amd64-netinst.iso" -var "ssh_pub_key_path=file://${PWD}/keys/id_rsa.pub" debian13.pkr.hcl

deploy:
	ansible-playbook -i ./inventories/inventory.yaml playbooks/deploy-vm.yml
	sleep 20
	ansible-playbook -i ./inventories/inventory.yaml playbooks/hardening.yml -e "ansible_user=root" -e "ansible_password=mizcorp"
	ansible-playbook -i ./inventories/inventory.yaml playbooks/wireguard.yml -e "ansible_user=root" -e "ansible_password=mizcorp"

cluster:
	ansible-playbook -i ./inventories/inventory.yaml playbooks/2-k3s.yml -e "ansible_user=root" -e "ansible_password=mizcorp"

hardening:
	ansible-playbook -i ./inventories/inventory.yaml playbooks/hardening.yml -e "ansible_user=root" -e "ansible_password=mizcorp"


argocd:
	terraform -chdir=terraform/argocd init
	terraform -chdir=terraform/argocd apply -auto-approve 

monitoring:
	terraform -chdir=terraform/monitoring init
	terraform -chdir=terraform/monitoring apply -auto-approve
	
kserve:
	terraform -chdir=terraform/kserve init
	terraform -chdir=terraform/kserve apply -auto-approve

vm-stop:
	virsh destroy node1
	virsh destroy node2
	virsh destroy node3


vm-start:
	virsh start node1
	virsh start node2
	virsh start node3

rm-deploy:
	virsh net-destroy smb-net
	virsh net-undefine smb-net
	virsh destroy node1
	virsh destroy node2
	virsh destroy node3
	virsh undefine node1 --remove-all-storage
	virsh undefine node2 --remove-all-storage
	virsh undefine node3 --remove-all-storage
	rm -fr /var/lib/libvirt/images/node*

all: build deploy cluster argocd monitoring kserve
