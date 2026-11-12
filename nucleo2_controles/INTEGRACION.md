# Guía de integración — Núcleo 2 (Controles)

Esta guía está pensada para alguien que **nunca ha tocado Godot**. Vamos paso a
paso, desde abrir el proyecto hasta ver los reportes JSON en vivo y usarlos
desde el Núcleo 3 (combate) o el Núcleo 4 (interfaz).

Si solo quieres el resumen: el Núcleo 2 **no escribe un archivo JSON por
fotograma**. Emite un `Dictionary` de Godot 60 veces por segundo mediante una
señal. El JSON que ves en los ejemplos es la forma de esos datos cuando se
serializan para documentación, consola o un archivo `.jsonl`.

---

## 1. Lo que vas a integrar

El Núcleo 2 hace esto:

1. Lee teclado y mandos.
2. Guarda los últimos 15–30 fotogramas en un búfer.
3. Reconoce comandos especiales.
4. Emite **un reporte por jugador por fotograma de física**:

```json
{
  "player_id": 1,
  "frame": 1042,
  "state": {
    "move_x": 1,
    "move_y": 0,
    "punch": false,
    "kick": true,
    "block": false,
    "pause": false
  },
  "command_detected": "SPECIAL_ATTACK_1"
}
```

El Núcleo 3 necesita conectarse a la señal para leer `state` y
`command_detected`. El Núcleo 4 también puede leer `pause` y las direcciones.

Archivos de referencia:

- `contracts/input_report.schema.json`: esquema formal del reporte.
- `contracts/input_report.example.json`: un reporte de ejemplo.
- `contracts/input_report.example.jsonl`: varios reportes de ejemplo, uno por
  línea.
- `CONTRATO.md`: explicación completa del contrato.

> `controls_config.json` **no** es el canal de salida. Es el archivo donde se
> configuran las teclas y los mandos; sus cambios se aplican solos al guardar.

---

## 2. Requisitos

- Godot 4.7. En este equipo está instalado como Flatpak.
- El repositorio GNDU descargado.
- Un teclado. Opcional: uno o dos mandos.

Para comprobar que Godot abre el proyecto del Núcleo 2:

```bash
flatpak run org.godotengine.Godot --path "/ruta/a/GNDU/nucleo2_controles"
```

Si no sabes cuál es la ruta, abre una terminal dentro de la carpeta
`nucleo2_controles` y ejecuta:

```bash
pwd
```

Ese resultado es la ruta que debes usar.

---

## 3. Glosario mínimo de Godot

- **Proyecto**: la carpeta que contiene `project.godot`.
- **Escena**: un archivo `.tscn`; por ejemplo, el diagnóstico o el visor JSON.
- **Nodo**: un elemento dentro de la escena (un botón, una etiqueta, un
  receptor de datos).
- **Script**: un archivo `.gd` con código GDScript asociado a un nodo.
- **Autoload**: un script que Godot carga una sola vez y deja disponible en
  todo el proyecto. El Núcleo 2 usa dos:
  - `N2ControlsConfig`
  - `N2InputCore`
- **Señal**: un aviso que un nodo emite y otro escucha, por ejemplo
  `report_emitted`.

---

## 4. Probar el Núcleo 2 antes de integrarlo

Con el proyecto abierto en Godot, pulsa **F5** o ejecuta:

```bash
flatpak run org.godotengine.Godot --path "/ruta/a/nucleo2_controles"
```

Deberías ver el diagnóstico con dos columnas, J1 y J2.

Teclas de la demo:

| Tecla | Qué hace |
|---|---|
| `R` | Fuerza la recarga de `controls_config.json` (normalmente automática) |
| `J` | Muestra/oculta los JSON en la consola |
| `C` | Congela la cinta del búfer |
| `V` | Abre el visor de JSON |
| `F10` | Sale |

Al guardar `controls_config.json`, la demo lo recarga sola en ~0.5 s; `R` solo
fuerza la recarga.

Si aparece `JUGADOR 1` y `JUGADOR 2`, el núcleo está funcionando.

