export AWS_ENDPOINT_URL=${AWS_ENDPOINT_URL:-""}
export AWS_REGION=${AWS_REGION:-us-east-1}
export AWS_PROFILE=${AWS_PROFILE:-default}

awsEndpoint=""
[[ ! -z "${AWS_ENDPOINT_URL}" ]] && awsEndpoint="--endpoint-url ${AWS_ENDPOINT_URL}"

function s3_create() {
    local bucketName=${1}
    [[ -z "${bucketName}" ]] && fail "cannot create s3 bucket without a name"

    # check if bucket exists
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
}

function api_create() {
    local apiName=${1}
    [[ -z "${apiName}" ]] && fail "cannot create api without a name"

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

    [ $? == 0 ] || fail "failed to add api method: ${BOLD_WHITE}PUT /{folder}/{object}${NC}"
    info "api method created: ${BOLD_WHITE}PUT /{folder}/{object}${NC}"

    # S3 integration configuration
    # UNSUPPORTED: ideally, we want to use direct api -> s3 upload
    #   however, LocalStack does not yet support PUT for S3 :((
    # aws ${awsEndpoint} apigateway put-integration \
    #     --region ${AWS_REGION} \
    #     --rest-api-id ${apiId} \
    #     --resource-id ${objectPathId} \
    #     --http-method PUT \
    #     --integration-http-method PUT \
    #     --type AWS \
    #     --uri \"arn:aws:apigateway:${AWS_REGION}:s3:action/PutObject&Bucket={bucket}&Key={key}\" \
    #     --request-parameters integration.request.path.bucket=method.request.path.folder,integration.request.path.key=method.request.path.object \
    #     --passthrough-behavior WHEN_NO_MATCH \
    #     --credentials arn:aws:iam::000000000000:role/inconsequential \
    #     > /dev/null 2>&1
}

s3_create portfolios-upload-bucket
api_create portfolios-rest-api
