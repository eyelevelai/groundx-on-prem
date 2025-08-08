
[program:celery_worker_${worker_number}]
command=celery -A ranker.celery.appSearch worker -n %(ENV_POD_NAME)s-w${worker_number} --loglevel=INFO --concurrency=1 --queues=${queues}
environment=
    CELERY_WORKER_NAME="%(ENV_POD_NAME)s-w${worker_number}",
    LOCAL=0,
    PYTHONUNBUFFERED="1"
autostart=true
autorestart=true
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0