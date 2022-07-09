import os
import shutil
import tempfile
import zipfile
import uuid
from pathlib import Path

from django.conf import settings
from django.http import Http404, StreamingHttpResponse
from django.shortcuts import render, redirect
from django.views.generic.list import ListView
from wsgiref.util import FileWrapper

from .forms import DownloadZipForm, UploadFileForm
from .models import DownloadFileModel


def index(request):
    return render(request, "index.html")


def upload(request, subfolder_id=None):
    if not settings.ALLOW_UPLOAD:
        return redirect("index")

    if request.method == "POST":
        form = UploadFileForm(request.POST, request.FILES)
        if form.is_valid():
            # Upload to root by default
            if not form.data.get("subfolder", None):
                parent = DownloadFileModel.objects.get(pk=1)
            else:
                # Get selected parent
                subfolder_id = form.data["subfolder"]
                parent = DownloadFileModel.objects.get(pk=subfolder_id)

            files = request.FILES.getlist("file")
            for f in files:
                # Move file to the right parent
                file_instance = DownloadFileModel()
                file_instance.name = f.name
                file_instance.size = f.size
                file_instance.parent = parent

                # Upload file to root / subdir
                file_name = f.name
                if parent.pk != 1:
                    relative_path = parent.path.replace(f"{settings.MEDIA_ROOT}/", "")
                    file_name = f"{relative_path}/{file_name}"
                file_instance.file.save(file_name, f)

                file_instance.save()
            return render(request, "upload_ok.html")
        else:
            return render(request, "upload.html", {"error": True})
    else:
        tpl = {}
        if subfolder_id:
            subfolder = DownloadFileModel.objects.get(pk=subfolder_id)
            tpl["subfolder"] = subfolder
            tpl["path"] = get_file_object_path(subfolder)
        return render(request, "upload.html", tpl)


class DownloadListView(ListView):
    model = DownloadFileModel
    template_name = "download.html"
    context_object_name = "files"
    # paginate_by = 10

    def dispatch(self, request, *args, **kwargs):
        if not settings.ALLOW_DOWNLOAD:
            return redirect("index")

        # List only dirs
        if not DownloadFileModel.objects.get(pk=self.kwargs["pk"]).is_dir:
            return redirect("index")

        return super(DownloadListView, self).dispatch(request, *args, **kwargs)

    def get_queryset(self):
        return DownloadFileModel.objects.filter(parent=self.kwargs["pk"]).order_by(
            "-is_dir", "name"
        )

    def get_context_data(self, **kwargs):
        context = super(DownloadListView, self).get_context_data(**kwargs)
        # Get parent
        obj = DownloadFileModel.objects.get(pk=self.kwargs["pk"])
        try:
            parent_pk = obj.parent.pk
        except:
            parent_pk = False
        context["pk"] = self.kwargs["pk"]
        context["path"] = get_file_object_path(obj)
        context["parent"] = parent_pk
        return context


def download_zip(request):
    if request.method == "POST":
        form = DownloadZipForm(request.POST)
        if form.is_valid():
            path_list = []
            file_list = form.cleaned_data["file_list"]
            for file in file_list:
                file_info = (
                    f"{settings.MEDIA_ROOT}/{get_file_object_path(file)}",
                    file.name,
                    file.is_dir,
                )
                path_list.append(file_info)
            # Calculate size of download
            total_size = 0
            for f in path_list:
                path = f[0]
                total_size += os.path.getsize(path)

            # Check current disk status
            total, used, free = shutil.disk_usage("/")

            # Enough free space to go
            if total_size < free:
                # Generate zip in temp file
                temp = tempfile.TemporaryFile()
                with zipfile.ZipFile(temp, "w", zipfile.ZIP_DEFLATED) as archive:
                    for f in path_list:
                        path = f[0]
                        filename = f[1]
                        is_dir = f[2]
                        if is_dir:
                            src_path = Path(path).expanduser().resolve(strict=True)
                            for file in src_path.rglob("*"):
                                archive.write(file, file.relative_to(src_path.parent))
                        else:
                            archive.write(path, filename)
                # Serve zip
                random = uuid.uuid4()
                response = StreamingHttpResponse(
                    FileWrapper(temp), content_type="application/zip"
                )
                response[
                    "Content-Disposition"
                ] = f"attachment; filename=torbox-tfs_{random}.zip"
                response["Content-Length"] = temp.tell()
                temp.seek(0)
                return response
            else:
                errors = {"type": "DISK_SPACE_ERROR"}
                return render(request, "error.html", errors)
        else:
            errors = {"type": "SELECTION_ERROR"}
            return render(request, "error.html", errors)
            # raise Http404
    else:
        raise Http404


def get_file_object_path(obj):
    # return path from media root
    path = []
    while obj.pk != 1:
        path.append(obj.name)
        obj = DownloadFileModel.objects.get(pk=obj.parent.pk)
    path.reverse()
    return "/".join(path)
