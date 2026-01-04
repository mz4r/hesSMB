packer {
  required_plugins {
    qemu = {
      version = "~> 1"
      source  = "github.com/hashicorp/qemu"
    }
    ansible = {
      version = ">= 1.1.2"
      source  = "github.com/hashicorp/ansible"
    }
  }
}

variable "config_file" {
  type    = string
  default = "debian13-preseed.cfg"
}

variable "cpu" {
  type    = string
  default = "2"
}

variable "disk_size" {
  type    = string
  default = "60000"
}

variable "headless" {
  type    = string
  default = "true"
}

variable "name" {
  type    = string
  default = "debian"
}

variable "ram" {
  type    = string
  default = "4096"
}

variable "ssh_password" {
  type    = string
  default = "mizcorp"
}

variable "ssh_username" {
  type    = string
  default = "root"
}

variable "version" {
  type    = string
  default = "13"
}

variable "iso_path" {
  type    = string
  default = "file://./iso/debian-13.2.0-amd64-netinst.iso"
}

variable "iso_checksum" {
  type = string
  default = "sha256:677c4d57aa034dc192b5191870141057574c1b05df2b9569c0ee08aa4e32125d"
}

variable "ssh_pub_key_path" {
  type    = string
  default = "file://./keys/id_rsa.pub"
}

source "qemu" "debian13" {
  iso_url          = var.iso_path
  iso_checksum     = var.iso_checksum
  accelerator      = "kvm"
  disk_cache       = "none"
  disk_compression = true
  disk_discard     = "unmap"
  disk_interface   = "virtio"
  disk_size        = var.disk_size
  format           = "qcow2"
  headless         = var.headless
  http_directory   = "."
  net_device       = "virtio-net"
  output_directory = "/var/lib/libvirt/images/base-images/${var.name}${var.version}"
  qemu_binary      = "/usr/bin/qemu-system-x86_64"
  qemuargs = [
    ["-m", "${var.ram}M"],
    ["-smp", "${var.cpu}"],
    ["-cpu", "host"],
    ["-audiodev", "none,id=snd0"]
  ]

  shutdown_command       = "sudo /usr/sbin/shutdown -h now"
  ssh_password           = var.ssh_password
  ssh_username           = var.ssh_username
  
  # FIX: Réduction du temps d'attente pour éviter le timeout de l'ISO
  boot_wait              = "5s" 

  ssh_handshake_attempts = 500
  ssh_timeout            = "45m"
  ssh_wait_timeout       = "45m"
  host_port_max          = 2229
  host_port_min          = 2222
  http_port_max          = 10089
  http_port_min          = 10082

  boot_command = [
  "<esc><wait>",
  "c<wait>",
  "linux /install.amd/vmlinuz auto=true priority=critical locale=fr_FR.UTF-8 keyboard-layout=fr ",
  "netcfg/get_hostname=${var.name}${var.version} ",
  "preseed/url=http://{{ .HTTPIP }}:{{ .HTTPPort }}/http/${var.config_file} ",
  "DEBIAN_FRONTEND=text fb=false lowmem/low=false speakup.synth=none ",
  "modprobe.blacklist=snd_intel8x0,snd_hda_intel,snd_ac97_codec,pcspkr ",
  "<enter><wait>",
  "initrd /install.amd/initrd.gz<enter><wait>",
  "boot<enter>"
  ]
}

build {
  sources = ["source.qemu.debian13"]

  provisioner "shell" {
    execute_command = "{{ .Vars }} sudo -E bash '{{ .Path }}'"
    inline          = [
      "apt-get update",
      "apt -y install ansible",
      "ansible-galaxy collection install community.libvirt",
      "ansible-galaxy collection install community.general"
    ]
  }

  provisioner "ansible" {
    extra_arguments = [
      "--scp-extra-args", "'-O'"
    ]
    playbook_file = "../playbooks/hardening.yml"
  }
}
