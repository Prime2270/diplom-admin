resource "yandex_compute_instance" "zabbix-vm" {
  name = "zabbix-vm"
  hostname = "zabbix-vm"
  zone = "ru-central1-b"

  resources {
    cores = 4
    memory = 4
  }

  boot_disk {
    initialize_params{
      image_id = "fd84ocs2qmrnto64cl6m"
      type = "network-ssd"
      size = "100"
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.private-3.id
    security_group_ids = [yandex_vpc_security_group.ssh-access-local.id, yandex_vpc_security_group.zabbix-sg.id]
    ip_address = "10.3.1.30"
    nat = true
  }

  metadata = {
    user-data = "${file("~/diplom/terraform/meta.yml")}"
  }
}