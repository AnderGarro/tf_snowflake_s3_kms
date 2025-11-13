#!/bin/bash

# Script de comandos útiles para el proyecto Terraform S3-Snowflake-KMS

echo "==================================="
echo "Terraform S3-Snowflake-KMS Commands"
echo "==================================="
echo ""

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

function show_menu() {
    echo "Selecciona una opción:"
    echo ""
    echo "DESPLIEGUE:"
    echo "  1) Inicializar Terraform"
    echo "  2) Ver plan de ejecución"
    echo "  3) Aplicar configuración"
    echo "  4) Aplicar en fases (recommended)"
    echo "  5) Destruir todos los recursos"
    echo ""
    echo "VERIFICACIÓN:"
    echo "  6) Ver outputs"
    echo "  7) Verificar KMS key"
    echo "  8) Verificar encriptación S3"
    echo "  9) Test de subida de archivo"
    echo "  10) Listar archivos en stage (Snowflake)"
    echo ""
    echo "DIAGNÓSTICO:"
    echo "  11) Ver estado actual"
    echo "  12) Validar configuración"
    echo "  13) Ver log de errores"
    echo ""
    echo "  0) Salir"
    echo ""
    read -p "Opción: " option
    
    case $option in
        1) terraform_init ;;
        2) terraform_plan ;;
        3) terraform_apply ;;
        4) terraform_apply_phases ;;
        5) terraform_destroy ;;
        6) show_outputs ;;
        7) verify_kms ;;
        8) verify_s3_encryption ;;
        9) test_upload ;;
        10) list_stage_files ;;
        11) show_state ;;
        12) validate_config ;;
        13) show_errors ;;
        0) exit 0 ;;
        *) echo -e "${RED}Opción inválida${NC}" ;;
    esac
}

function terraform_init() {
    echo -e "${GREEN}Inicializando Terraform...${NC}"
    terraform init
    echo ""
    read -p "Presiona Enter para continuar..."
}

function terraform_plan() {
    echo -e "${GREEN}Generando plan de ejecución...${NC}"
    terraform plan
    echo ""
    read -p "Presiona Enter para continuar..."
}

function terraform_apply() {
    echo -e "${YELLOW}⚠️  ADVERTENCIA: Esto creará recursos en AWS y Snowflake${NC}"
    read -p "¿Continuar? (yes/no): " confirm
    if [ "$confirm" == "yes" ]; then
        terraform apply
    else
        echo "Cancelado"
    fi
    echo ""
    read -p "Presiona Enter para continuar..."
}

function terraform_apply_phases() {
    echo -e "${GREEN}Aplicando en fases (recomendado para primera ejecución)...${NC}"
    echo ""
    
    echo -e "${YELLOW}Fase 1: KMS Key${NC}"
    terraform apply -target=aws_kms_key.snowflake_s3 -target=aws_kms_alias.snowflake_s3 -auto-approve
    
    echo -e "${YELLOW}Fase 2: S3 Bucket${NC}"
    terraform apply -target=aws_s3_bucket.snowflake_stage -auto-approve
    
    echo -e "${YELLOW}Fase 3: IAM Role${NC}"
    terraform apply -target=aws_iam_role.snowflake_role -auto-approve
    
    echo -e "${YELLOW}Fase 4: Snowflake Resources${NC}"
    terraform apply -target=snowflake_database.demo -target=snowflake_schema.demo -auto-approve
    
    echo -e "${YELLOW}Fase 5: Storage Integration${NC}"
    terraform apply -target=snowflake_storage_integration.s3_integration_kms -auto-approve
    
    echo -e "${YELLOW}Fase 6: Finalizar (actualizar políticas y stage)${NC}"
    terraform apply -auto-approve
    
    echo -e "${GREEN}✅ Despliegue completado${NC}"
    echo ""
    read -p "Presiona Enter para continuar..."
}

