#!/bin/bash

# ==========================================
# Multi-Platform Docker Build Script
# ==========================================

set -e

# Load environment variables from .env file
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/.env" ]]; then
    echo "Loading credentials from .env file..."
    export $(grep -v '^#' "${SCRIPT_DIR}/.env" | xargs)
fi

# Configuration - Can be set via .env file or environment variables
DOCKER_USERNAME="${DOCKER_USERNAME:-your-dockerhub-username}"
DOCKER_TOKEN="${DOCKER_TOKEN:-}"
IMAGE_NAME="${IMAGE_NAME:-php-laravel-base}"
PLATFORMS="linux/amd64,linux/arm64"

# PHP versions to build
PHP_VERSIONS=("8.2" "8.3" "8.4")

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}===========================================${NC}"
echo -e "${GREEN}  PHP Laravel Base Image Builder${NC}"
echo -e "${GREEN}===========================================${NC}"

# Check if logged in to Docker Hub
check_docker_login() {
    echo -e "\n${YELLOW}Checking Docker Hub authentication...${NC}"
    
    # If token is provided, login automatically
    if [[ -n "${DOCKER_TOKEN}" && -n "${DOCKER_USERNAME}" ]]; then
        echo -e "Logging in with credentials from .env..."
        echo "${DOCKER_TOKEN}" | docker login -u "${DOCKER_USERNAME}" --password-stdin
        echo -e "${GREEN}✓ Logged in as ${DOCKER_USERNAME}${NC}"
        return 0
    fi
    
    # Check if already logged in
    if ! docker info 2>/dev/null | grep -q "Username"; then
        echo -e "${YELLOW}You need to login to Docker Hub first${NC}"
        echo -e "Either:"
        echo -e "  1. Add DOCKER_USERNAME and DOCKER_TOKEN to .env file"
        echo -e "  2. Run: ${GREEN}docker login${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✓ Already logged in to Docker Hub${NC}"
}

# Setup buildx builder for multi-platform builds
setup_buildx() {
    echo -e "\n${YELLOW}Setting up Docker Buildx...${NC}"
    
    # Check if builder exists
    if ! docker buildx inspect multiplatform-builder &>/dev/null; then
        echo "Creating new buildx builder..."
        docker buildx create --name multiplatform-builder --driver docker-container --bootstrap
    fi
    
    docker buildx use multiplatform-builder
    echo -e "${GREEN}Buildx ready!${NC}"
}

# Build and push a specific PHP version
build_version() {
    local php_version=$1
    local full_tag="${DOCKER_USERNAME}/${IMAGE_NAME}:${php_version}"
    
    echo -e "\n${YELLOW}Building PHP ${php_version}...${NC}"
    echo -e "Image: ${full_tag}"
    echo -e "Platforms: ${PLATFORMS}"
    
    docker buildx build \
        --platform "${PLATFORMS}" \
        --build-arg PHP_VERSION="${php_version}" \
        --tag "${full_tag}" \
        --push \
        .
    
    echo -e "${GREEN}✓ PHP ${php_version} pushed successfully!${NC}"
}

# Build latest tag (points to highest PHP version)
build_latest() {
    local latest_version="${PHP_VERSIONS[-1]}"
    local latest_tag="${DOCKER_USERNAME}/${IMAGE_NAME}:latest"
    
    echo -e "\n${YELLOW}Building 'latest' tag (PHP ${latest_version})...${NC}"
    
    docker buildx build \
        --platform "${PLATFORMS}" \
        --build-arg PHP_VERSION="${latest_version}" \
        --tag "${latest_tag}" \
        --push \
        .
    
    echo -e "${GREEN}✓ Latest tag pushed successfully!${NC}"
}

# Build single version locally (for testing)
build_local() {
    local php_version="${1:-8.3}"
    local full_tag="${IMAGE_NAME}:${php_version}"
    
    echo -e "\n${YELLOW}Building PHP ${php_version} locally...${NC}"
    
    docker build \
        --build-arg PHP_VERSION="${php_version}" \
        --tag "${full_tag}" \
        .
    
    echo -e "${GREEN}✓ Local build complete: ${full_tag}${NC}"
}

# Build and push single platform (faster, for quick deployments)
# WARNING: This only builds for the local platform (arm64 on Mac, amd64 on Linux)
build_and_push_single() {
    local php_version="${1:-8.3}"
    local full_tag="${DOCKER_USERNAME}/${IMAGE_NAME}:${php_version}"
    
    echo -e "\n${YELLOW}Building and pushing PHP ${php_version} (single platform - LOCAL ARCH ONLY)...${NC}"
    echo -e "${RED}WARNING: This will only build for your local architecture!${NC}"
    echo -e "${RED}For multi-platform support (amd64+arm64), use: ${GREEN}./build.sh version ${php_version}${NC}"
    echo -e "Image: ${full_tag}"
    
    read -p "Continue with single-platform build? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Build cancelled. Use './build.sh version ${php_version}' for multi-platform build.${NC}"
        exit 1
    fi
    
    docker build \
        --build-arg PHP_VERSION="${php_version}" \
        --tag "${full_tag}" \
        .
    
    echo -e "\n${YELLOW}Pushing to Docker Hub...${NC}"
    docker push "${full_tag}"
    
    echo -e "${GREEN}✓ PHP ${php_version} pushed successfully!${NC}"
    echo -e "${YELLOW}Note: This image is only available for $(uname -m) architecture${NC}"
}

