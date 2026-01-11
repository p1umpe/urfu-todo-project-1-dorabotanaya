terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
  required_version = ">= 1.0"
}

provider "yandex" {
  token     = var.yc_token
  cloud_id  = var.cloud_id
  folder_id = var.folder_id
  zone      = "ru-central1-a"
}

variable "yc_token" {
  type      = string
  sensitive = true
}

variable "cloud_id" {
  type    = string
  default = "b1gc21jelpjvas6sava9"
}

variable "folder_id" {
  type    = string
  default = "b1g2nokdbvfvd2022ntd"
}

variable "student_name" {
  type    = string
  default = "p1umpe"
}

locals {
  name_prefix = "urfu-todo-${var.student_name}"
}

#Сервисные аккаунты (IAM)
resource "yandex_iam_service_account" "sa_functions" {
  name        = "${local.name_prefix}-sa-functions"
  description = "Service account for Cloud Functions"
}

resource "yandex_iam_service_account" "sa_ydb" {
  name        = "${local.name_prefix}-sa-ydb"
  description = "Service account for YDB access"
}

resource "yandex_iam_service_account" "sa_storage" {
  name        = "${local.name_prefix}-sa-storage"
  description = "Service account for Object Storage"
}

#Ключи доступа для сервисных аккаунтов
resource "yandex_iam_service_account_static_access_key" "sa_storage_key" {
  service_account_id = yandex_iam_service_account.sa_storage.id
  description        = "Static access key for storage"
}

#Назначение ролей (IAM)
resource "yandex_resourcemanager_folder_iam_member" "ydb_editor" {
  folder_id = var.folder_id
  role      = "ydb.editor"
  member    = "serviceAccount:${yandex_iam_service_account.sa_ydb.id}"
}

resource "yandex_resourcemanager_folder_iam_member" "functions_ydb_editor" {
  folder_id = var.folder_id
  role      = "ydb.editor"
  member    = "serviceAccount:${yandex_iam_service_account.sa_functions.id}"
}

resource "yandex_resourcemanager_folder_iam_member" "storage_editor" {
  folder_id = var.folder_id
  role      = "storage.editor"
  member    = "serviceAccount:${yandex_iam_service_account.sa_storage.id}"
}

resource "yandex_resourcemanager_folder_iam_member" "functions_invoker" {
  folder_id = var.folder_id
  role      = "functions.functionInvoker"
  member    = "serviceAccount:${yandex_iam_service_account.sa_functions.id}"
}

#Дополнительная роль для Message Queue
resource "yandex_resourcemanager_folder_iam_member" "mq_writer" {
  folder_id = var.folder_id
  role      = "ymq.writer"
  member    = "serviceAccount:${yandex_iam_service_account.sa_storage.id}"
}

#VPC
resource "yandex_vpc_network" "main" {
  name = "${local.name_prefix}-network"
}

resource "yandex_vpc_subnet" "main" {
  name           = "${local.name_prefix}-subnet"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.main.id
  v4_cidr_blocks = ["10.10.0.0/24"]
}

#YDB
resource "yandex_ydb_database_serverless" "todo_db" {
  name = "${local.name_prefix}-ydb"
}

#Object Storage с CORS
resource "yandex_storage_bucket" "static" {
  bucket     = "${local.name_prefix}-static"
  folder_id  = var.folder_id
  max_size   = 104857600 # 100 MB
  access_key = yandex_iam_service_account_static_access_key.sa_storage_key.access_key
  secret_key = yandex_iam_service_account_static_access_key.sa_storage_key.secret_key

  #Публичный доступ
  anonymous_access_flags {
    read = true
    list = true
  }

  #Настройки веб-сайта
  website {
    index_document = "index.html"
    error_document = "index.html"
  }

  #Настройки CORS
  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "HEAD", "PUT", "POST", "DELETE"]
    allowed_origins = ["*"]
    max_age_seconds = 3600
  }

  depends_on = [
    yandex_iam_service_account_static_access_key.sa_storage_key,
    yandex_resourcemanager_folder_iam_member.storage_editor
  ]
}

#Cloud Functions
resource "yandex_function" "create_task" {
  name               = "${local.name_prefix}-create-task"
  description        = "Create a new task"
  runtime            = "python311"
  entrypoint         = "index.handler"
  memory             = "128"
  execution_timeout  = "10"
  service_account_id = yandex_iam_service_account.sa_functions.id
  user_hash          = filebase64sha256("${path.module}/../functions/create_task.zip")
  environment = {
    YDB_ENDPOINT = "grpcs://${yandex_ydb_database_serverless.todo_db.ydb_api_endpoint}"
    YDB_DATABASE = yandex_ydb_database_serverless.todo_db.database_path
    YMQ_QUEUE_URL = "https://message-queue.api.cloud.yandex.net/b1gc21jelpjvas6sava9/${yandex_message_queue.todo_queue.name}"
    AWS_ACCESS_KEY_ID = yandex_iam_service_account_static_access_key.sa_storage_key.access_key
    AWS_SECRET_ACCESS_KEY = yandex_iam_service_account_static_access_key.sa_storage_key.secret_key
  }

  content {
    zip_filename = "${path.module}/../functions/create_task.zip"
  }
}

