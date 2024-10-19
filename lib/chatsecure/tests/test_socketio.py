import pgpy
from tests.test_login import get_test_keys
from chatsecure.app import socketio
from chatsecure.models import User, Group, UserMessage, GroupMessage


def test_connect(app, client, test_db):
    # Load keys
    keys = get_test_keys()

    # Login client
    data = {
        "name": "client1",
        "pubkey": keys["client1"]["pubkey"]
    }
    r = client.post("/login", json=data)
    assert r.status_code == 200

    token = r.json["token"]

    c = socketio.test_client(app, auth={"token": token})
    assert c.is_connected() == True


def test_chat_message(app, client, test_db):
    # Load keys
    keys = get_test_keys()

    # Login client 1
    data = {
        "name": "client1",
        "pubkey": keys["client1"]["pubkey"]
    }
    r = client.post("/login", json=data)
    assert r.status_code == 200
    token1 = r.json['token']
    user1 = User.get(User.token == token1)

    # Login client2
    data = {
        "name": "client2",
        "pubkey": keys["client2"]["pubkey"]
    }
    r = client.post("/login", json=data)
    assert r.status_code == 200
    token2 = r.json['token']
    user2 = User.get(User.token == token2)

    # Connect to socketio
    client1 = socketio.test_client(app, auth={"token": token1})
    client2 = socketio.test_client(app, auth={"token": token2})

    assert client1.is_connected() == True
    assert client2.is_connected() == True

    # Ignore new user event on client1
    client1.get_received()

    # Check new user event of client1
    data = client2.get_received()[0]
    assert data["name"] == "user_connected"
    assert data["args"][0]['fp'] == user2.fp

    # Prepare keys to send encrypted msg
    # client1
    pubkey1 = keys["client1"]["pubkey"]
    privkey1 = keys["client1"]["privkey"]

    # client 2
    pubkey2 = pgpy.PGPKey()
    pubkey2.parse(keys["client2"]["pubkey"])
    privkey2 = pgpy.PGPKey()
    privkey2.parse(keys["client2"]["privkey"])

    # encrypt msg
    msg_txt = "Testing message"
    msg = pgpy.PGPMessage.new(msg_txt)
    msg = str(pubkey2.encrypt(msg))

    # send encrypted msg
    data = {
        "sender": user1.id, "recipient": user2.id, "msg": msg, "is_group": 0
    }
    client1.emit("msg", data)

    # Check if new message on client2 is the one coming from client1
    data = client2.get_received()[0]
    assert data["name"] == "message"
    assert data["args"]["sender"] == user1.id
    assert data["args"]["msg"] == msg

    # Check if message has been added to database
    message = UserMessage.get(UserMessage.msg == msg)

    # Decrypt message
    msg_dec = pgpy.PGPMessage()
    msg_dec.parse(data["args"]["msg"])

    # Check if decrypted message is equal to sent message
    assert msg_txt == privkey2.decrypt(msg_dec).message
