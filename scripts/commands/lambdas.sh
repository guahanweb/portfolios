function usage() {
    echo "${CYAN}usage:${NC} ${programName} lambdas <command> [...options]"
}

function build_lambda() {
    cd ${PROJECT_ROOT}/cloud-functions/${WORKSPACE_DIR}
    rm -rf dist

    if [ -f ./tsconfig.json ]
    then
        # just build the local tsconfig
        info "${BOLD_WHITE}tsc${NC} running with local function config"
        npx tsc
    elif [ -f ${PROJECT_ROOT}/tsconfig.lambda.json ]
    then
        # use the global repo tsconfig
        info "${BOLD_WHITE}tsc${NC} running with project level config"
        ln -s "${PROJECT_ROOT}/tsconfig.lambda.json" tsconfig.lambda.json
        npx tsc --project tsconfig.lambda.json
        rm tsconfig.lambda.json
    else
        fail "cannot find local tsconfig.json or project level tsconfig.lambda.json"
    fi
}

function bundle_dependencies() {
    local outputDir="${PROJECT_ROOT}/cloud-functions/${WORKSPACE_DIR}/dist"
    [ -d "${outputDir}" ] || fail "no build output present for ${BOLD_WHITE}${WORKSPACE_NAME}${NC}"

    cd ${outputDir}
    info "pulling production dependencies"
    ln -s ../package.json package.json
    npm install --omit=dev --ignore-scripts > /dev/null 2>&1
    rm package*.json
}

function bundle_lambda() {
    local version="$( cat "${PROJECT_ROOT}/cloud-functions/${WORKSPACE_DIR}/package.json" | jq .version -r )"
    local filename="bundle-${version}.zip"

    cd ${PROJECT_ROOT}/cloud-functions/${WORKSPACE_DIR}/dist
    info "zipping up function into ${BOLD_WHITE}${filename}${NC}"

    [ -f "../${filename}" ] && rm "../${filename}"
    zip -r -X "../${filename}" . > /dev/null 2>&1
}

if [ "$#" -gt 0 ]
then
    CMD=${1} && shift
    case "${CMD}" in
        build )
            build_lambda
            bundle_dependencies
            bundle_lambda
            ;;

        * )
            usage
    esac
else
    usage
fi