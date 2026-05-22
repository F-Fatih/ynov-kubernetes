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

Une stack complète de logging qui collecte, stocke et visualise automatiquement les logs de tous les conteneurs de tous les namespaces de votre cluster Kubernetes.

> **Note** : les logs internes de la stack EFK elle-même (fluentd, elasticsearch, kibana) sont exclus de la collecte pour éviter les boucles de rétroaction.

### Architecture

- **Elasticsearch** : Base de données pour stocker et indexer les logs
- **Fluentd** : Agent de collecte (DaemonSet sur chaque nœud du cluster)
- **Kibana** : Interface web pour visualiser et rechercher les logs

### Comment ça fonctionne ?

1. **Fluentd** tourne sur **chaque nœud** de votre cluster (DaemonSet)
2. Il lit les logs de **tous les conteneurs** dans `/var/log/containers/` (hors stack EFK)
3. Il enrichit chaque log avec les métadonnées Kubernetes (namespace, pod, labels, etc.)
4. Il envoie tout à **Elasticsearch** qui indexe et stocke les logs
5. Vous visualisez tout ça dans **Kibana** avec une interface web puissante

---

## Prérequis

- Cluster Kubernetes fonctionnel (v1.19+)
- `kubectl` configuré et connecté au cluster
- StorageClass disponible pour les PersistentVolumes
- Au moins **8 Go de RAM** disponible sur les nœuds (**16 Go recommandé**)
- Accès aux images Docker publiques (docker.elastic.co, fluent, curlimages)

### Sur Docker Desktop (WSL2)

La RAM est gérée par Windows. Créez ou éditez `C:\Users\<VotreNom>\.wslconfig` :

```ini
[wsl2]
memory=16GB
processors=4
swap=2GB
```

Puis redémarrez WSL2 :

```powershell
wsl --shutdown
```

---

## Installation

```bash
chmod +x deploy.sh
./deploy.sh
```

Le script va :
- ✅ Vérifier les prérequis
- ✅ Déployer tous les composants
- ✅ Attendre qu'Elasticsearch soit prêt
- ✅ Configurer la rétention automatique des logs (ILM)
- ✅ Déployer Kibana et Fluentd
- ✅ Afficher les informations de connexion

**Temps d'installation** : 3 à 5 minutes selon les ressources disponibles.

```bash
# Suivre l'état des pods
kubectl get pods -n logging -w
```

---

## Rétention automatique des logs

La stack configure automatiquement une politique ILM (Index Lifecycle Management) via le Job `06-elasticsearch-setup.yaml` :

| Règle | Valeur |
|---|---|
| Suppression automatique | après **2 jours** |
| Rollover (nouvel index) | à **500 MB** ou **1 jour** |
| Réplication | 0 (single-node) |
| Refresh interval | 30s |

Pour vérifier la politique en place :

```bash
kubectl exec -n logging elasticsearch-0 -- \
  curl -s "http://localhost:9200/_cat/indices/logstash-*?v&h=index,docs.count,store.size,ilm.policy"
```

---

## Vérifier la collecte des logs

```bash
kubectl exec -n logging elasticsearch-0 -- \
  curl -s "http://localhost:9200/_cat/indices?v" | grep logstash
```

### Vérifier les namespaces collectés

