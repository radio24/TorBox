import json
from flask import request
from flask_socketio import emit, join_room, send

from chatsecure.app import socketio
from chatsecure.models import User, Group, UserMessage, GroupMessage

import logging
logging.basicConfig(level=logging.DEBUG)


# --------------------------------------------------------------------------------------
# USER EVENTS
# --------------------------------------------------------------------------------------
@socketio.on("msg")
def on_msg(data):
    """Message to User or Group"""
    # sender, recipient, msg, is_group
    sender = User.get(User.id == data["sender"])
    if not sender:
        return

    # msg for socket
    msg = {
        "sender": sender.id,
        "msg": data["msg"]
    }

    is_group = bool(data["is_group"])
    recipient = None
    if is_group:
        # recipient = Group.get(Group.id == data["recipient"])
        recipient = Group.get(Group.id == 1)
        msg["recipient"] = recipient.name
    else:
        recipient = User.get(User.id == data["recipient"])
        msg["recipient"] = recipient.id

    if not recipient:
        return

    # msg for db
    msg_db = msg.copy()
    msg_db["sender"] = sender
    msg_db["recipient"] = recipient

    if is_group:
        # send message to group
        gm = GroupMessage.create(**msg_db)
        del msg_db["recipient"]  # only one group available
        msg["id"] = gm.id
        msg["ts"] = gm.ts
        # FIXME: datetime handle
        msg = json.dumps(msg, default=str)
        msg = json.loads(msg)
        send(msg, to="default")
    else:
        # Send message to user inbox
        um = UserMessage.create(**msg_db)
        msg["id"] = um.id
        msg["ts"] = um.ts
        # FIXME: datetime handle
        msg = json.dumps(msg, default=str)
        msg = json.loads(msg)
        send(msg, to=recipient.fp)


# --------------------------------------------------------------------------------------
# SERVER EVENTS
# --------------------------------------------------------------------------------------
@socketio.on("connect")
def on_connect(auth=None):
    if not auth:
        return False


    # auth is a token. Check against db
    user = User.get(User.token == auth["token"])
    if not user.name:
        return False

    # if not user.active:
    #     return

    # Store sid for reference
    user.sid = request.sid

    # User is connecting, so it should be active now
    user.active = True

    user.save()

    user_data = {
        'fp': user.fp,
        'id': user.id,
        'last_update': user.last_update,
        'name': user.name,
        'pubkey': user.pubkey,
        'active': user.active,
    }

    # FIXME: handle datetime
    user_data = json.dumps(user_data, default=str)
    user_data = json.loads(user_data)

    # emit("new_user", {'data': user.fp}, broadcast=True)
    emit("user_connected", user_data, broadcast=True)

    # Group chat
    join_room("default")

    # Personal inbox
    join_room(user.fp)


@socketio.on("disconnect")
def on_disconnect():
    user = User.get(sid=request.sid)
    emit("user_disconnected", {"id": user.id}, broadcast=True)
    # user.delete_instance()
    user.sid = None
    user.active = False
    user.save()




