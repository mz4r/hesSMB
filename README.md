# Projet SMB112

## Prérequis

L'installation des paquets suivants est nécessaire :

* **Terraform** : Déploiement d'ArgoCD et des services gérés par celui-ci.
* **Packer** : Construction de l'image template des machines virtuelles (VM).
* **Ansible** : Exécution des playbooks pour le déploiement automatisé.
* **Kubectl** : Communication avec le cluster Kubernetes via le fichier `kubeconfig_cluster`.
* **Tsh** : Client Teleport pour l'accès sécurisé au service SOC.

### Configuration de l'hôte

Il est nécessaire de configurer **libvirt/QEMU** sur l'hôte, ainsi que les bibliothèques requises par Packer pour le build :

```bash
sudo modprobe iptable_filter
sudo modprobe ipt_tcp
sudo modprobe br_netfilter
sudo modprobe bridge

```

### Collections Ansible

Les collections nécessaires se trouvent dans le fichier `requirements.yml` du dossier `./ansible`. Vous pouvez les installer avec la commande suivante :
`ansible-galaxy collection install -r requirements.yml`

Sinon, installez-les manuellement :

```bash
ansible-galaxy collection install community.libvirt
ansible-galaxy collection install community.general

```

---

## Processus de déploiement

Le projet suit les étapes de validation suivantes :

* [x] **Déploiement des VM (Packer & Ansible)**
* [x] Construction de l'image
* [x] Déploiement de 3 VM via Ansible


* [x] **Hardening (Durcissement)** : Application des politiques de sécurité Ansible sur les 3 VM.
* [x] **Cluster K3S (Ansible)**
* [x] Déploiement de 3 nœuds K3S
* [x] Composants de sécurité et infrastructure : MetalLB, Cert-Manager, ArgoCD, Keel, Traefik, Kubernetes Dashboard, Longhorn, LLDAP, Teleport.


* [x] **Réseau** : WireGuard sur un nœud + DNSMasq pour la résolution interne.
* [x] **Déploiement via ArgoCD**
* [x] **KServe** : Inférence SKLearn-iris, Qwen.
* [x] **Observabilité** : Prometheus, Grafana, Loki, AlertManager, NodeExporter.



---

## Étapes détaillées du déploiement

### 1. Construction de l'image template

Nous construisons une image template **Debian 13** en appliquant un durcissement (hardening) de type `debian13-cis`.

```bash
make build

```

À l'issue du build, une image QCOW2 est générée : `./packer/debian13.qcow2/packer-debian13`.
**Note :** Veillez à déplacer cette image vers `/var/lib/libvirt/images/base-images/debian13-hardening-cis.qcow2` ou à modifier l'inventaire Ansible. Assurez-vous que les permissions permettent à `libvirt` d'y accéder.

### 2. Déploiement des VM et du réseau

Déployez les VM et le réseau `smb-net` sur l'hyperviseur :

```bash
make deploy

```

Cette commande exécute les playbooks qui :

1. Déploient le réseau et les VM.
2. Redimensionnent les disques selon les besoins.
3. Appliquent le hardening et configurent WireGuard pour l'accès VPN.

Le fichier de configuration client WireGuard est disponible sur l'hyperviseur à l'emplacement : `/root/wireguard-keys/admin.conf`.

### 3. Déploiement du cluster Kubernetes

Pour installer le cluster et ses composants socles :

```bash
make cluster

```

Cette étape configure le cluster et déploie automatiquement : MetalLB, Traefik, Cert-manager, Longhorn, Kube Dashboard, LLDAP et Teleport. Elle lance aussi le playbook **SmartDNS** qui configure `DNSMasq` de manière dynamique selon les Ingress Traefik.

### 4. Déploiement d'ArgoCD

Installez ArgoCD pour la gestion continue (GitOps) des services :

```bash
make argocd

```

### 5. Configuration des secrets et services

1. Récupérez le mot de passe administrateur ArgoCD dans les secrets du namespace `argocd`.
2. Reportez ce mot de passe dans les fichiers Terraform : `./terraform/kserve` et `./terraform/monitoring`.
3. Déployez les services finaux :

```bash
make services

```

Enfin, appliquez l'isolation réseau pour sécuriser les services sensibles :

```bash
make networkpolicies

```

---

## Architecture

L'objectif est d'automatiser la mise en place d'un cluster Kubernetes sur 3 VM afin d'exposer l'ensemble des services liés au cycle de vie d'un modèle d'Intelligence Artificielle (LLM).

Pour des raisons de ressources matérielles, nous avons choisi de ne pas déployer l'intégralité de la suite Kubeflow, mais de nous concentrer sur **KServe**, le composant final de la chaîne. KServe permet d'exposer les modèles via des API standardisées.

### Objectifs atteints

* Configuration et durcissement (hardening) de 3 VM.
* Mise en place automatisée d'un cluster K8s (1 nœud par VM).
* Déploiement automatisé des composants d'infrastructure.
* Gestion des services applicatifs via ArgoCD.

---

## Accès et URLs

| Service | URL |
| --- | --- |
| **Authentification** | [https://auth.mz4.re/](https://auth.mz4.re/) |
| **ArgoCD** | [https://argocd.mz4.re/](https://argocd.mz4.re/) |
| **Grafana** | [https://grafana.mz4.re/](https://grafana.mz4.re/) |
| **Teleport** | [https://teleport.mz4.re/](https://teleport.mz4.re/) |

### KSERVE (Inférence)

* **Modèle Iris (Sklearn)** :
* Domaine : `https://iris.kserve.mz4.re`
* Endpoint (V1) : `POST /v1/models/sklearn-iris:predict`


* **Modèle Qwen (HuggingFace)** :
* Domaine : `https://qwen.kserve.mz4.re`
* Endpoint (V2) : `POST /v2/models/qwen-mini/infer`

