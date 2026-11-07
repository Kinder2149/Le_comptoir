# Prototype du classeur Le Comptoir (proposition d'ergonomie, 07/11/2026).
# Usage : python -I prototype_classeur.py <menu_type.json> <sortie.xlsx>
import json
import sys

from openpyxl import Workbook
from openpyxl.formatting.rule import FormulaRule
from openpyxl.styles import Alignment, Border, Font, PatternFill, Side
from openpyxl.utils import get_column_letter
from openpyxl.worksheet.datavalidation import DataValidation

ANTHRACITE = "2F343C"
LIN = "F4EFE6"
LIN_FONCE = "E8DFD0"
SABLE = "D9B06F"
PRUNE = "6C4F86"
SAUGE = "5A7D4F"
OCRE = "9A670F"
BLANC = "FFFFFF"
GRIS = "6B6F76"

police = "Roboto"
f_titre = Font(name=police, size=20, bold=True, color=BLANC)
f_sous = Font(name=police, size=11, color=SABLE)
f_entete = Font(name=police, size=11, bold=True, color=BLANC)
f_texte = Font(name=police, size=11, color=ANTHRACITE)
f_calc = Font(name=police, size=11, italic=True, color=GRIS)
f_section = Font(name=police, size=13, bold=True, color=PRUNE)
f_aide = Font(name=police, size=10, italic=True, color=GRIS)
fond_anthracite = PatternFill("solid", fgColor=ANTHRACITE)
fond_lin = PatternFill("solid", fgColor=LIN)
fond_saisie = PatternFill("solid", fgColor="FFFFFF")
fond_calc = PatternFill("solid", fgColor=LIN_FONCE)
trait = Side(style="thin", color="D8CFC0")
bord = Border(left=trait, right=trait, top=trait, bottom=trait)
centre = Alignment(horizontal="center", vertical="center")
gauche = Alignment(horizontal="left", vertical="center", wrap_text=True)

TYPES = {"compose": "Composé (recette)", "unite": "À l'unité", "part": "À la part", "litre": "Au litre"}
PROVENANCES = {"achete": "Achetée", "apporte": "Apportée par les bénévoles"}
UNITES = ["unité", "tranche", "g", "kg", "cl", "L"]


def famille(p):
    n = p["nom"].lower()
    t = p.get("type", "unite")
    if p.get("provenance") == "apporte":
        return "Fait maison (bénévoles)"
    if t == "compose":
        return "Croques"
    if n.startswith(("café", "thé")):
        return "Boissons chaudes"
    if t == "litre":
        return "Boissons fraîches"
    return "Snacks et fruits"


def bandeau(ws, titre, sous_titre, largeur):
    """Bandeau anthracite en tête de feuille, comme la barre de titre de l'application."""
    ws.sheet_view.showGridLines = False
    for r in (1, 2, 3):
        for c in range(1, largeur + 1):
            ws.cell(r, c).fill = fond_anthracite
    ws.row_dimensions[1].height = 10
    ws.row_dimensions[2].height = 34
    ws.row_dimensions[3].height = 22
    ws.cell(2, 1, titre).font = f_titre
    ws.cell(3, 1, sous_titre).font = f_sous
    ws.merge_cells(start_row=2, start_column=1, end_row=2, end_column=largeur)
    ws.merge_cells(start_row=3, start_column=1, end_row=3, end_column=largeur)
    for c in range(1, largeur + 1):
        ws.cell(4, c).fill = PatternFill("solid", fgColor=SABLE)
    ws.row_dimensions[4].height = 4


def aide(ws, ligne, texte, largeur):
    ws.cell(ligne, 1, texte).font = f_aide
    ws.cell(ligne, 1).alignment = gauche
    ws.merge_cells(start_row=ligne, start_column=1, end_row=ligne, end_column=largeur)
    ws.row_dimensions[ligne].height = 32


def entetes(ws, ligne, noms, largeurs):
    for i, (n, l) in enumerate(zip(noms, largeurs), start=1):
        c = ws.cell(ligne, i, n)
        c.font = f_entete
        c.fill = PatternFill("solid", fgColor=PRUNE)
        c.alignment = centre
        c.border = bord
        ws.column_dimensions[get_column_letter(i)].width = l
    ws.row_dimensions[ligne].height = 30
    ws.freeze_panes = ws.cell(ligne + 1, 2)


def cellule(ws, r, c, v, calc=False, fmt=None):
    x = ws.cell(r, c, v)
    x.font = f_calc if calc else f_texte
    x.fill = fond_calc if calc else fond_saisie
    x.border = bord
    x.alignment = Alignment(vertical="center", horizontal="left" if isinstance(v, str) else "right")
    if fmt:
        x.number_format = fmt
    return x


def liste(ws, choix, plage):
    dv = DataValidation(type="list", formula1='"' + ",".join(choix) + '"', allow_blank=True)
    dv.error = "Choisissez une valeur dans la liste."
    dv.errorTitle = "Valeur inconnue"
    ws.add_data_validation(dv)
    dv.add(plage)