---

## 5. Entender el reporte

Cada reporte tiene cuatro claves de primer nivel:

| Clave | Tipo | Significado |
|---|---|---|
| `player_id` | entero | `1` o `2` |
| `frame` | entero | Número de fotograma de física |
| `state` | objeto | Estado del jugador en ese fotograma |
| `command_detected` | texto o `null` | Comando especial detectado |

Dentro de `state`:

| Clave | Valores | Significado |
|---|---|---|
| `move_x` | `-1`, `0`, `1` | izquierda, neutro, derecha |
| `move_y` | `-1`, `0`, `1` | abajo/agachado, neutro, arriba/salto |
| `punch` | `true`/`false` | puño mantenido |
| `kick` | `true`/`false` | patada mantenida |
| `block` | `true`/`false` | bloqueo mantenido |
| `pause` | `true`/`false` | pausa mantenida |

Cosas importantes:

- `move_y = 1` **es el salto**. Ya no existe `state.jump`.
- Los booleanos son **estado mantenido**, no eventos. Si quieres saber cuándo
  se acaba de pulsar, compara con el reporte anterior.
- `command_detected` solo trae texto en el fotograma exacto en que se detecta
  el comando. En los demás fotogramas vale `null`.
- Los dos jugadores comparten el mismo `frame` en el mismo tick.

---

## 6. Integrar el Núcleo 2 en el proyecto final

### Paso 1 — Abre el proyecto final

Abre en Godot el proyecto donde se van a juntar los núcleos. No abras solo el
proyecto aislado del Núcleo 3, porque ahí no existen los autoloads del
Núcleo 2.

### Paso 2 — Copia los archivos del Núcleo 2

Copia estos archivos desde `nucleo2_controles/` al proyecto final, respetando
exactamente las rutas:

```text
res://scripts/controls_config.gd
res://scripts/input_core.gd
res://scripts/input_buffer.gd
res://scripts/command_recognizer.gd
res://controls_config.json
```

Si ves archivos `.uid` al lado de los `.gd`, cópialos también. Godot los usa
para identificar los recursos.

> No cambies esas rutas. `input_core.gd` busca sus dependencias dentro de
> `res://scripts/` y `controls_config.gd` busca el JSON en
> `res://controls_config.json`.

### Paso 3 — Agrega los dos autoloads

En Godot:

1. Abre **Proyecto > Configuración del proyecto**
   (`Project > Project Settings`).
2. Entra a la pestaña **Globals** y busca la sección **Autoload**.
   En algunas versiones la pestaña se llama directamente **Autoload**.
3. En la ruta escribe o selecciona:

```text
res://scripts/controls_config.gd
```

4. En el nombre del nodo escribe:

```text
N2ControlsConfig
```

5. Pulsa **Agregar** / **Add** y deja activada la casilla de variable global.
6. Repite el proceso con:

```text
Ruta:  res://scripts/input_core.gd
Nombre: N2InputCore
```

7. Comprueba el orden en la lista: **primero** `N2ControlsConfig`, **después**
   `N2InputCore`. Si están al revés, usa las flechas para reordenarlos.

El orden importa porque `N2InputCore` usa `N2ControlsConfig` cuando arranca.

### Paso 4 — Comprueba los 60 fotogramas por segundo

En **Proyecto > Configuración del proyecto > General**, busca:

```text
Physics > Common > Physics Ticks Per Second
```

Debe valer `60`. El Núcleo 2 emite un reporte por tick de física.

### Paso 5 — Crea un receptor en el Núcleo 3

1. Abre la escena del Núcleo 3 donde quieras recibir las entradas.
2. Agrega un nodo `Node`.
3. Cámbiale el nombre a `InputReceiver`.
4. Pulsa el botón de agregar script y crea uno nuevo, por ejemplo:

```text
res://nucleo3_combate/input_receiver.gd
```

5. Pega este código completo:

