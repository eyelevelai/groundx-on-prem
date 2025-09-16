helm package groundx -d build
helm package opensearch -d build
helm repo index build --url https://registry.groundx.ai/helm