resource "yandex_function" "get_tasks" {
  name               = "${local.name_prefix}-get-tasks"
  description        = "Get list of tasks"
  runtime            = "python311"
  entrypoint         = "index.handler"
  memory             = "128"
  execution_timeout  = "10"
  service_account_id = yandex_iam_service_account.sa_functions.id
  user_hash          = filebase64sha256("${path.module}/../functions/get_tasks.zip")
  environment = {
    YDB_ENDPOINT = "grpcs://${yandex_ydb_database_serverless.todo_db.ydb_api_endpoint}"
    YDB_DATABASE = yandex_ydb_database_serverless.todo_db.database_path
  }

  content {
    zip_filename = "${path.module}/../functions/get_tasks.zip"
  }
}

resource "yandex_function" "update_task" {
  name               = "${local.name_prefix}-update-task"
  description        = "Update a task"
  runtime            = "python311"
  entrypoint         = "index.handler"
  memory             = "128"
  execution_timeout  = "10"
  service_account_id = yandex_iam_service_account.sa_functions.id
  user_hash          = filebase64sha256("${path.module}/../functions/update_task.zip")
  environment = {
    YDB_ENDPOINT = "grpcs://${yandex_ydb_database_serverless.todo_db.ydb_api_endpoint}"
    YDB_DATABASE = yandex_ydb_database_serverless.todo_db.database_path
  }

  content {
    zip_filename = "${path.module}/../functions/update_task.zip"
  }
}

resource "yandex_function" "delete_task" {
  name               = "${local.name_prefix}-delete-task"
  description        = "Delete a task"
  runtime            = "python311"
  entrypoint         = "index.handler"
  memory             = "128"
  execution_timeout  = "10"
  service_account_id = yandex_iam_service_account.sa_functions.id
  user_hash          = filebase64sha256("${path.module}/../functions/delete_task.zip")
  environment = {
    YDB_ENDPOINT = "grpcs://${yandex_ydb_database_serverless.todo_db.ydb_api_endpoint}"
    YDB_DATABASE = yandex_ydb_database_serverless.todo_db.database_path
  }

  content {
    zip_filename = "${path.module}/../functions/delete_task.zip"
  }
}

#API Gateway с CORS
resource "yandex_api_gateway" "todo_api" {
  name = "${local.name_prefix}-api"

  spec = <<-EOT
    openapi: "3.0.0"
    info:
      version: 1.0.0
      title: Todo API
    paths:
      /tasks:
        options:
          x-yc-apigateway-integration:
            type: dummy
            http_code: 200
            http_headers:
              Access-Control-Allow-Origin: "*"
              Access-Control-Allow-Methods: "GET, POST, PUT, DELETE, OPTIONS"
              Access-Control-Allow-Headers: "*"
              Access-Control-Max-Age: "3600"
            content:
              "application/json": ""
        get:
          x-yc-apigateway-integration:
            type: cloud_functions
            function_id: "${yandex_function.get_tasks.id}"
            tag: "$latest"
            service_account_id: "${yandex_iam_service_account.sa_functions.id}"
          parameters:
            - name: status
              in: query
              required: false
              schema:
                type: string
                enum: [all, active, completed]
                default: all
        post:
          x-yc-apigateway-integration:
            type: cloud_functions
            function_id: "${yandex_function.create_task.id}"
            tag: "$latest"
            service_account_id: "${yandex_iam_service_account.sa_functions.id}"
      /tasks/{taskId}:
        parameters:
          - name: taskId
            in: path
            required: true
            schema:
              type: string
        options:
          x-yc-apigateway-integration:
            type: dummy
            http_code: 200
            http_headers:
              Access-Control-Allow-Origin: "*"
              Access-Control-Allow-Methods: "GET, POST, PUT, DELETE, OPTIONS"
              Access-Control-Allow-Headers: "*"
              Access-Control-Max-Age: "3600"
            content:
              "application/json": ""
        put:
          x-yc-apigateway-integration:
            type: cloud_functions
            function_id: "${yandex_function.update_task.id}"
            tag: "$latest"
            service_account_id: "${yandex_iam_service_account.sa_functions.id}"
        delete:
          x-yc-apigateway-integration:
            type: cloud_functions
            function_id: "${yandex_function.delete_task.id}"
            tag: "$latest"
            service_account_id: "${yandex_iam_service_account.sa_functions.id}"
    EOT
}

#Message Queue
resource "yandex_message_queue" "todo_queue" {
  name                       = "${local.name_prefix}-notifications"
  visibility_timeout_seconds = 30
  receive_wait_time_seconds  = 20
  access_key                 = yandex_iam_service_account_static_access_key.sa_storage_key.access_key
  secret_key                 = yandex_iam_service_account_static_access_key.sa_storage_key.secret_key

  depends_on = [
    yandex_resourcemanager_folder_iam_member.mq_writer
  ]
}

