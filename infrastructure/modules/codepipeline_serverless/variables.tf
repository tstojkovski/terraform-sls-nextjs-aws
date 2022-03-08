# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

variable "name" {
  description = "The CodePipeline pipeline name"
  type        = string
}

variable "pipe_role" {
  description = "The role assumed by CodePipeline"
  type        = string
}

variable "s3_bucket" {
  description = "S3 bucket used for the artifact store"
  type        = string
}

variable "repo_owner" {
  description = "The username of the Github repository owner"
  type        = string
}

variable "repo_name" {
  description = "Github repository's name"
  type        = string
}

variable "branch" {
  description = "Github branch used to trigger the CodePipeline"
  type        = string
}

variable "app_name_backend" {
  description = "CodeDeploy Application name for the server"
  type        = string
}

variable "environment_name" {
  description = "Name of the environment"
  type        = string
}

variable "codestar_connection" {
  description = "The CodeStar connection"
}