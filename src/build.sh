rm build/.DS_Store
helm package groundx -d build
helm package opensearch -d build
helm repo index build --url https://registry.groundx.ai/helm
aws s3 cp ./build s3://eyelevel-upload/helm/ --recursive
