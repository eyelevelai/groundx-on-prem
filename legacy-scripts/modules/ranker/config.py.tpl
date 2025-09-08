env = dict(
    deviceType="${deviceType}",
    metricsAddr="${metricsAddr}",
    metricsPort=${metricsPort},
    searchBroker="redis://${cacheAddr}:${cachePort}/0",
    searchResultBroker="redis://${cacheAddr}:${cachePort}/0",
    searchLog="${rankerService}",
    service="${rankerService}",
    validAPIKeys=["${validAPIKey}", "${validUsername}"],
    workers=${workers},
)
