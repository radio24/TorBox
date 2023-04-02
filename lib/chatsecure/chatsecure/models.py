import peewee as pw
from datetime import datetime


# TODO: db name should be taken from INSTANCE_NAME on ./tcs
db = pw.SqliteDatabase(
    "tcs.db", pragmas={"journal_mode": "wal", "cache_size": 10000, "foreign_keys": 1}
)


class BaseModel(pw.Model):
    """Base for rest of models"""
    class Meta:
        database = db


class User(BaseModel):
    """Store name and pubkey"""
    name = pw.CharField(max_length=24, unique=True)
    pubkey = pw.TextField(unique=True)
    fp = pw.CharField(max_length=48, unique=True)
    token = pw.CharField(max_length=48, unique=True)
    sid = pw.CharField(max_length=32, unique=True, null=True)
    ts_join = pw.DateTimeField(default=datetime.now)
    last_update = pw.DateTimeField(default=datetime.now)


class Group(BaseModel):
    """Chat group. Many users can be in group"""
    name = pw.CharField(max_length=24)
    members = pw.ManyToManyField(User, on_delete="CASCADE", backref="chatgroups")
    last_update = pw.DateTimeField(default=datetime.now)


class UserMessage(BaseModel):
    """Messages between users"""
    sender = pw.ForeignKeyField(
        User, on_delete="SET NULL", backref="message_sent_users", null=True
    )
    recipient = pw.ForeignKeyField(
        User, on_delete="SET NULL", backref="message_received_users", null=True
    )
    msg = pw.TextField()
    ts = pw.DateTimeField(default=datetime.now)


class GroupMessage(BaseModel):
    """Messages to the group"""
    sender = pw.ForeignKeyField(
        User, on_delete="SET NULL", backref="message_sent_groups"
    )
    recipient = pw.ForeignKeyField(
        Group, on_delete="CASCADE", backref="messages"
    )
    msg = pw.TextField()
    ts = pw.DateTimeField(default=datetime.now)


if __name__ == '__main__':
    # Create tables
    db.create_tables([User, Group, UserMessage, GroupMessage])
    Group.create(name="default")
