# Núcleo 4 — Sistema de Menús, Flujo de Juego y HUD

Demo aislada y autocontenida del **Núcleo 4** para el juego de pelea 2D colaborativo.
Este núcleo gestiona la capa completa de interfaz visual de usuario (UI/HUD) y el flujo global de pantallas del juego. Se encarga de la navegación desde la pantalla de título hasta los resultados finales, la selección dinámica de personajes y el despliegue del marcador de combate reactivo. Todo esto opera de manera desacoplada mediante el Bus Central de Eventos (BCE).

## 1. Requisitos y Dependencias

* **Godot Engine**: Compatible con GDScript (Godot 4.x).

* **Estructura de directorios**: El sistema asume la existencia de la ruta `assets/fighters/` en la raíz del proyecto. Cada subcarpeta representa a un luchador y debe contener idealmente una imagen `portrait.png`. Si esta imagen no existe, el sistema cargará un ícono de silueta por defecto sin lanzar excepciones.

## 2. Cómo abrir y ejecutar la prueba local

Para probar este núcleo de forma aislada (sin necesidad de los núcleos de Controles, Combate o Audio):

1. Abre el proyecto en Godot.

2. **Para probar el flujo de pantallas**: Ejecuta la escena vinculada a `pantalla_titulo.tscn`. Navega por los menús usando los controles simulados detallados en la Sección 6.

3. **Para probar el HUD reactivo**: Ejecuta la escena del simulador (`simulador_hud.tscn` / `simulador_hud.gd`). Presiona los botones de esta interfaz de prueba para enviar eventos sintéticos de daño, sumar combos o declarar un K.O., verificando visualmente que el HUD responda correctamente.

## 3. Archivos del Proyecto

El núcleo está compuesto por una serie de escenas (`.tscn`) y scripts (`.gd`) organizados de manera modular:

### Escenas (Archivos `.tscn`)

**Navegación y Menús Principales:**

* `pantalla_titulo.tscn`: Pantalla inicial de arranque (Press Start).

* `Menu_Principal.tscn`: Gestiona las opciones base del juego (Combate Local, Opciones, Salir).

* `menu_seleccion_personajes.tscn`: Pantalla para elegir a los luchadores escaneando la carpeta de assets.

* `menu_seleccion_escenario.tscn`: Permite a los jugadores definir el escenario de la pelea.

* `Pantalla_Opciones.tscn`: Menú para ajustes generales.

* `menu_controles.tscn` / `Pantalla_InfoControles.tscn`: Pantallas de información y configuración de los mandos.

**Combate y HUD:**

* `pantalla_combate.tscn`: Escena orquestadora de la pelea. Carga el escenario e instancia a los personajes.

* `HUD.tscn`: Interfaz de marcador (barras de vida, combos, reloj) fijada sobre la cámara.

* `Menu_Pausa.tscn`: Menú emergente que congela la acción del combate.

**Resultados de la Partida:**

* `Pantalla_Ganador.tscn`: Muestra al vencedor, animaciones y opciones de revancha.

* `Pantalla_Empate.tscn`: Pantalla cinemática dedicada al caso de "DRAW" (empate).

**Escenarios (Arenas de Combate):**

* `Escenario_Uni.tscn`: Escenario base o universitario.

* `Escenario_CampoEntrenamiento.tscn`: Entorno de práctica.

* `Escenario_Desierto.tscn`: Entorno desértico.

* `Escenario_Espacio.tscn`: Entorno espacial.

* `Escenario_Playa.tscn`: Entorno de playa.

### Scripts (Archivos `.gd`)

* **Arquitectura**: `event_bus.gd` (Bus Central de Eventos), `DatosGlobales.gd` (Autoload para selecciones temporales).

* **Flujo**: `pantalla_titulo.gd`, `menu_principal.gd`, `menu_seleccion_personajes.gd`, `menu_seleccion_escenario.gd`, `pantalla_ganador.gd`.

* **Combate y HUD**: `pantalla_combate.gd`, `hud_manager.gd`, `menu_pausa.gd`, `camera_2d.gd`, `escenario_uni.gd`.

* **Pruebas**: `simulador_hud.gd` (Inyector de eventos falsos).

## 4. Especificación de Eventos (Contratos de Datos)

De acuerdo con la Matriz Maestra de Comunicación, el Núcleo 4 interactúa con el sistema de la siguiente manera:

