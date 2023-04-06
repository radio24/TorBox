import json
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
            try:
                # load key
                pubkey = pgpy.PGPKey()
                pubkey.parse(pubkey_txt)
                fp = pubkey.fingerprint
                name = pubkey.userids[0].name
                email = pubkey.userids[0].email

                # some checks
                assert name == name_txt
                assert name.lower() == email.split("@")[0].lower()

                # if user is already registered, login
                user = User.filter(fp=fp)
                if user:
                    reply = {"id": user.id, "token": user.token}
                    return jsonify(reply)

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

            except Exception as e:  # noqa
                # print(e)
                return Response(status=400)

        else:
            return Response(status=400)


class UserListResource(Resource):
    method_decorators = [token_required]

    def get(self, **kwargs):
        """Return list of active users"""
        try:
            users = list(User.select(
                User.id,
                User.name,
                User.fp,
                User.pubkey,
                User.last_update,
                User.active
            ).filter(User.id != kwargs["user"].id).dicts())
        except Exception as e:  # noqa
            users = []

        # FIXME: datetime handle
        users = json.dumps(users, default=str)
        users = json.loads(users)

        return jsonify(users)


class GroupListResource(Resource):
    method_decorators = [token_required]

    def get(self, **kwargs):
        """Return list of active groups"""
        try:
            groups = list(Group.select().dicts())
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
            messages = list(
                GroupMessage
                .select()
                .where(
                    (GroupMessage.recipient == 1)
                    # & (GroupMessage.ts >= user.ts_join)
                )
                .order_by("-ts")
                .dicts()
            )
        except Exception as e:  # noqa
            messages = []

        return jsonify(messages)
