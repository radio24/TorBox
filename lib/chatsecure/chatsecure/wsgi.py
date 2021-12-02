"""
WSGI config for chatsecure project.

It exposes the WSGI callable as a module-level variable named ``application``.

For more information on this file, see
https://docs.djangoproject.com/en/3.1/howto/deployment/wsgi/
"""

import os

from django.core.wsgi import get_wsgi_application
from django.conf import settings

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'chatsecure.settings')

if not settings.DEBUG:
    application = get_wsgi_application()
else:
    import socketio
    from django.contrib.staticfiles.handlers import StaticFilesHandler
    from apps.socketio_app.views import sio
    # sio = socketio.Server(async_mode='eventlet')
    application = StaticFilesHandler(get_wsgi_application())
    application = socketio.WSGIApp(sio, application)

    import eventlet

    eventlet.wsgi.server(eventlet.listen(('', 8010)), application)