```gdscript
extends Node

var _prev: Dictionary = {1: {}, 2: {}}

func _ready() -> void:
	N2InputCore.report_emitted.connect(_on_report)
	print("InputReceiver conectado a N2InputCore")

func _on_report(report: Dictionary) -> void:
	var pid := int(report.get("player_id", 0))
	if pid != 1 and pid != 2:
		return

	var state: Dictionary = report.get("state", {})
	var prev: Dictionary = _prev.get(pid, {})

	var move_x := int(state.get("move_x", 0))
	var move_y := int(state.get("move_y", 0))
	var punch := bool(state.get("punch", false))
	var kick := bool(state.get("kick", false))
	var block := bool(state.get("block", false))
	var pause := bool(state.get("pause", false))

	var punch_pressed := punch and not bool(prev.get("punch", false))
	var kick_pressed := kick and not bool(prev.get("kick", false))
	var jump_pressed := move_y == 1 and int(prev.get("move_y", 0)) != 1
	var pause_pressed := pause and not bool(prev.get("pause", false))

	if punch_pressed:
		print("J%d pulso puno" % pid)
	if kick_pressed:
		print("J%d pulso patada" % pid)
	if jump_pressed:
		print("J%d salto (move_y = +1)" % pid)
	if pause_pressed:
		print("J%d pausa" % pid)

	var command = report.get("command_detected", null)
	if command is String:
		print("J%d comando: %s" % [pid, command])

	_prev[pid] = state.duplicate(true)
```

### Paso 6 — Ejecuta y comprueba

Pulsa **F5**. Si presionas `F` (puño en J1), deberías ver en la consola:

```text
J1 pulso puno
```

Si haces `↓, →, A` (o `S`, `D`, `F` en J1), deberías ver:

```text
J1 comando: SPECIAL_ATTACK_1
```

Si no ves nada, revisa la sección de problemas comunes.

---

## 7. Cómo leer los datos correctamente

### Direcciones

- `move_x < 0`: izquierda.
- `move_x > 0`: derecha.
- `move_y < 0`: abajo/agachado.
- `move_y > 0`: arriba/salto.

### Pulsación contra mantenido

El reporte dice si el botón **está mantenido** en ese fotograma. Para detectar
“se acaba de pulsar”, guarda el estado anterior:

```gdscript
var punch_pressed := punch and not bool(prev.get("punch", false))
```

### Comandos especiales

`command_detected` es un evento de un solo fotograma. Si lo necesitas después,
guárdalo tú:

```gdscript
if report.command_detected != null:
	_mi_ultimo_comando = str(report.command_detected)
```

El Núcleo 3 decide qué significa cada comando. El Núcleo 2 solo manda el
nombre, por ejemplo `SPECIAL_ATTACK_1`, `DASH_RIGHT` o `COMBO_AAA`.

### Pausa

`pause` también es estado mantenido. Si quieres abrir el menú una sola vez,
usa el flanco de subida:

```gdscript
var pause_pressed := pause and not bool(prev.get("pause", false))
```

---

## 8. Ver los JSON en vivo de forma cómoda

El Núcleo 2 incluye un visor de reportes.

1. Ejecuta el proyecto del Núcleo 2.
2. Pulsa `V` o el botón **Visor JSON (V)**. Para volver, pulsa `V`, `Esc`
   o el botón **Volver**.
3. Verás una línea por cada reporte, con J1 en un color y J2 en otro.
4. Botones del visor:
   - **Pausar vista**: deja de refrescar la pantalla, pero sigue guardando en
     memoria.
   - **Limpiar**: vacía la lista.
   - **Filtro**: Todos, Solo J1, Solo J2.
   - **Solo comandos**: muestra únicamente los fotogramas con
     `command_detected`.
   - **Copiar visibles**: copia al portapapeles.
   - **Guardar JSONL**: guarda la lista actual en un archivo.
   - **Abrir carpeta**: abre la carpeta donde se guardan los reportes.
   - **Cargar ejemplo**: carga `contracts/input_report.example.jsonl` para
     probar el visor sin mandos.
   - **Grabar en vivo**: si lo activas, cada reporte se escribe a un `.jsonl`.
   - **Volver (Esc o V)**: regresa al diagnóstico.

