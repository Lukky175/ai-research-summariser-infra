Current:-  
1. Disabled public SSH rule from Security groupa since we use AWS SSM Session Manager.
2. Removed ArgoCD Port (WillUse NGINX Ingress.)
3. Major Updates in User Data Script.
4. Since Using k3s Traefik is enabled as default ingress controller so  Disabled Traefik (Will use NGINX Ingress controller)
5. Added Cert Manager
6. Installed Monitoring stack (Prometheus+Grafana)

<!-- To see which port:- (30080) -->
kubectl get svc argocd-server -n argocd  


To Check Logs of userdata Script
sudo cat /var/log/user-data-debug.log

<!-- % To Get argo cd password -->
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d && echo

<!-- To Check Grafana Password -->
kubectl get secret monitoring-grafana -n monitoring -o jsonpath="{.data.admin-password}" | base64 --decode


<!-- Future -  -->
1. Make environment/prod
   make tfvars for prod
   make pipeline work for dev/prod

   make a dev branch and a main branch
   dev branch = dev changes/ dev pipeline runs
   stage step (Will plan something)
   main branch p merge = will run pipeline for prod.

2. Add remote backend(Amazon s3)

3. Use NGINX Ingress to expose argocd, so that we will also be able to use certbot for ssl tls certificates










<!-- Pipeline checks format -->
terraform fmt -check (Checks Format)

pipeline is enforcing terraform fmt -check -recursive

logs /var/log/cloud-init-output.log (In EC-2)

$ sudo cat /var/log/user-data-debug.log to see logs