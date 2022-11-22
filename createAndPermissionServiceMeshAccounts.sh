# Create Microservice Service Account
#
# Important: Change <PROJECT_ID> to your project (check 'gcloud projects list')
#
PROJECT_ID="[PROJECT_ID]"
IAM_SA_NAME="registration-servicemesh-account"
K8S_NAMESPACE_NAME="default"
K8S_SA_NAME="initsa"

echo $PROJECT_ID
echo $IAM_SA_NAME
echo $K8S_NAMESPACE_NAME
echo $K8S_SA_NAME

# Ensure (the GCP IAM) service account doesn't exist before attempting to create it
#
IAM_SA_EXISTS=$(gcloud iam service-accounts list --filter="${IAM_SA_NAME}" | wc -l)

if [ "$IAM_SA_EXISTS" = "0" ]; then
  # Step 1: Create the GCloud IAM service account
  #
  gcloud iam service-accounts create $IAM_SA_NAME --description="Registration service mesh IAM service account" --display-name="${IAM_SA_NAME}"

  # Step 2: Bind Google Secrets Manager access read policy to this service account
  #
  gcloud secrets add-iam-policy-binding registration-db-username --project $PROJECT_ID --member="serviceAccount:${IAM_SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" --role="roles/secretmanager.secretAccessor"

  # Step 3. Create the Kubernetes (GCloud GKE) service account
  kubectl create sa --namespace $K8S_NAMESPACE_NAME $K8S_SA_NAME

  # Step 4. Enable the K8S service account to impersonate the GCloud IAM service account
  gcloud iam service-accounts add-iam-policy-binding \
     ${IAM_SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com \
     --role roles/iam.workloadIdentityUser \
     --member "serviceAccount:${PROJECT_ID}.svc.id.goog[${K8S_NAMESPACE_NAME}/${K8S_SA_NAME}]"

  # Step 5. Annotate the K8S service account
  kubectl annotate serviceaccount \
     --namespace $K8S_NAMESPACE_NAME $K8S_SA_NAME \
     iam.gke.io/gcp-service-account=${IAM_SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com
fi