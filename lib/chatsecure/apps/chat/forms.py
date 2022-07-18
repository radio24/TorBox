from django import forms
from django.core.validators import RegexValidator

alphanumeric = RegexValidator(r"^[a-zA-Z0-9_]*$", "Alphanumeric nick only")


class NickAvailableForm(forms.Form):
    nick = forms.CharField(max_length=18, validators=[alphanumeric])


class UserConnectForm(forms.Form):
    nick = forms.CharField(max_length=18, validators=[alphanumeric])
    pub_key = forms.CharField()