function terraform_destroy() {
    echo -e "${RED}⚠️  PELIGRO: Esto eliminará TODOS los recursos${NC}"
    echo "Recursos que se eliminarán:"
    echo "  - KMS Key (entrará en periodo de eliminación)"
    echo "  - S3 Bucket y todo su contenido"
    echo "  - IAM Role y políticas"
    echo "  - Storage Integration y Stage en Snowflake"
    echo ""
    read -p "¿Estás SEGURO? Escribe 'DELETE' para confirmar: " confirm
    if [ "$confirm" == "DELETE" ]; then
        terraform destroy
    else
        echo "Cancelado"
    fi
    echo ""
    read -p "Presiona Enter para continuar..."
}

function show_outputs() {
    echo -e "${GREEN}Outputs del despliegue:${NC}"
    terraform output
    echo ""
    read -p "Presiona Enter para continuar..."
}

function verify_kms() {
    echo -e "${GREEN}Verificando KMS Key...${NC}"
    KMS_ALIAS=$(terraform output -raw kms_key_alias 2>/dev/null)
    if [ -z "$KMS_ALIAS" ]; then
        echo -e "${RED}Error: No se encontró el alias de KMS. ¿Está desplegado?${NC}"
    else
        aws kms describe-key --key-id "$KMS_ALIAS" --region eu-west-1
        echo ""
        echo -e "${YELLOW}Política de la key:${NC}"
        aws kms get-key-policy --key-id "$KMS_ALIAS" --policy-name default --region eu-west-1
    fi
    echo ""
    read -p "Presiona Enter para continuar..."
}

function verify_s3_encryption() {
    echo -e "${GREEN}Verificando encriptación S3...${NC}"
    BUCKET=$(terraform output -raw s3_bucket_name 2>/dev/null)
    if [ -z "$BUCKET" ]; then
        echo -e "${RED}Error: No se encontró el bucket. ¿Está desplegado?${NC}"
    else
        aws s3api get-bucket-encryption --bucket "$BUCKET"
    fi
    echo ""
    read -p "Presiona Enter para continuar..."
}

function test_upload() {
    echo -e "${GREEN}Test de subida de archivo...${NC}"
    BUCKET=$(terraform output -raw s3_bucket_name 2>/dev/null)
    if [ -z "$BUCKET" ]; then
        echo -e "${RED}Error: No se encontró el bucket. ¿Está desplegado?${NC}"
        return
    fi
    
    # Crear archivo de prueba
    echo "col1,col2,col3" > test_upload.csv
    echo "value1,value2,value3" >> test_upload.csv
    echo "value4,value5,value6" >> test_upload.csv
    
    echo "Subiendo test_upload.csv..."
    aws s3 cp test_upload.csv "s3://$BUCKET/snowflake-data/test_upload.csv"
    
    echo ""
    echo "Verificando encriptación del objeto..."
    aws s3api head-object \
        --bucket "$BUCKET" \
        --key "snowflake-data/test_upload.csv" \
        --query '{Encryption: ServerSideEncryption, KMSKeyId: SSEKMSKeyId}'
    
    echo ""
    echo -e "${GREEN}✅ Archivo subido y encriptado correctamente${NC}"
    
    rm test_upload.csv
    echo ""
    read -p "Presiona Enter para continuar..."
}

function list_stage_files() {
    echo -e "${GREEN}Archivos en Snowflake Stage:${NC}"
    echo ""
    echo "Conecta a Snowflake y ejecuta:"
    echo ""
    echo "USE ROLE ACCOUNTADMIN;"
    echo "USE DATABASE DEMO_KMS_V3;"
    echo "USE SCHEMA DEMO_SCHEMA;"
    echo "LIST @S3_STAGE_KMS;"
    echo ""
    read -p "Presiona Enter para continuar..."
}

function show_state() {
    echo -e "${GREEN}Estado actual de Terraform:${NC}"
    terraform show
    echo ""
    read -p "Presiona Enter para continuar..."
}

function validate_config() {
    echo -e "${GREEN}Validando configuración...${NC}"
    terraform validate
    terraform fmt -check -recursive .
    echo ""
    read -p "Presiona Enter para continuar..."
}

function show_errors() {
    echo -e "${GREEN}Últimos errores de Terraform:${NC}"
    if [ -f "crash.log" ]; then
        tail -n 50 crash.log
    else
        echo "No se encontraron logs de errores"
    fi
    echo ""
    read -p "Presiona Enter para continuar..."
}

# Loop principal
while true; do
    clear
    show_menu
done
