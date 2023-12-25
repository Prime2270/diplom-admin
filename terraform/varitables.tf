#id облака
variable "yc_cloud_id" {
  default = "your_cloud"
}

#id подкаталога
variable "yc_folder_id" {
  default = "your_folder"
}

#OAuth-токен
variable "yc_token" {
   default = "your_token"
}

#Debian 11
variable "image_id" {
  default = "fd88b8f4jb1akihi1gfi" 
}

 
locals {
  web-servers = {
   "web-vm-1" = { zone = "ru-central1-a", subnet_id = yandex_vpc_subnet.private-1.id, ip_address = "10.1.1.10" },
   "web-vm-2" = { zone = "ru-central1-c", subnet_id = yandex_vpc_subnet.private-2.id, ip_address = "10.2.1.20" }
 }
}
