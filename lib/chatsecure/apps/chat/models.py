from django.db import models


class UserChat(models.Model):
    sid = models.CharField(max_length=24, unique=True, null=True)
    nick = models.CharField(max_length=18, unique=True)
    pub_key = models.TextField(unique=True)
