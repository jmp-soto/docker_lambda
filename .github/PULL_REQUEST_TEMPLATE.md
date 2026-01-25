# Despliegue de Lambdas

## Despliegue Automático

Para desplegar lambdas específicas, incluye en el título del PR:

### Ejemplos de títulos:
- `[deploy:api-processor,data-transformer] Mi nueva funcionalidad`
- `[deploy:image-processor] Optimización de procesamiento`
- `[deploy:user-service,payment-service] Integración de pagos`
- `[deploy-all] Actualización completa del sistema`

### Lambdas disponibles:
- `api-processor` - Procesador de API
- `data-transformer` - Transformador de datos
- `image-processor` - Procesador de imágenes
- `notification-service` - Servicio de notificaciones
- `user-service` - Servicio de usuarios
- `payment-service` - Servicio de pagos

## Checklist

- [ ] Testes unitarios pasan
- [ ] Testes de integración pasan
- [ ] Documentación actualizada
- [ ] Variables de entorno configuradas
- [ ] Backward compatibility verificada

## Despliegue

El despliegue automático se activará cuando el PR sea mergeado a `main`.

**Nota:** Solo las lambdas especificadas en el título serán desplegadas.