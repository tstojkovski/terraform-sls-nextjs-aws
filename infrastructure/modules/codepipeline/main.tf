# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

/*=======================================================
      AWS CodePipeline for build and deployment
========================================================*/

resource "aws_codepipeline" "aws_codepipeline" {
  name     = var.name
  role_arn = var.pipe_role

  artifact_store {
    location = var.s3_bucket
    type     = "S3"
  }

  stage {
    name = "Source"

    action {
      category         = "Source"
      configuration    = {
        "BranchName"           = var.branch
        "ConnectionArn"        = var.codestar_connection
        "FullRepositoryId"     = "${var.repo_owner}/${var.repo_name}"
        "OutputArtifactFormat" = "CODEBUILD_CLONE_REF"
      }
      input_artifacts  = []
      name             = "Source"
      output_artifacts = [
        "SourceArtifact",
      ]
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      run_order        = 1
      version          = "1"
    }
  }

  stage {
    name = "Build"

    action {
      name             = "Build_client"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["SourceArtifact"]
      output_artifacts = ["BuildArtifact_client"]
      configuration = {
        ProjectName = var.codebuild_project_client
      }
    }
  }

  stage {
    name = "Deploy"

    action {
      name            = "Deploy_client"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "CodeDeployToECS"
      input_artifacts = ["BuildArtifact_client"]
      version         = "1"

      configuration = {
        ApplicationName                = var.app_name_client
        DeploymentGroupName            = var.deployment_group_client
        TaskDefinitionTemplateArtifact = "BuildArtifact_client"
        TaskDefinitionTemplatePath     = "taskdef.json"
        AppSpecTemplateArtifact        = "BuildArtifact_client"
        AppSpecTemplatePath            = "appspec.yaml"
      }
    }
  }

  lifecycle {
    # prevents github OAuthToken from causing updates, since it's removed from state file
    ignore_changes = [stage[0].action[0].configuration]
  }

}