#Terraform AWS Auto Scaling + ALB
##Descripcion

Esta arquitectura contiene un grupo de escalado automático con un balanceador de carga de aplicaciones (ALB) para distribuir la carga entre las instancias. 

El grupo de escalado automático considera tres subnets públicas ubicadas en diferentes zonas de disponibilidad. Al ingresar la dirección DNS del ALB en un navegador, se puede verificar la distribución de carga entre las instancias mediante la visualización del ngnx que se instala durante el proceso de deploy.

La arquitectura, implementada en tres Zonas de Disponibilidad, consta de un Internet Gateway, tres subnets públicas, un grupo de escalado automático y un balanceador de carga de aplicaciones.

1 Internet Gateway
1 Tabla de rute
2 Security groups
3 Subnets publicas
1 Auto Scaling Group
1 Application Load Balancer

Adicionalmente para emplear el uso de modulos se utilizo los siguientes modulos:
-  EC2
- S3
- VPC

##Modo de uso

Debido a que se esta usando remot terraform state realizar el apply de la siguiente manera segun el ambiente:

Esta infra estructura esta dividida en dev, stg y prod, como ejemplo tomamos el ambiente de dev:

├── dev
│   ├── custom
│   │   └── id_rsa.pub
│   ├── http.sh
│   ├── main.tf
│   ├── outputs.tf
│   ├── terraform.tfvars
│   └── variables.tf
├── dev-TF-state-bakend
│   ├── dyanmodb.tf
│   ├── provider.tf
│   ├── s3.tf
│   ├── terraform.tfstate
│   ├── terraform.tfvars
│   └── variables.tf
├── prod
│   ├── custom
│   │   └── id_rsa.pub
│   ├── http.sh
│   ├── main.tf
│   ├── outputs.tf
│   ├── terraform.tfvars
│   └── variables.tf
├── prod-TF-state-bakend
│   ├── dyanmodb.tf
│   ├── provider.tf
│   ├── s3.tf
│   ├── terraform.tfstate
│   ├── terraform.tfvars
│   └── variables.tf
├── stg
│   ├── custom
│   │   └── id_rsa.pub
│   ├── http.sh
│   ├── main.tf
│   ├── outputs.tf
│   ├── terraform.tfvars
│   └── variables.tf
└── stg-TF-state-bakend
    ├── dyanmodb.tf
    ├── provider.tf
    ├── s3.tf
    ├── terraform.tfstate
    ├── terraform.tfvars
    └── variables.tf

Ejecute los siguientes comandos:

1.  cd dev-TF-state-bakend
2. terraform init
3. cd ..
4. cd dev
5. terraform init
6. terraform plan
7. terraform apply -auto-approve

Para eliminar la infraestructura, ejecutamos el comando terraform destroy en el directorio donde esta la infra. 

Sin embargo, este proceso no elimina automáticamente el bucket y la tabla DynamoDB en aws que utilizamos como backend.
####Nota
Estos dos recursos deben ser eliminados manualmente desde la consola aws.

Ejecute
1.  cd dev
2. terraform destroy -auto-approve
