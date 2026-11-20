# Núcleo 2 — Controles (GNDU)

Núcleo 2 integrado en el proyecto unificado de un juego de pelea 2D.
Captura teclado y mandos, guarda los últimos **15 a 30 fotogramas** de entrada
(30 por defecto), reconoce comandos (los seis especiales canónicos, combos y
doble toque) y emite un **reporte JSON por jugador en cada fotograma de física
a 60 Hz**.

El núcleo puede probarse por separado con datos simulados (incluye un
consumidor falso del N3 que valida el contrato), pero en este repositorio ya
convive con el N3 como un solo proyecto.

- Formato de datos: [CONTRATO.md](CONTRATO.md)
- Guía de integración paso a paso: [INTEGRACION.md](INTEGRACION.md)
- Esquema y ejemplos: [contracts/](../../contracts/)
- Matriz de cumplimiento contra el PDF: [VERIFICACION.md](VERIFICACION.md)

---

## 1. Requisitos

- **Godot 4.7** (probado con `4.7.2.stable`).
- En este equipo está como Flatpak:

```bash
flatpak run org.godotengine.Godot --path "/ruta/a/GNDU"
```

- Un teclado y, opcionalmente, 1 o 2 mandos (Xbox, PlayStation o genéricos).

---

## 2. Cómo abrir y ejecutar

1. Abrir el proyecto raíz `GNDU` desde el administrador de proyectos de Godot,
   o con el comando de arriba.
2. La escena principal del juego es `res://scenes/escenario.tscn` (combate).
   Para abrir solo el diagnóstico de controles usa
   `res://scenes/diagnostic.tscn`.
3. Al arrancar el diagnóstico se ve el panel con **J1** y **J2**.

El juego está pensado para **1920×1080** y el motor corre la física a
**60 fotogramas por segundo** (`project.godot`).

### Teclas de la propia demo

| Tecla | Acción |
|-------|--------|
| `F1`  | Forzar recarga de `controls_config.json` (normalmente es automática) |
| `F2`  | Mostrar/ocultar la consola de reportes JSON |
| `F3`  | Congelar/descongelar la cinta del búfer |
| `F4`  | Abrir/volver del visor de reportes JSON |
| `F10` | Salir |

> `F1`, `F2`, `F3`, `F4` y `F10` son teclas del **diagnóstico**, no del juego, y
> no forman parte del mapeo configurable. `F1` solo fuerza la recarga manual.

---

## 3. Controles por defecto

### Jugador 1 (híbrido: teclado + mando 0)

| Acción | Teclado | Mando |
|--------|---------|-------|
| Izquierda | `A` | D-pad izq. / stick izq. ← |
| Derecha   | `D` | D-pad der. / stick izq. → |
| Arriba (dirección) | `W` | D-pad arr. / stick izq. ↑ |
| Abajo     | `S` | D-pad aba. / stick izq. ↓ |
| **Salto** | `Espacio` | `X` (oeste) / `Y` (norte) |
| Puño      | `H` | `A` (sur) |
| Patada    | `J` | `B` (este) |
| Bloqueo   | `K` | `RB` |
| **Agarre**| `L` | `LB` |
| Pausa     | `Esc` | `Start` |

### Jugador 2 (híbrido: teclado + mando 1)

| Acción | Teclado | Mando |
|--------|---------|-------|
| Izquierda | `←` | D-pad izq. / stick izq. ← |
| Derecha   | `→` | D-pad der. / stick izq. → |
| Arriba (dirección) | `↑` | D-pad arr. / stick izq. ↑ |
| Abajo     | `↓` | D-pad aba. / stick izq. ↓ |
| **Salto** | `/` | `X` (oeste) / `Y` (norte) |
| Puño      | `Shift` | `A` (sur) |
| Patada    | `Enter` | `B` (este) |
| Bloqueo   | `Ctrl` | `RB` |
| **Agarre**| `Alt` | `LB` |
| Pausa     | `Backspace` | `Start` |

> El **salto** es una acción separada (`jump`), no la dirección arriba.
> `Espacio`/`/` y `X`/`Y` emiten `pressed.jump` en el snapshot interno de N2;
> `W`/`↑`, el D-pad arriba y el stick arriba siguen emitiendo `move_y = +1`
> como dirección. El **agarre** (`grab`) usa `L`/`Alt` y `LB`/`L1`.

