export AWS_ENDPOINT_URL=${AWS_ENDPOINT_URL:-""}
export AWS_REGION=${AWS_REGION:-us-east-1}
export AWS_PROFILE=${AWS_PROFILE:-default}

awsEndpoint=""
[[ ! -z "${AWS_ENDPOINT_URL}" ]] && awsEndpoint="--endpoint-url ${AWS_ENDPOINT_URL}"

# S3 BUCKET
# check if bucket exists
bucketName="portfolios-upload-bucket"
bucketstatus=$( aws s3api head-bucket --bucket ${bucketName} --region ${AWS_REGION} ${awsEndpoint} 2>&1 )
if echo "${bucketstatus}" | grep 'Not Found' > /dev/null 2>&1
then
    aws s3api ${awsEndpoint} create-bucket \
        --region ${AWS_REGION} \
        --bucket ${bucketName} \
        --create-bucket-configuration LocationConstraint=${AWS_REGION} \
        > /dev/null 2>&1

    ok "created s3 bucket ${BOLD_WHITE}${bucketName}${NC}"
else
    info "s3 bucket already exists: ${BOLD_WHITE}${bucketName}${NC}"
fi

# SQS QUEUE
queueName="LocalImageIngest"
queuestatus=$( aws ${awsEndpoint} --region ${AWS_REGION} sqs get-queue-url --queue-name ${queueName} 2>&1 )
queueUrl=""
if echo "${queuestatus}" | grep 'NonExistentQueue' > /dev/null 2>&1;
then
    aws ${awsEndpoint} --region ${AWS_REGION} sqs create-queue \
        --queue-name ${queueName} \
        > /dev/null 2>&1

    [ $? == 0 ] || fail "could not create queue ${BOLD_WHITE}${queueName}${NC}"
    info "successfully created queue ${BOLD_WHITE}${queueName}${NC}"

    queueUrl=$( aws ${awsEndpoint} --region ${AWS_REGION} sqs get-queue-url --queue-name ${queueName} --query "QueueUrl" --output text )
    info "queue url: ${CYAN}${queueUrl}${NC}"
else
    info "SQS queue already exists: ${BOLD_WHITE}${queueName}${NC}"
fi

# LAMBDA FUNCTIONS
# upload function
uploadFunction="portfolio-upload-function"
zipFile="${PROJECT_ROOT}/cloud-functions/image-upload/bundle-1.0.0.zip"
handler="index.handler"

aws ${awsEndpoint} lambda create-function \
    --region ${AWS_REGION} \
    --function-name ${uploadFunction} \
    --zip-file fileb://${zipFile} \
    --runtime nodejs16.x \
    --handler ${handler} \
    --environment "Variables={AWS_ENDPOINT_URL=http://host.docker.internal:4566,INGEST_QUEUE_URL=http://host.docker.internal:4566/000000000000/${queueName}}" \
    --role arn:aws:iam::000000000000:role/inconsequential \
    > /dev/null 2>&1

[ $? == 0 ] || fail "could not create function ${BOLD_WHITE}${uploadFunction}${NC}"
info "succesfully created function ${BOLD_WHITE}${uploadFunction}${NC}"

# NOTE: LocalStack does not fully support layering with free version - using build script for now
# sharp layer
# layerName="image-manipulation"
# zipFile="${PROJECT_ROOT}/layers/image-processing/sharplayer.zip"
# aws ${awsEndpoint} --region ${AWS_REGION} lambda publish-layer-version \
#     --layer-name ${layerName} \
#     --license-info "MIT" \
#     --zip-file fileb://${zipFile} \
#     --compatible-runtimes nodejs12.x nodejs14.x nodejs16.x \
#     --compatible-architectures "arm64" "x86_64" \
#     > /dev/null 2>&1

# [ $? == 0 ] || fail "could not create layer ${BOLD_WHITE}${layerName}${NC}"
# info "succesfully created layer ${BOLD_WHITE}${layerName}${NC}"

# ingest function
functionName="portfolio-ingest-function"
zipFile="${PROJECT_ROOT}/cloud-functions/image-ingestion/bundle-1.0.0.zip"
handler="index.handler"

