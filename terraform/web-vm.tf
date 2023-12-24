resource "yandex_compute_instance" "web-vm-1" {
  name = "web-vm-1"
  hostname = "web-vm-1"
  zone = "ru-central1-a"

  resources {
    cores = 2
    memory = 4
  }

  boot_disk {
    initialize_params{
      image_id = var.image_id
      type = "network-ssd"
      size = "15"
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.private-1.id
    security_group_ids = [yandex_vpc_security_group.ssh-access-local.id, yandex_vpc_security_group.nginx-sg.id, yandex_vpc_security_group.filebeat-sg.id]
    ip_address = "10.1.1.10"
  }

  metadata = {
    user-data = "${file("~/diplom/terraform/meta.yml")}"
  }
}

resource "yandex_compute_instance" "web-vm-2" {
  name = "web-vm-2"
  hostname = "web-vm-2"
  zone = "ru-central1-c"

  resources {
    cores = 2
    memory = 4
  }

  boot_disk {
    initialize_params{
      image_id = var.image_id
      type = "network-ssd"
      size = "15"
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.private-2.id
    security_group_ids = [yandex_vpc_security_group.ssh-access-local.id, yandex_vpc_security_group.nginx-sg.id, yandex_vpc_security_group.filebeat-sg.id]
    ip_address = "10.2.1.20"
  }

  metadata = {
    user-data = "${file("~/diplom/terraform/meta.yml")}"
  }
}