Los botones se nombran por **posición física**, no por letra impresa:

| Nombre en el JSON | Posición |
|---|---|
| `a` | sur (abajo) |
| `b` | este (derecha) |
| `x` | oeste (izquierda) |
| `y` | norte (arriba) |

En un mando Xbox, `a` es la `A` y `b` es la `B`. En un mando Switch Pro,
`a` es el botón del sur (impreso `B`) y `b` el del este (impreso `A`).
En PlayStation, `a` es la cruz y `b` el círculo.

Por eso el mismo JSON funciona en Xbox, PlayStation y Switch; el diagnóstico
muestra el nombre real del mando y el monitor de eventos permite comprobar
qué botón reporta cada uno.

Los gatillos `LT`/`RT` son **ejes analógicos** (0→1): se pueden usar como
`joy_axis` con `direction: 1` y `deadzone` (ver más abajo). No son botones.

---

## 4. Comandos reconocidos

Los comandos son **direccionales absolutos** (izquierda/derecha reales).
El N3 es quien decide qué significa "adelante" según hacia dónde mira el
personaje.

Notación: **A = puño**, **B = patada** (los mismos botones `a`/`b` del
mando y las teclas `H`/`J` de J1, `Shift`/`Enter` de J2). Las flechas son
direcciones absolutas de pantalla.

El **salto** y el **agarre** no son comandos de esta lista: se emiten como
`pressed.jump` y `pressed.grab` en el snapshot interno de N2. El N3 los lee con
`get_last_snapshot(player_id)`. El reporte JSON conserva sus seis claves.

| Comando | Secuencia | Ventana | Hueco máx. | Enfriamiento |
|---------|-----------|---------|-----------|--------------|
| `HADOKEN` | ←, →, A | 24 frames | 10 | 12 |
| `SHORYUKEN` | →, ↓, →, A | 32 frames | 10 | 12 |
| `ABAJO_ARRIBA` | ↓, ↑, A | 24 frames | 10 | 12 |
| `DOBLE_PATADA` | ↓, →, B | 24 frames | 10 | 12 |
| `EMBESTIDA` | →, ↓, →, B | 32 frames | 10 | 12 |
| `TATSUMAKI` | ←, →, B | 24 frames | 10 | 12 |
| `DASH_RIGHT` | →, → (doble toque) | 18 frames | 9 | 10 |
| `DASH_LEFT`  | ←, ← (doble toque) | 18 frames | 9 | 10 |
| `COMBO_AAA` | A, A, A | 30 frames | 12 | 18 |
| `COMBO_BBB` | B, B, B | 30 frames | 12 | 18 |
| `COMBO_ABA` | A, B, A | 30 frames | 12 | 18 |
| `COMBO_AAB` | A, A, B | 30 frames | 12 | 18 |

> Estos 12 nombres son los canónicos que consume el Núcleo 3. `SHORYUKEN` y
> `EMBESTIDA` comparten el prefijo `→, ↓, →` y se distinguen por el botón final
> (`A`/`B`). `TATSUMAKI` usa `←, →, B`; el N3 también conserva alias antiguos
> por compatibilidad.

Reglas de tolerancia:

- Todos los comandos por defecto usan `mode: "press"`: cada paso debe ser un
  **flanco de subida** (no vale mantener). El formato también admite
  `hold` (mantenido) y `release` (flanco de bajada) para comandos propios.
- Entre pasos hay un hueco máximo configurable (`max_gap`, por defecto 10).
- El **último** paso debe caer en los últimos `final_window` frames (2).
- Tras emitir un comando hay un `cooldown` propio (10–18 frames según el
  comando) y un enfriamiento global corto (2 frames).
- Las **pulsaciones usadas quedan consumidas**: para encadenar otro comando
  hay que volver a pulsar. Así un `B` suelto después de `AAA` no reutiliza
  los puños viejos para disparar `AAB`.
- Los dobles toques (`DASH_*`) son **exclusivos**: no puede haber otra
  pulsación entre los dos toques. Así el inicio de `→, ↓, →, B` no dispara
  un `DASH_RIGHT`.
