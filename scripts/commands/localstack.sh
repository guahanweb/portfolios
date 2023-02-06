function usage() {
    echo "${CYAN}usage:${NC} ${programName} localstack <command> [...options]"
}

if [ "$#" -gt 0 ]
then
    CMD=${1} && shift
    case "${CMD}" in
        start )
            info "starting localstack in the background."
            LOCALSTACK_DOCKER_NAME=portfolios_localstack docker-compose -f "${DIR}/docker-compose.yml" up --detach
            ok "running. to stop: ${BOLD_WHITE}${programName} locastack stop${NC}"
            ;;

        stop )
            info "stopping localstack if running."
            docker-compose -f "${DIR}/docker-compose.yml" down
            ok "done"
            ;;

        restart )
            info "restarting localstack and removing volume..."
            docker-compose -f "${DIR}/docker-compose.yml" down
            rm -rf ${DIR}/volume > /dev/null 2>&1
            LOCALSTACK_DOCKER_NAME=portfolios_localstack docker-compose -f "${DIR}/docker-compose.yml" up --detach
            ok "running. to stop: ${BOLD_WHITE}${programName} locastack stop${NC}"
            ;;

        create )
            source ${DIR}/commands/localstack/create.sh
            ;;

        * )
            usage
    esac
else
    usage
fi
