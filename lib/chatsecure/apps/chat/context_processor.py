from django.conf import settings


def chatsecure_context(request):
    obj = {"MSG_HEADER": settings.MSG_HEADER}
    return obj
