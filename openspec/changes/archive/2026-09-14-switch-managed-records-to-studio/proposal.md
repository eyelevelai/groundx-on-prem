# Move managed production records to Studio

## Why

Keep new Studio app records off the core production database by using the existing groundx-studio Aurora cluster. It currently serves Sterling development. No existing app data or credentials are to be moved or rotated.

## Scope and impact

Account 903713046261, us-west-2, EKS eyelevel_890ng3. Replace only the production managed-records connection in the Workspace-specific Secret and restart the six Workspace deployments. Preserve development storage, production S3/cache, application images, Sterling, and core services. Check that no production managed-record allocations exist before switching; otherwise stop for a migration decision.

Give groundx-studio a dedicated security group accepting MySQL from the verified EKS worker group and the existing operator IP only. Preserve the current public endpoint for that verified operator path. Do not edit its shared security group. Enable deletion protection. Keep its existing single instance and 0.5 to 16 ACU range; no new database capacity is purchased. Added app usage can increase existing Aurora usage charges.

Create a dedicated TLS-required managed administrator on Studio, test allocation and deletion before switching, then verify the live runner and disposable app storage lifecycle. Existing credentials must not rotate.

## Recovery

Retain the old connection securely through validation. Restore that connection and restart only Workspace if the switch fails before any real allocations. Restore the original cluster security-group attachment if a verified existing client loses access. Never switch back across newly allocated real app data without a migration decision.

## Open design questions

None. The existing operator IP requires retaining a restricted public endpoint.
