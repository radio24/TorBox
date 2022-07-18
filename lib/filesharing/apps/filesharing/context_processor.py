from django.conf import settings


def filesharing_context(request):
    obj = {
        "ALLOW_UPLOAD": settings.ALLOW_UPLOAD,
        "ALLOW_DOWNLOAD": settings.ALLOW_DOWNLOAD,
        "MSG_HEADER": settings.MSG_HEADER.replace("\\n", "\n"),
    }
    return obj
