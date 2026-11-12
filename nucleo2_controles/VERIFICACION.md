# Verificación de cumplimiento — Núcleo 2 (Controles)

Fuente: `requisitos.pdf`, sección **“Núcleo 2: Motor de controles e
interpretación de comandos”**, más las reglas generales de las secciones 3.1 y
6.4.

Este documento responde a una pregunta concreta: **qué cumple el núcleo, qué
está implementado pero falta probar en físico y qué decisiones quedan
pendientes**. No reemplaza a `leeme.md` (uso) ni a `CONTRATO.md` (formato de
datos).

## Cómo se verificó

```bash
flatpak run org.godotengine.Godot --headless --path . --import
flatpak run org.godotengine.Godot --headless --path . \
  --script res://tests/run_tests.gd
flatpak run org.godotengine.Godot --headless --path . --quit-after 120
flatpak run org.godotengine.Godot --headless --path . \
  res://scenes/report_viewer.tscn --quit-after 120
```

Resultado de esta revisión:

- **88 pruebas automáticas**: `OK: todas las pruebas pasaron`.
- Arranque de `scenes/diagnostic.tscn` sin errores de script.
- Arranque de `scenes/report_viewer.tscn` sin errores de script.
- Contrato v3 validado por `scripts/mock_consumer.gd`.
- Esquema JSON y ejemplos validados por las pruebas automáticas.

## 1. Objetivos específicos del Núcleo 2

| Requisito del PDF | Implementación / evidencia | Estado |
|---|---|---|
| Gestión de dispositivos múltiples y hot-plugging | `scripts/input_core.gd` conecta `joy_connection_changed` y reasigna por GUID/índice sin robar el mando de otro jugador. | Cumple; falta prueba física de desconexión/reconexión. |
| Controles independientes para J1 y J2 | `controls_config.json` define `players.1` (híbrido) y `players.2` (mando). `input_core.gd` recorre ambos por separado. | Cumple; falta prueba física simultánea. |
| Búfer de 15 a 30 fotogramas | `scripts/input_buffer.gd` (circular). `controls_config.gd` limita `buffer_size_frames` a **15–30**; valor por defecto 30. Pruebas: capacidad, orden y recorte. | Cumple. |
| Reconocer combinaciones rápidas y movimientos especiales | `scripts/command_recognizer.gd` con ventana, hueco máximo, `final_window`, prioridad, cooldown y consumo de pulsaciones. 12 comandos en la configuración. | Cumple; varios comandos solo probados en automático. |
| Mapeo reconfigurable por `controls_config.json` | `scripts/controls_config.gd` valida y auto-recarga el JSON cada 0.5 s; `R` ejecuta `reload()` manualmente. | Cumple; falta prueba física de auto-recarga con JSON roto/válido. |
| Abstracción de entrada y emisión estandarizada | `N2InputCore.report_emitted(report)` y `_build_report()` emiten el contrato del PDF. El diagnóstico y el mock consumen la misma señal. | Cumple. |

## 2. Conceptos técnicos exigidos

| Concepto | Dónde está | Estado |
|---|---|---|
| Acción abstracta frente a botón físico | `ACTIONS` y `_read_player()` en `input_core.gd`; el reporte no menciona teclas. | Cumple. |
| Memoria de entradas (15–30 frames) | `input_buffer.gd`; 30 frames por defecto. | Cumple. |
| Reconocedor de secuencias y combos | `command_recognizer.gd`; pruebas de especiales, dobles toques y 9 combos. | Cumple. |
| Pulsación única frente a sostenido | Cada snapshot guarda `held`, `pressed` y `released`; los comandos usan `press`, `hold` o `release`. | Cumple. |

## 3. Contrato de datos e interfaz

| Requisito | Evidencia | Estado |
|---|---|---|
| Reporte por jugador a 60 fps | `_physics_process` en `input_core.gd`; `physics_ticks_per_second=60` en `project.godot`. | Cumple. |
| `player_id`, `frame`, `state`, `command_detected` | `_build_report()` y `CONTRATO.md`. | Cumple. |
| `move_x` y `move_y` en `{-1, 0, 1}` | `_build_report()` y validación en `mock_consumer.gd`. | Cumple. |
| `move_y = +1` es salto y `-1` es agachado | `_build_report()`; `Espacio`, `X` y `Y` se mapean a `up`. | Cumple. |
| `punch`, `kick`, `block`, `pause` booleanos | `_build_report()` y `mock_consumer.gd`. | Cumple. |
| `command_detected` string o `null` | `command_recognizer.gd` y `mock_consumer.gd`. | Cumple. |
| **Sin claves extra** | Contrato v3 exacto: `mock_consumer.gd` rechaza `state.jump` y claves de primer nivel extra. Pruebas incluidas. | Cumple. |
| Esquema formal del reporte | `contracts/input_report.schema.json`; las pruebas verifican claves obligatorias, `additionalProperties: false`, seis claves de `state`, ausencia de `jump` y `move_y` en `{-1, 0, 1}`. | Cumple. |
| Ejemplos JSON y JSONL | `contracts/input_report.example.json` y `.jsonl`; cada línea pasa el validador, los frames crecen por jugador y hay comandos. | Cumple. |
| Visor de reportes en vivo | `scenes/report_viewer.tscn` y `scripts/report_viewer.gd`; filtros J1/J2, solo comandos, pausa, copia, carga de ejemplo y exportación JSONL. | Cumple; falta prueba visual con ventana real. |
| Guía de integración para principiantes | `INTEGRACION.md` con copia de archivos, autoloads, receptor N3 y lectura de flancos. | Cumple. |

