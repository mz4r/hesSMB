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

[X] Wireguard sur un node + DNSMasq pour resolution interne

[X] Deploiment via ArgoCD
    [X] KServe
        [X] Inference SKLearn-iris
        [X] Qwen 
    [X] Monitoring/Supervision
        [X] Prometheus
        [X] Grafana
        [X] Loki
        [X] AlertManager
        [X] NodeExporter
```

Voici les différentes étapes pour le déploiement complet :

**1. Construction de l'image template**
On construit l'image template Debian 13 avec un hardening (renforcement) `debian13-cis`.

```bash
make build

```

À la fin du build, une image qcow2 est créée : `./packer/debian13.qcow2/packer-debian13`.

Il faut la placer au bon endroit ou modifier l'inventory Ansible pour indiquer le chemin de l'image (les droits doivent être corrects pour que libvirt puisse y accéder) : `/var/lib/libvirt/images/base-images/debian13-hardening-cis.qcow2`.

**2. Déploiement des VM et du réseau**
On déploie les VM et le réseau `smb-net` sur notre hyperviseur avec :

```bash
make deploy

```

Cela lance les playbooks qui déploient le réseau et les VMs, puis redimensionnent les disques des VMs selon nos besoins. Ensuite, le playbook de hardening et le playbook WireGuard (pour l'accès VPN) sont relancés.

On peut ensuite récupérer sur l'hyperviseur le fichier de configuration client WireGuard pour la connexion VPN, situé dans `/root/wireguard-keys/admin.conf`.

**3. Déploiement du cluster Kubernetes**
On déploie le cluster Kubernetes et ses composants principaux :

```bash
make cluster

```

Cela met en place le cluster défini dans l'inventory puis déploie les composants suivants :

* MetalLB
* Traefik
* Cert-manager
* Longhorn
* Kube Dashboard
* LLDAP
* Teleport

Cela exécute également le playbook SmartDNS qui configure un serveur DNSMasq avec une configuration dynamique basée sur les Ingress gérés par Traefik.

**4. Déploiement d'ArgoCD**
On déploie ArgoCD pour la gestion des autres services :

```bash
make argocd
```

**5. Configuration des secrets et services**
On récupère le mot de passe admin ArgoCD généré automatiquement dans les secrets du namespace `argocd`, puis on modifie le mot de passe dans les fichiers de version Terraform : `./terraform/kserve` et `./terraform/monitoring`.

Une fois cela fait, on peut exécuter :

```bash
make services
```

Cela déploiera via Terraform les services sur ArgoCD pour le monitoring et KServe.

On peut ensuite terminer par le deploiment des network policies pour appliquer l'isolation des services sensible : 
```bash
make networkpolicies
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

# Urls :

https://auth.mz4.re/

https://argocd.mz4.re/

https://keel.mz4.re/

https://grafana.mz4.re/

https://teleport.mz4.re/


KSERVE => 

Modèle Iris (Sklearn) :

    Domaine : https://iris.kserve.mz4.re

    Endpoint de prédiction (V1) : POST https://iris.kserve.mz4.re/v1/models/sklearn-iris:predict

Modèle Qwen (HuggingFace) :

    Domaine : https://qwen.kserve.mz4.re

    Endpoint de prédiction (V2 standard pour LLM/Triton) : POST https://qwen.kserve.mz4.re/v2/models/qwen-mini/infer