- Si dos comandos coinciden, gana el de mayor `priority`; por eso `EMBESTIDA`
  (98) gana a su sufijo `DOBLE_PATADA` (95), y `SHORYUKEN` (100) gana a
  `HADOKEN` (100) cuando corresponde por orden de pasos.
- El orden importa: puño→→ no dispara el especial.

---

## 5. Archivos del proyecto

```
GNDU/                            # proyecto unificado (N2 + N3)
├── project.godot                # autoloads N2, escena principal N3, 60 Hz, 1920×1080
├── controls_config.json         # mapeo y comandos (auto-recarga al guardar)
├── README.md                    # entrada principal del repositorio
├── .gitignore                   # excluye caché de Godot y documentos de cátedra
├── icon.svg                     # icono del proyecto
├── assets/                      # fondos y sprites de combate
├── contracts/
│   ├── input_report.schema.json   # esquema formal del reporte
│   ├── input_report.example.json  # un reporte de ejemplo
│   └── input_report.example.jsonl # varios reportes, uno por línea
├── docs/
│   ├── controles/               # leeme, contrato, integración y verificación de N2
│   └── combate/                 # documentación del motor de combate
├── scenes/
│   ├── escenario.tscn           # escena principal del juego
│   ├── jugador.tscn             # luchador
│   ├── proyectil_hadoken.tscn   # proyectil
│   ├── diagnostic.tscn          # diagnóstico de controles
│   └── report_viewer.tscn       # visor de reportes (F4)
├── scripts/
│   ├── controls_config.gd       # autoload N2ControlsConfig
│   ├── input_core.gd            # autoload N2InputCore
│   ├── input_buffer.gd          # N2InputBuffer
│   ├── command_recognizer.gd    # N2CommandRecognizer
│   ├── player_panel.gd          # panel visual de un jugador
│   ├── diagnostic.gd            # escena de diagnóstico completa
│   ├── report_viewer.gd         # visor JSON en vivo + exportación JSONL
│   ├── mock_consumer.gd         # N3 simulado + validador del contrato
│   ├── jugador.gd               # motor de combate del luchador
│   ├── escenario.gd             # rondas, tiempo y UI de combate
│   ├── Camara.gd                # cámara dinámica
│   └── proyectil_hadoken.gd     # lógica del proyectil
└── tests/
    ├── run_tests.gd             # pruebas automáticas sin ventana
    └── joy_probe.gd             # sonda de mandos (botones y ejes en vivo)
```

Godot genera un archivo `.uid` junto a cada script; conviene versionarlos
junto con el `.gd`. La carpeta `.godot/` sí es caché y va excluida.

`input_buffer.gd` y `command_recognizer.gd` son clases **reutilizables**
(`class_name`) sin dependencias de la escena: se pueden llevar tal cual a
otro proyecto Godot.

- `N2InputBuffer.new(capacidad)`; `push(snapshot)`, `get_last(n)`, `clear()`,
  `size()`, `capacity()`, `resize(n)`.
- `N2CommandRecognizer.new(patrones)`; `set_patterns(patrones)`,
  `evaluate(buffer, frame)` y la propiedad `global_cooldown`.

El resto de la API de los autoloads (`get_last_report`, `get_last_snapshot`,
`get_buffer`, `get_device_info`, señales, etc.) está en `CONTRATO.md` §8.

---

## 6. Cómo funciona (resumen técnico)

1. `N2ControlsConfig` (autoload) carga `controls_config.json`, valida lo que
   puede y, si algo falla, usa valores por defecto y muestra el error.
2. `N2InputCore` (autoload) escucha cambios de mandos y, en
   `_physics_process` (60 Hz exactos), hace **polling** de cada acción:
   - teclas con `Input.is_physical_key_pressed` (independiente de la
     distribución del teclado),
   - botones con `Input.is_joy_button_pressed`,
   - ejes con `Input.get_joy_axis` aplicando zona muerta.
3. Por cada jugador arma un *snapshot* `{frame, held, pressed, released}` y lo
   empuja al búfer circular (30 frames por defecto, configurable entre 15 y 30).
4. El reconocedor recorre los patrones y devuelve el comando detectado o
   `null`.
