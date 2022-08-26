#!/usr/bin/env python3
import aws_cdk as cdk

from gatk_sv_cdk.core_stack import CoreStack
from gatk_sv_cdk.cromwell_stack import CromwellStack
from gatk_sv_cdk.ssm_stack import SSMStack

region = "us-east-1"

app = cdk.App()
core_stack = CoreStack(
    app,
    "CoreStack",
    env=cdk.Environment(region=region),
)
cromwell_stack = CromwellStack(
    app,
    "CromwellStack",
    core_stack.cromwell_params,
    env=cdk.Environment(region=region),
)

cromwell_stack.add_dependency(core_stack)

ssm_stack = SSMStack(
    app,
    "SSMStack",
    cromwell_stack.ssm_params,
    env=cdk.Environment(region=region),
)

ssm_stack.add_dependency(cromwell_stack)

app.synth()
