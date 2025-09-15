name: Destroy Infrastructure

on:
  workflow_dispatch:   # Allows manual trigger from GitHub UI

permissions:
  id-token: write      # Required for OIDC
  contents: read

jobs:
  terraform-destroy:
    runs-on: ubuntu-latest

    concurrency:
      group: terraform-state
      cancel-in-progress: false   # Prevent multiple jobs from colliding

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::897722687643:role/github_actions
          aws-region: us-east-1
          audience: sts.amazonaws.com

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3

      - name: Terraform Init
        run: terraform init -input=false

      - name: Terraform Destroy
        run: terraform destroy -auto-approve -input=false