5. Se construye el reporte y se emite la señal `report_emitted`.
6. El diagnóstico dibuja el estado; `mock_consumer.gd` valida el reporte
   contra el contrato y simula al N3.

No se usa `InputMap` ni `_input` para el juego: el polling en
`_physics_process` es determinista y no pierde pulsaciones rápidas entre
fotogramas. `_input` solo se usa para el **monitor de eventos físicos** del
diagnóstico.

---

## 7. Editar el mapeo (`controls_config.json`)

```json
{
  "version": 3,
  "buffer_size_frames": 30,
  "global_cooldown_frames": 2,
  "players": {
    "1": {
      "device": { "type": "hybrid", "joypad_index": 0 },
      "bindings": {
        "punch": [
          { "type": "key", "code": "F" },
          { "type": "joy_button", "button": "a" },
          { "type": "joy_axis", "axis": "trigger_right", "direction": 1, "deadzone": 0.4 }
        ]
      }
    }
  },
  "commands": [ ]
}
```

### `device.type`

| Valor | Significado |
|-------|-------------|
| `keyboard` | solo teclado |
| `joypad`   | solo mando (si no hay, el jugador queda desconectado) |
| `hybrid`   | teclado **y** mando a la vez |

`joypad_index` es una **preferencia**, no una imposición: es el índice dentro
de la lista de mandos conectados (`Input.get_connected_joypads()`). Al
conectar, el núcleo recuerda el **GUID** del mando asignado y lo reutiliza;
además nunca le quita un mando a otro jugador.

### Qué valida el cargador

- `version` es **informativa**: se copia al estado interno, pero no cambia el
  comportamiento ni bloquea la carga.
- `buffer_size_frames` se limita a **15–30** (por defecto 30), el rango que
  pide el PDF.
- `global_cooldown_frames` se limita a **0–30** (por defecto 2).
- Solo se leen los jugadores `"1"` y `"2"`; si falta uno, se usa su
  configuración interna por defecto.
- Si una acción falta o su lista de fuentes está vacía, se conserva la fuente
  por defecto de esa acción.
- Un tipo de dispositivo desconocido se ignora y queda el dispositivo por
  defecto del jugador.
- Un comando con `steps` inválidos se descarta. Si ningún comando del JSON es
  válido, se usan los comandos internos por defecto.
- Una tecla, botón o eje desconocido no rompe nada: se trata como inactivo y
  se avisa una sola vez por consola.

### Tipos de fuente

- `{"type": "key", "code": "A"}` — código de tecla física (`A`, `Space`,
  `Escape`, `Left`, …).
- `{"type": "joy_button", "button": "x"}` — `a`, `b`, `x`, `y`,
  `dpad_up`, `dpad_down`, `dpad_left`, `dpad_right`, `left_shoulder`,
  `right_shoulder`, `left_stick`, `right_stick`, `start`, `back`, `guide`.
- `{"type": "joy_axis", "axis": "left_x", "direction": -1, "deadzone": 0.35}` —
  ejes `left_x`, `left_y`, `right_x`, `right_y`, `trigger_left`,
  `trigger_right`; `direction` `1` o `-1`.

Una acción puede tener **varias fuentes**: se considera activa si cualquiera
lo está (para gatillos analógicos + botón, por ejemplo).

### Agregar un comando

```json
{
  "name": "SUPER_LEFT",
  "priority": 60,
  "window_frames": 20,
  "final_window": 2,
  "cooldown": 12,
  "steps": [
    { "action": "down",  "mode": "press", "max_gap": 8 },
    { "action": "left",  "mode": "press", "max_gap": 8 },
    { "action": "kick",  "mode": "press", "max_gap": 8 }
  ]
}
```

`mode` puede ser `press` (flancos de subida), `hold` (mantenido) o `release`
(flancos de bajada). El nombre del comando es libre; el N3 decide qué hacer
con él.

Opciones adicionales:

- `"exclusive": true` en un paso: no admite otras pulsaciones entre el paso
  anterior y ese paso. Se usa en los dobles toques para no confundirlos con
  el arranque de un combo.
- `"global_cooldown_frames": 2` en la raíz del JSON: enfriamiento mínimo
  entre dos comandos cualesquiera (además del `cooldown` de cada uno).
