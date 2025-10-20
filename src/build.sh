#!/usr/bin/env bash

rm build/*
helm package groundx -d build
helm package groundx/prereqs/kafka-cluster -d build
helm package groundx/prereqs/storageclass -d build
helm package opensearch -d build
helm repo index build --url https://registry.groundx.ai/helm
rm build/.DS_Store
aws s3 cp ./build s3://eyelevel-upload/helm/ --recursive
