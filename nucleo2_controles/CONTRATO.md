# Contrato de datos — Núcleo 2 → Núcleo 3 / Núcleo 4

Este documento es la definición **oficial y ejecutable** del contrato del
Núcleo 2, porque no hubo confirmación del Núcleo 3. Si el N3 necesita algo
distinto, este archivo es el punto único de cambio.

Versión actual: **3** (la 3 alinea el contrato exacto del PDF: elimina la
extensión `state.jump` de la v2. El salto se expresa con `move_y = +1`, tal
como pide el enunciado).

El Núcleo 2 **emite un reporte por jugador en cada fotograma de física**
(60 Hz). Con dos jugadores son **dos reportes por frame**, uno con
`player_id = 1` y otro con `player_id = 2`.

- Emisor: autoload `N2InputCore`, señal `report_emitted(report: Dictionary)`.
- Consumidor de ejemplo: `scripts/mock_consumer.gd` (valida y simula al N3).
- No hay acoplamiento: cualquier nodo puede conectarse a la señal, o leer
  `N2InputCore.get_last_report(player_id)`.
- Esquema formal: [`contracts/input_report.schema.json`](contracts/input_report.schema.json).
- Ejemplos: [`contracts/input_report.example.json`](contracts/input_report.example.json)
  y [`contracts/input_report.example.jsonl`](contracts/input_report.example.jsonl).
- Guía de integración: [`INTEGRACION.md`](INTEGRACION.md).

> El JSON es la representación serializada del `Dictionary`. El Núcleo 2 **no
> escribe un archivo JSON por fotograma**; la señal es el transporte oficial.
> Los archivos de `contracts/` son ejemplos y material de prueba.

---

## 1. Forma exacta del reporte

```json
{
  "player_id": 1,
  "frame": 12345,
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

### Claves de primer nivel

| Clave | Tipo | Obligatoria | Descripción |
|-------|------|-------------|-------------|
| `player_id` | `int` | sí | `1` o `2`. |
| `frame` | `int` | sí | `Engine.get_physics_frames()`, creciente y único por jugador. |
| `state` | `object` | sí | Estado mantenido de este frame. |
| `command_detected` | `string` o `null` | sí | Comando reconocido **en este frame**, o `null`. |

No se agregan ni renombran claves sin actualizar este archivo y el validador.

### `state`

| Clave | Tipo | Rango / valores | Semántica |
|-------|------|-----------------|-----------|
| `move_x` | `int` | `-1`, `0`, `1` | `-1` = izquierda, `1` = derecha. |
| `move_y` | `int` | `-1`, `0`, `1` | `-1` = abajo/agachado, `1` = arriba/salto. |
| `punch` | `bool` | — | Puño **mantenido** en este frame. |
| `kick` | `bool` | — | Patada mantenida. |
| `block` | `bool` | — | Bloqueo mantenido. |
| `pause` | `bool` | — | Pausa mantenida. |

Notas:

- `move_x` y `move_y` son **absolutos**, no relativos a la orientación del
  personaje. El N3 los convierte a "adelante/atrás" usando el *facing*.
- El signo de `move_y` sigue la convención del enunciado del proyecto:
  `-1` = abajo/agachado y `+1` = arriba/salto. **No** es el signo de pantalla
  de Godot (donde la Y crece hacia abajo); el N3 no debe invertirlo.
- El **salto** se expresa con `move_y = +1`. `Espacio`, `X` y `Y` del mando
  están mapeados a la acción `up`, igual que `W`, el D-pad arriba y el stick
  hacia arriba. No hay una clave `jump` separada.
- Si izquierda y derecha están pulsadas a la vez, `move_x = 0`
  (`derecha - izquierda`). Para `move_y` la fórmula es `arriba - abajo`, así
  que si ambas están pulsadas da `0`.
- La diagonal se representa con `move_x` y `move_y` no nulos a la vez.
- Los booleanos (`punch`, `kick`, `block`, `pause`) son **estado mantenido**,
  no eventos. Para detectar "se acaba de pulsar" el N3 compara con el reporte
  anterior del mismo jugador. Para el salto, el flanco de subida de
  `move_y` es el momento de iniciar el salto; la altura o duración las decide
  el N3.

---

## 2. `command_detected`

- Es un `string` en el frame exacto en que el reconocedor lo valida; en todos
  los demás frames es `null`.
- Un mismo comando **no se repite** hasta que pasa su `cooldown` propio
  (10–18 frames en la configuración por defecto). Además hay un
  `global_cooldown_frames` (2 por defecto) entre dos comandos cualesquiera.
- Valores que puede emitir la configuración por defecto:
  `SPECIAL_ATTACK_1`, `SPECIAL_ATTACK_2`, `DASH_RIGHT`, `DASH_LEFT`,
  `COMBO_AAA`, `COMBO_BBB`, `COMBO_ABA`, `COMBO_AAB`,
  `COMBO_RIGHT_DOWN_RIGHT_B`, `COMBO_DOWN_UP_A`, `COMBO_DOWN_RIGHT_B`,
  `COMBO_LEFT_RIGHT_A`.
- En la notación de los combos, **A = puño** y **B = patada**.
- El nombre es el campo `name` del patrón en `controls_config.json`; si se
  agregan comandos válidos al JSON, aparecen aquí automáticamente. Los
  comandos con `steps` inválidos se descartan al cargar la configuración; si
  ninguno queda válido, se usan los comandos internos por defecto.
- El reporte **no** dice qué jugador mirando a dónde: `DASH_RIGHT` siempre es
  hacia la derecha de la pantalla. La traducción a "dash adelante" es del N3.
- Es un evento de un solo frame: si el N3 lo pierde, se pierde. Alternativa
  sin pérdida: guardar también los reportes de los últimos N frames, o usar la
  señal directamente.

Ejemplo de consumo:

```gdscript
func _on_report(report: Dictionary) -> void:
    var pid: int = report.player_id
    var state: Dictionary = report.state
    if report.command_detected != null:
        _on_command(pid, report.command_detected)
    if state.punch and not _last_punch.get(pid, false):
        _on_punch_pressed(pid)
    _last_punch[pid] = state.punch
