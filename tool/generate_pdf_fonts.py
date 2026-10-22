"""Freeze the existing Manrope variable font for PDF weight support."""
from pathlib import Path
from fontTools.ttLib import TTFont
from fontTools.varLib.instancer import instantiateVariableFont

fonts = Path(__file__).resolve().parents[1] / "assets" / "fonts"
for name, weight in (("Regular", 400), ("Bold", 700)):
    source = TTFont(fonts / "Manrope-Variable.ttf")
    instance = instantiateVariableFont(source, {"wght": weight}, inplace=True)
    instance.save(fonts / f"Manrope-Pdf{name}.ttf")
