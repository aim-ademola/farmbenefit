import 'package:flint_ui/flint_ui.dart';

const white = '#ffffff';
const cream = '#fffdf7';
const softGreen = '#f5f9ef';
const line = '#dfe9d6';
const ink = '#173b22';
const muted = '#64715e';
const green = '#1f7a3d';
const darkGreen = '#0f4b2a';
const leaf = '#6ea33a';
const gold = '#c79b2b';

const softShadow = Shadow(
  x: 0,
  y: 16,
  blur: 42,
  spread: -20,
  color: 'rgba(23, 59, 34, .35)',
);

const farmsBenefitRootDesign = RootDesign(
  name: 'farms-benefit',
  html: DartStyle(scrollBehavior: ScrollBehavior.smooth),
  body: DartStyle(
    margin: EdgeInsets.all(0),
    background: cream,
    color: ink,
    fontFamily: FontFamily.systemSans,
  ),
  all: DartStyle(boxSizing: BoxSizing.borderBox),
  links: DartStyle(color: green),
);

const navOuterStyle = DartStyle(
  position: Position.sticky,
  top: 0,
  zIndex: 20,
  padding: EdgeInsets.symmetric(vertical: 10),
  background: 'rgba(255, 253, 247, .82)',
  backdropFilter: 'blur(18px)',
  borderBottom: Border(color: 'rgba(223, 233, 214, .72)'),
);

const navInnerStyle = DartStyle(
  display: Display.flex,
  alignItems: AlignItems.center,
  justifyContent: JustifyContent.between,
  gap: 16,
  minHeight: 64,
  padding: EdgeInsets.symmetric(vertical: 8, horizontal: 10),
  radius: 24,
  background: 'rgba(255, 255, 255, .68)',
  border: Border(color: 'rgba(255, 255, 255, .86)'),
  shadow: Shadow(y: 18, blur: 44, spread: -34, color: 'rgba(23, 59, 34, .34)'),
);

const brandLinkStyle = DartStyle(
  display: Display.flex,
  alignItems: AlignItems.center,
  gap: 12,
  minWidth: 0,
  color: ink,
  textDecoration: TextDecorationStyle.none,
);

const brandMarkStyle = DartStyle(
  width: 44,
  height: 44,
  radius: 14,
  background: green,
  color: white,
  display: Display.flex,
  alignItems: AlignItems.center,
  justifyContent: JustifyContent.center,
  shadow: Shadow(y: 10, blur: 24, spread: -14, color: 'rgba(31, 122, 61, .8)'),
);

const brandMarkTextStyle = DartStyle(fontWeight: 900, fontSize: 15);

const brandNameStyle = DartStyle(
  display: Display.block,
  color: ink,
  fontSize: 14,
  lineHeight: 1.05,
  fontWeight: 900,
);

const brandTaglineStyle = DartStyle(
  display: Display.block,
  color: muted,
  fontSize: 12,
  lineHeight: 1.25,
  margin: EdgeInsets.only(top: 3),
);

const navPillStyle = DartStyle(
  display: Display.none,
  alignItems: AlignItems.center,
  gap: 4,
  padding: EdgeInsets.all(5),
  radius: 999,
  background: 'rgba(245, 249, 239, .82)',
  border: Border(color: 'rgba(31, 122, 61, .12)'),
  lg: DartStyle(display: Display.flex),
);

final navLinkStyle = DartStyle(
  display: Display.inlineFlex,
  alignItems: AlignItems.center,
  minHeight: 38,
  padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 13),
  radius: 999,
  color: ink,
  textDecoration: TextDecorationStyle.none,
  fontSize: 13,
  fontWeight: 800,
  transition: StyleTransition.all(milliseconds: 160),
  hover: DartStyle(background: white, color: green),
);

const activeNavLinkStyle = DartStyle(
  display: Display.inlineFlex,
  alignItems: AlignItems.center,
  minHeight: 38,
  padding: EdgeInsets.symmetric(vertical: 9, horizontal: 13),
  radius: 999,
  background: green,
  color: white,
  textDecoration: TextDecorationStyle.none,
  fontSize: 13,
  fontWeight: 900,
  shadow: Shadow(y: 10, blur: 22, spread: -16, color: 'rgba(31, 122, 61, .8)'),
);

const desktopCtaStyle = DartStyle(
  display: Display.none,
  background: green,
  border: Border(color: green),
  radius: 999,
  padding: EdgeInsets.symmetric(vertical: 11, horizontal: 16),
  shadow: Shadow(y: 12, blur: 26, spread: -18, color: 'rgba(31, 122, 61, .7)'),
  hover: DartStyle(background: darkGreen, border: Border(color: darkGreen)),
  md: DartStyle(display: Display.inlineFlex),
);

const mobileMenuStyle = DartStyle(
  display: Display.block,
  position: Position.relative,
  lg: DartStyle(display: Display.none),
);

