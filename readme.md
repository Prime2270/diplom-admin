#  Дипломная работа по профессии «Системный администратор» «Яковлев Константин»

Содержание
==========
* [Задача](#Задача)
* [Инфраструктура](#Инфраструктура)
    * [Сайт](#Сайт)
    * [Мониторинг](#Мониторинг)
    * [Логи](#Логи)
    * [Сеть](#Сеть)
    * [Резервное копирование](#Резервное-копирование)
    * [Дополнительно](#Дополнительно)
* [Выполнение работы](#Выполнение-работы)
* [Критерии сдачи](#Критерии-сдачи)
* [Как правильно задавать вопросы дипломному руководителю](#Как-правильно-задавать-вопросы-дипломному-руководителю) 

---------
## Задача
Ключевая задача — разработать отказоустойчивую инфраструктуру для сайта, включающую мониторинг, сбор логов и резервное копирование основных данных. Инфраструктура должна размещаться в [Yandex Cloud](https://cloud.yandex.com/).

## Инфраструктура
Для развёртки инфраструктуры используйте Terraform и Ansible. 

```
Вся инфраструктура создаётся с помощью Terraform, дальнейшее конфигурирование осуществляется с помощью Ansible.
```

Параметры виртуальной машины (ВМ) подбирайте по потребностям сервисов, которые будут на ней работать. 

Ознакомьтесь со всеми пунктами из этой секции, не беритесь сразу выполнять задание, не дочитав до конца. Пункты взаимосвязаны и могут влиять друг на друга.

Установка Terraform и Ansible 

```
wget https://hashicorp-releases.yandexcloud.net/terraform/1.5.5/terraform_1.5.5_linux_amd64.zip

zcat terraform_1.5.5_linux_amd64.zip > terraform

chmod 766 terraform

Проверка работоспособности локально
./terraform

для полноценного использовния

cp terraform /usr/local/bin/terraform



в корневой папке пользовтеля который будет использовать terraform создать файл .terraformrc
в нем необходимо прописать провайдер яндекс, если этого не сделать, то terraform будет пытаться 
подключится к своим серверам, но не сможет из-за ошибки 403 или 404

nano ~/.terraformrc

provider_installation {
  network_mirror {
    url = "https://terraform-mirror.yandexcloud.net/"
    include = ["registry.terraform.io/*/*"]
  }
  direct {
    exclude = ["registry.terraform.io/*/*"]
  }
}

создать файл default.tf в папке с проектом

что-бы конфиг корректо отображался terraform fmt default.tf

terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }

}

terraform init


Установка Ansible производиться обычной командой apt install ansible -y
```

### Сайт
Создайте две ВМ в разных зонах, установите на них сервер nginx, если его там нет. ОС и содержимое ВМ должно быть идентичным, это будут наши веб-сервера.

```
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
      size = "10"
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.private-1.id
    security_group_ids = [yandex_vpc_security_group.private-sg.id, yandex_vpc_security_group.internal-ssh-sg.id, yandex_vpc_security_group.load-balancer-sg.id, yandex_vpc_security_group.zabbix-sg.id]
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
      size = "10"
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.private-2.id
    security_group_ids = [yandex_vpc_security_group.private-sg.id, yandex_vpc_security_group.internal-ssh-sg.id, yandex_vpc_security_group.load-balancer-sg.id, yandex_vpc_security_group.zabbix-sg.id]
    ip_address = "10.2.1.20"
  }

  metadata = {
    user-data = "${file("~/diplom/terraform/meta.yml")}"
  }
}

```

Используйте набор статичных файлов для сайта. Можно переиспользовать сайт из домашнего задания.

Создайте [Target Group](https://cloud.yandex.com/docs/application-load-balancer/concepts/target-group), включите в неё две созданных ВМ.

```
#target group для балансировщика из двух сайтов с nginx
resource "yandex_alb_target_group" "tg-group" {
  name = "tg-group"

  target {
    ip_address = yandex_compute_instance.web-vm-1.network_interface.0.ip_address
    subnet_id = yandex_vpc_subnet.private-1.id
  }

  target {
    ip_address = yandex_compute_instance.web-vm-2.network_interface.0.ip_address
    subnet_id = yandex_vpc_subnet.private-2.id
  }
}
```

Создайте [Backend Group](https://cloud.yandex.com/docs/application-load-balancer/concepts/backend-group), настройте backends на target group, ранее созданную. Настройте healthcheck на корень (/) и порт 80, протокол HTTP.

```
#backend Group
resource "yandex_alb_backend_group" "backend-group" {
  name = "backend-group"

  http_backend {
    name = "backend" 
    weight = 1
    port = 80
    target_group_ids = ["${yandex_alb_target_group.tg-group.id}"]
    load_balancing_config {
      panic_threshold = 90
    }

    healthcheck {
      timeout = "10s"
      interval = "3s"
      healthy_threshold = 10
      unhealthy_threshold = 15
      http_healthcheck {
        path = "/"
      }
    }
  }
}
```

Создайте [HTTP router](https://cloud.yandex.com/docs/application-load-balancer/concepts/http-router). Путь укажите — /, backend group — созданную ранее.

```
#роутер
resource "yandex_alb_http_router" "router" {
  name = "router"
}

resource "yandex_alb_virtual_host" "router-host" {
  name = "router-host"
  http_router_id = yandex_alb_http_router.router.id
  route {
    name = "route"
    http_route {
      http_match {
        path {
          prefix = "/"
        }
      }
      http_route_action {
        backend_group_id = yandex_alb_backend_group.backend-group.id
        timeout = "3s"
      }
    }
  }
}
```

Создайте [Application load balancer](https://cloud.yandex.com/en/docs/application-load-balancer/) для распределения трафика на веб-сервера, созданные ранее. Укажите HTTP router, созданный ранее, задайте listener тип auto, порт 80.

```
resource "yandex_alb_load_balancer" "load-balancer" {
  name = "load-balancer"
  network_id = yandex_vpc_network.network-diplom.id
  security_group_ids = [yandex_vpc_security_group.load-balancer-sg.id, yandex_vpc_security_group.vm-load-balancer-sg.id, yandex_vpc_security_group.private-sg.id, yandex_vpc_security_group.external-ssh-sg.id, yandex_vpc_security_group.internal-ssh-sg.id]

  allocation_policy {
    location {
      zone_id = "ru-central1-a"
      subnet_id = yandex_vpc_subnet.private-1.id
    }
  }

  listener {
    name = "listener-1"
    endpoint {
      address {
        external_ipv4_address {
        }
      }
      ports = [80]
    }
    http {
      handler {
        http_router_id = yandex_alb_http_router.router.id
      }
    }
  }
}
```

Протестируйте сайт
`curl -v <публичный IP балансера>:80` 

СКРИН

СКРИН

### Мониторинг
Создайте ВМ, разверните на ней Zabbix. На каждую ВМ установите Zabbix Agent, настройте агенты на отправление метрик в Zabbix. 

```
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
    security_group_ids = [yandex_vpc_security_group.private-sg.id, yandex_vpc_security_group.internal-ssh-sg.id, yandex_vpc_security_group.external-ssh-sg.id, yandex_vpc_security_group.zabbix-server-sg.id]
    ip_address = "10.3.1.30"
    nat = true 
  }

  metadata = {
    user-data = "${file("~/diplom/terraform/meta.yml")}"
  }
}
```

```
---
- hosts: web
  become: true

  tasks:
    - name: update apt packages
      apt:
        force_apt_get: true
        upgrade: dist
        update_cache: yes
      become: true

    - name: create a directory
      ansible.builtin.file:
        path: /etc/zabbix-files
        state: directory
        mode: "0755"

    - name: download the zabbix files
      ansible.builtin.get_url:
        url: "https://repo.zabbix.com/zabbix/6.4/debian/pool/main/z/zabbix-release/zabbix-release_6.4-1+debian11_all.deb"
        dest: /etc/zabbix-files
      become: true

    - name: Install the zabbix package
      ansible.builtin.apt:
        deb: /etc/zabbix-files/zabbix-release_6.4-1+debian11_all.deb
      become: true

    - name: update apt packages
      apt:
        force_apt_get: true
        upgrade: dist
        update_cache: yes
      become: true

    - name: Install zabbix agent
      ansible.builtin.apt:
        pkg:
          - zabbix-agent

    - name: Copy Zabbix Agent configuration file
      copy:
        src: /root/diplom/ansible/zabbix/zabbix_agent.conf
        dest: /etc/zabbix/zabbix_agentd.conf
        owner: root
        group: root
        mode: "0644"

    - name: Start and enable Zabbix Agent service
      service:
        name: zabbix-agent
        state: started
        enabled: yes
```

Настройте дешборды с отображением метрик, минимальный набор — по принципу USE (Utilization, Saturation, Errors) для CPU, RAM, диски, сеть, http запросов к веб-серверам. Добавьте необходимые tresholds на соответствующие графики.

СКРИН

СКРИН



### Логи
Cоздайте ВМ, разверните на ней Elasticsearch. Установите filebeat в ВМ к веб-серверам, настройте на отправку access.log, error.log nginx в Elasticsearch.

```
resource "yandex_compute_instance" "elasticsearch-vm" {
  name = "elasticsearch-vm"
  hostname = "elasticsearch-vm"
  zone = "ru-central1-b"

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
    subnet_id = yandex_vpc_subnet.private-3.id
    security_group_ids = [yandex_vpc_security_group.private-sg.id, yandex_vpc_security_group.elasticsearch-sg.id, yandex_vpc_security_group.internal-ssh-sg.id, yandex_vpc_security_group.external-ssh-sg.id, yandex_vpc_security_group.zabbix-sg.id]
    ip_address = "10.3.1.33"
  }

  metadata = {
    user-data = "${file("~/diplom/terraform/meta.yml")}"
  }
}
```

Создайте ВМ, разверните на ней Kibana, сконфигурируйте соединение с Elasticsearch.

```
resource "yandex_compute_instance" "kibana-vm" {
  name = "kibana-vm"
  hostname = "kibana-vm"
  zone = "ru-central1-b"

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
    subnet_id = yandex_vpc_subnet.public-subnet.id
    security_group_ids = [yandex_vpc_security_group.private-sg.id, yandex_vpc_security_group.kibana-sg.id, yandex_vpc_security_group.internal-ssh-sg.id, yandex_vpc_security_group.external-ssh-sg.id, yandex_vpc_security_group.zabbix-sg.id]
    ip_address = "10.4.1.44"
    nat = true 
  }

  metadata = {
    user-data = "${file("~/diplom/terraform/meta.yml")}"
  }
}
```

### Сеть
Разверните один VPC. Сервера web, Elasticsearch поместите в приватные подсети. Сервера Zabbix, Kibana, application load balancer определите в публичную подсеть.

Настройте [Security Groups](https://cloud.yandex.com/docs/vpc/concepts/security-groups) соответствующих сервисов на входящий трафик только к нужным портам.

Настройте ВМ с публичным адресом, в которой будет открыт только один порт — ssh. Настройте все security groups на разрешение входящего ssh из этой security group. Эта вм будет реализовывать концепцию bastion host. Потом можно будет подключаться по ssh ко всем хостам через этот хост.

СКРИН

СКРИН

### Резервное копирование
Создайте snapshot дисков всех ВМ. Ограничьте время жизни snaphot в неделю. Сами snaphot настройте на ежедневное копирование.

```
resource "yandex_compute_snapshot_schedule" "snapshot" {
  name = "snapshot"

  schedule_policy {
    expression = "0 15 ? * *"
  }

  retention_period = "168h"

  snapshot_count = 7

  snapshot_spec {
    description = "daily-snapshot"
  }

  disk_ids = [
    "${yandex_compute_instance.bastion-vm.boot_disk.0.disk_id}",
    "${yandex_compute_instance.web-vm-1.boot_disk.0.disk_id}",
    "${yandex_compute_instance.web-vm-1.boot_disk.0.disk_id}",
    "${yandex_compute_instance.zabbix-vm.boot_disk.0.disk_id}",
    "${yandex_compute_instance.elasticsearch-vm.boot_disk.0.disk_id}",
    "${yandex_compute_instance.kibana-vm.boot_disk.0.disk_id}", ]
}
```




### Дополнительно
Не входит в минимальные требования. 

1. Для Zabbix можно реализовать разделение компонент - frontend, server, database. Frontend отдельной ВМ поместите в публичную подсеть, назначте публичный IP. Server поместите в приватную подсеть, настройте security group на разрешение трафика между frontend и server. Для Database используйте [Yandex Managed Service for PostgreSQL](https://cloud.yandex.com/en-ru/services/managed-postgresql). Разверните кластер из двух нод с автоматическим failover.
2. Вместо конкретных ВМ, которые входят в target group, можно создать [Instance Group](https://cloud.yandex.com/en/docs/compute/concepts/instance-groups/), для которой настройте следующие правила автоматического горизонтального масштабирования: минимальное количество ВМ на зону — 1, максимальный размер группы — 3.
3. В Elasticsearch добавьте мониторинг логов самого себя, Kibana, Zabbix, через filebeat. Можно использовать logstash тоже.
4. Воспользуйтесь Yandex Certificate Manager, выпустите сертификат для сайта, если есть доменное имя. Перенастройте работу балансера на HTTPS, при этом нацелен он будет на HTTP веб-серверов.

## Выполнение работы
На этом этапе вы непосредственно выполняете работу. При этом вы можете консультироваться с руководителем по поводу вопросов, требующих уточнения.

⚠️ В случае недоступности ресурсов Elastic для скачивания рекомендуется разворачивать сервисы с помощью docker контейнеров, основанных на официальных образах.

**Важно**: Ещё можно задавать вопросы по поводу того, как реализовать ту или иную функциональность. И руководитель определяет, правильно вы её реализовали или нет. Любые вопросы, которые не освещены в этом документе, стоит уточнять у руководителя. Если его требования и указания расходятся с указанными в этом документе, то приоритетны требования и указания руководителя.

## Критерии сдачи
1. Инфраструктура отвечает минимальным требованиям, описанным в [Задаче](#Задача).
2. Предоставлен доступ ко всем ресурсам, у которых предполагается веб-страница (сайт, Kibana, Zabbix).
3. Для ресурсов, к которым предоставить доступ проблематично, предоставлены скриншоты, команды, stdout, stderr, подтверждающие работу ресурса.
4. Работа оформлена в отдельном репозитории в GitHub или в [Google Docs](https://docs.google.com/), разрешён доступ по ссылке. 
5. Код размещён в репозитории в GitHub.
6. Работа оформлена так, чтобы были понятны ваши решения и компромиссы. 
7. Если использованы дополнительные репозитории, доступ к ним открыт. 

## Как правильно задавать вопросы дипломному руководителю
Что поможет решить большинство частых проблем:
1. Попробовать найти ответ сначала самостоятельно в интернете или в материалах курса и только после этого спрашивать у дипломного руководителя. Навык поиска ответов пригодится вам в профессиональной деятельности.
2. Если вопросов больше одного, присылайте их в виде нумерованного списка. Так дипломному руководителю будет проще отвечать на каждый из них.
3. При необходимости прикрепите к вопросу скриншоты и стрелочкой покажите, где не получается. Программу для этого можно скачать [здесь](https://app.prntscr.com/ru/).

Что может стать источником проблем:
1. Вопросы вида «Ничего не работает. Не запускается. Всё сломалось». Дипломный руководитель не сможет ответить на такой вопрос без дополнительных уточнений. Цените своё время и время других.
2. Откладывание выполнения дипломной работы на последний момент.
3. Ожидание моментального ответа на свой вопрос. Дипломные руководители — работающие инженеры, которые занимаются, кроме преподавания, своими проектами. Их время ограничено, поэтому постарайтесь задавать правильные вопросы, чтобы получать быстрые ответы :)
