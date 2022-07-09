import json

from django.shortcuts import render
from django.http import JsonResponse
from django.views.decorators.csrf import ensure_csrf_cookie

from .forms import NickAvailableForm, UserConnectForm
from .models import UserChat


@ensure_csrf_cookie
def index(request):
    return render(request, "index.html")


def nick_available(request):
    if request.method == "POST":
        form = NickAvailableForm(data=json.loads(request.body))
        if form.is_valid():
            nick = form.cleaned_data["nick"]
            if UserChat.objects.filter(nick=nick).first():
                response = False
            else:
                response = True
        else:
            response = False
    else:
        response = False
    return JsonResponse({"reply": response})


def user_connect(request):
    if request.method == "POST":
        form = UserConnectForm(data=json.loads(request.body))
        if form.is_valid():
            nick = form.cleaned_data["nick"]
            pub_key = form.cleaned_data["pub_key"]
            user = UserChat(nick=nick, pub_key=pub_key)
            user.save()
            response = True
        else:
            response = False
    else:
        response = False
    return JsonResponse({"reply": response})


def user_list(request):
    users = []
    for u in UserChat.objects.all():
        users.append({"nick": u.nick, "pub_key": u.pub_key})
    return JsonResponse(users, safe=False)