#Compute Instance for Load Balancer
resource "yandex_compute_instance" "proxy" {
  name        = "${local.name_prefix}-proxy"
  platform_id = "standard-v3"
  zone        = "ru-central1-a"

  resources {
    cores  = 2
    memory = 1
    core_fraction = 20
  }

  boot_disk {
    initialize_params {
      image_id = "fd833v6c5tb0udvk4jo6"  # Ubuntu 22.04
      size     = 10
      type     = "network-hdd"
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.main.id
    nat       = true
  }

  scheduling_policy {
    preemptible = true
  }

  metadata = {
    user-data = <<-EOF
      #cloud-config
      packages:
        - python3
        - curl
      runcmd:
        - |
          # Простой HTTP сервер для health check
          cd /tmp
          echo '{"status": "ok"}' > health.json
          python3 -m http.server 80 &
          sleep 2
          echo "Proxy VM is ready"
    EOF
  }
}

#Application Load Balancer (критерий 4)
resource "yandex_alb_load_balancer" "todo_alb" {
  name       = "${local.name_prefix}-alb"
  network_id = yandex_vpc_network.main.id

  allocation_policy {
    location {
      zone_id   = "ru-central1-a"
      subnet_id = yandex_vpc_subnet.main.id
    }
  }

  listener {
  name = "http-listener"
  endpoint {
    address {
      external_ipv4_address {}
    }
    ports = [80]
  }
  http {
    handler {
      http_router_id = yandex_alb_http_router.todo_router.id
      allow_http10 = true
    }
  }
}

  depends_on = [
    yandex_compute_instance.proxy
  ]
}

#HTTP Router для ALB
resource "yandex_alb_http_router" "todo_router" {
  name = "${local.name_prefix}-router"
}

#Virtual Host
resource "yandex_alb_virtual_host" "main_vhost" {
  name           = "main-host"
  http_router_id = yandex_alb_http_router.todo_router.id
  authority      = ["*"]

  route {
    name = "proxy-route"
    http_route {
      http_route_action {
        backend_group_id = yandex_alb_backend_group.proxy_backend.id
        timeout          = "60s"
      }
    }
  }
}

#Backend Group
resource "yandex_alb_backend_group" "proxy_backend" {
  name = "${local.name_prefix}-proxy-backend"

  http_backend {
    name             = "proxy-backend"
    weight           = 1
    port             = 80
    target_group_ids = [yandex_alb_target_group.proxy_target.id]

    healthcheck {
      timeout             = "3s"
      interval            = "5s"
      healthy_threshold   = 2
      unhealthy_threshold = 2

      http_healthcheck {
        path = "/health"
      }
    }

    load_balancing_config {
      panic_threshold = 50
    }
  }
}

#Target Group
resource "yandex_alb_target_group" "proxy_target" {
  name = "${local.name_prefix}-proxy-target"

  target {
    subnet_id  = yandex_vpc_subnet.main.id
    ip_address = yandex_compute_instance.proxy.network_interface[0].ip_address
  }
}

#Outputs
output "project_name" {
  value       = local.name_prefix
  description = "Project name prefix"
}

output "vpc_id" {
  value = yandex_vpc_network.main.id
}

output "ydb_endpoint" {
  value = yandex_ydb_database_serverless.todo_db.ydb_api_endpoint
}

output "bucket_name" {
  value = yandex_storage_bucket.static.bucket
}

output "bucket_website_url" {
  value = "https://${yandex_storage_bucket.static.bucket}.website.yandexcloud.net"
}

output "api_gateway_domain" {
  value = yandex_api_gateway.todo_api.domain
}

output "api_gateway_url" {
  value = "https://${yandex_api_gateway.todo_api.domain}"
}

output "cloud_functions" {
  value = {
    create_task = yandex_function.create_task.id
    get_tasks   = yandex_function.get_tasks.id
    update_task = yandex_function.update_task.id
    delete_task = yandex_function.delete_task.id
  }
}

output "service_accounts" {
  value = {
    functions = yandex_iam_service_account.sa_functions.id
    ydb       = yandex_iam_service_account.sa_ydb.id
    storage   = yandex_iam_service_account.sa_storage.id
  }
}

output "alb_external_ip" {
  value       = try(yandex_alb_load_balancer.todo_alb.listener[0].endpoint[0].address[0].external_ipv4_address[0].address, "не создан")
  description = "Внешний IP адрес балансировщика нагрузки"
}

output "alb_url" {
  value       = "http://${try(yandex_alb_load_balancer.todo_alb.listener[0].endpoint[0].address[0].external_ipv4_address[0].address, "не-создан")}"
  description = "URL балансировщика нагрузки"
}

output "proxy_vm_ip" {
  value       = yandex_compute_instance.proxy.network_interface[0].ip_address
  description = "Внутренний IP адрес прокси-ВМ"
}

output "proxy_vm_nat_ip" {
  value       = yandex_compute_instance.proxy.network_interface[0].nat_ip_address
  description = "Внешний IP адрес прокси-ВМ (через NAT)"
}