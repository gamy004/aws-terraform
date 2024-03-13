resource "aws_ssm_document" "manual_deploy" {
  content = jsonencode(
    {
      assumeRole  = "${var.configs.assume_role_arn}"
      description = "Automation Document Deployment for ${var.tags.Project}"
      mainSteps = [
        {
          action = "aws:executeScript"
          inputs = {
            Handler = "script_handler"
            InputPayload = {
              accno     = "${var.configs.source_account_id}"
              project   = "{{ project }}"
              s3bucket  = "${var.configs.s3_bucket_name}"
              source_id = "{{ sourceID }}"
            }
            Runtime = "python3.7"
            Script  = <<-EOT
                            #!/usr/bin/python3
                            import boto3
                            import os
                            import sys
                            import json
                            import zipfile
                            
                            # load boto3
                            sys.path.append(os.path.join(os.getcwd(), "package"))
                            
                            
                            def script_handler(events, context):
                                # constant
                                accno = events['accno']
                                s3bucket = events['s3bucket']
                            
                                # events parameter
                                project = events['project']
                                source_id = events['source_id']
                            
                                s3_path = f"{project}/{project}.zip"
                                local_path = "/tmp/pipeline-definitions.zip"
                                contents = json.dumps(
                                    [{"accno": accno, "repository-name": project, "source-id": source_id}])
                                print(f"content: {contents}")
                            
                                zf = zipfile.ZipFile(local_path, mode="w",
                                                    compression=zipfile.ZIP_DEFLATED)
                                zf.writestr("pipeline-definitions.json", contents)
                                zf.close()
                            
                                s3 = boto3.resource('s3')
                                s3.Bucket(s3bucket).upload_file(local_path, s3_path)
                            
                                return {'message': 'done'}
                            
                            
                            if __name__ == "__main__":
                                script_handler(None, None)
                        EOT
          }
          name = "start"
        },
      ]
      parameters = {
        project = {
          allowedValues = var.configs.projects
          description   = "choose project name for deployment production"
          type          = "String"
        }
        sourceID = {
          default     = ""
          description = "input source deployment id from repository (if project is ElasticBeanstalk, SAM, S3 static you have to input commitID. But for ECS you have to input ImageTag instead.)"
          type        = "String"
        }
      }
      schemaVersion = "0.3"
    }
  )
  document_format = "JSON"
  document_type   = "Automation"
  name            = "${var.tags.Project}-autodoc-deployment"
  permissions     = {}
  tags            = merge(var.tags, { Name = "${var.tags.Project}-autodoc-deployment" })
}

resource "aws_cloudwatch_event_rule" "pipeline_trigger_deploy" {
  for_each = toset(var.configs.projects)

  description    = "${each.key} -> ${each.key}-codepipeline\nAmazon CloudWatch Events rule to automatically start your pipeline when a change occurs in the Amazon S3 object key or S3 folder. Deleting this may prevent changes from being detected in that pipeline. Read more: http://docs.aws.amazon.com/codepipeline/latest/userguide/pipelines-about-starting.html"
  event_bus_name = "default"
  event_pattern = jsonencode(
    {
      detail = {
        eventName = [
          "PutObject",
          "CompleteMultipartUpload",
          "CopyObject",
        ]
        eventSource = [
          "s3.amazonaws.com",
        ]
        requestParameters = {
          bucketName = [
            var.configs.s3_bucket_name
          ]
          key = [
            "${each.key}/${each.key}.zip",
          ]
        }
      }
      detail-type = [
        "AWS API Call via CloudTrail",
      ]
      source = [
        "aws.s3",
      ]
    }
  )
  state      = "ENABLED"
  name       = "${each.key}-triggers-${each.key}-codepipeline"
  tags       = merge(var.tags, { Name = "${each.key}-triggers-${each.key}-codepipeline" })
}

resource "aws_iam_policy" "start_pipeline_execution" {
  for_each = toset(var.configs.projects)

  description = "Allows Amazon CloudWatch Events to automatically start a new execution in the ${each.key}-codepipeline pipeline when a change occurs"
  name        = "start-pipeline-execution-${each.key}-codepipeline"
  path        = "/service-role/"
  policy = jsonencode(
    {
      Statement = [
        {
          Action = [
            "codepipeline:StartPipelineExecution",
          ]
          Effect = "Allow"
          Resource = [
            var.configs.pipeline_arns[var.configs.pipeline_mappings[each.key]]
          ]
        },
      ]
      Version = "2012-10-17"
    }
  )
  tags = merge(var.tags, { Name = "start-pipeline-execution-${each.key}-codepipeline" })
}

resource "aws_iam_role" "assume_cwe_role_codepipeline" {
  for_each = toset(var.configs.projects)

  assume_role_policy = jsonencode(
    {
      Statement = [
        {
          Action = "sts:AssumeRole"
          Effect = "Allow"
          Principal = {
            Service = "events.amazonaws.com"
          }
        },
      ]
      Version = "2012-10-17"
    }
  )

  force_detach_policies = false

  managed_policy_arns = [
    aws_iam_policy.start_pipeline_execution[each.key].arn
  ]

  max_session_duration = 3600
  name                 = "cwe-role-${each.key}-codepipeline"
  path                 = "/service-role/"
  tags                 = merge(var.tags, { Name = "cwe-role-${each.key}-codepipeline" })

}

resource "aws_cloudwatch_event_target" "app-web-codepipeline" {
  for_each = toset(var.configs.projects)

  rule           = aws_cloudwatch_event_rule.pipeline_trigger_deploy[each.key].name
  event_bus_name = try(var.configs.event_bus_name, "default")
  arn            = var.configs.pipeline_arns[var.configs.pipeline_mappings[each.key]]
  role_arn       = aws_iam_role.assume_cwe_role_codepipeline[each.key].arn
}
