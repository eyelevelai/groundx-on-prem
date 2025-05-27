_mysql: &mysql
  ro_addr: ${dbRO}
  rw_addr: ${dbRW}
  user: ${dbServiceUser}
  password: ${dbServiceUserPassword}
  database: ${dbName} 
  maxIdle: 5
  maxOpen: 10

ai:
  aws:
    search:
      baseURL: ${searchBaseUrl}
      index: ${searchIndex}
      languages:
%{ for language in jsondecode(languages) ~}
        - ${language}
%{ endfor ~}
      username: ${searchUser}
      password: ${searchPassword}
  eyelevelSearch:
    apiKey: ${groundxServiceKey}
    baseURL: http://${rankerService}.${namespace}.svc.cluster.local
  layout:
    client:
      apiKey: ${groundxServiceKey}
      baseURL: http://${layoutService}.${namespace}.svc.cluster.local
      callbackURL: http://${layoutWebhookService}.${namespace}.svc.cluster.local
  openai:
    apiKey: ${summaryApiKey}
    baseURL: ${summaryBaseUrl}
    defaultKitId: 0
  summaryType: ${summaryService}
  searchIndexes:
    ${searchIndex}:
      languages:
%{ for language in jsondecode(languages) ~}
        - ${language}
%{ endfor ~}
%{ if engineCount > 0 ~}

engines:
%{ for engine in jsondecode(engines) ~}
  ${engine.engineID}: 
    engineID: "${engine.engineID}"
%{ if engine.apiKey != null ~}
    apiKey: "${engine.apiKey}"
%{ endif ~}
%{ if engine.baseURL != null ~}
    baseURL: "${engine.baseURL}"
%{ endif ~}
%{ if engine.maxInputTokens != null ~}
    maxInputTokens: ${engine.maxInputTokens}
%{ endif ~}
%{ if engine.maxRequests != null ~}
    maxRequests: ${engine.maxRequests}
%{ endif ~}
%{ if engine.maxTokens != null ~}
    maxTokens: ${engine.maxTokens}
%{ endif ~}
%{ if engine.requestLimit != null ~}
    requestLimit: ${engine.requestLimit}
%{ endif ~}
%{ if engine.type != null ~}
    type: "${engine.type}"
%{ endif ~}
    vision: ${engine.vision}
%{ endfor ~}

%{ endif ~}
environment: prod

groundxServer:
  baseURL: http://${groundxService}.${namespace}.svc.cluster.local
  port: 8080
  serviceName: ${groundxService}

init:
  ingestOnly: ${ingestOnly}
  mysql:
    user: ${dbCreateDBUser}
    password: ${dbCreateDBPassword}
  search:
    password: ${searchRootPassword}
    searchModel: all_access
    username: admin

integrationTests:
  search:
    duration: 3660
    fileId: ey-mtr6hapxq7d94zigammwir6xz4
    modelId: 1

layoutWebhookServer:
  baseURL: http://${layoutWebhookService}.${namespace}.svc.cluster.local
  port: 8080
  serviceName: ${layoutWebhookService}

kafka:
  filePreProcess:
    broker: ${streamBaseUrl}
    groupId: ${namespace}-${streamService}
    topic: ${preProcessQueue}
  fileProcess:
    broker: ${streamBaseUrl}
    groupId: ${namespace}-${streamService}
    topic: ${processQueue}
  fileSummaryDev:
    broker: ${streamBaseUrl}
    groupId: ${namespace}-${streamService}
    topic: ${summaryClientQueue}
  fileSummaryProd:
    broker: ${streamBaseUrl}
    groupId: ${namespace}-${streamService}
    topic: ${summaryClientQueue}
  fileUpdate:
    broker: ${streamBaseUrl}
    groupId: ${namespace}-${streamService}
    topic: ${queueQueue}
  fileUpload:
    broker: ${streamBaseUrl}
    groupId: ${namespace}-${streamService}
    topic: ${uploadQueue}

metrics:
  active: true
  api:
