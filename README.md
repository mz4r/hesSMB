# Projet SMB111

# Prérequis
Installation des packages suivants : 
```
terraform # Déploiement d'argocd et les services géré par argocd
packer # Pour construire l'image template des VMs
ansible # Pour executer les playbook pour le deploiment automatisé
kubectl # Communication avec le cluster kubernetes en utilisant le fichier de configuration kubeconfig_cluster
tsh #Teleport client pour accès au service SOC
```

Il faut également mettre en place libvirt/qemu sur l'host avec les librairie nécessaire à packer pour le build de l'image template:
```
sudo modprobe iptable_filter
sudo modprobe ipt_tcp
sudo modprobe br_netfilter
sudo modprobe bridge
```

Pour ansible les collection nécessaire sont à mettre en place (un requirements galaxy est disponible dans ./ansible installable avec : ansible-galaxy collection install -r requirements.yml)
```
ansible-galaxy collection install community.libvirt
ansible-galaxy collection install community.general
```

# Processus de deploiment
```
[X] Deploiement des VMs : Packer
    [X] Construction image
    [X] Deploiment de 3 VMs via Ansible
[X] Hardening Ansible sur les 3 VMs
[X] Cluster K3S Ansible
   [X] Déploiment de 3 noeuds K3S
   [X] Composant sécurité du cluster K3S
        [X] Metallb
        [X] Cert-Manager
        [X] ArgoCD / Keel
        [X] Traefik
        [X] Kubernetes Dashboard
        [X] Longhorn
        [X] LLDAP
        [X] Teleport
        [ ] Vault

[X] Wireguard sur un node + DNSMasq pour resolution interne

[X] Deploiment via ArgoCD
    [X] KServe
        [X] Inference SKLearn-iris
        [/] Qwen 
    [X] Monitoring/Supervision
        [X] Prometheus
        [X] Grafana
        [X] Loki
        [X] AlertManager
```

# Architecture
L'objectif est de mettre en place un cluster kubernetes sur 3 VM de façon automatisé pour exposé tout les services du cycle de vie d'un model (LLM). 
Malheuresement pour une question de ressource principalement, nous n'avons pas pu mettre en place tout les composants de Kubeflow. Nous avons donc mis en place le composants final de la chaine Kserve.

Kserve permet d'exposer les models pour leurs utilisation simple avec des call api par exemple.

![alt text](./assets/img/ai-lifecycle-dev-prod.drawio.svg)
![alt text](./assets/img/ai-lifecycle-kubeflow.drawio.svg)

## Objectifs 
- Configuration hardening de 3 VM
- Mise en place automatisé d'un cluster k8s avec 1 node sur chaque VM
- Mise en place automatisé des composants principaux du cluster utile pour les différents services
- Deploiment des services via argocd  


## Hardening
Les services gérés sont :
- sshd
- iptables/ufw
- repo/packages
- users/permissions

## K8S

- Mise en place d'un node 
- Mise en place de rancher pour une meilleur visualisation
- Mise en place de longhorn pour gestion du volume persistent entre les 3 nodes
- Mise en place d'un repo gitops dans le path /iaplateform du repo 
