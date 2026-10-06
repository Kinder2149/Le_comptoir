# Fabrique toutes les icônes de Le Comptoir à partir du symbole (piste A, auvent et tasse).
# Lancer depuis la racine du projet : python audit_front/proposition/logo/fabriquer_icones.py
import os, fitz

RACINE = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
RES = os.path.join(RACINE, "android", "app", "src", "main", "res")
SORTIE = os.path.join(RACINE, "audit_front", "proposition", "logo")
PLAY = os.path.join(RACINE, "play_store")

ANTHRACITE, LIN, SABLE = "#2F343C", "#F4EFE6", "#D9B06F"

# Le symbole (viewBox 108), sans fond. Centré dans la zone de sécurité Android (cercle de 66).
SYMBOLE = f'''
<path d="M30 28h48l6 17H24z" fill="{LIN}"/>
<path d="M24 44h60a7.5 7.5 0 0 1-15 0 7.5 7.5 0 0 1-15 0 7.5 7.5 0 0 1-15 0 7.5 7.5 0 0 1-15 0z" fill="{LIN}"/>
<path d="M38 28h9l-2 16h-9zM61 28h9l2 16h-9z" fill="{SABLE}"/>
<path d="M39 58h26v8a11 11 0 0 1-11 11h-4a11 11 0 0 1-11-11z" fill="{LIN}"/>
<path d="M65 61h4a5.5 5.5 0 0 1 0 11h-4" fill="none" stroke="{LIN}" stroke-width="4.5" stroke-linecap="round"/>
<rect x="30" y="80" width="48" height="5" rx="2.5" fill="{SABLE}"/>'''
ECHELLE = 0.82  # réduit pour tenir dans la zone de sécurité adaptative
PIVOT = (54, 56)


def svg(fond, forme, echelle):
    g = f'<g transform="translate({PIVOT[0]} {PIVOT[1]}) scale({echelle}) translate({-PIVOT[0]} {-PIVOT[1]})">{SYMBOLE}</g>'
    if forme == "carre":
        f = f'<rect width="108" height="108" rx="24" fill="{fond}"/>'
    elif forme == "plein":
        f = f'<rect width="108" height="108" fill="{fond}"/>'
    else:
        f = ""
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 108 108">{f}{g}</svg>'


def png(contenu_svg, taille, chemin):
    os.makedirs(os.path.dirname(chemin), exist_ok=True)
    doc = fitz.open("svg", contenu_svg.encode())
    page = doc[0]
    pix = page.get_pixmap(matrix=fitz.Matrix(taille / page.rect.width, taille / page.rect.height), alpha=True)
    pix.save(chemin)


# 1) Icônes classiques (anciens Android) : carré arrondi, symbole un peu plus grand.
for dossier, t in {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}.items():
    png(svg(ANTHRACITE, "carre", 0.95), t, os.path.join(RES, f"mipmap-{dossier}", "ic_launcher.png"))

# 2) Icône adaptative (Android 8+) : fond anthracite + symbole vectoriel.
os.makedirs(os.path.join(RES, "mipmap-anydpi-v26"), exist_ok=True)
with open(os.path.join(RES, "mipmap-anydpi-v26", "ic_launcher.xml"), "w", encoding="utf-8") as f:
    f.write('''<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@drawable/ic_launcher_foreground"/>
</adaptive-icon>
''')
with open(os.path.join(RES, "values", "colors.xml"), "w", encoding="utf-8") as f:
    f.write(f'''<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">{ANTHRACITE}</color>
    <color name="fond_demarrage">{ANTHRACITE}</color>
</resources>
''')
with open(os.path.join(RES, "drawable", "ic_launcher_foreground.xml"), "w", encoding="utf-8") as f:
    f.write(f'''<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="108dp" android:height="108dp" android:viewportWidth="108" android:viewportHeight="108">
    <group android:pivotX="{PIVOT[0]}" android:pivotY="{PIVOT[1]}" android:scaleX="{ECHELLE}" android:scaleY="{ECHELLE}">
        <path android:fillColor="{LIN}" android:pathData="M30 28h48l6 17H24z"/>
        <path android:fillColor="{LIN}" android:pathData="M24 44h60a7.5 7.5 0 0 1-15 0 7.5 7.5 0 0 1-15 0 7.5 7.5 0 0 1-15 0 7.5 7.5 0 0 1-15 0z"/>
        <path android:fillColor="{SABLE}" android:pathData="M38 28h9l-2 16h-9zM61 28h9l2 16h-9z"/>
        <path android:fillColor="{LIN}" android:pathData="M39 58h26v8a11 11 0 0 1-11 11h-4a11 11 0 0 1-11-11z"/>
        <path android:strokeColor="{LIN}" android:strokeWidth="4.5" android:strokeLineCap="round" android:pathData="M65 61h4a5.5 5.5 0 0 1 0 11h-4"/>
        <path android:fillColor="{SABLE}" android:pathData="M30 80h48a2.5 2.5 0 0 1 0 5H30a2.5 2.5 0 0 1 0-5z"/>
    </group>
</vector>
''')

# 3) Écran de démarrage : fond anthracite + symbole centré.
png(svg(ANTHRACITE, "aucun", 1.0), 288, os.path.join(RES, "drawable-nodpi", "logo_demarrage.png"))
LANCEMENT = f'''<?xml version="1.0" encoding="utf-8"?>
<layer-list xmlns:android="http://schemas.android.com/apk/res/android">
    <item android:drawable="@color/fond_demarrage" />
    <item>
        <bitmap android:gravity="center" android:src="@drawable/logo_demarrage" />
    </item>
</layer-list>
'''
for d in ("drawable", "drawable-v21"):
    with open(os.path.join(RES, d, "launch_background.xml"), "w", encoding="utf-8") as f:
        f.write(LANCEMENT)

# 4) Éléments Play Store.
png(svg(ANTHRACITE, "plein", 0.95), 512, os.path.join(PLAY, "icone_512.png"))
# Aperçus pour la page de contrôle.
png(svg(ANTHRACITE, "carre", 0.95), 432, os.path.join(SORTIE, "apercu_carre.png"))
rond = svg(ANTHRACITE, "plein", ECHELLE).replace("<svg ", '<svg ', 1)
png(rond, 432, os.path.join(SORTIE, "apercu_adaptatif.png"))
print("icônes fabriquées")
