import atexit
import imp
from django.conf import settings
from apscheduler.schedulers.background import BackgroundScheduler


class Scheduler:
    def run_tasks(self):
        scheduler = BackgroundScheduler(timezone="UTC")

        # Tasks schedule
        scheduler.add_job(func=self.scan, trigger="interval", seconds=10)

        scheduler.start()
        atexit.register(lambda: scheduler.shutdown())

    def scan(self):
        tfs = imp.load_source("tfs", f"{settings.BASE_DIR}/tfs")
        tfs.restart_database()
