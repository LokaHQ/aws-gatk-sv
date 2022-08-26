import aws_cdk as core
import aws_cdk.assertions as assertions

from gatk_sv_cdk.gatk_sv_cdk_stack import GatkSvCdkStack

# example tests. To run these tests, uncomment this file along with the example
# resource in gatk_sv_cdk/gatk_sv_cdk_stack.py
def test_sqs_queue_created():
    app = core.App()
    stack = GatkSvCdkStack(app, "gatk-sv-cdk")
    template = assertions.Template.from_stack(stack)

#     template.has_resource_properties("AWS::SQS::Queue", {
#         "VisibilityTimeout": 300
#     })
