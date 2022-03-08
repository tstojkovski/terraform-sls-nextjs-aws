# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

/*===========================
          Root file
============================*/

# ------- Providers -------
provider "aws" {
  profile = var.aws_profile
  region  = var.aws_region

  # provider level tags - yet inconsistent when executing 
  # default_tags {
  #   tags = {
  #     Created_by = "Terraform"
  #     Project    = "AWS_demo_fullstack_devops"
  #   }
  # }
}

# ------- Random numbers intended to be used as unique identifiers for resources -------
resource "random_id" "RANDOM_ID" {
  byte_length = "2"
}

# ------- Account ID -------
data "aws_caller_identity" "id_current_account" {}

# ------- Networking -------
module "networking" {
  source = "../modules/networking"
  cidr   = ["10.120.0.0/16"]
  name   = var.environment_name
}

# ------- Creating Target Group for the backend ALB environment -------
module "target_group_backend" {
  source               = "../modules/alb"
  create_target_group  = true
  name                 = "tg-${var.environment_name}-b"
  port                 = 80
  protocol             = "HTTP"
  vpc                  = module.networking.aws_vpc
  tg_type              = "lambda"
  health_check_enabled = false
}


# ------- Creating Target Group for the client ALB blue environment -------
module "target_group_client_blue" {
  source              = "../modules/alb"
  create_target_group = true
  name                = "tg-${var.environment_name}-c-b"
  port                = 80
  protocol            = "HTTP"
  vpc                 = module.networking.aws_vpc
  tg_type             = "ip"
  health_check_path   = "/"
  health_check_port   = var.port_app_client
}

# ------- Creating Target Group for the client ALB green environment -------
module "target_group_client_green" {
  source              = "../modules/alb"
  create_target_group = true
  name                = "tg-${var.environment_name}-c-g"
  port                = 80
  protocol            = "HTTP"
  vpc                 = module.networking.aws_vpc
  tg_type             = "ip"
  health_check_path   = "/"
  health_check_port   = var.port_app_client
}

# ------- Creating Security Group for the backend ALB -------
module "security_group_alb_backend" {
  source              = "../modules/securitygroup"
  name                = "alb-${var.environment_name}-backend"
  description         = "Controls access to the server ALB"
  vpc_id              = module.networking.aws_vpc
  cidr_blocks_ingress = ["0.0.0.0/0"]
  ingress_port        = 80
}

# ------- Creating Security Group for the client ALB -------
module "security_group_alb_client" {
  source              = "../modules/securitygroup"
  name                = "alb-${var.environment_name}-client"
  description         = "Controls access to the client ALB"
  vpc_id              = module.networking.aws_vpc
  cidr_blocks_ingress = ["0.0.0.0/0"]
  ingress_port        = 80
}

# ------- Creating Backend Application ALB -------
module "alb_backend" {
  source         = "../modules/alb"
  create_alb     = true
  name           = "${var.environment_name}-be"
  subnets        = [module.networking.public_subnets[0], module.networking.public_subnets[1]]
  security_group = module.security_group_alb_backend.sg_id
  target_group   = module.target_group_backend.arn_tg
}

# ------- Creating Client Application ALB -------
module "alb_client" {
  source         = "../modules/alb"
  create_alb     = true
  name           = "${var.environment_name}-cli"
  subnets        = [module.networking.public_subnets[0], module.networking.public_subnets[1]]
  security_group = module.security_group_alb_client.sg_id
  target_group   = module.target_group_client_blue.arn_tg
}

# ------- ECS Role -------
module "ecs_role" {
  source             = "../modules/iam"
  create_ecs_role    = true
  name               = var.iam_role_name["ecs"]
  name_ecs_task_role = var.iam_role_name["ecs_task_role"]
  dynamodb_table     = [module.dynamodb_table.dynamodb_table_arn]
}

# ------- Creating a IAM Policy for role -------
module "ecs_role_policy" {
  source        = "../modules/iam"
  name          = "ecs-ecr-${var.environment_name}"
  create_policy = true
  attach_to     = module.ecs_role.name_role
}

# ------- Creating client ECR Repository to store Docker Images -------
module "ecr_client" {
  source = "../modules/ecr"
  name   = "repo-client"
}

# ------- Creating ECS Task Definition for the client -------
module "ecs_taks_definition_client" {
  source             = "../modules/ecs/taskdefinition"
  name               = "${var.environment_name}-client"
  container_name     = var.container_name["client"]
  execution_role_arn = module.ecs_role.arn_role
  task_role_arn      = module.ecs_role.arn_role_ecs_task_role
  cpu                = 256
  memory             = "512"
  docker_repo        = module.ecr_client.ecr_repository_url
  region             = var.aws_region
  container_port     = var.port_app_client
}

# ------- Creating a client Security Group for ECS TASKS -------
module "security_group_ecs_task_client" {
  source          = "../modules/securitygroup"
  name            = "ecs-task-${var.environment_name}-client"
  description     = "Controls access to the client ECS task"
  vpc_id          = module.networking.aws_vpc
  ingress_port    = var.port_app_client
  security_groups = [module.security_group_alb_client.sg_id]
}

# ------- Creating ECS Cluster -------
module "ecs_cluster" {
  source = "../modules/ecs/cluster"
  name   = var.environment_name
}

# ------- Creating ECS Service client -------
module "ecs_service_client" {
  depends_on          = [module.alb_client]
  source              = "../modules/ecs/service"
  name                = "${var.environment_name}-client"
  desired_tasks       = 1
  arn_security_group  = module.security_group_ecs_task_client.sg_id
  ecs_cluster_id      = module.ecs_cluster.ecs_cluster_id
  arn_target_group    = module.target_group_client_blue.arn_tg
  arn_task_definition = module.ecs_taks_definition_client.arn_task_definition
  subnets_id          = [module.networking.private_subnets_client[0], module.networking.private_subnets_client[1]]
  container_port      = var.port_app_client
  container_name      = var.container_name["client"]
}

