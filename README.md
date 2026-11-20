# GNDU

Juego de lucha 2D en Godot 4.7. El repositorio es un **proyecto único**: el
Núcleo 2 (controles) y el Núcleo 3 (combate) funcionan juntos desde la raíz.

## Ejecutar

```bash
flatpak run org.godotengine.Godot --path "/ruta/a/GNDU"
```

- Escena principal: `res://scenes/escenario.tscn`.
- Diagnóstico de controles: `res://scenes/diagnostic.tscn`.
- Visor de reportes: `res://scenes/report_viewer.tscn`.

La física corre a 60 Hz y el proyecto usa `gl_compatibility` para reducir
latencia y funcionar en más equipos.

## Controles

### Teclado

| Acción | J1 | J2 |
|---|---|---|
| Izquierda | `A` | `←` |
| Derecha | `D` | `→` |
| Arriba (dirección) | `W` | `↑` |
| Abajo | `S` | `↓` |
| **Salto** | `Espacio` | `/` |
| Puño | `H` | `Shift` |
| Patada | `J` | `Enter` |
| Bloqueo | `K` | `Ctrl` |
| **Agarre** | `L` | `Alt` |
| Pausa | `Esc` | `Backspace` |

### Mando

| Acción | Botón |
|---|---|
| Direcciones | D-pad / stick izquierdo |
| **Salto** | `X` / `Y` (cuadrado / triángulo en PlayStation) |
| Puño | `A` (cruz) |
| Patada | `B` (círculo) |
| Bloqueo | `RB` / `R1` |
| **Agarre** | `LB` / `L1` |
| Pausa | `Start` |

El salto es un botón propio (`jump`), no la dirección arriba. El reporte JSON de
N2 conserva seis claves; salto y agarre se leen del snapshot interno de
`N2InputCore`.

## Comandos especiales

Notación: **A = puño**, **B = patada**. Las direcciones son absolutas.

| Comando | Entrada | Resultado en combate |
|---|---|---|
| `HADOKEN` | `←, → + A` | Proyectil de energía |
| `SHORYUKEN` | `→, ↓, → + A` | Uppercut ascendente |
| `ABAJO_ARRIBA` | `↓, ↑ + A` | Ataque fuerte ascendente |
| `DOBLE_PATADA` | `↓, → + B` | Dos patadas ascendentes |
| `EMBESTIDA` | `→, ↓, → + B` | Embestida rompe-guardia |
| `TATSUMAKI` | `←, → + B` | Patada giratoria |

También se reconocen `DASH_LEFT`, `DASH_RIGHT`, `COMBO_AAA`, `COMBO_BBB`,
`COMBO_ABA` y `COMBO_AAB`.

## Configuración

El mapeo y los comandos se editan en `controls_config.json`. Al guardar, N2 lo
recarga automáticamente en ~0.5 s. La configuración por defecto también vive en
`scripts/controls_config.gd` como respaldo.

## Pruebas

```bash
# Importar recursos (primera vez o tras mover archivos)
flatpak run org.godotengine.Godot --headless --path "/ruta/a/GNDU" --import

# Pruebas automáticas
flatpak run org.godotengine.Godot --headless --path "/ruta/a/GNDU" \
  --script res://tests/run_tests.gd

# Arranque de la escena principal
flatpak run org.godotengine.Godot --headless --path "/ruta/a/GNDU" \
  --quit-after 120
```

## Documentación

- `docs/controles/leeme.md`: manual de controles, configuración y diagnóstico.
- `docs/controles/CONTRATO.md`: contrato de datos N2 → N3/N4 (versión 3).
- `docs/controles/INTEGRACION.md`: guía de integración paso a paso.
- `docs/controles/VERIFICACION.md`: matriz de cumplimiento.
- `docs/combate/README.md`: arquitectura del motor de combate.
- `contracts/`: esquemas y ejemplos de los contratos.
