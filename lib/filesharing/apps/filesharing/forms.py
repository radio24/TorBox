from django import forms
from .models import DownloadFileModel

class MultipleFileInput(forms.ClearableFileInput):
    allow_multiple_selected = True

class UploadFileForm(forms.ModelForm):
    subfolder = forms.IntegerField(required=False, initial=False)

    def __init__(self, *args, **kwargs):
        super(UploadFileForm, self).__init__(*args, **kwargs)
        self.fields["file"].required = True

    class Meta:
        model = DownloadFileModel
        fields = ["file"]
        widget = {"file": MultipleFileInput(attrs={"multiple": True})}


class DownloadZipForm(forms.Form):
    file_list = forms.ModelMultipleChoiceField(
        queryset=DownloadFileModel.objects.exclude(pk=1),
        widget=forms.CheckboxSelectMultiple,
    )
