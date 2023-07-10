import pgpy
import pytest
import peewee as pw
from chatsecure.app import create_app
from chatsecure.models import User, UserMessage, GroupMessage, Group


def get_test_keys():
    privkey1_txt = open("tests/keys/client1/private.key", "r").read()
    privkey1 = pgpy.PGPKey()
    privkey1.parse(privkey1_txt)

    pubkey1_txt = open("tests/keys/client1/public.key", "r").read()
    pubkey1 = pgpy.PGPKey()
    pubkey1.parse(pubkey1_txt)

    privkey2_txt = open("tests/keys/client2/private.key", "r").read()
    privkey2 = pgpy.PGPKey()
    privkey2.parse(privkey2_txt)

    pubkey2_txt = open("tests/keys/client2/public.key", "r").read()
    pubkey2 = pgpy.PGPKey()
    pubkey2.parse(pubkey2_txt)

    privkey3_txt = open("tests/keys/client3/private.key", "r").read()
    privkey3 = pgpy.PGPKey()
    privkey3.parse(privkey3_txt)

    pubkey3_txt = open("tests/keys/client3/public.key", "r").read()
    pubkey3 = pgpy.PGPKey()
    pubkey3.parse(pubkey3_txt)

    keys = {
        "client1": {
            "privkey": str(privkey1),
            "pubkey": str(pubkey1),
        },
        "client2": {
            "privkey": str(privkey2),
            "pubkey": str(pubkey2),
        },
        "client3": {
            "privkey": str(privkey3),
            "pubkey": str(pubkey3),
        },
    }
    return keys


@pytest.fixture()
def app():
    """Flask app"""
    app = create_app()
    app.config.update({
        "TESTING": True,
    })

    yield app


@pytest.fixture()
def client(app):
    """Flask client"""
    return app.test_client()


@pytest.fixture()
def client_auth(app, client, test_db):
    """Flask client authorized"""
    keys = get_test_keys()

    token = None
    # Login clients
    for i in range(1,4):
        data = {
            "name": f"client{i}",
            "pubkey": keys[f"client{i}"]["pubkey"]
        }
        r = client.post("/login", json=data)
        assert r.status_code == 200

        # Save one token (client1)
        if not token:
            token = r.json.get("token", False)

    # Create default channel
    Group.create(name="default")

    client = app.test_client()
    client.environ_base['HTTP_AUTHORIZATION'] = f"Token {token}"
    return client


@pytest.fixture()
def test_db():
    """Setup Database"""
    db = pw.SqliteDatabase(":memory:")
    tbl = (User, UserMessage, GroupMessage, Group)
    with db.bind_ctx(tbl):
        db.create_tables(tbl)
        try:
            yield test_db
        finally:
            db.drop_tables(tbl)