aws ${awsEndpoint} lambda create-function \
    --region ${AWS_REGION} \
    --function-name ${functionName} \
    --zip-file fileb://${zipFile} \
    --runtime nodejs16.x \
    --handler ${handler} \
    --environment "Variables={AWS_ENDPOINT_URL=http://host.docker.internal:4566}" \
    --role arn:aws:iam::000000000000:role/inconsequential \
    > /dev/null 2>&1

[ $? == 0 ] || fail "could not create function ${BOLD_WHITE}${functionName}${NC}"
info "succesfully created function ${BOLD_WHITE}${functionName}${NC}"

# EVENT MAPPING
aws ${awsEndpoint} --region ${AWS_REGION} lambda create-event-source-mapping \
    --function-name ${functionName} \
    --batch-size 1 \
    --maximum-batching-window-in-seconds 60 \
    --event-source-arn arn:aws:sqs:${AWS_REGION}:000000000000:${queueName} \
    > /dev/null 2>&1

# API GATEWAY
apiName="portfolios-rest-api"
# short-circuit if api has already been created
apiId=$( aws ${awsEndpoint} apigateway get-rest-apis --query "items[?name==\`${apiName}\`].id" --output text --region ${AWS_REGION} )
if [[ ! -z "${apiId}" ]]
then
    info "rest api already exists: ${BOLD_WHITE}${apiName}${NC}"
else
    aws ${awsEndpoint} apigateway create-rest-api \
        --region ${AWS_REGION} \
        --name ${apiName} \
        > /dev/null 2>&1

    [ $? == 0 ] || fail "failed to create rest api: ${BOLD_WHITE}${apiName}${NC}"

    apiId=$( aws ${awsEndpoint} apigateway get-rest-apis --query "items[?name==\`${apiName}\`].id" --output text --region ${AWS_REGION} )
    rootId=$( aws ${awsEndpoint} apigateway get-resources --rest-api-id ${apiId} --query "items[?path==\`/\`].id" --output text --region ${AWS_REGION} )

    ok "successfully created ${BOLD_WHITE}${apiName}${NC} rest api with id ${CYAN}${apiId}${NC}"
fi

# create the /{folder} resource
folderPathId=$( appendPathPart ${apiId} ${rootId} "{folder}" "${awsEndpoint}" )
info "created api resource: ${BOLD_WHITE}/{folder}${NC} with id ${CYAN}${folderPathId}${NC}"

# create the /{folder}/{object} resource
objectPathId=$( appendPathPart ${apiId} ${folderPathId} "{object}" "${awsEndpoint}" )
info "created api resource: ${BOLD_WHITE}/{folder}/{object}${NC} with id ${CYAN}${objectPathId}${NC}"

# PUT method for uploading artifacts
aws ${awsEndpoint} apigateway put-method \
    --region ${AWS_REGION} \
    --rest-api-id ${apiId} \
    --resource-id ${objectPathId} \
    --http-method POST \
    --authorization-type NONE \
    --request-parameters method.request.path.folder=true,method.request.path.object=true \
    > /dev/null 2>&1

[ $? == 0 ] || fail "failed to add api method: ${BOLD_WHITE}POST /{folder}/{object}${NC}"
info "api method created: ${BOLD_WHITE}POST /{folder}/{object}${NC}"

functionArn="arn:aws:lambda:${AWS_REGION}:000000000000:function:${uploadFunction}"
aws ${awsEndpoint} apigateway put-integration \
    --region ${AWS_REGION} \
    --rest-api-id ${apiId} \
    --resource-id ${objectPathId} \
    --http-method POST \
    --integration-http-method POST \
    --type AWS_PROXY \
    --uri arn:aws:apigateway:${AWS_REGION}:lambda:path/2015-03-31/functions/${functionArn}/invocations \
    --request-parameters integration.request.path.bucket=method.request.path.folder,integration.request.path.key=method.request.path.object \
    --passthrough-behavior WHEN_NO_MATCH \
    > /dev/null 2>&1

aws ${awsEndpoint} apigateway create-deployment \
    --region ${AWS_REGION} \
    --rest-api-id ${apiId} \
    --stage-name Local \
    > /dev/null 2>&1

apiUri="http://localhost:4566/restapis/${apiId}/Local/_user_request_/"
info "api available at: ${BOLD_WHITE}${apiUri}${NC}"
