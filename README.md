## Projet K8s – Build & Déploiement

Guide rapide pour builder les images, les pousser sur Docker Hub, puis déployer l’environnement complet sur Kubernetes (namespace `chomage`).

### Prérequis
- Docker + accès à Docker Hub (`ffatih/*`)
- `kubectl` configuré sur le cluster cible
- Ingress NGINX installé (voir plus bas pour l’installation)
- Certificats TLS disponibles dans `k8s/https/...`

### Build & push des images
Pattern général :
```bash
docker build -t <image>:1.0 -f <Dockerfile> .
docker tag <image>:1.0 ffatih/<image>:1.0
docker push ffatih/<image>:1.0
```

Commandes prêtes à l’emploi :

```bash
# mssql-linux
docker build -t mssql-linux:1.0 -f /Database/Dockerfile .
docker tag mssql-linux:1.0 ffatih/mssql-linux:1.0
docker push ffatih/mssql-linux:1.0

# applicants.api
docker build -t applicants.api:1.0 -f Services/Applicants.Api/Dockerfile .
docker tag applicants.api:1.0 ffatih/applicants.api:1.0
docker push ffatih/applicants.api:1.0

# identity.api
docker build -t identity.api:1.0 -f Services/Identity.Api/Dockerfile .
docker tag identity.api:1.0 ffatih/identity.api:1.0
docker push ffatih/identity.api:1.0

# jobs.api
docker build -t jobs.api:1.0 -f Services/Jobs.Api/Dockerfile .
docker tag jobs.api:1.0 ffatih/jobs.api:1.0
docker push ffatih/jobs.api:1.0

# web
docker build -t web:1.0 -f Web/Dockerfile .
docker tag web:1.0 ffatih/web:1.0
docker push ffatih/web:1.0
```

### Déploiement Kubernetes
1) Créer le namespace :
```bash
kubectl apply -f k8s\namespace-chomage.yaml
```

2) Services de base :
```bash
kubectl apply -f k8s\sql-server.yaml
kubectl apply -f k8s\redis.yaml
kubectl apply -f k8s\rabbitmq.yaml
```

3) APIs + frontend :
```bash
kubectl apply -f k8s\applicants-api.yaml
kubectl apply -f k8s\identity-api.yaml
kubectl apply -f k8s\jobs-api.yaml
kubectl apply -f k8s\web.yaml
kubectl apply -f k8s\hpa-applicants.yaml
kubectl apply -f k8s\ingress.yaml
```

4) Nettoyer toutes les deployments du namespace :
```bash
kubectl delete deployment --all -n chomage
```

### Ingress & TLS
1) Installer l’Ingress controller NGINX :
```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/cloud/deploy.yaml
```

2) Generation des certificats
```bash
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout web.home.key -out web.home.crt -subj "/CN=web.home/O=home-lab"
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout rabbitmq.home.key -out rabbitmq.home.crt -subj "/CN=rabbitmq.home/O=home-lab"
```
  
3) Créer les secrets TLS :
```bash
kubectl create secret tls web-home-tls --cert=https/web/web.home.crt --key=https/web/web.home.key -n chomage
kubectl create secret tls rabbitmq-home-tls --cert=https/rabbitmq/rabbitmq.home.crt --key=https/rabbitmq/rabbitmq.home.key -n chomage
```

4) Ajout URL dans fichier Hosts :
```bash
127.0.0.1 web.home rabbitmq.home
```

5) URL d'accès :
```bash
https://web.home
https://rabbitmq.home
```

### Scaling pods
1) Lancement stress test

```bash
kubectl run load-tester -n chomage --image=alpine --restart=Never -- /bin/sh -c "apk add --no-cache curl >/dev/null 2>&1; while true; do curl -s http://web >/dev/null; done"
kubectl get hpa -n chomage -w
```

2) Delete stress test

```bash
 kubectl delete pod load-tester -n chomage
```

### Monitoring

Installer Metrics Server
```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

Si le Pod ne tourne pas, modifier le deploiement (nécessaire pour Docker Desktop):

```bash
kubectl edit deployment metrics-server -n kube-system
```
Ajouter en args :

- --kubelet-insecure-tls
- --kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname

Re-démarrez le Pod
Vérifiez que le pod tourne : 
```bash
kubectl get pods -n kube-system | grep metrics-server
```

Tester les métriques :
```bash
kubectl top nodes
kubectl top pods -A
```

### Installer Kube-State-Metrics
```bash
helm install kube-state-metrics prometheus-community/kube-state-metrics -n kube-system
```

Vérifier le fonctionnement :
```bash
kubectl get pods -n kube-system | grep kube-state-metrics
```

Pour vérifier le scrap sans prometheus :
```bash
kubectl port-forward -n kube-system svc/kube-state-metrics 8080:8080
```
Puis lors d'un curl ou navigateur voir : http://localhost:8080/metrics

### Monitoring : Prometheus & Grafana
```bash
kubectl apply -f k8s\monitoring
```

Accès Prometheus : http://localhost:30090/
Accès Grafana :http://localhost:30300/   ( Login: admin / admin )


### Workflow express
- Build + push toutes les images (section ci-dessus)
- `kubectl apply -f k8s\namespace-chomage.yaml`
- Appliquer les manifests des services + APIs + web
- Installer l’ingress NGINX puis créer les secrets TLS
- Vérifier les ingress et les pods : `kubectl get ingress,pods,svc -n chomage`

