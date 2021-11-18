from django.conf import settings
from django.shortcuts import render, redirect
from django.views.generic.list import ListView

from .forms import UploadFileForm
from .models import DownloadFileModel

# Create your views here.
def index(request):
    return render(request, 'index.html')

def upload(request):
    if not settings.ALLOW_UPLOAD:
        return redirect('index')

    if request.method == 'POST':
        form = UploadFileForm(request.POST, request.FILES)
        if form.is_valid():
            parent = DownloadFileModel.objects.get(pk=1)
            files = request.FILES.getlist('file')
            for f in files:
                file_instance = DownloadFileModel(name=f.name,
                                                file=f,
                                                size=f.size,
                                                parent=parent)
                file_instance.save()

            return render(request, 'upload_ok.html')
        else:
            return render(request, "upload.html", {'error': True})
    else:
        return render(request, "upload.html")

class DownloadListView(ListView):
    model = DownloadFileModel
    template_name = 'download.html'
    context_object_name = 'files'
    paginate_by = 10

    def dispatch(self, request, *args, **kwargs):
        if not settings.ALLOW_DOWNLOAD:
            return redirect('index')

        return super(DownloadListView, self).dispatch(request, *args, **kwargs)

    def get_queryset(self):
        return DownloadFileModel.objects.filter(parent=self.kwargs['pk']).order_by('-is_dir')
    
    def get_context_data(self, **kwargs):
        context = super(DownloadListView, self).get_context_data(**kwargs)
        # Get parent
        obj = DownloadFileModel.objects.get(pk=self.kwargs['pk'])
        try:
            parent_pk = obj.parent.pk
        except:
            parent_pk = False
        context['pk'] = self.kwargs['pk']
        context['dir_name'] = obj.name
        context['parent'] = parent_pk
        return context