- Las pulsaciones que usa un comando quedan consumidas; el siguiente comando
  necesita pulsaciones nuevas. Por eso conviene dejar ~0,2 s entre combos
  distintos.

### Recarga en caliente

La demo vigila `controls_config.json` cada 0.5 s. Al guardar el archivo, el
mapeo y los comandos nuevos se aplican solos, **sin recompilar ni pulsar nada**.

1. Edita `controls_config.json`.
2. Guarda el archivo.
3. En menos de ~1 s la franja de estado muestra `Config recargada`.

Si el JSON es inválido, la demo **conserva la configuración anterior** y
muestra el error en rojo; al corregirlo y guardar se recarga sola. Si nunca
hubo una válida, usa la interna.

Para volver a los valores de fábrica hay que **reiniciar la demo sin el
archivo** (o con el archivo borrado/renombrado antes de arrancar). Si el
archivo se borra con la demo en marcha, se conserva la última configuración
válida; al restaurarlo se recarga si su contenido cambia.

`F1` y el botón **Recargar (F1)** siguen disponibles como recarga manual forzada.

Al recargar se reconstruyen el búfer y el reconocedor de cada jugador, pero
`frame` sigue creciendo. El primer frame posterior a la recarga puede marcar
como `pressed` un botón que ya estaba mantenido: evita guardar el JSON justo
mientras mantienes un ataque si estás midiendo combos.

> `F1`, `F2`, `F3`, `F4` y `F10` están reservadas para el diagnóstico. No las
> uses como teclas de juego en el JSON: la acción se ejecutaría y además se
> recargaría, cambiaría la consola, congelaría, abriría el visor o cerraría
> la demo.

---

## 8. Qué muestra el diagnóstico

- **Encabezado**: frame de física actual, FPS, botón de recarga manual, consola
  y congelar.
- **Estado de configuración**: ruta del JSON y errores en rojo.
- **Último evento físico**: tecla o botón/eje de mando con su frame. Sirve
  para descubrir qué reporta un mando genérico.
- **Panel por jugador**:
  - dispositivo asignado (teclado, mando con número y nombre),
  - indicadores de dirección (se iluminan al mantener, borde blanco al pulsar),
  - indicadores de dirección, salto, puño, patada, bloqueo, agarre y pausa con
    la tecla o botón configurado,
  - `move_x` / `move_y` calculados (`move_y`: `+1` arriba, `-1` abajo),
  - **cinta del búfer** (30 frames por defecto): `<` `>` `^` `v` dirección
    mantenida, `S` `P` `K` `B` `G` `II` pulsación, minúscula si solo está
    mantenido,
  - últimos eventos con su frame.

> En la cinta se dibuja **una sola dirección y un solo botón por celda**,
> en este orden de prioridad: izquierda, derecha, arriba, abajo; y salto,
> puño, patada, bloqueo, agarre, pausa. En una diagonal se ve solo la
> dirección de mayor prioridad; el estado completo está en `move_x`,
> `move_y` y en los indicadores. La dirección arriba (`^`) no es el salto.
- **Banner central**: nombre del comando detectado durante ~0,9 s.
- **Registro**: últimas 20 líneas JSON de reportes.

### Visor de reportes (tecla F4)

El visor es una escena aparte (`scenes/report_viewer.tscn`) que se abre con
`F4` o con el botón **Visor JSON (F4)**; `F4` o `Esc` vuelven al diagnóstico.
Muestra una línea por reporte, con J1 en cian y J2 en naranja.

- **Pausar vista**: congela la pantalla; los reportes se siguen guardando en
  memoria.
- **Filtro**: Todos, Solo J1 o Solo J2.
- **Solo comandos**: deja únicamente los frames con `command_detected`.
- **Copiar visibles**: copia al portapapeles los reportes filtrados.
- **Guardar JSONL**: escribe los reportes filtrados en
  `user://n2_reports/reports_<fecha>.jsonl`.
- **Grabar en vivo**: escribe cada reporte a
  `user://n2_reports/live_<fecha>.jsonl` mientras está activo.
- **Abrir carpeta**: abre `user://n2_reports/` en el explorador del sistema.
- **Cargar ejemplo**: carga `contracts/input_report.example.jsonl` para ver el
  visor sin mandos.
- **Volver (Esc o V)**: regresa al diagnóstico.

