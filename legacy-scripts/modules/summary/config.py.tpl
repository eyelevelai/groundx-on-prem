env = dict(
    deviceType="${deviceType}",
    deviceUtilize=${deviceUtilize},
    metricsAddr="${metricsAddr}",
    metricsPort=${metricsPort},
    service="${summaryService}",
    summaryBroker="redis://${cacheAddr}:${cachePort}/0",
    summaryResultBroker="redis://${cacheAddr}:${cachePort}/0",
    summaryLog="${summaryService}",
    validAPIKeys=["${validAPIKey}", "${validUsername}"],
    workers=${workers},
)