const mobileMenuPanelStyle = DartStyle(
  position: Position.absolute,
  top: 52,
  right: 0,
  display: Display.grid,
  gap: 6,
  minWidth: 238,
  padding: EdgeInsets.all(10),
  radius: 20,
  background: white,
  shadow: softShadow,
  border: Border(color: line),
);

const menuSummaryStyle = DartStyle(
  display: Display.inlineFlex,
  alignItems: AlignItems.center,
  gap: 10,
  minHeight: 42,
  padding: EdgeInsets.symmetric(vertical: 10, horizontal: 14),
  radius: 999,
  background: softGreen,
  border: Border(color: line),
  cursor: Cursor.pointer,
  color: ink,
  fontSize: 13,
  fontWeight: 900,
);

const menuSummaryIconStyle = DartStyle(
  display: Display.inlineFlex,
  alignItems: AlignItems.center,
  justifyContent: JustifyContent.center,
  width: 22,
  height: 22,
  radius: 999,
  background: white,
  color: green,
  fontWeight: 900,
);

const heroSectionStyle = DartStyle(
  position: Position.relative,
  overflow: Overflow.hidden,
  background:
      'radial-gradient(circle at 12% 18%, rgba(199,155,43,.18), transparent 30%), linear-gradient(135deg, #f8fbef 0%, #e4f1d8 48%, #fffdf7 100%)',
);

const heroBadgeStyle = DartStyle(
  display: Display.inlineFlex,
  alignItems: AlignItems.center,
  padding: EdgeInsets.symmetric(vertical: 9, horizontal: 14),
  radius: 999,
  background: 'rgba(255, 255, 255, .74)',
  border: Border(color: 'rgba(31, 122, 61, .18)'),
  color: green,
  shadow: Shadow(y: 12, blur: 28, spread: -20, color: 'rgba(23, 59, 34, .32)'),
);

const heroTitleStyle = DartStyle(
  margin: EdgeInsets.only(top: 18, bottom: 18),
  color: ink,
  fontSize: 44,
  lineHeight: 1.03,
  fontWeight: 900,
  md: DartStyle(fontSize: 64),
);

const leadStyle = DartStyle(
  maxWidth: 670,
  margin: EdgeInsets.all(0),
  color: muted,
  fontSize: 18,
  lineHeight: 1.75,
);

const primaryButtonStyle = DartStyle(
  background: green,
  border: Border(color: green),
  color: white,
  radius: 999,
  padding: EdgeInsets.symmetric(vertical: 14, horizontal: 22),
  shadow: Shadow(y: 12, blur: 28, spread: -16, color: 'rgba(31, 122, 61, .85)'),
  hover: DartStyle(background: darkGreen, border: Border(color: darkGreen)),
);

const secondaryButtonStyle = DartStyle(
  background: 'transparent',
  border: Border(color: green),
  color: green,
  radius: 999,
  padding: EdgeInsets.symmetric(vertical: 14, horizontal: 22),
  hover: DartStyle(background: white),
);

const heroVisualStyle = DartStyle(
  position: Position.relative,
  padding: EdgeInsets.all(16),
  radius: 30,
  background: 'rgba(255, 255, 255, .68)',
  border: Border(color: 'rgba(255, 255, 255, .9)'),
  shadow: softShadow,
);

const heroImagePanelStyle = DartStyle(
  minHeight: 410,
  display: Display.flex,
  alignItems: AlignItems.end,
  padding: EdgeInsets.all(18),
  radius: 24,
  overflow: Overflow.hidden,
  background:
      'linear-gradient(145deg, rgba(15,75,42,.08), rgba(15,75,42,.3)), repeating-linear-gradient(110deg, #174f2d 0 18px, #1f7a3d 18px 36px, #6ea33a 36px 54px, #d5c979 54px 72px)',
);

const heroImageOverlayStyle = DartStyle(
  display: Display.grid,
  gap: 8,
  maxWidth: 360,
  padding: EdgeInsets.all(20),
  radius: 20,
  background: 'rgba(15, 75, 42, .72)',
  backdropFilter: 'blur(10px)',
  border: Border(color: 'rgba(255,255,255,.18)'),
);

const heroFloatingCardStyle = DartStyle(
  display: Display.grid,
  gap: 8,
  margin: EdgeInsets.only(top: -44, left: 18, right: 18),
  padding: EdgeInsets.all(18),
  radius: 20,
  background: white,
  border: Border(color: line),
  shadow: Shadow(y: 18, blur: 38, spread: -24, color: 'rgba(23, 59, 34, .34)'),
);

const heroMiniLabelStyle = DartStyle(
  color: green,
  fontWeight: 900,
  textTransform: TextTransform.uppercase,
);

