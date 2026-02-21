Instead of manual SSH we will use aws session manager

Current:- Fixed Scoping Error For Output Of Argo CD Was Calling Module Inside a Module



logs /var/log/cloud-init-output.log (In EC-2)

$ sudo cat /var/log/user-data-debug.log to see logs

To see which port:-
kubectl get svc argocd-server -n argocd  


To Get argo cd password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d && echo