### Eventos que EMITE (Salida)

* **`on_match_start`** (Desde `pantalla_combate.gd`): Inicializa los Núcleos de Combate (3) y Audio (5). Envía la configuración del combate incluyendo IDs de luchadores, escenario, tiempo y rondas.

* **`on_state_change`** (Desde los Menús): Avisa al Núcleo de Audio (5) para que conmute las pistas de música según la pantalla actual.

### Eventos que ESCUCHA (Entrada)

* **`on_combat_event`** (Desde el Núcleo 3): El `hud_manager.gd` lo utiliza para leer `current_hp` (salud actual), animar la barra residual según el `damage` recibido, desplegar el `combo_count`, y mostrar el cartel cinemático de K.O. si `is_ko` es `true`.

* **Reporte de Controles por Fotograma** (Desde el Núcleo 2): Permite la navegación por los menús usando `move_x` y `move_y`, y detecta la señal `pause == true` para abrir el `Menu_Pausa.tscn`.

## 5. Casos Especiales y Manejo de Errores

* **Retrato Faltante**: Si la subcarpeta de un personaje no tiene una imagen `portrait.png`, la grilla no se rompe; se asigna una silueta oscura automáticamente.

* **Empates**: En caso de que el tiempo llegue a cero con vidas iguales, o haya una doble caída en el mismo fotograma, la interfaz mostrará el cartel de "DRAW" (mediante `Pantalla_Empate.tscn`).

## 6. Controles Simulados por Escena (Modo Aislado)

Dado que este núcleo debe probarse de forma independiente antes de integrarse con los comandos que emitirá el **Núcleo 2 (Controles)**, se han configurado controles simulados estándar en Godot (`InputMap`) o mediante interfaces gráficas para evaluar cada sección:

### Escenas de Navegación Simple
*(Aplica para `pantalla_titulo.tscn`, `Menu_Principal.tscn`, `menu_seleccion_escenario.tscn`, `Pantalla_Opciones.tscn`, `Pantalla_Ganador.tscn`, etc.)*

* **Navegación (Mover cursor):** Teclas Direccionales (Flechas) o `W`, `A`, `S`, `D`. (Simulan los eventos de direcciones abstractas `move_x` y `move_y`).
* **Aceptar / Confirmar:** Tecla `Enter` o `Espacio`.
* **Cancelar / Volver:** Tecla `Escape` o `Retroceso` (`Backspace`).

### Pantalla de Selección de Personajes (`menu_seleccion_personajes.tscn`)
Para comprobar la carga dinámica y permitir la selección de dos luchadores en el entorno de pruebas, los controles se dividen:

* **Jugador 1:** Utiliza las teclas `W`, `A`, `S`, `D` para mover su cursor por la grilla y `Espacio` o `F` para confirmar su selección.
* **Jugador 2:** Utiliza las **Flechas Direccionales** para mover su cursor independiente y `Enter` para confirmar.

### Menú de Pausa y Escena de Combate (`pantalla_combate.tscn` / `Menu_Pausa.tscn`)
* **Pausar el juego:** Presionar la tecla `Escape` o `P`. Esto simula recibir la señal `pause == true`, congelando el reloj (y simulando detener el Núcleo 3) e invocando la interfaz emergente.
* **Navegar en Pausa:** Se retoman los controles de menú estándar (Flechas direccionales para subir/bajar y Enter para seleccionar opciones como reanudar o salir).

### Simulador del HUD (`simulador_hud.tscn` o `.gd`)
Para esta escena de diagnóstico no se utiliza el teclado. Funciona como un inyector (Mock) mediante una **botonera visual interactiva** operada únicamente con el **Ratón (Click izquierdo)**:

* **Botones de Daño (Ej: "-10 HP"):** Simulan el impacto, forzando la actualización instantánea de la barra verde del HUD y activando el efecto de deslizamiento de la barra roja residual.
* **Botones de Combo ("+1 Hit"):** Emiten el evento incrementando la clave `combo_count` para verificar la animación de contadores en pantalla.
* **Botón de K.O.:** Emite el diccionario con el valor `"is_ko": true`, forzando al HUD a desplegar el anuncio gigante de finalización y detener el cronómetro.
* **Botón de Time/Reset:** Modifica el reloj virtual o resetea las barras de vida para hacer más pruebas sin necesidad de reiniciar la escena.