El visor conserva hasta 2000 reportes y dibuja los últimos 400 visibles. El
`.jsonl` es un registro/replay para depurar; el transporte oficial entre
núcleos sigue siendo la señal `N2InputCore.report_emitted`.

---

## 9. Pruebas automáticas

Sin abrir ventana:

```bash
flatpak run org.godotengine.Godot --headless \
  --path "/ruta/a/GNDU" \
  --script res://tests/run_tests.gd
```

Salida esperada: `OK: todas las pruebas pasaron` y código de salida 0.
Si algo falla, imprime `FALLARON N pruebas` y devuelve código 1.

Las **194 pruebas** cubren:

- JSON válido, raíz de objeto, `players`, `commands`, versión 3 y rango del
  búfer (15–30).
- Búfer circular: capacidad, orden viejo→nuevo y `get_last` con pocos frames.
- Doble toque derecha/izquierda, cooldown, doble toque lento y doble toque
  con dirección contraria.
- Especiales canónicos `HADOKEN`, `SHORYUKEN`, `ABAJO_ARRIBA`,
  `DOBLE_PATADA`, `EMBESTIDA` y `TATSUMAKI`, orden incorrecto, fuera de
  ventana y tolerancia de huecos.
- Los 12 comandos de la configuración: `HADOKEN`, `SHORYUKEN`,
  `ABAJO_ARRIBA`, `DOBLE_PATADA`, `EMBESTIDA`, `TATSUMAKI`, `DASH_*`,
  `COMBO_AAA`, `COMBO_BBB`, `COMBO_ABA` y `COMBO_AAB`.
- Que `EMBESTIDA` no dispara también `DOBLE_PATADA`.
- Que las pulsaciones consumidas no se reutilizan: `AAA` + `B` no dispara
  `AAB`; `EMBESTIDA` no dispara también `DOBLE_PATADA`; `AAA` y `AAB` se
  encadenan solo con pulsaciones nuevas.
- Que J1/J2 tienen `jump` y `grab` como acciones separadas, que `up` ya no
  incluye `Space`, `X` ni `Y`, y que el salto usa `Space`/`/` y `X`/`Y`.
- Que las teclas de J1 son `A/D/W/S`, `Space`, `H/J/K/L` y `Esc`; las de J2
  son flechas, `/`, `Shift`, `Enter`, `Ctrl`, `Alt` y `Backspace`.
- Que un reporte v3 válido pasa el validador y que este rechaza `state.jump`,
  claves extra de primer nivel, un `command_detected` vacío y un `move_y`
  fuera de rango.
- Que `state` tiene exactamente las seis claves del PDF.
- Que `move_y` es `+1` al pulsar arriba y `-1` al pulsar abajo, como dice
  el contrato (no el signo de pantalla de Godot).
- El esquema JSON: claves obligatorias, `state` con seis claves, sin
  `state.jump` y `move_y` con `-1` y `+1`.
- El ejemplo JSON y cada línea del ejemplo JSONL: pasan el contrato, los
  frames crecen por jugador, aparecen J1/J2 y hay al menos un comando.
- Que el script y la escena del visor se pueden cargar; también se comprueba
  que la escena de diagnóstico y la escena principal de combate existen.
- Que la escena principal raíz es `escenario.tscn`, que los autoloads están
  declarados y que `jugador.gd` lee salto/agarre del snapshot de N2.

Prueba manual de mandos (requiere ventana, no `--headless`):

```bash
flatpak run org.godotengine.Godot --path "/ruta/a/GNDU" \
  --script res://tests/joy_probe.gd
```

Dura 60 s por defecto; se puede cambiar con `N2_PROBE_SECONDS=30`. Lista los
mandos conectados (índice, nombre y GUID) y muestra en vivo qué botón/eje
reporta cada uno.

Prueba rápida de arranque de la escena (sin interacción):

```bash
flatpak run org.godotengine.Godot --headless \
  --path "/ruta/a/GNDU" --quit-after 120
```

> Nota: si el proyecto se copia a otra máquina, abrirlo una vez en el editor
> (o ejecutar `--import`) para que Godot registre las clases globales
> `N2InputBuffer`, `N2CommandRecognizer` y `N2PlayerPanel`.

