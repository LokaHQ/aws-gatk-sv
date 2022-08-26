from aws_cdk import CfnParameter, Stack
from aws_cdk import cloudformation_include as cfn_inc
from constructs import Construct


class CromwellStack(Stack):
    def __init__(
        self, scope: Construct, construct_id: str, cromwell_params, **kwargs
    ) -> None:
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

        server_subnet_id = CfnParameter(
            self,
            "ServerSubnetID",
            type="String",
            description="Subnet for the Cromwell server. For public access, use a public subnet.",
        )

        params = {
            "Namespace": "Cromwell-Server",
            "GWFCoreNamespace": "GatkSV-Cromwell",
            "VpcId": vpc_id.value_as_string,
            "ServerSubnetID": server_subnet_id.value_as_string,
            "DBSubnetIDs": subnet_ids.value_as_list,
            "DBPassword": "cromwell",
            "EC2RootVolumeSize": 32,
            "FSxFileSystemID": cromwell_params["FSxFileSystemID"],
            "FSxFileSystemMount": cromwell_params["FSxFileSystemMount"],
            "FSxSecurityGroupId": cromwell_params["FSxSecurityGroupId"],
            "UseFSx": "Yes",
        }

        template_folder = cromwell_params["template_folder"]
        cromwell_stack = cfn_inc.CfnInclude(
            self,
            "cromwell",
            template_file=f"{template_folder}/cromwell/cromwell-resources.template.yaml",
            parameters=params,
        )

        self.ssm_params = {
            "S3Bucket": cromwell_params["S3Bucket"],
            "EC2Instance": cromwell_stack.get_output("EC2Instance").value,
        }
