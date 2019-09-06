LATEST_RELEASED_VERSION="$(printf "v%s.%s" "$(jq -r -c '.version.latestReleased.major' build_info.json)" \
                                           "$(jq -r -c '.version.latestReleased.minor' build_info.json)")"
TARGET_VERSION="$(printf "v%s.%s" "$(jq -r -c '.version.target.major' build_info.json)" \
                                  "$(jq -r -c '.version.target.minor' build_info.json)")"
APP_NAME="$(jq -r -c '.appName' build_info.json)"
DOCKER_USER_NAME="$(jq -r -c '.docker.user' build_info.json)"
export LATEST_RELEASED_VERSION
export TARGET_VERSION
export APP_NAME
export DOCKER_USER_NAME
export DOCKER_REPO_NAME="${DOCKER_USER_NAME}/${APP_NAME}"