const heroStatsStyle = DartStyle(
  display: Display.grid,
  gap: 14,
  gridTemplateColumns: GridTemplateColumns('1fr 1fr 1fr'),
  margin: EdgeInsets.only(top: 14),
  padding: EdgeInsets.all(18),
  radius: 20,
  background: white,
);

const heroProofStyle = DartStyle(
  padding: EdgeInsets.all(16),
  radius: 18,
  background: 'rgba(255,255,255,.58)',
  border: Border(color: 'rgba(31,122,61,.16)'),
);

const valueStripStyle = DartStyle(
  display: Display.grid,
  gap: 18,
  margin: EdgeInsets.only(top: -28),
  padding: EdgeInsets.all(22),
  position: Position.relative,
  zIndex: 2,
  radius: 24,
  background: white,
  border: Border(color: line),
  shadow: Shadow(y: 18, blur: 42, spread: -28, color: 'rgba(23, 59, 34, .36)'),
  md: DartStyle(gridTemplateColumns: GridTemplateColumns('1fr 1fr 1fr')),
);

const pageHeroStyle = DartStyle(
  background: 'linear-gradient(135deg, #f7fbef 0%, #edf6e4 52%, #fffdf7 100%)',
  borderBottom: Border(color: line),
);

const pageTitleStyle = DartStyle(
  maxWidth: 840,
  margin: EdgeInsets.only(top: 14, bottom: 18),
  color: ink,
  fontSize: 38,
  lineHeight: 1.08,
  fontWeight: 900,
  md: DartStyle(fontSize: 54),
);

const eyebrowStyle = DartStyle(
  display: Display.inlineBlock,
  color: green,
  fontSize: 12,
  fontWeight: 900,
  textTransform: TextTransform.uppercase,
);

const sectionTitleStyle = DartStyle(
  margin: EdgeInsets.only(top: 12, bottom: 14),
  color: ink,
  fontSize: 32,
  lineHeight: 1.16,
  fontWeight: 900,
  md: DartStyle(fontSize: 42),
);

const bodyStyle = DartStyle(
  margin: EdgeInsets.all(0),
  color: muted,
  fontSize: 17,
  lineHeight: 1.75,
);

const compactBodyStyle = DartStyle(
  margin: EdgeInsets.all(0),
  color: muted,
  fontSize: 15,
  lineHeight: 1.55,
);

const panelStyle = DartStyle(
  display: Display.grid,
  gap: 16,
  padding: EdgeInsets.all(24),
  radius: 24,
  background: white,
  border: Border(color: line),
  shadow: softShadow,
);

const checkStyle = DartStyle(
  width: 28,
  height: 28,
  display: Display.inlineFlex,
  alignItems: AlignItems.center,
  justifyContent: JustifyContent.center,
  radius: 999,
  background: softGreen,
  color: green,
  fontWeight: 900,
);

final cardStyle = DartStyle(
  minHeight: 228,
  padding: EdgeInsets.all(24),
  radius: 22,
  background: white,
  border: Border(color: line),
  shadow: Shadow(y: 16, blur: 38, spread: -26, color: 'rgba(23, 59, 34, .28)'),
  transition: StyleTransition.all(milliseconds: 180),
  hover: DartStyle(transform: StyleTransform.translateY(-4)),
);

const cardTitleStyle = DartStyle(
  margin: EdgeInsets.only(top: 18, bottom: 10),
  color: ink,
  fontSize: 20,
  lineHeight: 1.25,
);

const cardBodyStyle = DartStyle(
  margin: EdgeInsets.all(0),
  color: muted,
  fontSize: 15,
  lineHeight: 1.65,
);

const contactDetailsStyle = DartStyle(
  display: Display.grid,
  gap: 16,
  margin: EdgeInsets.only(top: 28),
  padding: EdgeInsets.all(22),
  radius: 22,
  background: white,
  border: Border(color: line),
);

const contactLabelStyle = DartStyle(
  display: Display.block,
  margin: EdgeInsets.only(bottom: 4),
  color: green,
  fontWeight: 900,
  textTransform: TextTransform.uppercase,
);

const formPanelStyle = DartStyle(
  padding: EdgeInsets.all(24),
  radius: 24,
  background: white,
  border: Border(color: line),
  shadow: softShadow,
);

const footerTitleStyle = DartStyle(
  margin: EdgeInsets.only(top: 0, bottom: 10),
  color: white,
);

const footerHeadingStyle = DartStyle(
  display: Display.block,
  margin: EdgeInsets.only(bottom: 12),
  color: white,
);

const footerTextStyle = DartStyle(
  margin: EdgeInsets.only(top: 0, bottom: 8),
  color: 'rgba(255, 255, 255, .72)',
  lineHeight: 1.6,
);

const footerLinkStyle = DartStyle(
  display: Display.block,
  margin: EdgeInsets.only(bottom: 8),
  color: 'rgba(255, 255, 255, .76)',
  textDecoration: TextDecorationStyle.none,
  hover: DartStyle(color: white),
);
