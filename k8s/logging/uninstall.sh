#!/bin/bash

set -e

echo ""
echo ""
echo ""
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
echo "Désinstallation de la stack EFK"
echo "==================================================="
echo ""

RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}  Cette opération va supprimer :${NC}"
echo "   - Tous les pods de logging"
echo "   - Les données Elasticsearch (logs)"
echo "   - Le namespace 'logging'"
echo ""

read -p "Êtes-vous sûr de vouloir continuer ? (oui/non) : " CONFIRMATION

if [ "$CONFIRMATION" != "oui" ]; then
    echo "Opération annulée."
    exit 0
fi

echo ""
echo "🗑️  Suppression des ressources..."

kubectl delete -f 05-fluentd-daemonset.yaml --ignore-not-found=true
kubectl delete -f 04-fluentd-configmap.yaml --ignore-not-found=true
kubectl delete -f 03-fluentd-rbac.yaml --ignore-not-found=true
kubectl delete -f 02-kibana.yaml --ignore-not-found=true
kubectl delete -f 01-elasticsearch.yaml --ignore-not-found=true

echo ""
echo " Attente de la suppression des pods..."
sleep 5

echo ""
echo " Suppression du namespace..."
kubectl delete -f 00-namespace.yaml --ignore-not-found=true

echo ""
echo "Attente de la suppression complète du namespace..."
kubectl wait --for=delete namespace/logging --timeout=60s 2>/dev/null || true

echo ""
echo -e "${YELLOW} Note : Les PersistentVolumes peuvent persister selon votre StorageClass${NC}"
echo ""
echo "Pour vérifier et supprimer manuellement si nécessaire :"
echo "   kubectl get pv | grep logging"
echo "   kubectl delete pv <nom-du-pv>"
echo ""

echo "Désinstallation terminée"
