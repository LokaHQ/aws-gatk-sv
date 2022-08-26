from aws_cdk import Stack
from aws_cdk import aws_ssm as ssm
from constructs import Construct


class SSMStack(Stack):
    def __init__(
        self, scope: Construct, construct_id: str, ssm_params, **kwargs
    ) -> None:
        super().__init__(scope, construct_id, **kwargs)

        setup_doc = {
            "schemaVersion": "0.3",
            "description": "Downloads and setup GATK-SV Repo to the EC2 Instance",
            "mainSteps": [
                {
                    "maxAttempts": 1,
                    "inputs": {
                        "Parameters": {
                            "commands": [
                                "#!/bin/bash",
                                "set -x",
                                "sudo -i -u ec2-user bash << EOF",
                                "git clone https://github.com/lokahq/aws-gatk-sv.git",
                                "chmod 777 -R aws-gatk-sv",
                                "sh aws-gatk-sv/scripts/setup_env.sh",
                                "EOF",
                            ]
                        },
                        "CloudWatchOutputConfig": {"CloudWatchOutputEnabled": "true"},
                        "InstanceIds": [ssm_params["EC2Instance"]],
                        "DocumentName": "AWS-RunShellScript",
                    },
                    "name": "setup_env",
                    "action": "aws:runCommand",
                    "timeoutSeconds": 600,
                },
                {
                    "maxAttempts": 1,
                    "inputs": {
                        "Parameters": {
                            "commands": [
                                "#!/bin/bash",
                                "set -x",
                                "sudo -i -u ec2-user bash << EOF",
                                f"sh aws-gatk-sv/scripts/setup_gatksv.sh /{ssm_params['S3Bucket'].to_string()}",
                                "EOF",
                            ]
                        },
                        "CloudWatchOutputConfig": {"CloudWatchOutputEnabled": "true"},
                        "InstanceIds": [ssm_params["EC2Instance"]],
                        "DocumentName": "AWS-RunShellScript",
                    },
                    "name": "setup_GATKSV",
                    "action": "aws:runCommand",
                },
            ],
        }

        ssm.CfnDocument(
            self,
            "setup-document",
            content=setup_doc,
            name="setup-pipeline",
            document_format="JSON",
            document_type="Automation",
        )

        run_doc = {
            "schemaVersion": "0.3",
            "description": "Submit GATK-SV Pipeline on the EC2 Instance",
            "mainSteps": [
                {
                    "maxAttempts": 1,
                    "inputs": {
                        "Parameters": {
                            "commands": [
                                "#!/bin/bash",
                                "set -x",
                                "sudo -i -u ec2-user bash << EOF",
                                "cd aws-gatk-sv",
                                (
                                    "/usr/local/bin/cromshell submit"
                                    " gatk-sv/gatk_run/wdl/GATKSVPipelineBatch.wdl"
                                    " gatk-sv/gatk_run/aws_GATKSVPipelineBatch.json"
                                    " gatk-sv/gatk_run/opts.json"
                                    " gatk-sv/gatk_run/wdl/dep.zip"
                                ),
                                "EOF",
                            ]
                        },
                        "CloudWatchOutputConfig": {"CloudWatchOutputEnabled": "true"},
                        "InstanceIds": [ssm_params["EC2Instance"]],
                        "DocumentName": "AWS-RunShellScript",
                    },
                    "name": "Run",
                    "action": "aws:runCommand",
                    "timeoutSeconds": 600,
                }
            ],
        }

        ssm.CfnDocument(
            self,
            "run-document",
            content=run_doc,
            name="run-pipeline",
            document_format="JSON",
            document_type="Automation",
        )
