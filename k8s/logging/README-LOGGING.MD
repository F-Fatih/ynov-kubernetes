# Stack EFK (Elasticsearch, Fluentd, Kibana) pour Kubernetes

```
          $$$$$$\  $$\  $$$$$$\            
         $$ ___$$\ $$ |$$$ __$$\           
$$$$$$$$\\_/   $$ |$$ |$$$$\ $$ | $$$$$$$\ 
\____$$  | $$$$$ / $$ |$$\$$\$$ |$$  _____|
  $$$$ _/  \___$$\ $$ |$$ \$$$$ |\$$$$$$\  
 $$  _/  $$\   $$ |$$ |$$ |\$$$ | \____$$\ 
$$$$$$$$\\$$$$$$  |$$ |\$$$$$$  /$$$$$$$  |
\________|\______/ \__| \______/ \_______/
```

## Qu'est-ce que c'est ?

Une stack complète de logging qui collecte, stocke et visualise **automatiquement** les logs de **TOUS les conteneurs** de **TOUS les namespaces** de votre cluster Kubernetes.

### Architecture

- **Elasticsearch** : Base de données pour stocker et indexer les logs
- **Fluentd** : Agent de collecte (DaemonSet sur chaque nœud du cluster)
- **Kibana** : Interface web pour visualiser et rechercher les logs

### Comment ça fonctionne ?

1. **Fluentd** tourne sur **chaque nœud** de votre cluster (DaemonSet)
2. Il lit les logs de **tous les conteneurs** dans `/var/log/containers/`
3. Il enrichit chaque log avec les métadonnées Kubernetes (namespace, pod, labels, etc.)
4. Il envoie tout à **Elasticsearch** qui indexe et stocke les logs
5. Vous visualisez tout ça dans **Kibana** avec une interface web puissante

## Prérequis

- Cluster Kubernetes fonctionnel (v1.19+)
- `kubectl` configuré et connecté au cluster
- StorageClass disponible pour les PersistentVolumes
- Au moins **4 Go de RAM** disponible sur les nœuds
- Accès aux images Docker publiques (docker.elastic.co, fluent)

## Installation

```bash
# Rendre le script exécutable
chmod +x deploy.sh

# Lancer l'installation
./deploy.sh
```

Le script va :
- ✅ Vérifier les prérequis
- ✅ Déployer tous les composants
- ✅ Attendre que tout soit prêt
- ✅ Afficher les informations de connexion

**Temps d'installation** : variable

```bash
# Voir tous les pods
kubectl get pods -n logging
```

### Vérifier la collecte des logs

```bash
kubectl exec -n logging elasticsearch-0 -- curl -s "http://localhost:9200/_cat/indices?v" | grep logstash
```

### Vérifier les namespaces collectés

```bash
kubectl exec -n logging elasticsearch-0 -- curl -s -X GET "http://localhost:9200/logstash-*/_search?size=0&pretty" -H 'Content-Type: application/json' -d'
{
  "aggs": {
    "namespaces": {
      "terms": {
        "field": "kubernetes.namespace_name.keyword",
        "size": 50
      }
    }
  }
}'
```

## 🌐 Accéder à Kibana

Une fois le déploiement terminé, vous devez accéder à l'interface Kibana.

### Via Port-Forward (recommandé pour les tests locaux)

```bash
# Créer un tunnel vers Kibana
kubectl port-forward -n logging svc/kibana 5601:5601
```

Puis ouvrez votre navigateur : **http://localhost:5601**


## Configuration initiale de Kibana

### Première connexion (à faire UNE SEULE FOIS)

1. **Ouvrez Kibana** dans votre navigateur
2. Cliquez sur le menu en haut à gauche
3. Allez dans **Management** → **Stack Management**
4. Dans la section "Kibana", cliquez sur **Index Patterns** (ou **Data Views**)
5. Cliquez sur **Create index pattern** / **Create data view**

### Créer l'Index Pattern

1. **Index pattern name** : `logstash-*`
   - L'astérisque `*` permet de capturer tous les index (un par jour)
   - Format : `logstash-2026.02.02`, `logstash-2026.02.03`, etc.

2. Cliquez sur **Next step**

3. **Time field** : Sélectionnez `@timestamp`

4. Cliquez sur **Create index pattern**

**C'est fait !** plus besoin de refaire cette étape.

## Utiliser Kibana pour consulter les logs

### Accéder à l'interface Discover

