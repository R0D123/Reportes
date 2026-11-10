# Dashboard DTS · GitHub Pages + Supabase

Sitio web estático para analizar ingresos, gastos, utilidad, margen y centros de costo. Mantiene la vista, los gráficos, los filtros, la comparación mensual y el acumulado anual del dashboard original. También guarda el archivo Excel original y sus datos procesados **en la nube por usuario** cuando se configura Supabase.

## Arquitectura

- **GitHub Pages**: aloja `index.html`, `styles.css`, `config.js` y el código JavaScript. GitHub Pages NO almacena archivos cargados por visitantes.
- **Supabase Auth**: protege el acceso mediante correo y contraseña.
- **Supabase Database**: tabla `public.dts_imports`, una fila por usuario/periodo y datos procesados en JSONB. **Es el único almacenamiento persistente de datos procesados**.
- **Supabase Storage**: bucket **privado** `dts-excels` donde se conservan los `.xlsx`, `.xls` y `.csv` originales. Puedes descargarlos desde el histórico en cualquier dispositivo con tu misma cuenta.
- **RLS**: políticas de seguridad para que cada usuario acceda únicamente a sus archivos y periodos.

## Configuración (necesaria para conservar los Excel originales)

1. Crea un proyecto en https://supabase.com/ .
2. Abre **Storage > New bucket**. Nombre exacto: `dts-excels`. **Public bucket: OFF**. Opcional: limita a 15 MB (o ajusta `MAX_FILE_MB` en `config.js` sin exceder el límite configurado en Storage). Si activas restricción MIME, verifica compatibilidad con `.xls`, `.xlsx` y `.csv`.
3. Abre **SQL Editor**, pega `supabase.sql` y ejecútalo. Este archivo crea la tabla y sus políticas RLS de lectura/escritura/borrado.
4. Abre **Project Settings > API Keys** y copia la **Project URL** y una **Publishable key** (`sb_publishable_...`, o la clave `anon` antigua). Colócalas en `config.js`:

   ```js
   window.DTS_CONFIG = {
     SUPABASE_URL: "https://TU-PROYECTO.supabase.co",
     SUPABASE_PUBLISHABLE_KEY: "sb_publishable_TU_CLAVE",
     MAX_FILE_MB: 15
   };
   ```

   Estas dos variables son públicas por diseño, pero **NO** incluyas jamás una clave `service_role`, `sb_secret_...`, tokens personales ni contraseñas en GitHub.
5. En **Authentication > Providers**, activa Email. Crea tu cuenta desde el panel web. Si tienes confirmación de correo activada, abre **Authentication > URL Configuration** e incluye la URL de GitHub Pages en **Site URL** y/o **Redirect URLs**. Se recomienda desactivar nuevos registros públicos después de dar de alta las cuentas autorizadas en **Authentication > Settings** o la sección equivalente.
6. Crea un repositorio GitHub, añade `index.html`, `styles.css`, `config.js`, `supabase.sql`, `README.md` y `.nojekyll`. No subas Excel financieros al repositorio.
7. En GitHub: **Settings > Pages > Build and deployment > Deploy from a branch > main > /(root) > Save**.
8. Accede a `https://TU-USUARIO.github.io/TU-REPOSITORIO/`. Inicia sesión, sube un Excel, cierra sesión y vuelve a entrar para comprobar la persistencia. Desde otro equipo, abre el mismo enlace e inicia sesión con **la misma cuenta**. Selecciona el periodo y usa **Excel** para descargar el original. **Sincronizar con la nube** recupera el histórico actualizado de Supabase.
9. **No se habilita la carga hasta haber autenticado y leído correctamente el histórico en la nube**. Si Supabase no responde, la aplicación bloquea las cargas en lugar de guardarlas en el navegador.

## Almacenamiento exclusivamente en la nube (obligatorio)

**No existe modo local ni almacenamiento persistente de datos financieros en el navegador.** `config.js` necesita las claves públicas de Supabase para habilitar el dashboard, y es obligatorio iniciar sesión para cargar, descargar, borrar y sincronizar periodos. Si faltan estas variables o no se puede consultar la base de datos, la interfaz muestra un bloqueo explícito. Nunca anuncia una carga guardada sin confirmación de Supabase.

**Flujo de importación:**

1. El navegador lee el Excel y calcula ingresos, gastos, utilidad y margen **temporalmente en memoria**, para su procesamiento y presentación.
2. Sube el **Excel original** al bucket privado `dts-excels` de Supabase Storage.
3. Guarda los **datos procesados** en `public.dts_imports` de Supabase Database, asociados a uno o más periodos. El servidor confirma la inserción/actualización antes de mostrar éxito.
4. Consulta nuevamente la nube para actualizar los filtros, gráficos e histórico. El botón **Sincronizar con la nube** repite esa lectura para mostrar cambios realizados desde otros dispositivos.

