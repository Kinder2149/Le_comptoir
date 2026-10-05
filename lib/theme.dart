import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Couleurs de la charte (décision 31 de PROJET_CONTEXTE.md, « Anthracite & pigments »).
abstract final class Palette {
  // Marque et neutres
  static const anthracite = Color(0xFF2F343C);
  static const anthraciteFonce = Color(0xFF1B1F25);
  static const anthraciteDoux = Color(0xFFE6E8EB);
  static const lin = Color(0xFFF4EFE6);
  static const papier = Color(0xFFFFFDF9);
  static const filet = Color(0xFFDDD5C5);
  static const encre = Color(0xFF1E2430);
  static const gris = Color(0xFF5F6573);
  static const sable = Color(0xFFD9B06F);
  static const sableDoux = Color(0xFFF1E6D2);

  // Couleurs d'action (chacune a un seul sens, voir [TypeAction])
  static const prune = Color(0xFF6C4F86);
  static const pruneFonce = Color(0xFF43305A);
  static const pruneDoux = Color(0xFFEBE3F1);
  static const framboise = Color(0xFFA04467);
  static const framboiseFonce = Color(0xFF66223F);
  static const framboiseDoux = Color(0xFFF5E3EA);
  static const sauge = Color(0xFF5A7D4F);
  static const saugeFonce = Color(0xFF34502C);
  static const saugeDoux = Color(0xFFE5EFDD);
  static const ocre = Color(0xFF9A670F);
  static const ocreFonce = Color(0xFF6E4A0E);
  static const ocreDoux = Color(0xFFF6E8C6);
  static const brique = Color(0xFFA8433A);
  static const briqueFonce = Color(0xFF6E2620);
  static const briqueDoux = Color(0xFFF6E2DF);
}

/// Le sens d'une couleur d'action : gérer, comprendre, réussir, faire attention, défaire.
/// La couleur renforce toujours un mot clair sur le bouton, elle ne le remplace jamais.
enum TypeAction {
  gerer(Palette.prune, Palette.pruneFonce, Palette.pruneDoux),
  analyser(Palette.framboise, Palette.framboiseFonce, Palette.framboiseDoux),
  reussir(Palette.sauge, Palette.saugeFonce, Palette.saugeDoux),
  attention(Palette.ocre, Palette.ocreFonce, Palette.ocreDoux),
  danger(Palette.brique, Palette.briqueFonce, Palette.briqueDoux);

  const TypeAction(this.fort, this.fonce, this.doux);

  final Color fort;
  final Color fonce;
  final Color doux;

  /// Bouton plein (FilledButton) : l'action principale de l'écran.
  ButtonStyle get plein => FilledButton.styleFrom(
        backgroundColor: fort,
        foregroundColor: Colors.white,
      );

  /// Bouton à contour (OutlinedButton) : action secondaire. Le danger est toujours à contour.
  ButtonStyle get contour => OutlinedButton.styleFrom(
        foregroundColor: fonce,
        side: BorderSide(color: fort, width: 1.5),
      );

  /// Bouton texte (TextButton) : action discrète avec une zone d'appui de 48 px.
  ButtonStyle get texte => TextButton.styleFrom(
        foregroundColor: fonce,
        minimumSize: const Size(72, 48),
      );
}

/// Thème de toute l'application : anthracite, lin et boutons arrondis (14), cartes (16).
ThemeData themeComptoir() {
  const scheme = ColorScheme.light(
    primary: Palette.anthracite,
    onPrimary: Colors.white,
    primaryContainer: Palette.anthraciteDoux,
    onPrimaryContainer: Palette.anthraciteFonce,
    secondary: Palette.prune,
    onSecondary: Colors.white,
    secondaryContainer: Palette.pruneDoux,
    onSecondaryContainer: Palette.pruneFonce,
    tertiary: Palette.framboise,
    onTertiary: Colors.white,
    tertiaryContainer: Palette.framboiseDoux,
    onTertiaryContainer: Palette.framboiseFonce,
    error: Palette.brique,
    onError: Colors.white,
    errorContainer: Palette.briqueDoux,
    onErrorContainer: Palette.briqueFonce,
    surface: Palette.lin,
    onSurface: Palette.encre,
    onSurfaceVariant: Palette.gris,
    surfaceContainerLowest: Colors.white,
    surfaceContainerLow: Palette.papier,
    surfaceContainer: Palette.papier,
    surfaceContainerHigh: Palette.sableDoux,
    surfaceContainerHighest: Palette.sableDoux,
    outline: Color(0xFFC5BBA8),
    outlineVariant: Palette.filet,
    surfaceTint: Colors.transparent,
  );

  final base = ThemeData(useMaterial3: true, colorScheme: scheme).textTheme.apply(
        bodyColor: Palette.encre,
        displayColor: Palette.encre,
      );
  final texte = base.copyWith(
    titleLarge: base.titleLarge?.copyWith(fontWeight: FontWeight.w700),
    titleMedium: base.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    titleSmall: base.titleSmall?.copyWith(fontWeight: FontWeight.w700),
    headlineSmall: base.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
  );

  final arrondi14 = RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));
  const minimum = Size(64, 48);
  const gras = TextStyle(fontSize: 15, fontWeight: FontWeight.w700);

  OutlineInputBorder champ(Color c, [double largeur = 1.5]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c, width: largeur),
      );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: Palette.lin,
    textTheme: texte,
    appBarTheme: AppBarTheme(
      backgroundColor: Palette.anthracite,
      foregroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      titleTextStyle: const TextStyle(
          fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: minimum,
        shape: arrondi14,
        textStyle: gras,
        disabledBackgroundColor: const Color(0xFFE6E0D6),
        disabledForegroundColor: const Color(0xFF9A9486),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: minimum,
        shape: arrondi14,
        textStyle: gras,
        foregroundColor: Palette.anthracite,
      ).copyWith(
        // Le contour se grise avec le texte quand le bouton est désactivé.
        side: WidgetStateProperty.resolveWith(
          (etats) => BorderSide(
            color: etats.contains(WidgetState.disabled)
                ? Palette.filet
                : Palette.anthracite,
            width: 1.5,
          ),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: minimum,
        shape: arrondi14,
        textStyle: gras,
        foregroundColor: Palette.anthracite,
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: TypeAction.gerer.fort,
      foregroundColor: Colors.white,
      shape: arrondi14,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: champ(const Color(0xFFC5BBA8)),
      enabledBorder: champ(const Color(0xFFC5BBA8)),
      focusedBorder: champ(Palette.anthracite, 2),
      errorBorder: champ(Palette.brique),
      focusedErrorBorder: champ(Palette.brique, 2),
    ),
    cardTheme: CardThemeData(
      color: Palette.papier,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Palette.filet),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Palette.papier,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titleTextStyle: texte.titleLarge,
    ),
    dividerTheme: const DividerThemeData(color: Palette.filet, thickness: 1),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: Palette.anthracite,
        selectedForegroundColor: Colors.white,
        foregroundColor: Palette.anthracite,
        side: const BorderSide(color: Palette.anthracite, width: 1.5),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: Palette.anthracite,
      contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      behavior: SnackBarBehavior.floating,
    ),
    progressIndicatorTheme:
        const ProgressIndicatorThemeData(color: Palette.anthracite),
  );
}
