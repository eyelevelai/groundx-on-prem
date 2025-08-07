
[program:celery_worker_${worker_number}]
command=LOCAL=0 celery -A ranker.celery.appSearch worker -n %(ENV_POD_NAME)s-w${worker_number} --loglevel=INFO --concurrency=1 --queues=${queues}
autostart=true
autorestart=true
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0