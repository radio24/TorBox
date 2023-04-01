import json
import pgpy
import hashlib
from flask import jsonify, Response, current_app
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

    is_group = bool(data["is_group"])
    recipient = None
    if is_group:
        # recipient = Group.get(Group.id == data["recipient"])
        recipient = Group.get(Group.id == 1)
    else:
        recipient = User.get(User.id == data["recipient"])

    if not recipient:
        return

    # msg for socket
    msg = {
        "sender": sender.id,
        "recipient": recipient,
        "msg": data["msg"]
    }

    # msg for db
    msg_db = msg.copy()
    msg_db["sender"] = sender
    msg_db["recipient"] = recipient

    if is_group:
        # send message to group
        send(msg, to="default")
        GroupMessage.create(**msg_db)
    else:
        # Send message to user inbox
        send(msg, to=recipient.fp)
        UserMessage.create(**msg_db)


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

    user_data = {
        'fp': user.fp,
        'id': user.id,
        'last_update': user.last_update,
        'name': user.name,
        'pubkey': user.pubkey,
    }
    user_data = json.dumps(user_data, default=str)

    # emit("new_user", {'data': user.fp}, broadcast=True)
    emit("new_user", user_data, broadcast=True)

    # Group chat
    join_room("default")

    # Personal inbox
    join_room(user.fp)




