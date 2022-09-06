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

resource "yandex_compute_instance" "build" {
  name        = "t-build1"
  hostname    = "t-build1"
  platform_id = "standard-v1"
  zone        = "ru-central1-b"
  scheduling_policy {
    preemptible = true
  }
  core_fraction = 20
  allow_stopping_for_update = true

  resources {
    cores  = 4
    memory = 4
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
      "sudo apt-get update -y && sudo apt-get install -y maven git",
      "sudo git clone https://github.com/tovmayor/myboxfuse.git",
      "sudo mvn -f ./myboxfuse package", 
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
  core_fraction = 20
  allow_stopping_for_update = true

  resources {
    cores  = 2
    memory = 2
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
      "RUN apt-get install -y openjdk-11-jre-headless"
      "RUN wget https://dlcdn.apache.org/tomcat/tomcat-9/v9.0.65/bin/apache-tomcat-9.0.65.tar.gz"
      "RUN tar xvfz apache-tomcat-9.0.65.tar.gz"
      "RUN mkdir -p /usr/local/tomcat9 && mv ./apache-tomcat-9.0.65/* /usr/local/tomcat9 && rm apache-tomcat-9.0.65.tar.gz"

    ]
    connection {
      type = "ssh"
      user = "ubuntu"
      private_key = file("~/.ssh/id_rsa")
      host = self.network_interface[0].nat_ip_address
    }
  }
}