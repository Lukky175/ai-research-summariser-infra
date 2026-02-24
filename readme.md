Instead of manual SSH we will use aws session manager

Current:- Added AWS Login Step In Pipeline

terraform fmt -check (Checks Format)

pipeline is enforcing terraform fmt -check -recursive

logs /var/log/cloud-init-output.log (In EC-2)

$ sudo cat /var/log/user-data-debug.log to see logs

To see which port:-
kubectl get svc argocd-server -n argocd  


To Get argo cd password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d && echo


  Future - Make environment/prod
  make tfvars for prod
  make pipeline work for dev/prod

  make a dev branch and a main branch
  dev branch = dev changes/ dev pipeline runs
  stage step (Will plan something)
  main branch p merge = will run pipeline for prod.

  Add remote backend(Amazon s3)