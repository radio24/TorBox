from tests.fixtures import app, client, test_db, get_test_keys

def test_login_success(app, client, test_db):
    """Test a valid login"""
    keys = get_test_keys()

    data = {
        "name": "client1",
        "pubkey": keys["client1"]["pubkey"]
    }
    r = client.post("/login", json=data)
    assert r.status_code == 200

    id = r.json.get("id", False)
    assert id != False

    token = r.json.get("token", False)
    assert token != False


def test_login_fail(client):
    """Fail login, without pubkey"""
    data = {
        "name": "hacky'boy",
    }
    r = client.post("/login", json=data)

    assert r.status_code == 400


def test_login_fail_pubkey(client):
    """Fail login, with wrong pubkey"""
    data = {
        "name": "torbox",
        "pubkey": "hacky'boy"
    }
    r = client.post("/login", json=data)

    assert r.status_code == 400