Supabase Auth sí puede guardar **el token de sesión** del usuario en el navegador para mantener su acceso, pero **nunca guarda los Excel ni los datos financieros procesados allí**. La descarga manual de CSV o JSON es una copia que el usuario decide guardar, no un respaldo automático local.

Si usaste versiones antiguas que guardaban datos en `localStorage`, esos registros **no se transfieren automáticamente** a Supabase ni se borran sin tu autorización. Antes de sustituir la versión previa, exporta un respaldo si los necesitas y vuelve a cargar sus Excel originales en la versión nueva. Si deseas eliminar el almacenamiento obsoleto del navegador, hazlo desde las herramientas del navegador, después de comprobar que el respaldo en la nube está completo.

**Importante sobre compartir:** con este diseño, *cualquier dispositivo con la misma cuenta* ve y descarga los archivos. Las cuentas diferentes no comparten históricos; para que varios trabajadores con usuarios distintos vean datos comunes sería necesario un esquema adicional de equipos/permisos.

## Formatos de Excel admitidos (importador flexible)

El importador no exige nombres específicos de pestañas. Detecta las columnas por sus encabezados y es capaz de procesar varios meses en un solo archivo, siempre que los periodos sean identificables:

- **Tabla simple**: columnas `Centro`, `Ingresos` y `Gastos` o equivalentes (p. ej. `Centro de Costo`, `Ventas`, `Costos`). Puede tener `Utilidad` y `Margen`, los que se contrastan con los cálculos y no se consideran valores fuente para el dashboard.
- **Tabla larga con meses**: columnas `Mes`/`Periodo`, `Centro`, `Ingresos`, `Gastos`. Cada fila se almacena bajo su mes. El año puede figurar en la celda de periodo o en el nombre del archivo.
- **Pestañas por mes**: hojas `Enero`, `Febrero`, etc. con columnas `Centro`, `Ingresos`, `Gastos`. Incluir el año en el nombre del archivo (ejemplo: `DTS_2026.xlsx`).
- **Meses distribuidos en columnas**: `Centro | Enero Ingresos | Enero Gastos | Febrero Ingresos | Febrero Gastos` o dos filas de encabezado (mes arriba, ingresos/gastos abajo).
- **Formato contable original**: tabla con el encabezado de total mensual y las cuentas `4 - Ingresos` y `31` a `37` para gastos, o `3 - Gastos` como alternativa.
- **CSV**: columnas `Periodo` (opcional), `Centro`, `Ingresos`, `Gastos`; separador `;` o `,`.

Se recalculan siempre **Utilidad = Ingresos − Gastos** y **Margen = Utilidad / Ingresos**, siempre que el ingreso sea distinto de cero. Para archivos que abarcan más de un mes sin una columna o encabezados de mes, la carga se rechaza en lugar de agrupar indebidamente todo en un único periodo. Si aparece un mensaje de incompatibilidad, revisa el diagnóstico de hojas y primeras celdas o proporciona el Excel para agregar un mapeo exacto. Si los meses vienen sin **año**, se podrán consultar individualmente, pero aparecerán como *Sin año informado* en la comparación anual.

Si se importa nuevamente un periodo, reemplaza ese mes completo. **No se suman copias del mismo mes**. En la nube, un mismo Excel puede asociarse a varios periodos sin necesidad de duplicar su archivo original.

## Consideraciones

- Supabase y credenciales son **obligatorios**. Esta entrega no incluye una base de datos ni credenciales activas; GitHub Pages por sí solo no conserva los Excel ni las cargas.
- Los datos son **privados por cuenta**, no constituyen todavía un espacio de trabajo multiusuario compartido. Para acceso colaborativo de varios usuarios con datos comunes se requiere un esquema de organizaciones/permisos adicional.
- GitHub Pages expone el código fuente; la seguridad depende de RLS y del bucket privado. No guardes Excel en el repositorio.
- La importación y el cálculo ocurren en el navegador; los originales se almacenan en el bucket. La versión de la librería Excel se carga desde CDN de SheetJS y la de Supabase desde jsDelivr; se requiere internet para Excel `.xlsx`/`.xls`.
- Se guarda primero el Excel original y luego los datos. Como Storage y Database no comparten una transacción única, si ocurre una interrupción de red entre ambos pueden quedar archivos huérfanos; no se marca esa carga como confirmada. Comprueba los estados de Supabase y el histórico después de cualquier fallo.
- Verifica que los importes de Gastos en tu planilla sean positivos (la fórmula de utilidad resta los gastos). Si tu contabilidad registra gastos como valores negativos, modifica la normalización antes de operar.