# Push an existing local image
# WARNING: This only pushes for the local platform architecture
push_image() {
    local php_version="${1:-8.3}"
    local local_tag="${IMAGE_NAME}:${php_version}"
    local remote_tag="${DOCKER_USERNAME}/${IMAGE_NAME}:${php_version}"
    
    echo -e "\n${YELLOW}Tagging and pushing ${local_tag}...${NC}"
    echo -e "${RED}WARNING: This will only push for your local architecture ($(uname -m))!${NC}"
    echo -e "${RED}For multi-platform support, rebuild using: ${GREEN}./build.sh version ${php_version}${NC}"
    
    # Tag the local image with remote name
    docker tag "${local_tag}" "${remote_tag}"
    
    # Push to Docker Hub
    echo -e "Pushing to: ${remote_tag}"
    docker push "${remote_tag}"
    
    echo -e "${GREEN}✓ Pushed ${remote_tag} successfully!${NC}"
    echo -e "${YELLOW}Note: This image is only available for $(uname -m) architecture${NC}"
}

# Push all local images
push_all() {
    echo -e "\n${YELLOW}Pushing all local images to Docker Hub...${NC}"
    
    for version in "${PHP_VERSIONS[@]}"; do
        local local_tag="${IMAGE_NAME}:${version}"
        if docker image inspect "${local_tag}" &>/dev/null; then
            push_image "${version}"
        else
            echo -e "${RED}✗ ${local_tag} not found locally, skipping...${NC}"
        fi
    done
    
    # Push latest if exists
    if docker image inspect "${IMAGE_NAME}:latest" &>/dev/null; then
        local remote_latest="${DOCKER_USERNAME}/${IMAGE_NAME}:latest"
        docker tag "${IMAGE_NAME}:latest" "${remote_latest}"
        docker push "${remote_latest}"
        echo -e "${GREEN}✓ Pushed latest tag${NC}"
    fi
    
    echo -e "\n${GREEN}All available images pushed!${NC}"
}

# Rebuild and push existing image for multi-platform support
rebuild_multiarch() {
    local php_version="${1:-8.3}"
    
    if [[ -z "${1:-}" ]]; then
        echo -e "${RED}Error: Please specify a PHP version${NC}"
        echo -e "Usage: $0 rebuild-multiarch <version>"
        echo -e "Example: $0 rebuild-multiarch 8.4"
        exit 1
    fi
    
    echo -e "\n${YELLOW}Rebuilding PHP ${php_version} for multi-platform support...${NC}"
    echo -e "This will rebuild and push for: ${PLATFORMS}"
    
    check_docker_login
    setup_buildx
    build_version "$php_version"
    
    echo -e "\n${GREEN}✓ Multi-platform rebuild complete!${NC}"
    echo -e "The image ${DOCKER_USERNAME}/${IMAGE_NAME}:${php_version} now supports both amd64 and arm64"
}

# Show usage
usage() {
    echo -e "\nUsage: $0 [command] [options]"
    echo -e "\nCommands:"
    echo -e "  ${GREEN}all${NC}                    Build and push all PHP versions (multi-platform: amd64+arm64)"
    echo -e "  ${GREEN}version <ver>${NC}          Build and push a specific version (multi-platform)"
    echo -e "  ${GREEN}latest${NC}                Build and push only the latest tag (multi-platform)"
    echo -e "  ${GREEN}local [ver]${NC}           Build locally for testing (default: 8.3)"
    echo -e "  ${GREEN}push [ver]${NC}            Push an existing local image to Docker Hub (single platform)"
    echo -e "  ${GREEN}push-all${NC}              Push all existing local images to Docker Hub (single platform)"
    echo -e "  ${GREEN}quick <ver>${NC}           Build and push single platform (faster, local arch only)"
    echo -e "  ${GREEN}rebuild-multiarch <ver>${NC} Rebuild existing image for multi-platform support"
    echo -e "  ${GREEN}setup${NC}                 Setup buildx builder only"
    echo -e "\nEnvironment Variables (set in .env file):"
    echo -e "  ${GREEN}DOCKER_USERNAME${NC}  Your Docker Hub username"
    echo -e "  ${GREEN}DOCKER_TOKEN${NC}     Your Docker Hub access token"
    echo -e "\nExamples:"
    echo -e "  $0 local 8.3              # Build locally for testing"
    echo -e "  $0 version 8.4            # Build and push 8.4 (multi-platform) ${GREEN}← RECOMMENDED${NC}"
    echo -e "  $0 rebuild-multiarch 8.4  # Fix existing 8.4 image (add amd64 support)"
    echo -e "  $0 quick 8.3              # Build and push 8.3 (single platform - local arch only)"
    echo -e "  $0 all                    # Build and push all versions (multi-platform)"
}

# Main script
main() {
    case "${1:-}" in
        all)
            check_docker_login
            setup_buildx
            for version in "${PHP_VERSIONS[@]}"; do
                build_version "$version"
            done
            build_latest
            echo -e "\n${GREEN}===========================================${NC}"
            echo -e "${GREEN}All images built and pushed successfully!${NC}"
            echo -e "${GREEN}===========================================${NC}"
            ;;
        version)
            if [[ -z "${2:-}" ]]; then
                echo -e "${RED}Error: Please specify a PHP version${NC}"
                usage
                exit 1
            fi
            check_docker_login
            setup_buildx
            build_version "$2"
            ;;
        latest)
            check_docker_login
            setup_buildx
            build_latest
            ;;
        local)
            build_local "${2:-8.3}"
            ;;
        push)
            check_docker_login
            push_image "${2:-8.3}"
            ;;
        push-all)
            check_docker_login
            push_all
            ;;
        quick)
            if [[ -z "${2:-}" ]]; then
                echo -e "${RED}Error: Please specify a PHP version${NC}"
                usage
                exit 1
            fi
            check_docker_login
            build_and_push_single "$2"
            ;;
        rebuild-multiarch)
            rebuild_multiarch "$2"
            ;;
        setup)
            setup_buildx
            ;;
        *)
            usage
            ;;
    esac
}

main "$@"