```bash
kubectl exec -n logging elasticsearch-0 -- curl -s -X GET \
  "http://localhost:9200/logstash-*/_search?size=0&pretty" \
  -H 'Content-Type: application/json' \
  -d '{
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

---

## Accéder à Kibana

### Via Port-Forward (recommandé pour les tests locaux)

```bash
kubectl port-forward -n logging svc/kibana 5601:5601
```

Puis ouvrez : **http://localhost:5601**

---

## Configuration initiale de Kibana

### Première connexion (à faire UNE SEULE FOIS)

1. Ouvrez Kibana dans votre navigateur
2. Menu en haut à gauche → **Management** → **Stack Management**
3. Section "Kibana" → **Index Patterns** (ou **Data Views**)
4. Cliquez sur **Create index pattern** / **Create data view**

### Créer l'Index Pattern

1. **Index pattern name** : `logstash-*`
   - Format des index : `logstash-2026.05.22`, `logstash-2026.05.23`, etc.
2. Cliquez sur **Next step**
3. **Time field** : sélectionnez `@timestamp`
4. Cliquez sur **Create index pattern**

---

## Utiliser Kibana pour consulter les logs

### Colonnes recommandées dans Discover

Par défaut Kibana affiche seulement `@timestamp`. Dans **Available fields**, ajoutez :

- `kubernetes.namespace_name` → Namespace
- `kubernetes.pod_name` → Nom du pod
- `kubernetes.container_name` → Nom du conteneur
- `kubernetes.labels.app` → Label application
- `log` → Contenu du message
- `stream` → stdout ou stderr

### Recherches KQL utiles

```
# Par namespace
kubernetes.namespace_name: "production"

# Par application
kubernetes.labels.app: "mon-app"

# Par pod
kubernetes.pod_name: "mon-pod-*"

# Erreurs uniquement
log: *error* OR log: *ERROR* OR log: *failed*

# Combiner
kubernetes.namespace_name: "production" AND log: *error*

# Exclure kube-system
NOT kubernetes.namespace_name: "kube-system"

# Logs stderr
kubernetes.namespace_name: "production" AND stream: "stderr"
```

### Exemples pratiques

```
# Suivre une appli spécifique
kubernetes.labels.app: "rabbitmq"

# Débugger après un déploiement
kubernetes.pod_name: "mon-app-v2-*" AND (log: *error* OR log: *fatal*)

# Surveiller les connexions
log: *connection* OR log: *connected* OR log: *disconnected*
```

---

## Ressources et documentation

- [Documentation Elasticsearch](https://www.elastic.co/guide/en/elasticsearch/reference/current/index.html)
- [Documentation Fluentd](https://docs.fluentd.org/)
- [Documentation Kibana](https://www.elastic.co/guide/en/kibana/current/index.html)
- [Kubernetes Logging](https://kubernetes.io/docs/concepts/cluster-administration/logging/)

---

## Fichiers inclus

| Fichier | Rôle |
|---|---|
| `00-namespace.yaml` | Namespace `logging` |
| `01-elasticsearch.yaml` | Elasticsearch StatefulSet + Service |
| `02-kibana.yaml` | Kibana Deployment + Service (limite : 1536Mi) |
| `03-fluentd-rbac.yaml` | RBAC pour Fluentd (cluster-wide) |
| `04-fluentd-configmap.yaml` | Configuration Fluentd (exclude_path, timezone) |
| `05-fluentd-daemonset.yaml` | Fluentd DaemonSet (limite CPU : 500m) |
| `06-elasticsearch-setup.yaml` | Job ILM — rétention automatique des index |
| `deploy.sh` | Script de déploiement automatique |
| `uninstall.sh` | Script de désinstallation |
| `README-LOGGING.MD` | Ce fichier |

## Commandes utiles

```bash
# État de la stack
kubectl get pods -n logging
kubectl get all -n logging

# Logs de chaque composant
kubectl logs -n logging -l app=elasticsearch
kubectl logs -n logging -l app=kibana
kubectl logs -n logging -l app=fluentd --tail=50

# Consommation ressources
kubectl top pods -n logging

# Vérifier les index et leur taille
kubectl exec -n logging elasticsearch-0 -- \
  curl -s "http://localhost:9200/_cat/indices/logstash-*?v&h=index,docs.count,store.size,ilm.policy"

# Port-forward vers Kibana
kubectl port-forward -n logging svc/kibana 5601:5601

# Santé Elasticsearch
kubectl exec -n logging elasticsearch-0 -- \
  curl -s "http://localhost:9200/_cluster/health?pretty"
```
