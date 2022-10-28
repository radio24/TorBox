"""
WSGI config for chatsecure project.

It exposes the WSGI callable as a module-level variable named ``application``.

For more information on this file, see
https://docs.djangoproject.com/en/3.1/howto/deployment/wsgi/
"""

import os
import socketio
import eventlet
import socket

from django.core.wsgi import get_wsgi_application
from django.conf import settings

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'chatsecure.settings')

application = get_wsgi_application()
app_socket = (f"unix:/var/run/tcs_{settings.INSTANCE_NAME}.sock",)
app_socket_family = socket.AF_UNIX

if settings.DEBUG:
    # dev
    from django.contrib.staticfiles.handlers import StaticFilesHandler
    application = StaticFilesHandler(get_wsgi_application())
    app_socket = ('127.0.0.1', 8010)
    app_socket_family = socket.AF_INET

from apps.socketio_app.views import sio
application = socketio.WSGIApp(sio, application)
# eventlet.wsgi.server(eventlet.listen(('127.0.0.1', 8010)), application)
# eventlet.wsgi.server(
#         sock=eventlet.listen(app_socket),
#         site=application
#     )