## 4. Demostración para la primera entrega

| Ítem del PDF | Evidencia | Estado |
|---|---|---|
| Dos columnas J1/J2 con botones iluminados y cinta del búfer en tiempo real | `scenes/diagnostic.tscn`, `scripts/diagnostic.gd`, `scripts/player_panel.gd`. | Cumple. |
| Reconocimiento en vivo de doble toque y técnica especial con tolerancia | `command_recognizer.gd`; pruebas automáticas de `DASH_*` y `SPECIAL_ATTACK_*`. | Cumple en automático; falta demo física de todos. |
| Multijugador simultáneo sin bloqueo ni interferencias | Dos jugadores con estado, búfer y reconocedor independientes. | Implementado; **falta prueba física**. |
| Configuración dinámica sin tocar código | Editar y guardar `controls_config.json`; se auto-recarga en ~0.5 s. `controls_config.gd` conserva la última configuración válida si falla. | Implementado; **falta prueba física**. |
| Emisión estructurada del reporte en consola o pantalla | Registro JSON de 20 líneas en el diagnóstico; `J` activa `print()` por frame; `V` abre el visor con filtros, copia y exportación JSONL. | Cumple; falta prueba visual con ventana real. |

## 5. Archivos obligatorios

| Archivo exigido | Presente | Observación |
|---|---|---|
| Código de captura, búfer y analizador | Sí | `scripts/input_core.gd`, `input_buffer.gd`, `command_recognizer.gd`. |
| Escena ejecutable de diagnóstico | Sí | `scenes/diagnostic.tscn`. |
| `controls_config.json` | Sí | Mapeo de J1/J2 y 12 comandos. |
| `leeme.md` con instrucciones y mapeo | Sí | Incluye ejecución, controles, solución de problemas y pendientes. |
| Material de integración | Sí | `INTEGRACION.md`, `contracts/` y el visor de reportes. No reemplaza el contrato ni el `leeme.md`. |

## 6. Reglas generales y protocolo de pruebas

| Regla | Estado | Nota |
|---|---|---|
| Carpeta propia del núcleo y `leeme.md` | Cumple | Todo vive en `nucleo2_controles/`; no se modificaron otros núcleos. |
| `.gitignore` sin basura | Cumple | Excluye `.godot/`, temporales, exportaciones temporales, basura de editor/SO y `requisitos.pdf`. Conserva `.uid` e `.import`. |
| Mocks / datos simulados | Parcial | `mock_consumer.gd` valida el contrato y `tests/run_tests.gd` genera snapshots sintéticos. No hay un inyector independiente; el equipo decidió no agregarlo en esta iteración. |
| Contrato inmutable y acordado con otros núcleos | Pendiente | El contrato v3 es exacto al PDF, pero **falta confirmación formal de N3/N4**. |
| Licencia del repositorio | Decisión pendiente | No se agregó `LICENSE` por decisión del equipo. |

## 7. Pendientes que no se pueden cerrar solo con código

- [ ] Probar el combo 6 (`→, ↓, →, B`) y los 12 comandos con mando real.
- [ ] Probar el visor con ventana real: layout, copiar y abrir la carpeta.
- [ ] Probar hot-plug: desconectar/conectar un mando sin robar el del otro jugador.
- [ ] Probar a J1 y J2 pulsando a la vez durante varios segundos.
- [ ] Probar la auto-recarga con un JSON válido y con uno roto en la ventana real (y que `R` siga funcionando).
- [ ] Confirmar con N3/N4 el contrato v3 (seis claves, salto por `move_y`).
- [ ] Decidir si se agrega `LICENSE`.
- [ ] Decidir si se agrega el inyector sintético independiente del protocolo 6.4.

## 8. Conclusión

Con el contrato v3, el Núcleo 2 **cumple los requisitos funcionales y los
archivos obligatorios del PDF**. Además entrega material de integración
reproducible: esquema JSON, ejemplos, guía paso a paso y visor de reportes.
Lo que resta no es código faltante: son pruebas físicas y visuales, la
confirmación del contrato con N3/N4 y dos decisiones explícitas del equipo
(licencia e inyector sintético).