---

## 10. Mandos: notas prácticas

- Conectar los mandos **antes** de abrir la demo es lo más seguro; también se
  detectan en caliente (`joy_connection_changed`).
- **Importante:** el modo `--headless` no procesa eventos de mando (detecta el
  mando conectado, pero no sus botones ni ejes). Para probar mandos hay que
  ejecutar la demo con ventana.
- Si un mando aparece con otro índice, no pasa nada: se reasigna por GUID y,
  si no coincide, por índice y luego por el primero libre.
- Mandos genéricos: usar el monitor de "último evento físico" para ver qué
  botón/eje reporta cada tecla y ajustar el JSON.
- En Linux algunos mandos inalámbricos tardan uno o dos segundos en
  registrarse; esperar antes de probar.
- Si un mando Xbox/PlayStation tiene un modo de compatibilidad (XInput/DInput
  o "modo Switch"), probar el modo estándar primero.
- Probado con un **Nintendo Switch Pro Controller** (GUID
  `0500d71f7e0500000920000001800000`): botones 0–3 = sur/este/oeste/norte,
  hombros 9/10, start 6, back 4, D-pad 11–14, sticks como ejes 0–3 y clics 7/8,
  gatillos como ejes 4/5 (0→1).
- Probado con un **DualShock 4 / PS4** (GUID
  `05009b514c050000cc09000000810000`): mismos índices posicionales; `a` es
  cruz, `b` es círculo, `x` es cuadrado y `y` es triángulo. En la prueba real
  funcionaron salto, combos y ambos jugadores a la vez (Switch Pro en J1 y
  PS4 en J2).
- El combo 6 (`→, ↓, →, B`) funciona en pruebas automáticas y en simulación
  determinista; falta confirmarlo una vez con mando real. Hecho **muy
  despacio** puede caer en el combo 8 (`↓, →, B`), que es su sufijo; usa el
  ritmo de combo (huecos de ~4–8 frames) para que gane el patrón largo.

---

## 11. Limitaciones conocidas

- No hay interfaz gráfica de remapeo; el mapeo se edita en el JSON y se
  recarga automáticamente al guardar. (El documento pedía JSON+recarga como
  obligatorio; la UI era un extra.)
- La auto-recarga se implementa con polling del MD5 del archivo cada 0.5 s
  (no con `FileSystemWatcher`). `F1`, el botón o `N2ControlsConfig.reload()`
  permiten forzarla.
- La auto-recarga funciona ejecutando desde Godot o con el JSON como archivo
  externo editable. En un export con el JSON dentro del PCK no hay cambios en
  caliente.
- No hay vibración. Los gatillos se leen como ejes, pero se convierten a
  booleano con zona muerta; no se expone su valor continuo en el reporte.
- El reconocimiento es por flancos dentro de una ventana de frames. El
  formato admite `press`, `hold` y `release`, pero no hay *input leniency*
  por tiempo real ni detección especial de botones simultáneos (los combos
  son secuenciales).
- El reporte es una **foto por frame**, no una cola de eventos: el N3 usa
  `snapshot.pressed` para los flancos (ver `CONTRATO.md`).
- El visor conserva hasta 2000 reportes en memoria y dibuja los últimos 400
  visibles. Para sesiones largas, usa **Grabar en vivo** o **Guardar JSONL**.
- El visor no dibuja cambios de flanco ni estadísticas de combos: muestra el
  reporte crudo. El análisis fino se hace sobre el `.jsonl`.
- J1 y J2 pueden usar teclado y mando a la vez. Dos personas en un mismo
  teclado pueden sufrir *ghosting*; para juego simultáneo se recomiendan
  mandos.
- Con un solo mando, J1 puede usar teclado y J2 el mando (o ambos el teclado).
  Para que los dos jueguen con mando hacen falta dos mandos.
- No hay ejecutable exportado: la entrega se ejecuta desde Godot con el
  comando de la sección 1. Si se necesita un binario, hay que exportarlo
  aparte (no está generado en el repositorio).

---

## 12. Estado de la entrega y pendientes

### Verificado

- [x] `flatpak run …` abre el proyecto unificado; la escena principal es
      `escenario.tscn` y el diagnóstico sigue disponible.
