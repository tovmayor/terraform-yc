terraform {
  required_providers {
    docker = {
      source = "kreuzwerker/docker"
      version = "2.20.2"
    }
    yandex = {
      source = "yandex-cloud/yandex"
      version = "0.77.0"
    }
  }
}

#provider "docker" {
  #Configuration options
#  host = "unix:///var/run/docker.sock"
#}

#resource "docker_container" "nginx_cont" {
#  image = docker_image.nginx.latest
#    name = "nginx_image"
#    ports {
#      internal = 80
#      external = 80
#    }
#}

#resource "docker_image" "nginx" {
#  name = "nginx:latest"
#}

provider "yandex" {
  token     = "y0_AgAAAAAKYyQGAATuwQAAAADNneRzsw53q7T1Q2qTJPmxqfz87uq9uBk"
  cloud_id  = "b1g2mjplbcl08o830ovt"
  folder_id = "b1gqgtdu7assr55vqtf2"
  zone      = "ru-central1-b"
}

# resource "yandex_storage_object" "war-bucket" {    #!!NOT WORKS!!
#   access_key = "YCAJECaxhWcm6rHMYeehDO2kH"
#   secret_key = "YCPxhl-X6BvNYbA6cSF5Wpr8TlRHxBhkV6lhHz5S"
#   bucket     = "devbucket"
#   key        = "folder"
#   source     = "/home/andrew/terraform-yc/hello-1.0.war"
# }

resource "yandex_iam_service_account" "sa" {
  name = "bucket-admin"
}

// Назначение роли сервисному аккаунту
resource "yandex_resourcemanager_folder_iam_member" "sa-editor" {
  role   = "storage.editor"
  member = "serviceAccount:${yandex_iam_service_account.sa.id}"
  folder_id = "b1gqgtdu7assr55vqtf2"
}

// Создание статического ключа доступа
resource "yandex_iam_service_account_static_access_key" "sa-static-key" {
  service_account_id = yandex_iam_service_account.sa.id
  description        = "static access key for object storage"
}

// Создание бакета с использованием ключа
resource "yandex_storage_bucket" "a1dc8aa6f31a45f83" {
  access_key = yandex_iam_service_account_static_access_key.sa-static-key.access_key
  secret_key = yandex_iam_service_account_static_access_key.sa-static-key.secret_key
  bucket     = "a1dc8aa6f31a45f83"
  max_size   = 200000000
  anonymous_access_flags {
    read = true
    list = false
  }
}

resource "yandex_compute_instance" "build" {
  name        = "t-build1"
  hostname    = "t-build1"
  platform_id = "standard-v1"
  zone        = "ru-central1-b"
  scheduling_policy {
    preemptible = true
  }
  allow_stopping_for_update = true

  resources {
    cores  = 4
    memory = 4
    core_fraction = 20  
  }

  boot_disk {
    initialize_params {
      image_id = "fd8kdq6d0p8sij7h5qe3"
      size = "10"
    }
  }
network_interface {
    subnet_id = "e2lbocl9ri9asmv0hq7i"
    nat = true
  }

  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
  }
provisioner "remote-exec" {
    inline = [
      "sudo apt-get update -y && sudo apt-get install -y maven git && sudo apt-get install -y s3fs",
      "sudo echo YCAJECaxhWcm6rHMYeehDO2kH:YCPxhl-X6BvNYbA6cSF5Wpr8TlRHxBhkV6lhHz5S > ~/.passwd-s3fs && sudo chmod 600  ~/.passwd-s3fs",
      "sudo mkdir /mnt/ycb",
      "sudo s3fs a1dc8aa6f31a45f83 /mnt/ycb -o passwd_file=$HOME/.passwd-s3fs -o url=http://storage.yandexcloud.net -o use_path_request_style",
      "sudo git clone https://github.com/tovmayor/myboxfuse.git",
      "sudo mvn -f ./myboxfuse package", 
      "sudo cp /home/ubuntu/myboxfuse/target/hello-1.0.war /mnt/ycb/"
    ]
    connection {
      type = "ssh"
      user = "ubuntu"
      private_key = file("~/.ssh/id_rsa")
      host = self.network_interface[0].nat_ip_address
    }
  }
}

resource "yandex_compute_instance" "prod" { 
  name        = "t-prod1"
  hostname    = "t-prod1"
  platform_id = "standard-v1"
  zone        = "ru-central1-b"
  scheduling_policy {
    preemptible = true
  }
  allow_stopping_for_update = true

  resources {
    cores  = 2
    memory = 2
    core_fraction = 20
  }

  boot_disk {
    initialize_params {
      image_id = "fd8kdq6d0p8sij7h5qe3"
      size = "10"
    }
  }
network_interface {
    subnet_id = "e2lbocl9ri9asmv0hq7i"
    nat = true
  }

  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
  }
provisioner "remote-exec" {
    inline = [
      "sudo apt-get update -y && apt-get install -y openjdk-11-jre-headless && sudo apt-get install -y s3fs",
      "sudo echo YCAJECaxhWcm6rHMYeehDO2kH:YCPxhl-X6BvNYbA6cSF5Wpr8TlRHxBhkV6lhHz5S > ~/.passwd-s3fs && sudo chmod 600  ~/.passwd-s3fs",
      "sudo mkdir /mnt/ycb",
      "sudo s3fs a1dc8aa6f31a45f83 /mnt/ycb -o passwd_file=$HOME/.passwd-s3fs -o url=http://storage.yandexcloud.net -o use_path_request_style",
      "sudo wget https://dlcdn.apache.org/tomcat/tomcat-9/v9.0.65/bin/apache-tomcat-9.0.65.tar.gz",
      "sudo tar xvfz apache-tomcat-9.0.65.tar.gz",
      "sudo mkdir -p /usr/local/tomcat9 && sudo mv ./apache-tomcat-9.0.65/* /usr/local/tomcat9 && sudo rm apache-tomcat-9.0.65.tar.gz",
      "sudo cp /mnt/ycb/hello-1.0.war /usr/local/tomcat9/webapps",
      "sudo /usr/local/tomcat9/bin/catalina.sh run"


    ]
    connection {
      type = "ssh"
      user = "ubuntu"
      private_key = file("~/.ssh/id_rsa")
      host = self.network_interface[0].nat_ip_address
    }
  }
}