%{ for a in jsondecode(metrics.api) ~}
    - name: ${a.name}
%{ endfor ~}
  document:
    tokensPerMinute: ${metrics.documentTPM}
  inference:
%{ for a in jsondecode(metrics.inference) ~}
    - name: ${a.name}
%{ if a.tokensPerMinute != null ~}
      tokensPerMinute: ${a.tokensPerMinute}
%{ endif ~}
%{ endfor ~}
  page:
    tokensPerMinute: ${metrics.pageTPM}
  queue:
%{ for a in jsondecode(metrics.queue) ~}
    - name: ${a.name}
%{ if a.target != null ~}
      target: ${a.target}
%{ endif ~}
%{ if a.threshold != null ~}
      threshold: ${a.threshold}
%{ endif ~}
%{ endfor ~}
  session:
    addr: ${metrics.cacheAddr}:${metrics.cachePort}
    notCluster: ${metrics.cacheNotCluster}
  summaryRequest:
    tokensPerMinute: ${metrics.summaryRequestTPM}
  task:
%{ for a in jsondecode(metrics.task) ~}
    - name: ${a.name}
%{ if a.target != null ~}
      target: ${a.target}
%{ endif ~}
%{ if a.threshold != null ~}
      threshold: ${a.threshold}
%{ endif ~}
%{ endfor ~}

metricsServer:
  baseURL: http://${metrics.service}.${namespace}.svc.cluster.local
  port: 8080
  serviceName: ${metrics.service}
  sslCACert: ${sslCACert}
  sslCert: ${sslCert}
  sslKey: ${sslKey}
  sslPort: 8443

owner:
  baseURL: http://${groundxService}.${namespace}.svc.cluster.local/api/v1
  name: on-prem
  type: ${deploymentType}
  username: ${groundxUsername}

preProcessFileServer:
  baseURL: http://${preProcessService}.${namespace}.svc.cluster.local
  maxConcurrent: ${preProcessQueueSize}
  port: 8080
  serviceName: ${preProcessService}

processFileServer:
  baseURL: http://${processService}.${namespace}.svc.cluster.local
  maxConcurrent: ${processQueueSize}
  port: 8080
  serviceName: ${processService}

processors:%{ if ingestOnly }
  extraPostDefaults:
    - processorID: 1
      type: skip-generate%{ endif }
  convert: [11]
  layout: [3]
  map: [4]
  saveFile: [2]
  skipConvert: [12]
  skipGenerate: [1]
  skipLayout: [5]
  skipMap: [6]
  skipSummarize: [7]
  summarize: [8]
  summarizeChunks: [10]
  summarizeSections: [9]

queueFileServer:
  baseURL: http://${queueService}.${namespace}.svc.cluster.local
  maxConcurrent: ${queueQueueSize}
  pollTime: 1
  port: 8080
  serviceName: ${queueService}

rec:
  mysql: *mysql
  session:
    addr: ${cacheAddr}:${cachePort}
    notCluster: ${cacheNotCluster}

ssp:
  baseURL: http://${dashboardService}.${namespace}.svc.cluster.local
  dashboardURL: http://${dashboardService}.${namespace}.svc.cluster.local

summaryServer:
  baseURL: http://${summaryService}.${namespace}.svc.cluster.local
  maxConcurrent: ${summaryClientWorkers}
  port: 8080
  serviceName: ${summaryClientService}

upload:
  baseDomain: ${fileBaseDomain}
  baseUrl: ${fileSSL ? "https" : "http"}://${fileBaseDomain}
  bucket: ${uploadBucket}
  bucketUrl: ${fileSSL ? "https" : "http"}://${fileBaseDomain}
  id: ${fileUsername}
  secret: ${filePassword}
  service: minio
  ssl: ${fileSSL}

uploadFileServer:
  baseURL: http://${uploadService}.${namespace}.svc.cluster.local
  maxConcurrent: ${uploadQueueSize}
  port: 8080
  serviceName: ${uploadService}