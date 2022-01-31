import atexit
import imp

from apscheduler.schedulers.background import BackgroundScheduler

class Scheduler:
    def run_tasks(self):
        scheduler = BackgroundScheduler(timezone='UTC')

        # Tasks schedule
        scheduler.add_job(func=self.scan,
                          trigger="cron",
                          day_of_week="*",
                          hour="*",
                          minute="*",
                          second="*/5")

        scheduler.start()
        atexit.register(lambda: scheduler.shutdown())
    
    def scan(self):
        tfs = imp.load_source('tfs', 'tfs')
        tfs.restart_database()