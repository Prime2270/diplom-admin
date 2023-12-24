#id облака
variable "yc_cloud_id" {
  default = "b1g81tfcidpm51imdjrm"
}

#id подкаталога
variable "yc_folder_id" {
  default = "b1gjkksr8jd4enj7cm6l"
}

#OAuth-токен
variable "yc_token" {
   default = "y0_AgAAAAAkqjA0AATuwQAAAADq5N_7ej1JLnE0RWajrgbrQ3xf4GP-j-U"
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