# AWS-Ephemeral-CI/CD-Infrastructure-with-Terraform-Ansible-GitHub-Actions

## Overview

This project demonstrates the core idea of using Terraform and Ansible in a pipeline workflow. Every push to the main branch triggers the pipeline to test the developer's code; in our scenario, it is an index.html file. Terraform is triggered, then confirms with its portal about the state file statuses, and it decides after that to deploy or destroy. The authentication of HCP cloud and AWS is with OpenID Connect for short-lived credentials assumed by Terraform. After provisioning, the Ansible role comes and the public ip passed by the pipeline to generate a dynamic `inventory.ini` file, and then ansible run the `playbook.yaml` and configure the ec2 by downloading nginx, and then copies the index file to the default path of nginx. After that, a validation was performed to ensure that everything works correctly. Last job is a TTL count for 2 hours or any time you predict your test will finish, after this TTL, a destroy job starts. This demonstrates that every tool has its own role and job. Terraform is responsible for provisioning infrastructure; on the other hand, Ansible is about infrastructure configuration management while the pipeline is the deamon that drive all this workflow in automated way.

## Workflow Diagram

<img width="1101" height="619" alt="Untitled Diagram drawio" src="https://github.com/user-attachments/assets/dec1ef1f-728f-47fc-8bf1-2fa2eb1b498c" />


## Objective of the Task

- Expalin and simulate the terrafrom concept
- Expalin and simulate the ansible concept
- Automated workflow, by github actions
- Storing the state file remotely for collobration
- Use short-lived credentails instead of long-lived credentials

## What Was Implemented so far

#### Created identity provider
>
>

<img width="1552" height="761" alt="1" src="https://github.com/user-attachments/assets/08c26ea7-a85b-4bed-b61e-81acec17a367" />

#### Created role
>
>
<img width="1546" height="131" alt="2" src="https://github.com/user-attachments/assets/286a8a8f-711e-450e-b058-cfd9b9aee88c" />

#### Stroing the backend in HCP
- Created Organization
- Created Workspace
- Generated token for github
- Map the aws authentication with HCP
>
>
  
  <img width="1467" height="497" alt="3" src="https://github.com/user-attachments/assets/d05f1923-1d21-47a2-b5a5-8cd00420c58c" />


#### Storing the github token and other vars
>
>

<img width="1078" height="377" alt="4" src="https://github.com/user-attachments/assets/cc4e6cee-e631-4b4a-80e6-7c4e8755c0f8" />

#### File structure 
>
>

<img width="382" height="616" alt="5" src="https://github.com/user-attachments/assets/85f47534-944a-4d93-a401-c0893418c007" />

#### Terrafrom configuration

- main.tf
  
  ```bash
  
  provider "aws" {  
  }
    ```

- variables.tf
  ```bash
  variable "region" {
  description = "AWS region"
  }


  variable "key_name" {
  type = string
  }

  variable "public_key" {
  type = string
  }



  variable "instance_type" {
  default = "t3.micro"
  }



  variable "ami_id" {
  description = "The AMI ID for the NGINX server"
  default     = "ami-068c0051b15cdb816" 
  }  


  variable "env" {
  description = "Deployment environment"
  type        = string
  }
    ```

- auth.tf
  
  ```bash
  resource "aws_key_pair" "ci_key" {
  key_name   = var.key_name
  public_key = var.public_key

  }
    ```

- ec2.tf
  
  ```bash
  resource "aws_instance" "web" {
  ami = var.ami_id
  instance_type = var.instance_type
  key_name = var.key_name
  vpc_security_group_ids = [aws_security_group.web_sg.id]

  tags = {
    Name = "ci_ephemeral_web"

  associate_public_ip_address = true  
  }

  }
    ```

- sg.tf

  ```bash
  resource "aws_security_group" "web_sg" {

  name        = "public-ec2-sg"

  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }


  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }


  egress {
    from_port = 0
    to_port = 0
    protocol = -1
    cidr_blocks = ["0.0.0.0/0"]
  }
 

  }
    ```

- output.tf

  ```bash
  output "public_ip" {
    value = aws_instance.web.public_ip
  

  }
    ```

#### Ansible Configuration