1. Menu → **Discover**
2. Vous voyez maintenant **TOUS les logs de TOUS vos conteneurs !**

### Ajouter des colonnes utiles

Par défaut, Kibana affiche seulement `@timestamp`. Ajoutez des colonnes pour mieux voir vos logs :

1. À gauche, dans **Available fields**, cherchez ces champs :
2. Cliquez sur le **+** à côté de chaque champ pour l'ajouter comme colonne :
   - `kubernetes.namespace_name` → Namespace
   - `kubernetes.pod_name` → Nom du pod
   - `kubernetes.container_name` → Nom du conteneur
   - `kubernetes.labels.app` → Label application
   - `log` → **Le contenu du log (message)**
   - `stream` → stdout ou stderr

## Filtrer et rechercher les logs

### Recherche par namespace

Dans la barre de recherche en haut :

```
kubernetes.namespace_name: "xxxx"
```

### Recherche par application

```
kubernetes.labels.app: "xxxx"
```

### Recherche par pod spécifique

```
kubernetes.pod_name: "xxxx"
```

### Recherche dans le contenu des logs

```
# Logs contenant "error" (insensible à la casse)
log: *error*

# Logs contenant "ERROR" (sensible à la casse)
log: *ERROR*

# Logs contenant une phrase exacte
log: *"connection refused"*
```

### Combiner plusieurs filtres

```
# Erreurs dans le namespace production
kubernetes.namespace_name: "production" AND log: *error*

# Logs d'une app spécifique sans le namespace kube-system
kubernetes.labels.app: "nginx" AND NOT kubernetes.namespace_name: "kube-system"

# Logs stderr (erreurs) d'un namespace
kubernetes.namespace_name: "production" AND stream: "stderr"
```

### Exclure des namespaces

```
# Tout sauf kube-system
NOT kubernetes.namespace_name: "kube-system"

# Exclure plusieurs namespaces
NOT kubernetes.namespace_name: ("kube-system" OR "kube-public" OR "logging")
```

## 📊 Exemples pratiques

### Voir les logs d'une application spécifique

```bash
kubernetes.labels.app: "rabbitmq"
```

### Débugger une erreur

```bash
log: *error* OR log: *ERROR* OR log: *failed*
kubernetes.namespace_name: "production" AND (log: *error* OR log: *ERROR*)
```

### Suivre les connexions

```bash
log: *connection* OR log: *connected* OR log: *disconnected*
log: *auth* OR log: *login* OR log: *logout*
```

### Monitorer un déploiement

Après un déploiement, surveillez :

```bash
kubernetes.pod_name: "mon-app-v2-*"
kubernetes.pod_name: "mon-app-v2-*" AND (log: *error* OR log: *fatal*)
```

## Ressources et documentation

- [Documentation Elasticsearch](https://www.elastic.co/guide/en/elasticsearch/reference/current/index.html)
- [Documentation Fluentd](https://docs.fluentd.org/)
- [Documentation Kibana](https://www.elastic.co/guide/en/kibana/current/index.html)
- [Kubernetes Logging](https://kubernetes.io/docs/concepts/cluster-administration/logging/)

## Support et aide

### Fichiers inclus dans ce projet

- `00-namespace.yaml` - Namespace "logging"
- `01-elasticsearch.yaml` - Elasticsearch StatefulSet + Service
- `02-kibana.yaml` - Kibana Deployment + Service
- `03-fluentd-rbac.yaml` - RBAC pour Fluentd (cluster-wide)
- `04-fluentd-configmap.yaml` - Configuration Fluentd
- `05-fluentd-daemonset.yaml` - Fluentd DaemonSet
- `deploy.sh` - Script de déploiement automatique
- `uninstall.sh` - Script de désinstallation
- `README-LOGGING.md` - Ce fichier

### Commandes utiles

```bash
# Voir tous les pods de logging
kubectl get pods -n logging

# Logs de chaque composant
kubectl logs -n logging -l app=elasticsearch
kubectl logs -n logging -l app=kibana
kubectl logs -n logging -l app=fluentd --tail=50

# État du cluster
kubectl get all -n logging

# Vérifier les index Elasticsearch
kubectl exec -n logging elasticsearch-0 -- curl -s "http://localhost:9200/_cat/indices?v"

# Port-forward vers Kibana
kubectl port-forward -n logging svc/kibana 5601:5601

# Supprimer un vieux index
kubectl exec -n logging elasticsearch-0 -- curl -X DELETE "http://localhost:9200/logstash-2026.01.01"
```
