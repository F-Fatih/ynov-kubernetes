Stack EFK (Elasticsearch, Fluentd, Kibana) pour Kubernetes
Cette stack complète permet de collecter, stocker et visualiser les logs de tous les conteneurs de tous les namespaces de votre cluster Kubernetes.
Architecture

Elasticsearch : Stockage et indexation des logs
Fluentd : Collecte des logs de tous les pods (DaemonSet sur chaque nœud)
Kibana : Interface de visualisation et recherche des logs

Prérequis

Cluster Kubernetes fonctionnel (1.19+)
kubectl configuré
StorageClass disponible pour les PersistentVolumes
Au moins 4 Go de RAM disponible sur les nœuds

Déploiement
1. Déployer tous les composants
bashkubectl apply -f 00-namespace.yaml
kubectl apply -f 01-elasticsearch.yaml
kubectl apply -f 02-kibana.yaml
kubectl apply -f 03-fluentd-rbac.yaml
kubectl apply -f 04-fluentd-configmap.yaml
kubectl apply -f 05-fluentd-daemonset.yaml
Ou en une seule commande :
bashkubectl apply -f .
2. Vérifier le déploiement
bash# Vérifier le namespace
kubectl get all -n logging

# Vérifier que Elasticsearch est prêt
kubectl wait --for=condition=ready pod -l app=elasticsearch -n logging --timeout=300s

# Vérifier que Kibana est prêt
kubectl wait --for=condition=ready pod -l app=kibana -n logging --timeout=300s

# Vérifier que Fluentd tourne sur tous les nœuds
kubectl get daemonset -n logging
3. Accéder à Kibana
Option 1 : Via LoadBalancer (si disponible)
bashkubectl get svc kibana -n logging
Récupérez l'IP externe et accédez à http://EXTERNAL-IP:5601
Option 2 : Via Port-Forward
bashkubectl port-forward -n logging svc/kibana 5601:5601
Puis accédez à http://localhost:5601
Option 3 : Via Ingress (à créer séparément)
Créez un Ingress pour exposer Kibana selon votre configuration.
Configuration de Kibana
Première connexion

Accédez à Kibana
Allez dans Management → Stack Management → Index Patterns
Créez un index pattern :

Index pattern : logstash-*
Time field : @timestamp
Cliquez sur Create index pattern



Visualiser les logs

Allez dans Discover
Sélectionnez l'index pattern logstash-*
Vous verrez tous les logs de tous les conteneurs de tous les namespaces

Filtres utiles
Dans Kibana Discover, utilisez KQL (Kibana Query Language) :
# Logs d'un namespace spécifique
kubernetes.namespace_name: "default"

# Logs d'un pod spécifique
kubernetes.pod_name: "mon-pod-123"

# Logs d'une application spécifique
kubernetes.labels.app: "nginx"

# Logs avec un niveau ERROR
log: *ERROR*

# Combiner plusieurs filtres
kubernetes.namespace_name: "production" AND log: *error*
Personnalisation
Changer le stockage Elasticsearch
Dans 01-elasticsearch.yaml, modifiez la section volumeClaimTemplates :
yamlstorage: 10Gi  # Changez selon vos besoins
Changer le préfixe des index
Dans 04-fluentd-configmap.yaml, modifiez :
yaml- name: FLUENT_ELASTICSEARCH_LOGSTASH_PREFIX
  value: "logstash"  # Changez en "mon-prefix" par exemple
Ajuster les ressources
Modifiez les sections resources dans chaque fichier selon vos besoins :

Elasticsearch : 01-elasticsearch.yaml
Kibana : 02-kibana.yaml
Fluentd : 05-fluentd-daemonset.yaml

Filtrer certains namespaces
Dans 04-fluentd-configmap.yaml, ajoutez un filtre avant le match elasticsearch :
xml<filter kubernetes.**>
  @type grep
  <exclude>
    key $.kubernetes.namespace_name
    pattern /^(kube-system|kube-public)$/
  </exclude>
</filter>
Monitoring
Vérifier l'état d'Elasticsearch
bashkubectl exec -n logging elasticsearch-0 -- curl -s http://localhost:9200/_cluster/health?pretty
Vérifier les logs Fluentd
bashkubectl logs -n logging -l app=fluentd --tail=50
Vérifier les index créés
bashkubectl exec -n logging elasticsearch-0 -- curl -s http://localhost:9200/_cat/indices?v
Dépannage
Elasticsearch ne démarre pas
bash# Vérifier les logs
kubectl logs -n logging elasticsearch-0

# Problèmes courants :
# - vm.max_map_count trop bas : les initContainers devraient le corriger
# - Pas assez de mémoire : ajustez les limites de ressources
Fluentd ne collecte pas les logs
bash# Vérifier les logs Fluentd
kubectl logs -n logging -l app=fluentd

# Vérifier les permissions RBAC
kubectl get clusterrolebinding fluentd

# Vérifier que les volumes sont bien montés
kubectl describe pod -n logging -l app=fluentd
Pas de données dans Kibana

Vérifiez que l'index pattern est créé : logstash-*
Vérifiez que des index existent dans Elasticsearch
Vérifiez la plage de temps sélectionnée dans Kibana (en haut à droite)
Générez des logs de test :

bashkubectl run test-logger --image=busybox --restart=Never -- sh -c "while true; do echo 'Test log entry'; sleep 1; done"
Maintenance
Rotation des index
Elasticsearch créera automatiquement un nouvel index chaque jour (format : logstash-YYYY.MM.DD).
Pour supprimer les anciens index :
bash# Lister les index
kubectl exec -n logging elasticsearch-0 -- curl -s http://localhost:9200/_cat/indices

# Supprimer un index spécifique
kubectl exec -n logging elasticsearch-0 -- curl -X DELETE http://localhost:9200/logstash-2024.01.01
Backup
Pour sauvegarder les données Elasticsearch, sauvegardez le PersistentVolume associé.
Désinstallation
bashkubectl delete -f .
kubectl delete namespace logging
Sécurité
⚠️ Important : Cette configuration désactive la sécurité Elasticsearch pour simplifier le déploiement. Pour la production :

Activez l'authentification Elasticsearch (xpack.security)
Configurez TLS/SSL
Utilisez des secrets Kubernetes pour les mots de passe
Restreignez l'accès réseau avec NetworkPolicies
Utilisez un Ingress avec authentification pour Kibana

Support
Pour plus d'informations :

Documentation Elasticsearch
Documentation Fluentd
Documentation Kibana