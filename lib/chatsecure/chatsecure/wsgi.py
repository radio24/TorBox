"""
WSGI config for chatsecure project.

It exposes the WSGI callable as a module-level variable named ``application``.

For more information on this file, see
https://docs.djangoproject.com/en/3.1/howto/deployment/wsgi/
"""

import os
import socketio

from django.core.wsgi import get_wsgi_application
from django.conf import settings

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'chatsecure.settings')

application = get_wsgi_application()

if settings.DEBUG:
    # dev
    from django.contrib.staticfiles.handlers import StaticFilesHandler
    application = StaticFilesHandler(get_wsgi_application())

from apps.socketio_app.views import sio
application = socketio.WSGIApp(sio, application)

import eventlet
eventlet.wsgi.server(eventlet.listen(('127.0.0.1', 8010)), application)
