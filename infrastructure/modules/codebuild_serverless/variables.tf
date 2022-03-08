# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

variable "name" {
  type        = string
  description = "CodeBuild Project name"
}

variable "iam_role" {
  type        = string
  description = "IAM role to attach to CodeBuild"
}
variable "region" {
  type        = string
  description = "AWS Region used"
}
variable "account_id" {
  description = "AWS Account ID where the solution is being deployed"
  type        = string
}

variable "buildspec_path" {
  description = "Path to for the Buildspec file"
  type        = string
}

variable "folder_path" {
  description = "Folder path to use to run the sls command"
  type        = string
}

variable "environment_name" {
  description = "The environment name"
  type        = string
}