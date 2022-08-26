import logging
import subprocess
import tarfile

import requests
from aws_cdk import CfnParameter, Fn, RemovalPolicy, Stack
from aws_cdk import aws_s3 as s3
from aws_cdk import aws_s3_deployment as s3deploy
from aws_cdk import cloudformation_include as cfn_inc
from constructs import Construct


class CoreStack(Stack):
    def __init__(self, scope: Construct, construct_id: str, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)

        # Parameters
        vpc_id = CfnParameter(
            self,
            "VpcId",
            type="String",
            description="The VPC to create security groups and deploy the architecture.",
        )

        subnet_ids = CfnParameter(
            self,
            "SubnetIds",
            type="CommaDelimitedList",
            description="Subnets (minimum 2) you want your batch compute environment, Cromwell database and FSx to be launched in. We recommend private subnets.",
        )

        bucket = self.setup_s3()

        gwoa_url = "https://github.com/aws-samples/aws-genomics-workflows/archive/refs/tags/v3.1.0.tar.gz"
        gwoa_url = "https://github.com/henriqueribeiro/aws-genomics-workflows/archive/refs/tags/gatksv-quickstart.tar.gz"

        try:
            response = requests.get(gwoa_url, stream=True)
            response.raise_for_status()

            file = tarfile.open(fileobj=response.raw, mode="r|gz")
            file.extractall(path=".")

            folder = file.getnames()[0]
        except Exception as err:
            error_res = err.response
            logging.error(
                f"Status code: {error_res.status_code}\n"
                f"Reason: {error_res.reason}\n"
                f"Error: {error_res.json()['error']}"
            )
            raise err

        # Prepare files to deploy
        process = subprocess.Popen([f"{folder}/_scripts/make-dist.sh"])
        process.wait()

        artifacts_deploy = self.upload_dist_s3(folder, "artifacts", bucket)
        templates_deploy = self.upload_dist_s3(folder, "templates", bucket)

        # VPC
        params = {
            "Namespace": "GatkSV-Cromwell",
            "VpcId": vpc_id.value_as_string,
            "SubnetIds": subnet_ids.value_as_list,
            "NumberOfSubnets": len(subnet_ids.value_as_list),
            "ArtifactBucketName": artifacts_deploy.bucket_name,
            "TemplateRootUrl": templates_deploy,
            "S3BucketName": artifacts_deploy.bucket_name,
            "ExistingBucket": "Yes",
            "CreateFSx": "Yes",
            "FSxStorageType": "SCRATCH",
            "FSxStorageVolumeSize": "16800",
            "FSxSubnetId": Fn.select(0, subnet_ids.value_as_list),
            "FSxBucketName": f"gatk-sv-data-{self.region}",
        }

        tmpl_folder = f"{folder}/dist/templates/gwfcore"
        core_stack = cfn_inc.CfnInclude(
            self,
            "gwf-core",
            template_file=f"{tmpl_folder}/gwfcore-root.template.yaml",
            parameters=params,
            load_nested_stacks=dict(
                S3Stack=cfn_inc.CfnIncludeProps(
                    template_file=f"{tmpl_folder}/gwfcore-s3.template.yaml"
                ),
                IamStack=cfn_inc.CfnIncludeProps(
                    template_file=f"{tmpl_folder}/gwfcore-iam.template.yaml"
                ),
                LaunchTplStack=cfn_inc.CfnIncludeProps(
                    template_file=f"{tmpl_folder}/gwfcore-launch-template.template.yaml"
                ),
                CodeStack=cfn_inc.CfnIncludeProps(
                    template_file=f"{tmpl_folder}/gwfcore-code.template.yaml"
                ),
                EfsStack=cfn_inc.CfnIncludeProps(
                    template_file=f"{tmpl_folder}/gwfcore-efs.template.yaml"
                ),
                FsxStack=cfn_inc.CfnIncludeProps(
                    template_file=f"{tmpl_folder}/gwfcore-fsx.template.yaml"
                ),
                BatchStack=cfn_inc.CfnIncludeProps(
                    template_file=f"{tmpl_folder}/gwfcore-batch.template.yaml"
                ),
            ),
        )

        self.cromwell_params = {
            "template_folder": f"{folder}/dist/templates",
            "S3Bucket": core_stack.get_output("S3BucketName").value,
            "FSxFileSystemID": core_stack.get_output("FSxFileSystemID").value,
            "FSxFileSystemMount": core_stack.get_output("FSxFileSystemMount").value,
            "FSxSecurityGroupId": core_stack.get_output("FSxSecurityGroupId").value,
        }

    def setup_s3(self):

        # create input bucket
        input_bucket = s3.Bucket(
            self,
            "gwoa_bucket",
            versioned=False,
            encryption=s3.BucketEncryption.S3_MANAGED,
            removal_policy=RemovalPolicy.DESTROY,
            auto_delete_objects=True,
        )

        return input_bucket

    def upload_dist_s3(self, parent_folder, folder, bucket):

        deployment = s3deploy.BucketDeployment(
            self,
            folder,
            sources=[s3deploy.Source.asset(f"{parent_folder}/dist/{folder}")],
            destination_bucket=bucket,
            destination_key_prefix=folder,
        )

        return deployment.deployed_bucket
