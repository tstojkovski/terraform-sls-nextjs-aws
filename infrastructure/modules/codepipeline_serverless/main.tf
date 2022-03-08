# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

/*=======================================================
      AWS CodePipeline for build and deployment
========================================================*/

resource "aws_codepipeline" "aws_codepipeline_serverless" {
  name     = var.name
  role_arn = var.pipe_role

  artifact_store {
    location = var.s3_bucket
    type     = "S3"
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "ThirdParty"
      provider         = "GitHub"
      version          = "1"
      output_artifacts = ["SourceArtifact"]

      configuration = {
        OAuthToken           = var.github_token
        Owner                = var.repo_owner
        Repo                 = var.repo_name
        Branch               = var.branch
        PollForSourceChanges = true
      }
    }
  }

  stage {
    name = "Deploy"

    action {
      name             = "Deploy_backend"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["SourceArtifact"]
      output_artifacts = ["BuildArtifact_backend"]

      configuration = {
        ProjectName          = var.app_name_backend
        EnvironmentVariables = jsonencode(
          [
            {
              name  = "STAGE"
              type  = "PLAINTEXT"
              value = var.environment_name
            },
          ]
        )
      }
    }
  }

  lifecycle {
    # prevents github OAuthToken from causing updates, since it's removed from state file
    ignore_changes = [stage[0].action[0].configuration]
  }

}