# GNDU CONTROLES

Núcleo 2 integrado en el proyecto raíz: captura de teclado y mandos, búfer de
15 a 30 fotogramas (30 por defecto), reconocimiento de comandos y reporte JSON
por jugador a 60 fps.

- Instrucciones de uso, mapeo y solución de problemas: [leeme.md](leeme.md)
- Contrato de datos para N3/N4: [CONTRATO.md](CONTRATO.md)
- Guía de integración paso a paso: [INTEGRACION.md](INTEGRACION.md)
- Esquema y ejemplos del reporte: [contracts/](../../contracts/)
- Matriz de cumplimiento contra el PDF: [VERIFICACION.md](VERIFICACION.md)

## Ejecutar

Requiere Godot 4.7 (probado con 4.7.2 Flatpak).

```bash
# Juego completo
flatpak run org.godotengine.Godot --path .

# Diagnóstico de controles
flatpak run org.godotengine.Godot --path . res://scenes/diagnostic.tscn
```

La escena principal del proyecto es `scenes/escenario.tscn`; el diagnóstico de
controles vive en `scenes/diagnostic.tscn`. Los cambios en
`controls_config.json` se aplican solos al guardar (cada ~0.5 s). Teclas del
diagnóstico: `F1` fuerza una recarga, `F2` muestra/oculta la consola, `F3`
congela la cinta, `F4` abre el visor de reportes JSON y `F10` sale. El visor
permite filtrar J1/J2, pausar la vista, copiar, cargar el ejemplo y guardar
`.jsonl` en `user://n2_reports/`.

## Probar

```bash
# 194 pruebas automáticas, sin ventana
flatpak run org.godotengine.Godot --headless --path . \
  --script res://tests/run_tests.gd

# sonda de mandos, con ventana
flatpak run org.godotengine.Godot --path . \
  --script res://tests/joy_probe.gd
```

## Estado

N2 y N3 funcionan como un solo proyecto desde la raíz. Las 194 pruebas
automáticas pasan y el contrato v3, exacto al PDF, está documentado en
`CONTRATO.md`. También incluye un esquema JSON, ejemplos, una guía de
integración para principiantes y un visor de reportes en vivo.
El detalle de lo cumplido y lo pendiente está en `VERIFICACION.md`;
las pruebas físicas y decisiones de entrega están en `leeme.md` §12.
