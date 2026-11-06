# GNDU CONTROLES

Demo aislada del **Núcleo 2**: captura de teclado y mandos, búfer de 30
fotogramas, reconocimiento de comandos y reporte JSON por jugador a 60 fps.

- Instrucciones de uso, mapeo y solución de problemas: [leeme.md](leeme.md)
- Contrato de datos para N3/N4: [CONTRATO.md](CONTRATO.md)

## Ejecutar

Requiere Godot 4.7 (probado con 4.7.2 Flatpak).

```bash
flatpak run org.godotengine.Godot --path .
```

La escena principal es `scenes/diagnostic.tscn` (1280×720). Teclas de la demo:
`R` recarga el JSON, `J` muestra/oculta la consola, `C` congela la cinta y
`F10` sale.

## Probar

```bash
# 41 pruebas automáticas, sin ventana
flatpak run org.godotengine.Godot --headless --path . \
  --script res://tests/run_tests.gd

# sonda de mandos, con ventana
flatpak run org.godotengine.Godot --path . \
  --script res://tests/joy_probe.gd
```

## Estado

El núcleo funciona de forma aislada con datos simulados. Las pruebas
automáticas pasan y el contrato v2 está documentado en `CONTRATO.md`. Los
pendientes de verificación física y las decisiones de entrega están en
`leeme.md` §12.