- [x] J1 responde con teclado y con mando 0 (asignación híbrida).
- [x] J2 responde con teclado y con mando 1.
- [x] El salto responde con `Espacio`/`/` y con `X` (oeste)/`Y` (norte) en
      J1 y J2 mediante la acción `jump`. Probado con Switch Pro y DualShock 4.
- [x] El agarre usa `L`/`Alt` y `LB`/`L1`.
- [x] `COMBO_AAA`, `COMBO_BBB`, `COMBO_AAB` y los especiales canónicos se
      reconocieron con pulsaciones reales.
- [x] Las pruebas automáticas terminan en `OK`.
- [x] `CONTRATO.md` v3 coincide con lo que emite `input_core.gd`: seis claves
      en `state`, sin `jump`/`grab`; esos se leen del snapshot interno.
- [x] El esquema JSON, el ejemplo JSON y el ejemplo JSONL pasan las pruebas
      del contrato.
- [x] El visor JSON carga la escena sin errores; las pruebas cargan el
      ejemplo y filtran por jugador/comandos.
- [x] Guardar y grabar `.jsonl` se validaron en un smoke headless; crean
      archivos en `user://n2_reports/`.

### Pendiente o no verificado en físico

- [ ] Probar `←, →, B` (`TATSUMAKI`) y los 12 comandos con mando real.
- [ ] Probar los 12 comandos con mando real (varios solo están cubiertos por
      pruebas automáticas).
- [ ] Probar la auto-recarga con un JSON válido y con uno roto en la ventana real (y que `F1` siga funcionando).
- [ ] Probar desconectar/conectar un mando en caliente y comprobar que no se
      roba el mando del otro jugador.
- [ ] Probar a dos jugadores pulsando a la vez (J1 y J2) durante varios
      segundos, sin interferencias.
- [ ] Probar el visor con ventana real: layout, botones, copiar y abrir la
      carpeta en el explorador.
- [ ] Decidir si hace falta un ejecutable exportado para la entrega. Hoy no
      está generado; se ejecuta con Godot.
- [ ] Decidir licencia del repositorio (no hay archivo `LICENSE`; por ahora
      se decidió no agregarla).
- [ ] Confirmar con el N3/N4 que el contrato v3 exacto del PDF (seis claves
      en `state`, salto y agarre por snapshot) es el que van a consumir.

---

## 13. Problemas comunes

| Síntoma | Qué revisar |
|---------|-------------|
| No aparece ningún mando | Conectarlo antes de abrir la demo; ejecutar `tests/joy_probe.gd` con ventana; en `--headless` no llegan eventos de mando. |
| Un botón no responde | Ver el “último evento físico” o `joy_probe.gd` para saber qué índice reporta; ajustar el JSON. |
| El JSON nuevo no se aplica | Guardar el archivo y esperar ~0.5 s; revisar la franja de estado (rojo si el JSON es inválido). `F1` fuerza la recarga. |
| Error de configuración | El mensaje queda en `N2ControlsConfig.last_error`; se conserva la última configuración válida. |
| No se detecta un combo | Revisar el ritmo (huecos de ~4–8 frames), el orden y que las pulsaciones sean nuevas; `EMBESTIDA` y `DOBLE_PATADA` comparten prefijo, pero se distinguen por el botón final. |
| El visor está vacío | No hay entradas ni mandos. Usa el teclado o pulsa **Cargar ejemplo**. |
| No se puede guardar el JSONL | Revisar permisos de `user://n2_reports/`; el visor muestra la ruta y el error en la franja inferior. |
| Las clases globales no existen al copiar el proyecto | Abrir una vez el editor o ejecutar `--import` para que Godot registre `N2InputBuffer`, `N2CommandRecognizer` y `N2PlayerPanel`. |
| La ventana no abre por Vulkan/Forward+ | El proyecto usa `gl_compatibility`; si hace falta, revisar el driver en Ajustes del proyecto. |
| Dos personas en el mismo teclado | J1 y J2 tienen teclado separado; si faltan teclas a la vez, el teclado sufre *ghosting*. Para juego simultáneo usa mandos. |
| `F1`, `F2`, `F3`, `F4` o `F10` hacen cosas raras | Están reservadas al diagnóstico; no las uses como bindings de juego. |
