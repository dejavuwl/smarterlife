#!/usr/bin/env bash
# 一次性 GCP 基础设施初始化脚本
# 用法：PROJECT_ID=your-project-id bash scripts/setup-gcp.sh
set -euo pipefail

: "${PROJECT_ID:?请设置环境变量 PROJECT_ID，例如：export PROJECT_ID=your-project-id}"
: "${FIREBASE_API_KEY:?请设置环境变量 FIREBASE_API_KEY}"
: "${OPENAI_API_KEY:?请设置环境变量 OPENAI_API_KEY}"

REGION="asia-east1"
SA_NAME="smarterlife-api"
SA_EMAIL="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

echo ">>> 设置默认项目: $PROJECT_ID"
gcloud config set project "$PROJECT_ID"

echo ">>> 启用所需 API"
gcloud services enable \
  run.googleapis.com \
  cloudbuild.googleapis.com \
  artifactregistry.googleapis.com \
  secretmanager.googleapis.com \
  firestore.googleapis.com

echo ">>> 创建 Artifact Registry 仓库"
if ! gcloud artifacts repositories describe smarterlife --location="$REGION" --project="$PROJECT_ID" &>/dev/null; then
  gcloud artifacts repositories create smarterlife \
    --repository-format=docker \
    --location="$REGION" \
    --description="smarterlife-api images" \
    --project="$PROJECT_ID"
else
  echo "仓库已存在，跳过"
fi

echo ">>> 创建服务账号"
if ! gcloud iam service-accounts describe "${SA_EMAIL}" --project="$PROJECT_ID" &>/dev/null; then
  gcloud iam service-accounts create "$SA_NAME" \
    --display-name="smarterlife API Service Account" \
    --project="$PROJECT_ID"
else
  echo "服务账号已存在，跳过"
fi

echo ">>> 授权服务账号权限"
# Firestore 读写
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/datastore.user"

# Secret Manager 读取
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/secretmanager.secretAccessor"

echo ">>> 将密钥写入 Secret Manager"
for SECRET_NAME in FIREBASE_API_KEY OPENAI_API_KEY; do
  SECRET_VALUE="${!SECRET_NAME}"
  if ! gcloud secrets describe "$SECRET_NAME" --project="$PROJECT_ID" &>/dev/null; then
    echo -n "$SECRET_VALUE" | gcloud secrets create "$SECRET_NAME" \
      --data-file=- --project="$PROJECT_ID"
  else
    echo -n "$SECRET_VALUE" | gcloud secrets versions add "$SECRET_NAME" \
      --data-file=- --project="$PROJECT_ID"
    echo "密钥 $SECRET_NAME 已存在，已添加新版本"
  fi
done

echo ">>> 授权 Cloud Build 部署 Cloud Run"
PROJECT_NUMBER=$(gcloud projects describe "$PROJECT_ID" --format="value(projectNumber)")
CB_SA="${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com"
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:${CB_SA}" \
  --role="roles/run.admin"
gcloud iam service-accounts add-iam-policy-binding "${SA_EMAIL}" \
  --member="serviceAccount:${CB_SA}" \
  --role="roles/iam.serviceAccountUser"

echo ">>> 创建 Cloud Build 触发器（监听 master 分支）"
if ! gcloud builds triggers describe smarterlife-api-deploy --project="$PROJECT_ID" &>/dev/null; then
  gcloud builds triggers create github \
    --repo-name=smarterlife \
    --repo-owner=dejavuwl \
    --branch-pattern='^master$' \
    --build-config=cloudbuild.yaml \
    --name=smarterlife-api-deploy \
    --project="$PROJECT_ID"
else
  echo "触发器已存在，跳过"
fi

echo ""
echo "========================================="
echo "✅ 初始化完成！"
echo ""
echo "后续步骤："
echo "  1. 在 GCP Console 完成 GitHub 仓库授权："
echo "     https://console.cloud.google.com/cloud-build/triggers"
echo "  2. 推送到 master 分支即可自动部署"
echo "  3. 首次手动触发：gcloud builds submit --config cloudbuild.yaml --substitutions=COMMIT_SHA=manual"
echo "========================================="