def main(chemin_json, sortie):
    produits = json.load(open(chemin_json, encoding="utf-8"))
    ordre = ["Croques", "Boissons chaudes", "Boissons fraîches", "Snacks et fruits", "Fait maison (bénévoles)"]
    produits.sort(key=lambda p: ordre.index(famille(p)))
    gymnases = [("Gymnase Jean Moulin", 80), ("Salle Coubertin", 40)]

    wb = Workbook()

    # ---------------- Accueil
    ws = wb.active
    ws.title = "Accueil"
    bandeau(ws, "Le Comptoir — classeur de l'association", "Handball Club des Aigles · Tournoi de printemps 2026", 6)
    ws.column_dimensions["A"].width = 6
    ws.column_dimensions["B"].width = 28
    for col in "CDEF":
        ws.column_dimensions[col].width = 18
    ws.cell(6, 1, "Comment s'en servir").font = f_section
    etapes = [
        ("1", "Menu", "Vos produits, leurs prix et ce que chaque personne consomme par jour."),
        ("2", "Recettes", "Les ingrédients d'un produit composé (croque…), une ligne par ingrédient."),
        ("3", "Stock de départ", "Ce que vous avez déjà, gymnase par gymnase, avant le tournoi."),
        ("4", "Historique", "Les ventes d'un tournoi passé : l'application en tire la prévision."),
        ("5", "Importer", "Dans l'application : Préparation → « Importer un classeur »."),
    ]
    for i, (n, nom, texte) in enumerate(etapes):
        r = 8 + i * 2
        c = ws.cell(r, 1, n)
        c.font = Font(name=police, size=14, bold=True, color=BLANC)
        c.fill = PatternFill("solid", fgColor=SAUGE)
        c.alignment = centre
        b = ws.cell(r, 2, nom)
        b.font = Font(name=police, size=12, bold=True, color=ANTHRACITE, underline="single" if nom != "Importer" else None)
        if nom != "Importer":
            b.hyperlink = f"#'{nom}'!A1"
        t = ws.cell(r, 3, texte)
        t.font = f_texte
        ws.merge_cells(start_row=r, start_column=3, end_row=r, end_column=6)
        ws.row_dimensions[r].height = 26
    r = 19
    ws.cell(r, 1, "Les couleurs").font = f_section
    legende = [
        (fond_saisie, "Case blanche : à remplir ou à corriger."),
        (fond_calc, "Case beige en italique : calculée, ne pas la modifier."),
        (PatternFill("solid", fgColor=PRUNE), "En-tête violet : ne pas renommer (l'application le lit)."),
    ]
    for i, (fond, texte) in enumerate(legende):
        ws.cell(r + 2 + i, 1).fill = fond
        ws.cell(r + 2 + i, 1).border = bord
        ws.cell(r + 2 + i, 2, texte).font = f_texte
        ws.merge_cells(start_row=r + 2 + i, start_column=2, end_row=r + 2 + i, end_column=6)

    # ---------------- Menu
    ws = wb.create_sheet("Menu")
    noms = ["Famille", "Produit", "Prix (€)", "Type", "Provenance", "Verres par litre", "Parts par gâteau", "Conso / pers / jour"]
    larg = [24, 32, 11, 20, 26, 14, 14, 18]
    bandeau(ws, "Menu", "Le catalogue de la buvette : ce qu'on vend, à quel prix, et ce qu'une personne consomme par jour.", len(noms))
    aide(ws, 5, "Une ligne par produit. Type et Provenance se choisissent dans la liste. « Conso / pers / jour » : 0,5 = un produit pour deux personnes par jour.", len(noms))
    entetes(ws, 6, noms, larg)
    r = 7
    for p in produits:
        t = p.get("type", "unite")
        vals = [famille(p), p["nom"], p["prixCentimes"] / 100, TYPES[t], PROVENANCES[p.get("provenance", "achete")],
                p.get("verresParLitre") if t == "litre" else None, p.get("partsParEntier"), p.get("conso")]
        for c, v in enumerate(vals, start=1):
            fmt = '#,##0.00 "€"' if c == 3 else ("0.00" if c == 8 else None)
            x = cellule(ws, r, c, v, fmt=fmt)
            if (c == 6 and t != "litre") or (c == 7 and t != "part"):
                x.fill = fond_calc
        r += 1
    fin = r - 1
    liste(ws, list(TYPES.values()), f"D7:D{fin + 30}")
    liste(ws, list(PROVENANCES.values()), f"E7:E{fin + 30}")
    liste(ws, ordre, f"A7:A{fin + 30}")
    ws.conditional_formatting.add(f"A7:H{fin}", FormulaRule(formula=['$E7="Apportée par les bénévoles"'],
                                                            fill=PatternFill("solid", fgColor="F3ECF8")))

    # ---------------- Recettes
    ws = wb.create_sheet("Recettes")
    noms = ["Produit", "Ingrédient", "Quantité par produit", "Unité"]
    bandeau(ws, "Recettes", "Ce qu'il faut pour faire UN produit composé. Les courses en déduisent les ingrédients à acheter.", 4)
    aide(ws, 5, "Une ligne par ingrédient. Exemple : un croque-monsieur = 2 tranches de pain de mie, 16 g de gruyère…", 4)
    entetes(ws, 6, noms, [32, 30, 20, 12])
    r = 7
    for p in produits:
        for ing in p.get("ingredients", []):
            for c, v in enumerate([p["nom"], ing["nom"], ing["quantite"], ing["unite"]], start=1):
                cellule(ws, r, c, v, fmt="0.###" if c == 3 else None)
            r += 1
        if p.get("ingredients"):
            for c in range(1, 5):
                ws.cell(r - 1, c).border = Border(left=trait, right=trait, top=trait, bottom=Side(style="medium", color=SABLE))
    liste(ws, UNITES, f"D7:D{r + 40}")

    # ---------------- Stock de départ
    ws = wb.create_sheet("Stock de départ")
    noms = ["Gymnase", "Produit", "Quantité", "Compté en"]
    bandeau(ws, "Stock de départ", "Ce que vous avez déjà avant le tournoi. Vide = produit non suivi.", 4)
    aide(ws, 5, "Les boissons se comptent en verres (1 L = 4 verres), les gâteaux en parts. Les ingrédients n'ont pas de stock : seuls les produits finis comptent.", 4)
    entetes(ws, 6, noms, [26, 32, 12, 14])
    r = 7
    for g, _ in gymnases:
        for p in produits:
            t = p.get("type", "unite")
            unite = {"litre": "verres", "part": "parts"}.get(t, "unités")
            cellule(ws, r, 1, g)
            cellule(ws, r, 2, p["nom"])
            cellule(ws, r, 3, None, fmt="0")
            cellule(ws, r, 4, unite, calc=True)
            r += 1
        for c in range(1, 5):
            ws.cell(r - 1, c).border = Border(left=trait, right=trait, top=trait, bottom=Side(style="medium", color=SABLE))

    # ---------------- Historique
    ws = wb.create_sheet("Historique")
    noms = ["Événement", "Gymnase", "Personnes", "Jours", "Produit", "Quantité vendue", "Conso / pers / jour"]
    bandeau(ws, "Historique", "Les ventes d'un tournoi passé : l'application en tire la prévision du prochain.", 7)
    aide(ws, 5, "Une ligne par gymnase et par produit. La dernière colonne se calcule toute seule : c'est le chiffre que l'application proposera.", 7)
    entetes(ws, 6, noms, [26, 24, 12, 10, 32, 16, 20])
    exemples = [("Croque-monsieur", 104), ("Café", 208), ("Coca", 51), ("Tarte", 160)]
    r = 7
    for prod, q in exemples:
        for c, v in enumerate(["Tournoi 2025", "Gymnase Jean Moulin", 80, 2, prod, q], start=1):
            cellule(ws, r, c, v)
        cellule(ws, r, 7, f"=IF(C{r}*D{r}=0,\"\",F{r}/(C{r}*D{r}))", calc=True, fmt="0.00")
        r += 1
    for k in range(r, r + 40):
        for c in range(1, 7):
            cellule(ws, k, c, None)
        cellule(ws, k, 7, f"=IF(OR(F{k}=\"\",C{k}*D{k}=0),\"\",F{k}/(C{k}*D{k}))", calc=True, fmt="0.00")

    # ---------------- Courses (rempli à l'export)
    ws = wb.create_sheet("Courses")
    noms = ["Rayon", "Article", "Quantité", "Unité", "Coût (€)"]
    bandeau(ws, "Courses", "Rempli par l'application à l'export du tournoi : ce qui a été acheté, rayon par rayon.", 5)
    entetes(ws, 6, noms, [22, 32, 12, 10, 12])
    lignes = [("Boulangerie", "Pain de mie", 476, "tranches", None), ("Crèmerie", "Gruyère râpé", 1.46, "kg", None),
              ("Charcuterie", "Jambon blanc", 79, "tranches", None), ("Boissons", "Café", 45.5, "L", None),
              ("Entretien", "Liquide vaisselle", 2, "unités", None)]
    for i, l in enumerate(lignes):
        for c, v in enumerate(l, start=1):
            cellule(ws, 7 + i, c, v, calc=True, fmt='#,##0.00 "€"' if c == 5 else None)
    t = 7 + len(lignes)
    ws.cell(t, 4, "Total").font = Font(name=police, bold=True, color=ANTHRACITE)
    x = ws.cell(t, 5, f"=SUM(E7:E{t - 1})")
    x.font = Font(name=police, bold=True, color=ANTHRACITE)
    x.number_format = '#,##0.00 "€"'

    wb.active = 0
    wb.save(sortie)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
