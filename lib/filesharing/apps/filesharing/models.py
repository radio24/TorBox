from django.db import models
from django.db.models.fields import BooleanField, CharField


class DownloadFileModel(models.Model):
    name = CharField(max_length=255)
    is_dir = BooleanField(blank=False, null=False, default=False)
    file = models.FileField(blank=True)
    size = models.IntegerField(default=0)
    date = models.DateField(auto_now_add=True)
    parent = models.ForeignKey(
        "self", default=None, null=True, on_delete=models.CASCADE
    )
    path = models.TextField(blank=False)
