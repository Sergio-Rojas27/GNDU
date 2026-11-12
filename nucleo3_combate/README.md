# ⚔️ GNDU — Núcleo 3: Motor de Combate (`nucleo3_combate`)

El **Núcleo 3 (Combate)** es el módulo encargado de la simulación física en tiempo real, las mecánicas de pelea 2D, la máquina de estados de los luchadores, el sistema de colisiones (*Pushbox*, *Hurtboxes* y *Hitboxes*), las reglas de rondas/tiempo y la emisión de eventos de combate hacia el resto de los núcleos del proyecto GNDU.

> **Nota importante:** Este documento detalla la arquitectura técnica, controles, jerarquías de escenas y la lógica interna para la integración con los demás núcleos (como el de Entradas y el Bus de Eventos).

---

## 📑 Tabla de Contenidos

1. [Arquitectura y Estructura del Directorio](#1-arquitectura-y-estructura-del-directorio)
2. [Configuración del Proyecto y Controles](#2-configuración-del-proyecto-y-controles)
3. [Escenas y Jerarquía de Nodos](#3-escenas-y-jerarquía-de-nodos)
4. [Lógica del Luchador (`script/jugador.gd`)](#4-lógica-del-luchador-scriptjugadorgd)
5. [Gestor de Escenario y Partida (`script/escenario.gd`)](#5-gestor-de-escenario-y-partida-scriptescenariogd)
6. [Cámara Dinámica (`script/Camara.gd`)](#6-cámara-dinámica-scriptcamaragd)
7. [Proyectil Hadoken (`script/proyectil_hadoken.gd`)](#7-proyectil-hadoken-scriptproyectil_hadokengd)
8. [Contratos e Integración con el Bus Central](#8-contratos-e-integración-con-el-bus-central-contracts)

---

## 🏗️ 1. Arquitectura y Estructura del Directorio

```text
nucleo3_combate/
├── project.godot                        # Configuración de Godot 4.7, resolución (1920x1080) e Input Map
├── escenas/
│   ├── escenario.tscn                   # Escena principal del combate (escenario, HUD, cámara y 2 jugadores)
│   ├── jugador.tscn                     # Prefab del luchador con sprites, hurtboxes, hitboxes y pushbox
│   └── proyectil_hadoken.tscn           # Escena instanciable para el proyectil de energía (Hadoken)
├── script/
│   ├── jugador.gd                       # Controlador principal del luchador y mecánicas de combate
│   ├── escenario.gd                     # Controlador de rondas, reloj, barras de vida y eventos de partida
│   ├── Camara.gd                        # Seguimiento dinámico del punto medio entre ambos jugadores
│   └── proyectil_hadoken.gd             # Movimiento, alcance y detección de impacto del proyectil
├── contracts/
│   ├── on_combat_event.schema.json      # JSON Schema (Draft 2020-12) del contrato de salida hacia N4 y N5
│   └── on_combat_event.example.json     # Ejemplo de payload válido emitido en un evento de combate
└── assets/
    ├── background/                      # Texturas de escenario y suelo de prueba
    └── sprites/                         # Hojas de sprites para animaciones de ataque, movimiento, daño y especiales
```

---

## ⚙️ 2. Configuración del Proyecto y Controles

Definida en `project.godot`:
- **Motor:** Godot 4.7 (modo de renderizado `gl_compatibility`).
- **Resolución base:** 1920x1080 (`stretch/mode = "canvas_items"`, `stretch/aspect = "expand"`).
- **Escena principal:** `res://escenas/escenario.tscn`.

### Mapa de Entradas Locales (Modo Demo / Pruebas)
Cuando el Núcleo 2 (`N2InputCore`) no está presente en el árbol global, cada instancia de `jugador.gd` lee las acciones configuradas en el InputMap:

| Acción Lógica | Acción Jugador 1 (`p1_*`) | Tecla J1 | Acción Jugador 2 (`p2_*`) | Tecla J2 |
| :--- | :--- | :---: | :--- | :---: |
| Mover Izquierda | `p1_izquierda` | `A` | `p2_izquierda` | `Flecha Izquierda` |
| Mover Derecha | `p1_derecha` | `D` | `p2_derecha` | `Flecha Derecha` |
| Arriba (Apuntar) | `p1_arriba` | `W` | `p2_arriba` | `Flecha Arriba` |
| Agacharse | `p1_agachar` | `S` | `p2_agachar` | `Flecha Abajo` |
| Saltar | `p1_salto` | `Espacio` | `p2_salto` | `/` |
| Puño | `p1_puno` | `H` | `p2_puno` | `Shift` |
| Patada | `p1_patada` | `J` | `p2_patada` | `Enter` |
| Bloquear | `p1_bloquear` | `K` | `p2_bloquear` | `Ctrl` |
| Agarre | `p1_agarre` | `L` | `p2_agarre` | `Alt` |

---

## 🎬 3. Escenas y Jerarquía de Nodos

### `escenas/escenario.tscn`
Escena raíz (`Node2D`) controlada por `script/escenario.gd`:
- **CanvasLayer/Control:** Interfaz de usuario de combate:
  - `Timer`: Reloj con `autostart = true` (intervalo de 1s).
  - `Label_tiempo`: Muestra los segundos restantes del round (inicia en 99).
  - `Vida_P1` / `Vida_P2`: Barras de progreso (`ProgressBar`) vinculadas al `current_hp` de cada luchador.
  - `Rounds_P1` / `Rounds_P2`: Indicadores visuales (○ / ●) de rondas ganadas.
  - `Boton_Hitboxes`: Botón para activar/desactivar en caliente la visualización de cajas de colisión (Hitboxes: ON/OFF).
  - `Texto Victoria`: Etiqueta central para anuncios de round, KO y ganador definitivo.
  - `Boton_Reiniciar`: Botón visible al finalizar la partida para reiniciar todo el encuentro.
- **ColisionEscenario (`StaticBody2D`):** Contiene `HitboxSuelo` (y = 1060), `HitboxParedIzquierda` (x = -22) y `HitboxParedDerecha` (x = 1932).
- **Jugador y Jugador2:** Instancias de `jugador.tscn` cruzadas mediante la propiedad exportada `rival`.
- **Camera2D:** Cámara con `zoom = Vector2(1.3, 1.3)` gobernada por `script/Camara.gd`.

### `escenas/jugador.tscn`
Escena del luchador (`CharacterBody2D`) controlada por `script/jugador.gd`:
- **Pushbox (`CollisionShape2D`):** Colisionador físico del cuerpo para contacto con el suelo y paredes del escenario.
- **AnimatedSprite2D:** Contiene todas las secuencias de `SpriteFrames` (*Reposo, Caminar_Adelante, Caminar_Atras, Agachado, Salto_Subida, Salto_Adelante, Salto_Atras, Dash_Adelante, Dash_Atras, Bloqueo_Alto, Bloqueo_Bajo, Golpear, Patada, Punio_Arriba, Patada_Arriba, Punio_Abajo, Patada_Abajo, Punio_Aire, Patada_Aire, Agarre, Agarrado, Stun, Tumbar, Hadoken, Shoryuken, Tatsumaki*).
- **Hurtbox-Estandar (`Area2D`):** Caja vulnerable cuando el personaje está de pie o en el aire (150 x 247.75).
- **Hurtbox-Baja (`Area2D`):** Caja vulnerable reducida cuando el personaje está agachado (150 x 121.5, desplazada hacia abajo).
- **Hitbox-Alta, Hitbox-Media, Hitbox-Baja (`Area2D`):** Cajas de daño ofensivas ubicadas a distintas alturas que se activan dinámicamente según el ataque ejecutado.

---

## 🧠 4. Lógica del Luchador (`script/jugador.gd`)

### 4.1 Constantes y Parámetros de Balance

| Constante | Valor | Propósito |
| :--- | :---: | :--- |
| `SPEED` | `300.0` | Velocidad de desplazamiento horizontal al caminar. |
| `JUMP_VELOCITY` | `-750.0` | Impulso vertical inicial del salto. |
| `VENTANA_DOBLE_TOQUE_MS` | `280 ms` | Tiempo máximo entre pulsaciones de dirección para Dash. |
| `VENTANA_ESPECIAL_MS` | `500 ms` | Memoria direccional (abajo/atrás) para ataques especiales. |
| `DURACION_DASH` | `0.22 s` | Duración del desplazamiento de dash. |
| `VEL_DASH_ADELANTE / ATRAS`| `850.0 / 700.0` | Velocidad horizontal durante el dash frontal o trasero. |
| `IMPULSO_ESPECIAL_X / Y` | `320.0 / -750.0`| Impulso diagonal del ataque especial ascendente (Shoryuken). |
| `DURACION_TATSUMAKI / VEL` | `0.9 s / 1000.0` | Duración y velocidad horizontal del Tatsumaki. |
| `DURACION_HADOKEN / LANZ` | `0.9 s / 0.35 s` | Duración estado Hadoken y tiempo de disparo del proyectil. |
| `VENTANA_COMBO` | `0.7 s` | Tiempo disponible tras un golpe para encadenar combo. |
| `DURACION_STUN` | `0.5 s` | Duración del aturdimiento (`dano`) al recibir un golpe en tierra.|
| `COOLDOWN_ATAQUE` | `0.18 s` | Enfriamiento tras un ataque normal o paso 1/2 de combo. |
| `COOLDOWN_ATAQUE_FINAL` | `0.45 s` | Recuperación extendida tras 3er golpe (`ataque_combo_*_3`). |
| `COOLDOWN_ESPECIAL` | `0.7 s` | Recuperación aplicada al finalizar un movimiento especial. |
| `DISTANCIA_PUSHBOX / ALTURA`| `150.0 / 170.0` | Distancia mínima y umbral vertical del sistema de empuje. |
| `CAPA_JUGADOR / MASC_MUNDO`| `4 / 1` | Evita colisiones rígidas entre jugadores, solo con el escenario.|

#### Tabla de Empujes por Ataque (`EMPUJES_ATAQUE`)
Cada ataque aplica un vector `Vector2(x, y)` al rival (la `x` se invierte automáticamente según hacia dónde mira el atacante):
- **Básicos y Combos de Puño:** `ataque_golpe` (180, 0) → `ataque_combo_punio_2` (220, 0) → `ataque_combo_punio_3` (480, -60).
- **Básicos y Combos de Patada:** `ataque_patada` (280, 0) → `ataque_combo_patada_2` (280, 0) → `ataque_combo_patada_3` (540, -80).
- **Antiaéreos (Arriba):** `ataque_punio_arriba` (180, -300), `ataque_patada_arriba` (160, -300).
- **Bajos (Agachado):** `ataque_punio_abajo` (160, 40), `ataque_patada_abajo` (240, 60).
- **Aéreos:** `ataque_aire_punio` (200, 120), `ataque_aire_patada` (240, 100).
- **Especiales:** `ataque_especial` (Shoryuken) (250, -750), `ataque_tatsumaki` (300, -100), Proyectil Hadoken (320, -140).

### 4.2 Sistema de Entrada Dual (Local y Núcleo 2)
El luchador abstrae sus controles en el diccionario `input_nucleo2` (`move_x`, `move_y`, `salto`, `punch`, `kick`, `block`, `grab`):

1. **Integración con Núcleo 2 (`recibir_reporte_entrada`):**
   - En `_ready()`, el jugador busca el autoload `/root/N2InputCore` y se conecta a su señal `report_emitted`.
   - Acepta reportes tanto en formato Dictionary como String JSON, filtrando por `player_id`.
   - Detecta flancos de subida (pulsaciones únicas) comparando con `_estado_previo_n2` para `salto`, `punch` y `kick`.
   - Lee comandos compuestos desde `command_detected` (Dashes y Especiales).
2. **Simulación Local (`_simular_entrada_nucleo2`):**
   - Si no se recibió un reporte externo de N2 en el frame actual (`_usar_reporte_externo_n2 == false`), consulta directamente Input de Godot y registra las marcas de tiempo (`Time.get_ticks_msec()`) para detectar dobles toques y secuencias de ataques.

### 4.3 Máquina de Estados del Luchador
La variable `estado_actual` controla el comportamiento en `_physics_process(delta)`:
- **Movimiento y Neutral:** `reposo`, `caminar`, `agachado`, `salto_estatico`, `salto_adelante`, `salto_atras`, `dash_adelante`, `dash_atras`.
- **Defensa:** `bloqueo_alto`, `bloqueo_bajo`.
- **Ataques Normales y Direccionales:** `ataque_golpe`, `ataque_patada`, `ataque_punio_arriba`, `ataque_patada_arriba`, `ataque_punio_abajo`, `ataque_patada_abajo`.
- **Ataques en el Aire:** `ataque_aire_punio`, `ataque_aire_patada` (limitados a un único ataque por salto mediante `_ataque_aereo_usado`).
- **Secuencias de Combo:** `ataque_combo_punio_2`, `ataque_combo_punio_3`, `ataque_combo_patada_2`, `ataque_combo_patada_3`.
- **Ataques Especiales:** `ataque_hadoken`, `ataque_especial` (Shoryuken), `ataque_tatsumaki`.
- **Agarre y Estados Restrictivos:** `intentar_agarre`, `agarrando`, `agarrado`, `lanzado`, `caida_rebote`, `en_suelo`, `dano` (hitstun), `derrota` (KO).

> **Mirada Fija al Rival:** En cada frame físico, el personaje compara su `global_position.x` con la del rival para orientar automáticamente su sprite (`sprite.flip_h`) e invertir la escala horizontal (`scale.x`) de las hitboxes, excepto en estados comprometidos (daño, derrota, agarres, dashes o ataques especiales).

### 4.4 Sistema de Colisiones: Pushbox, Hurtboxes y Hitboxes
1. **Pushbox estilo Mortal Kombat (`_resolver_pushbox`):**
   - Los cuerpos de los jugadores están en `CAPA_JUGADOR = 4` y solo tienen máscara con el mundo (`MASCARA_MUNDO = 1`). Permite que un jugador salte libremente por encima del otro.
   - Cuando ambos están en el suelo, `_resolver_pushbox()` mantiene una separación mínima de `DISTANCIA_PUSHBOX` (150 px), repartiendo la corrección (50% cada uno).
2. **Hurtboxes Segmentadas (`_actualizar_hurtbox`):**
   - **En el suelo / Derrota:** Hurtboxes se desactivan (OTG deshabilitado).
   - **Agachado:** Se desactiva `Hurtbox-Estandar` y se habilita `Hurtbox-Baja`.
   - **Activo:** `Hurtbox-Estandar` permanece activa y `Hurtbox-Baja` desactivada.
3. **Hitboxes Segmentadas y Control por Fotogramas:**
   - `activar_hitbox(altura)` habilita únicamente la caja correspondiente (ALTO, MEDIO o BAJO).
   - En `_on_sprite_frame_changed()`, la hitbox se activa en `frame == 1` y se apaga en `frame > 1` (recovery).
   - `_verificar_colision_hitboxes_activas()` inspecciona superposiciones por frame para no perder impactos.
   - `_golpe_conectado_en_ataque` evita golpes múltiples en un solo ataque y emite el evento `WHIFF` si no se conectó nada.

### 4.5 Bloqueo, Alturas de Ataque y Daño
Cada ataque se clasifica en una de tres alturas al impactar:
- **ALTO:** `ataque_punio_arriba`, `ataque_patada_arriba`, `ataque_aire_punio`, `ataque_especial` (Shoryuken).
- **MEDIO:** `ataque_golpe`, `ataque_patada`, pasos 2 y 3 de combos, `ataque_tatsumaki`, y proyectil Hadoken.
- **BAJO:** `ataque_punio_abajo`, `ataque_patada_abajo`, `ataque_aire_patada`.

#### Matriz de Guardia (`recibir_ataque`)
| Estado del Defensor | Ataque ALTO | Ataque MEDIO | Ataque BAJO | Agarre (`es_agarre = true`) |
| :--- | :--- | :--- | :--- | :--- |
| `bloqueo_alto` (De pie) | Bloqueado | Bloqueado | Impacta (Rompe guardia) | Inmune? No: Agarrable |
| `bloqueo_bajo` (Agachado)| Impacta (*Overhead*) | Bloqueado | Bloqueado | Agarrable |

- **Si el golpe es bloqueado:** No reduce `current_hp`, retroceso reducido (35%), reinicia combo y emite evento `BLOCK` (`sfx_block`).
- **Si el golpe conecta (HIT):** Resta vida (fuerza 15 por defecto), entra en estado `dano` por 0.5s, incrementa el combo y emite `HIT` (y `KO` si `current_hp <= 0`).

### 4.6 Combos Básicos (AAA / BBB), Cancelaciones y Contador de Hits
- **Cadenas de 3 golpes:** Presionar repetidamente Puño o Patada encadena hasta 3 pasos. Ventana de 0.7s para continuar, finalizando con mayor empuje y cooldown.
- **Cancelación en Especiales:** Cualquier golpe de la cadena en el suelo puede cancelarse en un ataque especial ignorando el cooldown.
- **Contador de Combo:** Muestra "X HITS" mientras el rival permanece en `dano`. Se reinicia si el rival se recupera o bloquea.

### 4.7 Dash y Movimientos Especiales

| Movimiento | Entrada Local (Mirando a la derecha) | Comando Núcleo 2 (`command_detected`) | Comportamiento en Código |
| :--- | :--- | :--- | :--- |
| **Dash** | `→ →` o `← ←` (<= 280 ms) | `DASH_RIGHT` / `DASH_LEFT` | Desplazamiento rápido 0.22s. |
| **Hadoken** | `←` luego `→` + Puño (<= 500 ms) | `SPECIAL_ATTACK_1`, `HADOKEN` | Instancia `proyectil_hadoken.tscn` a los 0.35s. |
| **Shoryuken**| `↓` luego `→` + Puño (<= 500 ms) | `SPECIAL_ATTACK_2`, `SHORYUKEN` | Impulso diagonal ascendente con hitbox ALTA. |
| **Tatsumaki**| `←` luego `→` + Patada (<= 500 ms)| `COMBO_DOWN_RIGHT_B`, `TATSUMAKI` | Avanza a 1000 px/s con hitbox MEDIO. |

### 4.8 Sistema de Agarres, Lanzamientos y Rebotes
1. **Inicio del Agarre (`intentar_agarre`):** Activa hitbox MEDIO en frame 1. Si conecta, el atacante pasa a `agarrando` y el defensor a `agarrado`.
2. **Elección de Lanzamiento:** Durante un máximo de 1.5s, el atacante puede elegir dirección:
   - **Arriba:** Lanzamiento vertical.
   - **Abajo:** Estrellar contra el suelo.
   - **Adelante / Puño / Patada:** Lanzamiento frontal.
   - **Atrás:** Reposiciona al rival detrás (-60 px) e invierte los lados.
3. **Daño y Rebote:** Ser lanzado inflige 10 de daño. Al impactar el suelo, rebota una vez (`velocity.y = -400.0`). Entra en estado `en_suelo` (invulnerable por 0.3s) antes de levantarse.

### 4.9 Límites de Cámara y Escenario
El método `_aplicar_limites_camara()` impone dos restricciones en cada frame:
1. **Separación máxima:** Ningún jugador puede alejarse del otro más del ancho visible de la cámara.
2. **Bordes absolutos:** Restringe la coordenada X dentro de `[80.0, 1840.0]`.

### 4.10 Depurador Visual (`DebugOverlay`)
Dibuja en tiempo real (conmutable desde el botón UI):
- **Cian:** Pushbox física.
- **Verde:** Hurtbox activa (`Estandar` o `Baja`).
- **Rojo:** Hitboxes ofensivas activas en ese fotograma.

---

## 🏟️ 5. Gestor de Escenario y Partida (`script/escenario.gd`)
Controla el ciclo de vida del encuentro y comunicación de alto nivel:
- **Sistema de Rondas (`MAX_ROUNDS = 2`):** Al mejor de 3. Evalúa si hay KO o Doble KO. Espera 2.5s antes de reanudar.
- **Temporizador:** Descuenta desde 99s. Al llegar a 0, emite `TIME_OVER` y otorga ronda por mayor vida.
- **Recepción de Configuración (`on_match_start`):** Configura IDs, tiempos y rondas al iniciar.

---

## 🎥 6. Cámara Dinámica (`script/Camara.gd`)
- **Seguimiento Horizontal:** Calcula el punto medio entre jugadores con *clamp* instantáneo al viewport.
- **Seguimiento Vertical:** Suaviza el movimiento mediante interpolación lineal (`lerp`).

> **Nota sobre `escenario.gd`:** Si la propiedad `camara` no está asignada en el inspector, `Camara.gd` tiene el control total (X e Y). Si se asigna, `escenario.gd` fija la altura vertical.

---

## ☄️ 7. Proyectil Hadoken (`script/proyectil_hadoken.gd`)
Controla la escena del proyectil:
- **Velocidad:** 900.0 px/s.
- **Daño:** 15.
- **Ciclo de vida:** Avanza horizontalmente. Si llega a `distancia_maxima` sin impactar, emite `WHIFF`. Si impacta, llama a `recibir_ataque()` del rival y desaparece.

---

## 📜 8. Contratos e Integración con el Bus Central (`contracts/`)

El Núcleo 3 publica sucesos hacia `/root/EventBus` y señales locales `on_combat_event`.

### Esquema del Contrato (`contracts/on_combat_event.schema.json`)
| Campo | Tipo | Valores Permitidos / Descripción |
| :--- | :--- | :--- |
| `event_name` | `string` | Constante `"on_combat_event"`. |
| `source_core` | `string` | Constante `"nucleo3_combate"`. |
| `frame` | `integer` | Fotograma de proceso actual (>= 0). |
| `data.type` | `string` | `"HIT"`, `"BLOCK"`, `"WHIFF"`, `"TIME_OVER"`, `"KO"`. |
| `data.attacker` | `int | null` | ID del atacante (`1`, `2`, o `null` en TIME_OVER). |
| `data.defender` | `int | null` | ID del defensor (`1`, `2`, o `null` en WHIFF/TIME_OVER). |
| `data.damage` | `integer` | Daño aplicado (>= 0). |
| `data.current_hp` | `int | null` | Vida restante del defensor (`null` en WHIFF/TIME_OVER).|
| `data.combo_count`| `integer` | Número de impactos consecutivos en el combo. |
| `data.is_ko` | `boolean` | `true` si el golpe dejó al defensor en KO. |
| `data.sound_id` | `string` | Identificador de audio (ej: `"sfx_heavy_hit"`). |

### Ejemplo de Payload (`contracts/on_combat_event.example.json`)
```json
{
  "event_name": "on_combat_event",
  "source_core": "nucleo3_combate",
  "frame": 1240,
  "data": {
    "type": "HIT",
    "attacker": 1,
    "defender": 2,
    "damage": 15,
    "current_hp": 85,
    "combo_count": 2,
    "is_ko": false,
    "sound_id": "sfx_heavy_hit"
  }
}
```
