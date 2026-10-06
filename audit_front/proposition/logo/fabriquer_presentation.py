# Image de présentation Play Store (1024x500) : symbole + nom + slogan sur fond anthracite.
# Lancer depuis la racine du projet : python audit_front/proposition/logo/fabriquer_presentation.py
import os, fitz

RACINE = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
ANTHRACITE, LIN, SABLE = "#2F343C", "#F4EFE6", "#D9B06F"
SYMBOLE = f'''
<path d="M30 28h48l6 17H24z" fill="{LIN}"/>
<path d="M24 44h60a7.5 7.5 0 0 1-15 0 7.5 7.5 0 0 1-15 0 7.5 7.5 0 0 1-15 0 7.5 7.5 0 0 1-15 0z" fill="{LIN}"/>
<path d="M38 28h9l-2 16h-9zM61 28h9l2 16h-9z" fill="{SABLE}"/>
<path d="M39 58h26v8a11 11 0 0 1-11 11h-4a11 11 0 0 1-11-11z" fill="{LIN}"/>
<path d="M65 61h4a5.5 5.5 0 0 1 0 11h-4" fill="none" stroke="{LIN}" stroke-width="4.5" stroke-linecap="round"/>
<rect x="30" y="80" width="48" height="5" rx="2.5" fill="{SABLE}"/>'''
html = f'''<div style="background:{ANTHRACITE};width:1024px;height:500px"></div>'''
svg = f'''<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="500" viewBox="0 0 1024 500">
<rect width="1024" height="500" fill="{ANTHRACITE}"/>
<g transform="translate(60 85) scale(3.1)">{SYMBOLE}</g>
<text x="420" y="245" font-family="Helvetica" font-weight="bold" font-size="84" fill="{LIN}">Le Comptoir</text>
<rect x="422" y="275" width="150" height="6" rx="3" fill="{SABLE}"/>
<text x="420" y="340" font-family="Helvetica" font-size="34" fill="{LIN}">La caisse des buvettes associatives</text>
</svg>'''
doc = fitz.open("svg", svg.encode())
doc[0].get_pixmap(alpha=False).save(os.path.join(RACINE, "play_store", "image_presentation_1024x500.png"))
