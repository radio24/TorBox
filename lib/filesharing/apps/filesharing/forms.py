from django import forms
from .models import DownloadFileModel

class UploadFileForm(forms.ModelForm):
    def __init__(self, *args, **kwargs):
        super(UploadFileForm, self).__init__(*args, **kwargs)
        self.fields['file'].required = True
    class Meta:
        model = DownloadFileModel
        fields = ['file']
        widget = {
            'file': forms.ClearableFileInput(attrs={'multiple': True})
        }