Los archivos se guardan en la carpeta de usuario de Godot:

```text
user://n2_reports/
```

En Linux suele corresponder a:

```text
~/.local/share/godot/app_userdata/GNDU - Nucleo 2 Controles/n2_reports/
```

El visor muestra la ruta y tiene un botón para abrir la carpeta.

> El `.jsonl` es un archivo de registro/replay. No es el transporte oficial
> entre núcleos. El transporte oficial es la señal `N2InputCore.report_emitted`.

---

## 9. Probar la integración sin mandos

Puedes usar J1 con teclado:

| Acción | Tecla |
|---|---|
| Izquierda | `A` |
| Derecha | `D` |
| Arriba / salto | `W` o `Espacio` |
| Abajo | `S` |
| Puño | `F` |
| Patada | `G` |
| Bloqueo | `H` |
| Pausa | `Esc` |

Si no tienes mando, J2 quedará desconectado. Para ver reportes de ambos
jugadores sin hardware, abre el visor y pulsa **Cargar ejemplo**.

---

## 10. Problemas comunes

| Problema | Causa probable | Solución |
|---|---|---|
| `Identifier "N2InputCore" not declared` | Falta el autoload o está mal el nombre. | Agrégalo en Globals/Autoload con el nombre exacto `N2InputCore`. |
| `Identifier "N2ControlsConfig" not declared` | Falta el autoload de configuración. | Agrégalo como `N2ControlsConfig` y ponlo antes de `N2InputCore`. |
| No se puede abrir `res://controls_config.json` | El JSON no está en la raíz del proyecto. | Cópialo como `res://controls_config.json`. |
| Error con `N2InputBuffer` o `N2CommandRecognizer` | Faltan scripts o la caché de clases no está actualizada. | Copia los scripts en `res://scripts/` y ejecuta `--import`. |
| No llega ningún reporte | El autoload está desactivado o el receptor no está conectado. | Revisa Autoload y la línea `report_emitted.connect(...)`. |
| No funciona el mando en `--headless` | Godot no procesa mandos sin ventana. | Ejecuta con ventana. |
| El mando no responde como esperaba | El mapeo del JSON no coincide con el mando. | Abre la demo, mira el “último evento físico” y ajusta `controls_config.json`. |
| `state.jump` no existe | El contrato v3 usa `move_y = +1` para el salto. | Usa `move_y == 1`. |
| `command_detected` casi siempre es `null` | Es normal: solo se emite en el fotograma exacto. | Guarda el valor cuando no sea `null`. |
| El visor está vacío | No hay entradas o no hay mandos. | Usa el teclado o pulsa **Cargar ejemplo**. |

---

## 11. Checklist final de integración

- [ ] Los 4 scripts están en `res://scripts/`.
- [ ] `controls_config.json` está en `res://controls_config.json`.
- [ ] `N2ControlsConfig` está en Autoload.
- [ ] `N2InputCore` está en Autoload.
- [ ] `N2ControlsConfig` aparece antes que `N2InputCore`.
- [ ] La física está a 60 ticks por segundo.
- [ ] El receptor del N3 conecta `N2InputCore.report_emitted`.
- [ ] Al pulsar `F` aparece `J1 pulso puno`.
- [ ] Al hacer `↓, →, A` aparece `SPECIAL_ATTACK_1`.
- [ ] El visor JSON muestra reportes de J1 y J2.
- [ ] Guardar JSONL crea un archivo en `user://n2_reports/`.
- [ ] Las pruebas automáticas siguen dando `OK`.

---

## 12. Si hay que cambiar el contrato

El contrato es inmutable salvo acuerdo con todos los núcleos. Si necesitas
cambiarlo:

1. Propón el cambio al equipo.
2. Actualiza `CONTRATO.md`, `contracts/input_report.schema.json` y los
   ejemplos.
3. Actualiza `tests/run_tests.gd`.
4. Avisa a N3/N4 y a N5 si corresponde.
5. Sube la versión del documento.
