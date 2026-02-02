#!/bin/bash

set -e

echo ""
echo "          $$$$$$\  $$\  $$$$$$\            "
echo "         $$ ___$$\ $$ |$$$ __$$\           "
echo "$$$$$$$$\\_/   $$ |$$ |$$$$\ $$ | $$$$$$$\ "
echo "\____$$  | $$$$$ / $$ |$$\$$\$$ |$$  _____|"
echo "  $$$$ _/  \___$$\ $$ |$$ \$$$$ |\$$$$$$\  "
echo " $$  _/  $$\   $$ |$$ |$$ |\$$$ | \____$$\ "
echo "$$$$$$$$\\$$$$$$  |$$ |\$$$$$$  /$$$$$$$  |"
echo "\________|\______/ \__| \______/ \_______/"
echo ""
echo "==================================================="
echo "Déploiement de la stack EFK sur Kubernetes"
echo "==================================================="
echo ""

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Vérifier que kubectl est installé
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}❌ kubectl n'est pas installé${NC}"
    exit 1
fi

# Vérifier la connexion au cluster
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}❌ Impossible de se connecter au cluster Kubernetes${NC}"
    exit 1
fi

echo -e "${GREEN}✓${NC} Connecté au cluster Kubernetes"
echo ""

# Créer le namespace
echo "📦 Création du namespace 'logging'..."
kubectl apply -f 00-namespace.yaml

echo ""
echo "🔍 Déploiement d'Elasticsearch..."
kubectl apply -f 01-elasticsearch.yaml

echo ""
echo "📊 Déploiement de Kibana..."
kubectl apply -f 02-kibana.yaml

echo ""
echo "🔐 Configuration RBAC pour Fluentd..."
kubectl apply -f 03-fluentd-rbac.yaml

echo ""
echo "⚙️  Configuration de Fluentd..."
kubectl apply -f 04-fluentd-configmap.yaml

echo ""
echo "📝 Déploiement de Fluentd (DaemonSet)..."
kubectl apply -f 05-fluentd-daemonset.yaml

echo ""
echo "==================================================="
echo -e "${YELLOW}Attente du démarrage des composants...${NC}"
echo "==================================================="
echo ""

# Attendre Elasticsearch
echo "⏳ Attente d'Elasticsearch (peut prendre 2-3 minutes)..."
kubectl wait --for=condition=ready pod -l app=elasticsearch -n logging --timeout=300s || {
    echo -e "${RED}❌ Elasticsearch n'a pas démarré correctement${NC}"
    echo "Logs Elasticsearch :"
    kubectl logs -n logging -l app=elasticsearch --tail=50
    exit 1
}
echo -e "${GREEN}✓${NC} Elasticsearch est prêt"

# Attendre Kibana
echo ""
echo "⏳ Attente de Kibana..."
kubectl wait --for=condition=ready pod -l app=kibana -n logging --timeout=300s || {
    echo -e "${RED}❌ Kibana n'a pas démarré correctement${NC}"
    echo "Logs Kibana :"
    kubectl logs -n logging -l app=kibana --tail=50
    exit 1
}
echo -e "${GREEN}✓${NC} Kibana est prêt"

# Vérifier Fluentd
echo ""
echo "⏳ Vérification de Fluentd..."
sleep 10
FLUENTD_READY=$(kubectl get daemonset -n logging fluentd -o jsonpath='{.status.numberReady}')
FLUENTD_DESIRED=$(kubectl get daemonset -n logging fluentd -o jsonpath='{.status.desiredNumberScheduled}')

if [ "$FLUENTD_READY" -eq "$FLUENTD_DESIRED" ]; then
    echo -e "${GREEN}✓${NC} Fluentd est déployé sur $FLUENTD_READY/$FLUENTD_DESIRED nœuds"
else
    echo -e "${YELLOW}⚠${NC}  Fluentd : $FLUENTD_READY/$FLUENTD_DESIRED nœuds prêts"
    echo "   (les pods Fluentd peuvent prendre quelques secondes supplémentaires)"
fi

echo ""
echo "==================================================="
echo -e "${GREEN}✅ Déploiement terminé avec succès !${NC}"
echo "==================================================="
echo ""

# Afficher les informations de connexion
echo "📋 Informations de connexion :"
echo ""
echo "Pour accéder à Kibana, utilisez l'une des méthodes suivantes :"
echo ""

# Vérifier si un LoadBalancer est disponible
LB_IP=$(kubectl get svc kibana -n logging -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
LB_HOSTNAME=$(kubectl get svc kibana -n logging -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")

if [ -n "$LB_IP" ]; then
    echo -e "${GREEN}1. LoadBalancer :${NC}"
    echo "   http://$LB_IP:5601"
    echo ""
elif [ -n "$LB_HOSTNAME" ]; then
    echo -e "${GREEN}1. LoadBalancer :${NC}"
    echo "   http://$LB_HOSTNAME:5601"
    echo ""
else
    echo -e "${YELLOW}1. LoadBalancer : Non disponible${NC}"
    echo ""
fi

echo -e "${GREEN}2. Port-Forward :${NC}"
echo "   kubectl port-forward -n logging svc/kibana 5601:5601"
echo "   Puis accédez à http://localhost:5601"
echo ""

echo "📝 Prochaines étapes dans Kibana :"
echo ""
echo "   1. Allez dans Management → Stack Management → Index Patterns"
echo "   2. Créez un index pattern avec : logstash-*"
echo "   3. Sélectionnez @timestamp comme champ de temps"
echo "   4. Allez dans Discover pour voir vos logs"
echo ""

echo "🔍 Commandes utiles :"
echo ""
echo "   # Voir tous les pods de logging"
echo "   kubectl get pods -n logging"
echo ""
echo "   # Voir les logs Fluentd"
echo "   kubectl logs -n logging -l app=fluentd --tail=50"
echo ""
echo "   # Vérifier l'état d'Elasticsearch"
echo "   kubectl exec -n logging elasticsearch-0 -- curl -s http://localhost:9200/_cluster/health?pretty"
echo ""
echo "   # Voir les index créés"
echo "   kubectl exec -n logging elasticsearch-0 -- curl -s http://localhost:9200/_cat/indices?v"
echo ""

echo "📚 Consultez le README.md pour plus d'informations"
echo ""