```

---

## 3. Frecuencia y orden

- Un reporte por jugador por `_physics_process`, a
  `physics/common/physics_ticks_per_second = 60`.
- Orden dentro de un frame: primero `player_id = 1`, luego `player_id = 2`.
- `frame` empieza en 0 al arrancar y **no** se reinicia al recargar el JSON.
- Los dos jugadores comparten el mismo `frame` en el mismo tick.
- El reporte se emite **después** de leer hardware y empujar al búfer, así que
  el comando detectado ya incluye el frame actual.
- `Engine.get_physics_frames()` es la única fuente de tiempo: no usar
  `delta` acumulado.

---

## 4. Garantías y no garantías

Garantizado:

- Las claves existen siempre, con los tipos de la tabla.
- `frame` es estrictamente creciente por jugador (el validador lo comprueba).
- `state.move_x` y `state.move_y` están en `{-1, 0, 1}`.
- `command_detected` es `string` o `null`, nunca `""`.
- El reporte llega aunque no haya mando conectado (con todo en `false`/`0`),
  de modo que el N3 nunca se queda sin datos.

No garantizado:

- Que `command_detected` refleje la intención del jugador (puede haber
  falsos positivos por mashing).
- Que exista un reporte por frame si el juego se pausa o pierde foco
  (Godot puede reducir ticks). El N3 debe tolerar huecos en `frame`.
- Que `player_id` 1 use teclado o 2 use mando: eso depende del JSON.

---

## 5. Errores de configuración

Si `controls_config.json` no se puede leer o es inválido (al arrancar o al
recargarlo automáticamente):

- Se conserva la última configuración válida (o la interna por defecto).
- `N2ControlsConfig.last_error` contiene el mensaje.
- Se emite `config_error(message)` y el diagnóstico lo muestra en rojo.
- El flujo de reportes **no se interrumpe**.

El N3 no debe asumir que el contenido del JSON es el que escribió el usuario:
solo debe confiar en la forma del reporte.

---

## 6. Validación

`scripts/mock_consumer.gd` implementa el validador y es la referencia
ejecutable. Comprueba:

1. Claves presentes y permitidas: `player_id`, `frame`, `state`,
   `command_detected`. Cualquier clave extra se rechaza.
2. `player_id` entero y en `{1, 2}`.
3. `frame` entero y mayor que el anterior de ese jugador.
4. `state` es objeto con exactamente las seis claves oficiales.
5. `move_x`/`move_y` enteros en `{-1, 0, 1}`.
6. `punch`/`kick`/`block`/`pause` booleanos.
7. `command_detected` es `null` o un `string` no vacío.

Si algo falla, imprime `CONTRATO N2: …` con `push_error` y emite
`contract_error`.

Estas comprobaciones están cubiertas por `_test_contract()` en
`tests/run_tests.gd`: un reporte v3 válido pasa, y se rechazan una clave
extra en `state`, una clave extra de primer nivel, un `command_detected`
vacío y un `move_y` fuera de rango.

El esquema de `contracts/input_report.schema.json` declara la misma forma de
manera formal. `_test_contract_artifacts()` comprueba que el esquema no admita
claves extra, que `state` tenga seis claves y que `move_y` acepte `-1` y
`+1`; además valida el ejemplo JSON y cada línea del ejemplo JSONL con
`mock_consumer.gd`. Los números leídos de JSON se normalizan a `int` en la
prueba porque `JSON.parse_string()` devuelve números como `float`.

---

## 7. Cómo evolucionar el contrato

1. Cambiar `input_core.gd` (`_build_report`) y/o `mock_consumer.gd`.
2. Actualizar este documento en el mismo cambio.
3. Actualizar `contracts/input_report.schema.json`, el ejemplo JSON y el
   ejemplo JSONL.
4. Agregar o ajustar la prueba correspondiente en `tests/run_tests.gd`.
5. Avisar al N3/N4 con la versión nueva.

La versión (**3**) es la del **documento**, no un campo del reporte. El JSON
emitido no lleva `contract_version`; quien integre debe fijar la versión de
este archivo. Si en el futuro se necesita detectar la versión en tiempo de
ejecución, habría que agregar ese campo al reporte y al validador (sería una
versión 4).

---

## 8. API pública para N3/N4

Además de la señal `report_emitted`, el autoload `N2InputCore` expone:

| Miembro | Uso |
|---------|-----|
| `get_last_report(player_id)` | Último reporte completo del jugador. |
| `get_last_snapshot(player_id)` | Último snapshot interno: `frame`, `held`, `pressed`, `released`. |
| `get_buffer(player_id)` | Búfer circular (`N2InputBuffer`) del jugador. |
| `get_device_info(player_id)` | Tipo, conexión, `pad_id`, nombre y GUID del dispositivo. |
| `get_device_label(player_id)` | Texto listo para mostrar en UI. |
| `get_last_raw_event()` | Último evento físico (solo diagnóstico). |
| `get_raw_serial()` | Contador para detectar eventos nuevos. |
| `devices_changed` | Señal al conectar/desconectar un mando o recargar el JSON. |

`N2ControlsConfig` expone `reload()`, `last_error`, `get_player`,
`get_device`, `get_bindings`, `get_commands`, `get_buffer_size`,
`get_global_cooldown`, `get_action_names` y las señales `config_reloaded` y
`config_error(message)`. Además sondea `controls_config.json` cada 0.5 s y
llama a `reload()` automáticamente cuando cambia; `reload()` sigue disponible
para forzarla.

Para consumir el reporte sin duplicar lógica, conectar una sola vez:

```gdscript
func _ready() -> void:
    N2InputCore.report_emitted.connect(_on_report)
```

Si se instancian varios consumidores, todos reciben la misma señal; el
`mock_consumer.gd` es solo una referencia y no debe convivir con el
consumidor real del N3 en la misma escena.

> Al recargar el JSON (automáticamente al guardarlo o con `reload()`) se
> reconstruyen el búfer y el reconocedor de cada jugador; `frame` sigue
> creciendo. El primer frame después de recargar puede marcar como `pressed`
> lo que ya estaba mantenido. Evita guardar el JSON mientras mantienes un
> botón de ataque si estás midiendo combos.
