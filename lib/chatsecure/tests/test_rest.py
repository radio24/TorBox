from chatsecure.models import User, Group, UserMessage, GroupMessage


def test_list_users(client_auth, test_db):
    # Prepare users with keys
    # NOTE: this takes much time to test
    # s = string.ascii_lowercase
    # users = []
    # for i in range(0,3):
    #     name = ''.join(random.choice(s) for i in range(8))
    #     key = pgpy.PGPKey.new(PubKeyAlgorithm.RSAEncryptOrSign, 4096)
    #     uid = pgpy.PGPUID.new("client3", email=f'client3@torboxchatsecure.onion')
    #     key.add_uid(
    #         uid,
    #         usage={KeyFlags.Sign},
    #         hashes=[HashAlgorithm.SHA512, HashAlgorithm.SHA256],
    #         ciphers=[SymmetricKeyAlgorithm.AES256, SymmetricKeyAlgorithm.Camellia256],
    #         compression=[CompressionAlgorithm.BZ2, CompressionAlgorithm.Uncompressed],
    #         key_expiration=timedelta(minutes=1)
    #     )
    #
    #     print(str(key))
    #     print(str(key.pubkey))
    #     quit()
    #     pubkey = str(key.pubkey)
    #     user = {"name": name, "pubkey": pubkey}
    #     users.append(user)

    # Get all users
    users = list(User.select().dicts())

    # Get user list to api rest
    r = client_auth.get("/users")
    assert r.status_code == 200

    data = r.json
    assert len(data) > 0

    # Compare with local list
    for u in data:
        assert any(user for user in users if user["name"] == u["name"])


def test_group_list(client_auth, test_db):
    # TODO: Integration not ready.
    assert 1 == 1
    return
    # Create default group
    # g = Group.create(name="default")

    # Test /groups endpoint
    r = client_auth.get("/groups")
    assert r.status_code == 200

    print(r.text)
    data = r.json
    assert len(data) > 0

    assert data[0]["name"] == "default"

def test_user_message_list(client_auth, test_db):
    # Get users
    users = User.select()

    # Create a small talk between 2 users
    UserMessage.create(sender=users[0].id, recipient=users[1].id, msg="Hello")
    UserMessage.create(sender=users[1].id, recipient=users[0].id, msg="Hi")
    UserMessage.create(sender=users[0].id, recipient=users[1].id, msg="How are you?")
    UserMessage.create(sender=users[1].id, recipient=users[0].id, msg="I'm fine thanks")

    # New user talks to user 1
    UserMessage.create(sender=users[2].id, recipient=users[0].id, msg="Hello?")

    # Get list of messages with user 2
    r = client_auth.get("/user_msg/2")
    assert r.status_code == 200

    data = r.json
    assert len(data) == 4

    # Get list of messages with user 3
    r = client_auth.get("/user_msg/3")
    assert r.status_code == 200

    data = r.json
    assert len(data) == 1

def test_group_message_list(client_auth, test_db):
    # Get users
    users = User.select()

    # Create a small talk between 2 users
    GroupMessage.create(sender=users[0].id, recipient=1, msg="Hello")
    GroupMessage.create(sender=users[1].id, recipient=1, msg="Hi")
    GroupMessage.create(sender=users[0].id, recipient=1, msg="How are you?")
    GroupMessage.create(sender=users[1].id, recipient=1, msg="I'm fine thanks")
    GroupMessage.create(sender=users[2].id, recipient=1, msg="Hello all!")

    # Get group messages
    r = client_auth.get("/group_msg")
    assert r.status_code == 200

    data = r.json
    assert len(data) == 5
