# NetBeans 8.2 para Apple Silicon

Script de un solo comando para instalar **NetBeans IDE 8.2** en Mac con Apple Silicon (M1, M2, M3, M4). Corre **100% nativo en ARM64, sin Rosetta**, usando Azul Zulu JDK 8 **con JavaFX incluido**. Pensado para escuelas y cursos que todavía piden NetBeans 8.2.

## ¿Por qué existe esto?

NetBeans 8.2 salió en 2016, cuatro años antes del primer chip Apple Silicon. No hay versión oficial para estas Macs, Oracle ya no la distribuye y el instalador `.dmg` de la época es código Intel sin firmar que macOS actual bloquea.

Pero NetBeans está hecho en Java, así que no depende del procesador: lo que depende del procesador es el **JDK** que lo ejecuta. Este script junta las dos piezas correctas:

- el **ZIP original de NetBeans 8.2** (la versión "platform independent", puro Java), y
- un **JDK 8 compilado para ARM64 con JavaFX** (Azul Zulu FX),

y las configura para que funcionen juntas. El resultado es el mismo NetBeans 8.2 que usan en el salón (build `201609300101`), corriendo nativo en tu chip.

## Instalación

Abre la **Terminal** y pega esto:

```bash
curl -fsSL https://raw.githubusercontent.com/Cookles-lsi/NetBeans-8.2-Apple-Silicon/main/instalar.sh | bash
```

Tarda unos minutos (descarga unos 350 MB). No pide contraseña: todo se instala dentro de tu usuario.

Cuando termine, ábrelo de cualquiera de estas formas:

- **Spotlight:** `Cmd + Espacio` → escribe `NetBeans 8.2`
- **Terminal:** abre una ventana nueva y escribe `nb82`

La primera vez tarda un poco en abrir porque crea su configuración.

## Qué hace el script

1. Busca si ya tienes un JDK 8 nativo ARM64 **con JavaFX**. Si no, descarga Azul Zulu JDK 8 FX y lo pone en `~/Library/Java/JavaVirtualMachines/zulu-8-fx.jdk`.
2. Descarga el ZIP original de NetBeans 8.2 y lo instala en `~/Applications/netbeans-8.2`.
3. Configura `etc/netbeans.conf` para que NetBeans use ese JDK 8 (con Java 9 o más nuevo, NetBeans 8.2 no arranca).
4. Crea el acceso directo `~/Applications/NetBeans 8.2.app` y el comando `nb82`.

Las dos descargas se verifican con SHA-256: si el archivo no es idéntico al original, el script se detiene sin instalar nada.

Puedes correrlo las veces que quieras. Si NetBeans ya está instalado, no lo vuelve a descargar: solo revisa que la configuración esté bien.

## Comprobar que corre nativo

```bash
file ~/Library/Java/JavaVirtualMachines/zulu-8-fx.jdk/Contents/Home/bin/java
```

Debe decir `Mach-O 64-bit executable arm64`. También puedes abrir **Monitor de Actividad**, buscar el proceso `java` con NetBeans abierto y ver que en la columna **Tipo** diga **Apple** (no Intel).

## Opciones

| Opción | Qué hace |
|---|---|
| `--reinstalar` | Vuelve a descargar NetBeans desde cero. La carpeta anterior se guarda como respaldo. |
| `--desinstalar` | Quita NetBeans 8.2, el acceso directo y el comando `nb82`. |
| `--ayuda` | Muestra la ayuda. |

Con `curl`, las opciones se pasan así:

```bash
curl -fsSL https://raw.githubusercontent.com/Cookles-lsi/NetBeans-8.2-Apple-Silicon/main/instalar.sh | bash -s -- --desinstalar
```

Desinstalar **no borra** tus proyectos (`~/NetBeansProjects`) ni tu configuración. El JDK 8 solo se borra si lo instaló este script.

## Requisitos

- Mac con chip Apple Silicon (M1 o más nuevo)
- Conexión a internet para la instalación
- Aproximadamente 1 GB libre en disco

No necesitas Homebrew ni Rosetta.

## Preguntas frecuentes

**¿Funciona JavaFX?**
Sí. El JDK que instala el script trae JavaFX (`jfxrt.jar` y sus librerías gráficas nativas ARM64), y NetBeans 8.2 incluye las plantillas de proyecto JavaFX (**File → New Project → JavaFX**). Si ya habías instalado con una versión anterior del script, o tu JDK 8 no traía JavaFX, vuelve a correr el comando de instalación: detecta que falta y lo agrega sin tocar tus proyectos.

Para comprobarlo:

```bash
ls ~/Library/Java/JavaVirtualMachines/zulu-8-fx.jdk/Contents/Home/jre/lib/ext/jfxrt.jar
```

**Me sale "An instance of the program seems to be already running with your user directory".**
NetBeans se cerró de golpe la última vez y dejó un archivo de candado. Si no tienes otro NetBeans abierto, dale **OK** y abre normal.

**Cada vez que corro un programa con `JFrame` aparece un icono nuevo en el Dock y se queda ahí.**
Es tu programa que sigue vivo después de cerrar la ventana. Por defecto Swing solo esconde la ventana (`HIDE_ON_CLOSE`). Ponle esto antes de `setVisible(true)`:

```java
setDefaultCloseOperation(JFrame.EXIT_ON_CLOSE);
```

Si usaste el diseñador visual, cámbialo en **Properties → defaultCloseOperation → EXIT_ON_CLOSE**. En Windows pasa lo mismo, solo que ahí no se nota.

**El texto se ve muy chico.**
Ábrelo con `nb82 --fontsize 14` (prueba el tamaño que te acomode). Para dejarlo fijo, agrega `--fontsize 14` dentro de `netbeans_default_options` en `~/Applications/netbeans-8.2/etc/netbeans.conf`.

**Ya tengo Apache NetBeans (versión moderna). ¿Hay conflicto?**
No. Cada versión usa su propia carpeta y su propia configuración, y pueden estar instaladas al mismo tiempo.

**¿Mis proyectos abren en las computadoras de la escuela con Windows?**
Sí. Un proyecto de NetBeans es una carpeta con `src`, `build.xml` y `nbproject`, nada que dependa del sistema. Evita acentos y espacios raros en la ruta del proyecto porque el Ant de esa época se confunde.

**NetBeans se cierra solo en "Turning on modules...".**
Casi siempre es porque está usando un Java más nuevo que el 8 (por ejemplo, el JDK 21 que trae Apache NetBeans). Revisa la línea `netbeans_jdkhome` en `~/Applications/netbeans-8.2/etc/netbeans.conf`: debe apuntar a un JDK 8. Si la cambiaste, vuelve a correr el script y la corrige solo.

## De dónde sale cada cosa

| Componente | Origen | Licencia |
|---|---|---|
| NetBeans IDE 8.2 | ZIP original en el CDN heredado de Oracle (`dlc-cdn.sun.com`) | CDDL / GPL v2 con excepción de classpath |
| Azul Zulu JDK 8 FX (incluye OpenJFX) | CDN oficial de Azul (`cdn.azul.com`) | GPL v2 con excepción de classpath |
| Este script | Este repositorio | [MIT](LICENSE) |

Este repositorio **no incluye** NetBeans ni el JDK: el script los descarga directamente de sus fuentes originales.

## Aviso

Proyecto independiente, sin afiliación con Apache Software Foundation, Oracle, Azul Systems ni Apple. NetBeans, Java, macOS y Apple Silicon son marcas de sus respectivos dueños.