- playbook.yml
  
  ```bash
  - hosts: web
  become: true
  tasks:
    - name: Install nginx
      yum:
        name: nginx
        state: present
        update_cache: yes

    - name: Copy web content
      copy:
        src: index.html
        dest: /usr/share/nginx/html
        mode: '0644'

    - name: Start nginx
      service:
        name: nginx
        state: started
        enabled: true
  ```

  #### Github Action logic

  ```bash

  name: Ephemeral Infra CI/CD (Terraform Cloud + Ansible)

  on:
    push:
      branches:
        - main

  env:
    TF_CLOUD_ORG: aws_pipelines
    TF_WORKSPACE: aws_dev
    TF_VAR_region: ${{ secrets.AWS_REGION }}
    TF_VAR_key_name: ${{ secrets.KEY_NAME }}
  
  jobs:
    # --------------------------------------------------
    # JOB 1: Terraform Init
    # --------------------------------------------------
    terraform_init:
      runs-on: ubuntu-latest

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3

      - name: Authenticate to Terraform Cloud
        run: |
          echo 'credentials "app.terraform.io" {
            token = "${{ secrets.TF_API_TOKEN }}"
          }' > ~/.terraformrc

      - name: Terraform Init
        run: |
          cd terraform
          terraform init


  # --------------------------------------------------
  # JOB 2: Terraform Plan
  # --------------------------------------------------
  terraform_plan:
    needs: terraform_init
    runs-on: ubuntu-latest

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Create SSH key files
        run: |
          echo "${{ secrets.SSH_PRIVATE_KEY }}" > key.pem
          chmod 600 key.pem
          ssh-keygen -y -f key.pem > key.pem.pub

      
      - name: Export public key to Terraform
        run: |
          echo "TF_VAR_public_key=$(cat key.pem.pub)" >> $GITHUB_ENV
          echo "TF_VAR_key_name=ci-key" >> $GITHUB_ENV
      

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3

      - name: Authenticate to Terraform Cloud
        run: |
          echo 'credentials "app.terraform.io" {
            token = "${{ secrets.TF_API_TOKEN }}"
          }' > ~/.terraformrc

      - name: Terraform Init
        run: |
          cd terraform
          terraform init
      
      - name: Terraform Plan
        run: |
          cd terraform
          terraform plan

  # --------------------------------------------------
  # JOB 3: Terraform Apply
  # --------------------------------------------------
  terraform_apply:
    needs: terraform_plan
    runs-on: ubuntu-latest
    outputs:
      ec2_ip: ${{ steps.tf_output.outputs.ec2_ip }}

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Create SSH key files
        run: |
          echo "${{ secrets.SSH_PRIVATE_KEY }}" > key.pem
          chmod 600 key.pem
          ssh-keygen -y -f key.pem > key.pem.pub

          
      - name: Export public key to Terraform
        run: |
          echo "TF_VAR_public_key=$(cat key.pem.pub)" >> $GITHUB_ENV
          echo "TF_VAR_key_name=ci-key" >> $GITHUB_ENV
    

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3

      - name: Authenticate to Terraform Cloud
        run: |
          echo 'credentials "app.terraform.io" {
            token = "${{ secrets.TF_API_TOKEN }}"
          }' > ~/.terraformrc

      - name: Terraform Init
        run: |
          cd terraform
          terraform init

      - name: Terraform Apply (from plan)
        run: |
          cd terraform
          terraform apply -auto-approve

      - name: Export EC2 Public IP
        id: tf_output
        run: |
          echo "ec2_ip=$(terraform -chdir=terraform output -raw public_ip)" >> $GITHUB_OUTPUT


  # --------------------------------------------------
  # JOB 4: Ansible Configuration
  # --------------------------------------------------
  ansible_configure:
    needs: terraform_apply
    runs-on: ubuntu-latest

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Create SSH key
        run: |
          echo "${{ secrets.SSH_PRIVATE_KEY }}" > key.pem
          chmod 600 key.pem

      - name: Generate dynamic inventory
        run: |
          echo "[web]" > inventory.ini
          echo "${{ needs.terraform_apply.outputs.ec2_ip }} ansible_user=ec2-user ansible_ssh_private_key_file=key.pem" >> inventory.ini

      - name: Run Ansible playbook
        run: |
          ansible-playbook \
          -i inventory.ini ansible/playbook.yml \
          --ssh-extra-args="-o StrictHostKeyChecking=no"


  # --------------------------------------------------
  # JOB 5: Validate Application
  # --------------------------------------------------
  validate_app:
    needs: [terraform_apply, ansible_configure]
    runs-on: ubuntu-latest

    steps:
      - name: Validate NGINX endpoint
        run: |
          curl -f http://${{ needs.terraform_apply.outputs.ec2_ip }}


  # --------------------------------------------------
  # JOB 6: TTL Destroy (Always Runs)
  # --------------------------------------------------
  ttl_destroy:
    needs: [terraform_apply, validate_app]
    runs-on: ubuntu-latest
    if: always()

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4


      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3

      - name: Authenticate to Terraform Cloud
        run: |
          echo 'credentials "app.terraform.io" {
            token = "${{ secrets.TF_API_TOKEN }}"
          }' > ~/.terraformrc

      - name: Recreate SSH key files
        run: |
          echo "${{ secrets.SSH_PRIVATE_KEY }}" > key.pem
          chmod 600 key.pem
          ssh-keygen -y -f key.pem > key.pem.pub

      - name: Export Terraform variables
        run: |
          echo "TF_VAR_key_name=ci-key" >> $GITHUB_ENV
          echo "TF_VAR_public_key=$(cat key.pem.pub)" >> $GITHUB_ENV
          echo "TF_VAR_region=us-east-1" >> $GITHUB_ENV
      
      - name: Wait for TTL (10 mins)
        run: sleep 600

      - name: Terraform Destroy
        run: |
          cd terraform
          terraform init
          terraform destroy -auto-approve

  ```


