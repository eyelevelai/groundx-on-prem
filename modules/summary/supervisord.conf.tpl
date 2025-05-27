
[program:celery_worker_${worker_number}]
command=celery -A summary.celery_inference.appSummary worker -n %(ENV_POD_NAME)s-w${worker_number} --loglevel=INFO --concurrency=${threads} --queues=${queues} --pool=solo
environment=CELERY_WORKER_NAME="%(ENV_POD_NAME)s-w${worker_number}"
autostart=true
autorestart=true
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0

[program:celery_monitor]
command=python /workspace/summary_monitor.py
autostart=true
autorestart=true
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0

[program:celery_health]
command=python /workspace/summary_health.py
autostart=true
autorestart=true
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0