# ------- Creating ECS Autoscaling policies for the client application -------
module "ecs_autoscaling_client" {
  depends_on   = [module.ecs_service_client]
  source       = "../modules/ecs/autoscaling"
  name         = "${var.environment_name}-client"
  cluster_name = module.ecs_cluster.ecs_cluster_name
  min_capacity = 1
  max_capacity = 4
}

# ------- CodePipeline -------

# ------- Creating Bucket to store CodePipeline artifacts -------
module "s3_codepipeline" {
  source      = "../modules/s3"
  bucket_name = "codepipeline-${var.aws_region}-${random_id.RANDOM_ID.hex}"
}

# ------- Creating IAM roles used during the pipeline execution -------
module "devops_role" {
  source             = "../modules/iam"
  create_devops_role = true
  name               = var.iam_role_name["devops"]
}

module "codedeploy_role" {
  source                 = "../modules/iam"
  create_codedeploy_role = true
  name                   = var.iam_role_name["codedeploy"]
}

# ------- Creating an IAM Policy for role ------- 
module "policy_devops_role" {
  source                = "../modules/iam"
  name                  = "devops-${var.environment_name}"
  create_policy         = true
  attach_to             = module.devops_role.name_role
  create_devops_policy  = true
  ecr_repositories      = [module.ecr_client.ecr_repository_arn]
  code_build_projects   = [module.codebuild_client.project_arn, module.codebuild_backend.project_arn]
  code_deploy_resources = [module.codedeploy_client.application_arn, module.codedeploy_client.deployment_group_arn]
}

# ------- Creating a SNS topic -------
module "sns" {
  source   = "../modules/sns"
  sns_name = "sns-${var.environment_name}"
}

# ------- Creating the backend CodeBuild project -------
module "codebuild_backend" {
  source                 = "../modules/codebuild_serverless"
  name                   = "codebuild-${var.environment_name}-backend"
  iam_role               = module.devops_role.arn_role
  region                 = var.aws_region
  account_id             = data.aws_caller_identity.id_current_account.account_id
  buildspec_path         = var.backend_buildspec_path
}


# ------- Creating the client CodeBuild project -------
module "codebuild_client" {
  source                 = "../modules/codebuild"
  name                   = "codebuild-${var.environment_name}-client"
  iam_role               = module.devops_role.arn_role
  region                 = var.aws_region
  account_id             = data.aws_caller_identity.id_current_account.account_id
  ecr_repo_url           = module.ecr_client.ecr_repository_url
  folder_path            = var.folder_path_client
  buildspec_path         = var.client_buildspec_path
  task_definition_family = module.ecs_taks_definition_client.task_definition_family
  container_name         = var.container_name["client"]
  service_port           = var.port_app_client
  ecs_role               = var.iam_role_name["ecs"]
  backend_alb_url        = module.alb_backend.dns_alb
}

# ------- Creating the client CodeDeploy project -------
module "codedeploy_client" {
  source          = "../modules/codedeploy"
  name            = "deploy-${var.environment_name}-client"
  ecs_cluster     = module.ecs_cluster.ecs_cluster_name
  ecs_service     = module.ecs_service_client.ecs_service_name
  alb_listener    = module.alb_client.arn_listener
  tg_blue         = module.target_group_client_blue.tg_name
  tg_green        = module.target_group_client_green.tg_name
  sns_topic_arn   = module.sns.sns_arn
  codedeploy_role = module.codedeploy_role.arn_role_codedeploy
}

# ------- Creating CodeStar connection -------
resource "aws_codestarconnections_connection" "pipeline" {
  name          = "codestar-gh"
  provider_type = "GitHub"
}

# ------- Creating CodePipeline -------
module "codepipeline" {
  source                    = "../modules/codepipeline"
  name                      = "pipeline-${var.environment_name}"
  pipe_role                 = module.devops_role.arn_role
  s3_bucket                 = module.s3_codepipeline.s3_bucket_id
  repo_owner                = var.repository_owner
  repo_name                 = var.repository_name
  branch                    = var.repository_branch
  codebuild_project_client  = module.codebuild_client.project_id
  app_name_client           = module.codedeploy_client.application_name
  deployment_group_client   = module.codedeploy_client.deployment_group_name
  codestar_connection       = aws_codestarconnections_connection.pipeline.arn

  depends_on = [module.policy_devops_role]
}


# ------- Creating CodePipeline backend -------
module "codepipeline_serverless" {
  source                    = "../modules/codepipeline_serverless"
  name                      = "pipeline-sls-${var.environment_name}"
  pipe_role                 = module.devops_role.arn_role
  s3_bucket                 = module.s3_codepipeline.s3_bucket_id
  repo_owner                = var.repository_owner
  repo_name                 = var.repository_name
  branch                    = var.repository_branch
  codebuild_project_backend = module.codebuild_backend.project_id
  environment_name          = var.environment_name
  codestar_connection       = aws_codestarconnections_connection.pipeline.arn

  depends_on = [module.policy_devops_role]
}


# ------- Creating Bucket to store assets accessed by the Back-end -------
module "s3_assets" {
  source      = "../modules/s3"
  bucket_name = "assets-${var.aws_region}-${random_id.RANDOM_ID.hex}"
}

# ------- Creating Dynamodb table by the Back-end -------
module "dynamodb_table" {
  source = "../modules/dynamodb"
  name   = "assets-table-${var.environment_name}"
}