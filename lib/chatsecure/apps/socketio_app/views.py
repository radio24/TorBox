import json
import socketio

from django.shortcuts import redirect

from apps.chat.models import UserChat

# Create your views here.
sio = socketio.Server(async_mode="eventlet")


def index(request):
    return redirect("index")


@sio.on("auth")
def auth(sid, data):
    nick = data["nick"]
    pub_key = data["pub_key"]

    # Check user on db
    user = UserChat.objects.filter(nick=nick, pub_key=pub_key).first()
    if user:
        user.sid = sid
        user.save()

        room_name = user.nick

        # Enter room
        sio.enter_room(sid, room_name)
        sio.emit("user-connected", data)
    else:
        print(f"[**] ERROR CONNECT [{nick}] => [{pub_key}]")


@sio.on("message")
def message(sid, data):
    # Who sent the message
    user = UserChat.objects.filter(sid=sid).first()
    if user:
        nick = data["nick"]
        data["nick"] = user.nick
        sio.emit("message", data, room=nick)
