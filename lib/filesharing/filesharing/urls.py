"""filesharing URL Configuration

The `urlpatterns` list routes URLs to views. For more information please see:
    https://docs.djangoproject.com/en/3.1/topics/http/urls/
Examples:
Function views
    1. Add an import:  from my_app import views
    2. Add a URL to urlpatterns:  path('', views.home, name='home')
Class-based views
    1. Add an import:  from other_app.views import Home
    2. Add a URL to urlpatterns:  path('', Home.as_view(), name='home')
Including another URLconf
    1. Import the include() function: from django.urls import include, path
    2. Add a URL to urlpatterns:  path('blog/', include('blog.urls'))
"""
from django.contrib import admin
from django.urls import path
from django.conf import settings
from django.conf.urls.static import static

from apps.filesharing import views

urlpatterns = [
    path('', views.index, name='index'),
    path('upload/', views.upload, name='upload'),
    path('upload/<int:subfolder_id>/', views.upload, name='upload-subfolder'),
    path('download/<int:pk>/', views.DownloadListView.as_view(), name='download'),
    path('download_zip/', views.download_zip, name='download-zip'),
]

if settings.DEBUG:
    # Serve files in dev mode
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
