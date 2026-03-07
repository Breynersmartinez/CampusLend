| Prefijo         | Objeto                  | Ejemplo                   | Recomendación              |
| --------------- | ----------------------- | ------------------------- | -------------------------- |
| `v_`            | Vista                   | `v_usuarios_activos`      | ✅ Estándar                 |
| `vw_`           | Vista                   | `vw_productos_stock`      | ⚠️ Menos común             |
| `m_`            | Vista materializada     | `m_reportes_ventas`       | ✅ Recomendado              |
| `mv_`           | Vista materializada     | `mv_datos_agregados`      | ✅ Alternativa              |
| `fn_`           | Función                 | `fn_calcular_edad()`      | ✅ Estándar                 |
| `get_`          | Función (getter)        | `get_total_pedidos()`     | ✅ Descriptivo              |
| `idx_`          | Índice                  | `idx_email_usuario`       | ✅ Estándar                 |
| `seq_`          | Secuencia               | `seq_usuarios_id`         | ⚠️ Generalmente automática |
| `tg_`           | Trigger                 | `tg_actualizar_timestamp` | ✅ Recomendado              |
| `tmp_`          | Tabla temporal          | `tmp_datos_importacion`   | ✅ Estándar                 |
| *(sin prefijo)* | Tabla                   | `usuarios`, `productos`   | ✅ Estándar                 |
| *(sin prefijo)* | Procedimiento / Función | `crear_usuario()`         | ✅ PostgreSQL               |
