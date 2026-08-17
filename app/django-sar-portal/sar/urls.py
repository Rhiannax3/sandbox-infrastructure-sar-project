from django.urls import path

from sar import views

urlpatterns = [
    path("", views.portal_home, name="home"),
    path("requests/", views.request_list, name="request_list"),
    path("requests/new/", views.request_create, name="request_create"),
    path("requests/<str:request_id>/edit/", views.request_edit, name="request_edit"),
    path("requests/<str:request_id>/delete/", views.request_delete, name="request_delete"),
    path("requests/<str:request_id>/", views.request_detail, name="request_detail"),
]
