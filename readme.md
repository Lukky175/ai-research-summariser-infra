Instead of manual SSH we will use aws session manager

Current:- Changed User_Data Script Now Instead Of Range Of Port ArgoCD Is On Port 30080

Now Terraform Gives Public IP of EC2 & Exact ArgoCD URL



logs /var/log/cloud-init-output.log (In EC-2)

$ sudo cat /var/log/user-data-debug.log to see logs

To see which port:-
kubectl get svc argocd-server -n argocd  


To Get argo cd password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d && echo