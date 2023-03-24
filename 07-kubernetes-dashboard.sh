# Install the Kubernetes dashboard by running the following kubectl command.


kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.6.1/aio/deploy/recommended.yaml

# Run the following kubectl command to verify that all resources have been installed successfully.

kubectl get all -n kubernetes-dashboard