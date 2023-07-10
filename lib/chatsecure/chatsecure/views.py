import json

import peewee
import pgpy
import hashlib
from flask import Blueprint, request, jsonify, Response, current_app, render_template
from flask_restful import Resource, reqparse
from chatsecure.models import User, Group, UserMessage, GroupMessage

bp = Blueprint("index", __name__)
@bp.route("/")
def index():
    return render_template("index.html")


def token_required(func):
    """Decorator to authenticate users with api"""
    def decorator(*args, **kwargs):
        if 'AUTHORIZATION' in request.headers:
            auth = request.headers['AUTHORIZATION']
            auth_method, token = auth.split(" ")

            if auth_method.lower() != "token":
                return Response(status=401)

            current_user = User.filter(token=token).get()
            if not current_user:
                return Response(status=401)
            else:
                kwargs["user"] = current_user
                return func(*args, **kwargs)
        else:
            return Response(status=401)
    return decorator


class LoginResource(Resource):
    def post(self):
        """Receive user and pubkey and store in db"""
        parser = reqparse.RequestParser()
        parser.add_argument('name', type=str)
        parser.add_argument('pubkey', type=str)
        args = parser.parse_args()

        # data = request.json
        name_txt = args.get("name", None)
        pubkey_txt = args.get("pubkey", None)
        if name_txt and pubkey_txt:
            # try:
            # load key
            try:
                pubkey = pgpy.PGPKey()
                pubkey.parse(pubkey_txt)
                fp = pubkey.fingerprint
            except:
                return Response(status=400)
            name = pubkey.userids[0].name
            email = pubkey.userids[0].email

            # some checks
            # assert name == name_txt
            # assert name.lower() == email.split("@")[0].lower()

            # if user is already registered, login
            user = User.filter(User.fp == fp)
            if user:
                user = list(user.dicts())[0]
                print(user)
                reply = {"id": user["id"], "token": user["token"]}
                return jsonify(reply)
            del user

            # There can be only one unique name online
            user = User.filter((User.name == name) & (User.active == True))
            if user:
                return Response(status=403)

            # generate token
            s = str(fp + current_app.config["SECRET_KEY"]).encode("utf-8")
            token = hashlib.sha1(s).hexdigest()
            # add to db
            new_user = User.create(
                name=name,
                pubkey=pubkey_txt,
                fp=fp,
                token=token,
            )
            new_user.save()
            reply = {"id": new_user.id, "token": token}
            return jsonify(reply)

            # except Exception as e:  # noqa
            #     # print(e)
            #     return Response(status=400)

        else:
            return Response(status=400)


class UserListResource(Resource):
    method_decorators = [token_required]

    def get(self, **kwargs):
        """Return list of active users"""
        try:
            last_message = (
                UserMessage.select(
                    UserMessage.recipient,
                    UserMessage.sender,
                    UserMessage.msg,
                )
                .filter(UserMessage.recipient == kwargs["user"].id)
                .order_by(-UserMessage.id)
                .limit(1)
            )

            users = list(
                User.select(
                    User.id,
                    User.name,
                    User.fp,
                    User.pubkey,
                    User.last_update,
                    User.active,
                    last_message.c.msg
                )
                .join(
                    last_message,
                    peewee.JOIN.LEFT_OUTER,
                    on=(User.id == last_message.c.sender_id),
                )
                .filter(
                    (User.id != kwargs["user"].id) & (User.active == True)
                 )
                .dicts()
            )

        except Exception as e:  # noqa
            print("Exception: {}".format(e))
            users = []

        # FIXME: datetime handle
        users = json.dumps(users, default=str)
        users = json.loads(users)

        return jsonify(users)


class GroupListResource(Resource):
    method_decorators = [token_required]

    def get(self, **kwargs):
        """Return list of active groups"""

        # TODO: Integration not ready.
        return Response(status=501)
        try:
            last_message = (
                GroupMessage.select(
                    GroupMessage.recipient,
                    GroupMessage.sender,
                    GroupMessage.msg,
                )
                .filter(GroupMessage.recipient == kwargs["user"].id)
                .order_by(-GroupMessage.id)
                .limit(1)
            )
            groups = list(
                Group.select()
                .join(
                    last_message,
                    peewee.JOIN.LEFT_OUTER,
                    on=(User.id == last_message.c.sender_id),
                )
                .dicts())
        except Exception as e:  # noqa
            groups = []

        return jsonify(groups)


class UserMessageResource(Resource):
    method_decorators = [token_required]

    def get(self, sender_id, **kwargs):
        """Get list of messages with a specific user"""
        try:
            recipient_id = kwargs["user"].id
            messages = list(
                UserMessage
                .select()
                .where(
                    ((UserMessage.sender == sender_id) & (UserMessage.recipient == recipient_id))
                    | ((UserMessage.sender == recipient_id) & (UserMessage.recipient == sender_id))
                )
                .order_by(UserMessage.ts)
                .dicts()
            )
        except Exception as e:  # noqa
            messages = []

        return jsonify(messages)


class GroupMessageResource(Resource):
    method_decorators = [token_required]

    def get(self, group_id="default", **kwargs):
        """Get list of messages in group"""
        try:
            user = kwargs["user"]
            active_users = list(
                User
                .select(User.id)
                .where(
                    (User.active == 1)
                )
                .dicts()
            )
            active_users = [u["id"] for u in active_users]

            messages = list(
                GroupMessage
                .select()
                .where(
                    # (GroupMessage.recipient == 1) &
                    ((GroupMessage.ts >= user.ts_join) &
                    (GroupMessage.sender << active_users))
                )
                .order_by(GroupMessage.id)
                # .limit(100)
                .dicts()
            )
            if len(messages) > 100:
                messages = messages[-100:]

        except Exception as e:  # noqa
            print("EXCEPTION!!!: {}".format(e))
            messages = []

        return jsonify(messages)
