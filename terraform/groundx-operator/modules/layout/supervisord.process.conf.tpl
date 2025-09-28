
[program:celery_worker_${worker_number}]
command=celery -A document.celery_process.app worker -n %(ENV_POD_NAME)s-w${worker_number} --loglevel=INFO --queues=${queues} --concurrency=${threads}
environment=
    LOCAL=0,
    PYTHONUNBUFFERED="1"
autostart=true
autorestart=true
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0