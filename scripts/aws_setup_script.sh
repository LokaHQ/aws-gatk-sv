# Update the below variables
S3_OR_FSX=$1
BROAD_REF_PATH="${S3_OR_FSX}/reference/broad-ref"
CRAM_BAM_FILE_PATH="${S3_OR_FSX}/bams"
HAPLOTYPE_GVCF_PATH="${S3_OR_FSX}/reference/gvcf"
GATK_SV_RESOURCES_PATH="${S3_OR_FSX}/reference/gatk-sv-resources"
BATCH_DEF_PATH="${S3_OR_FSX}/reference/batch_sv.test_large.qc_definitions.tsv"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --output text --query 'Account')
AWS_REGION=`curl -s http://169.254.169.254/latest/dynamic/instance-identity/document| grep region | cut -d '"' -f4`
ECR_REPO_NAME="sv-pipeline"

# Install docker
sudo yum install -y jq
sudo amazon-linux-extras install -y docker
sudo usermod -a -G docker ec2-user
sudo service docker start
sudo chkconfig docker on
sudo curl -L https://github.com/docker/compose/releases/download/1.22.0/docker-compose-"$(uname -s)"-"$(uname -m)" -o /usr/local/bin/docker-compose
sudo curl -L https://github.com/docker/compose/releases/latest/download/docker-compose-"$(uname -s)"-"$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
docker-compose version
sudo chmod 755 /var/run/docker.sock

# Download the gatk-sv github repo
# The working AWS FSx code is uploaded in the report mentioned due to on-going PR with Broad.
# cd /home/ec2-user
# git init
# git remote add origin -f https://github.com/LokaHQ/aws-gatk-sv.git
# echo "gatk-sv" > .git/info/sparse-checkout
# git pull origin master
# This will be hard-coded to a particular release/tag if Broad is unable to maintain it.
# Uncomment below once tagged version from Broad is created and specify the Version.
# wget https://github.com/broadinstitute/gatk-sv/archive/refs/tags/v<UPDATE_LATER>.zip
# unzip v<UPDATE_LATER>.zip
# mv gatk-sv-<UPDATE_LATER> gatk-sv
# chmod 755 -R gatk-sv

# Create the required code and reference files.
cd aws-gatk-sv/gatk-sv
mkdir gatk_run 
python3 -m pip install jinja2
BASE_DIR=$(pwd)
GATK_SV_ROOT=$(pwd)
CLOUD_ENV="aws.gatk_sv"
echo '{ "google_project_id": "broad-dsde-methods", "terra_billing_project_id": "broad-dsde-methods" }' > inputs/values/"${CLOUD_ENV}".json
python3 scripts/inputs/build_inputs.py "${BASE_DIR}"/inputs/values "${BASE_DIR}"/inputs/templates/test "${BASE_DIR}"/inputs/build/ref_panel_1kg/test  -a '{ "test_batch" : "ref_panel_1kg", "cloud_env" : "'$CLOUD_ENV'" }'
cp inputs/build/ref_panel_1kg/test/GATKSVPipelineBatch/GATKSVPipelineBatch.json
cp inputs/build/ref_panel_1kg/test/GATKSVPipelineBatch/GATKSVPipelineBatch.json gatk_run/

cd gatk_run
cp -r ../wdl .
cd wdl; 
# MAKE MELT FLAGS FALSE. Search for "use_melt" and change flag to false. 
# `find . -type f | xargs grep "Boolean use_melt"` can be used to search files.
# sed -i "s/Boolean use_melt = true/Boolean use_melt = false/g" GATKSVPipelineBatch.wdl
# sed -i "s/Boolean use_melt = true/Boolean use_melt = false/g" GATKSVPipelineSingleSample.wdl
# Update TinyResolve CPU/MEM for AWS in order to run it on newer instance as we have seen Container Pull issues while it runs with other jobs.
# Increasing the CPU/MEM to 16 will ensure a new Batch EC2 is spun up coz rest other parallel jobs are using below 8 cpus.
sed -i "s/cpu_cores: 1/cpu_cores: 16/g;s/mem_gb: 3.75/mem_gb: 16/g" TinyResolve.wdl
zip dep.zip *.wdl

# Update and Copy the aws config file.
cd ../
# wget https://github.com/lokahq/aws-gatk-sv/blob/master/configs/aws_GATKSVPipelineBatch.json\?raw\=true -O aws_GATKSVPipelineBatch.json
cp ../configs/aws_GATKSVPipelineBatch.json aws_GATKSVPipelineBatch.json 
# wget https://github.com/lokahq/aws-gatk-sv/blob/master/configs/opts.json\?raw\=true -O opts.json
cp ../configs/opts.json opts.json
chmod 755 aws_GATKSVPipelineBatch.json opts.json
# Update the aws_GATKSVPipelineBatch.ref_panel_1kg.json json with the correct values as per variables defined
array=( BROAD_REF_PATH CRAM_BAM_FILE_PATH HAPLOTYPE_GVCF_PATH GATK_SV_RESOURCES_PATH BATCH_DEF_PATH AWS_ACCOUNT_ID AWS_REGION ECR_REPO_NAME )
for i_var in "${array[@]}"
do
	i_val=${!i_var}
    # Below might need -i '' if running on mac.
	sed -i "s#${i_var}#${i_val}#g" aws_GATKSVPipelineBatch.json
done


# Upload the images to ECR
# wget https://github.com/lokahq/aws-gatk-sv/blob/master/scripts/upload_images_ecr.sh\?raw\=true -O upload_images_ecr.sh
cd ../scripts
chmod 755 upload_images_ecr.sh
sh upload_images_ecr.sh -r "${AWS_REGION}" -e "${ECR_REPO_NAME}"


echo "IMPORTANT : Kindly compare the below :
    - BROAD : gatk-sv/gatk_run/GATKSVPipelineBatch.json
    - AWS : gatk-sv/gatk_run/aws_GATKSVPipelineBatch.json

And update the missing params in AWS json from BROAD json with correct AWS paths/account id/aws region and at the same location as of BROADs.
"