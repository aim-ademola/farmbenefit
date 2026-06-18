import 'package:flint_ui/flint_ui.dart';

import '../data/site_content.dart';
import '../styles/theme.dart';

class SiteLayout extends StatelessComponent {
  SiteLayout({required this.activeComponent});

  final String activeComponent;

  @override
  FlintNode build() {
    return SiteFrame(
      activeComponent: activeComponent,
      children: [
        HeroSection(),
        ValueStripSection(),
        AboutSection(),
        ServicesSection(),
        ProductsSection(),
        WhyChooseUsSection(),
        GallerySection(),
        ContactSection(),
      ],
    );
  }
}

class SiteFrame extends StatelessComponent {
  SiteFrame({required this.activeComponent, required this.children});

  final String activeComponent;
  final List<Object?> children;

  @override
  FlintNode build() {
    return Container(
      dartStyle:
          const DartStyle(minHeight: SizeValue.percent(100), background: cream),
      children: [
        SiteNav(activeComponent: activeComponent),
        ...children,
        SiteFooter(),
      ],
    );
  }
}

class SiteNav extends StatelessComponent {
  SiteNav({required this.activeComponent});

  final String activeComponent;

  @override
  FlintNode build() {
    return Container(
      props: const {'role': 'banner'},
      dartStyle: navOuterStyle,
      child: Shell(
        child: Container(
          dartStyle: navInnerStyle,
          children: [
            Brand(),
            Container(
              props: const {'aria-label': 'Primary navigation'},
              dartStyle: navPillStyle,
              children: [
                for (final item in navItems)
                  NavAnchor(
                      item: item, active: item.component == activeComponent),
              ],
            ),
            Link(
              href: '/contact-us',
              child: 'Get in Touch',
              variant: ButtonVariant.solid,
              dartStyle: desktopCtaStyle,
            ),
            MobileMenu(activeComponent: activeComponent),
          ],
        ),
      ),
    );
  }
}

class Brand extends StatelessComponent {
  @override
  FlintNode build() {
    return Link(
      href: '/',
      dartStyle: brandLinkStyle,
      children: [
        Container(
          dartStyle: brandMarkStyle,
          child: Text.span('FB', dartStyle: brandMarkTextStyle),
        ),
        Container(
          children: [
            Text.strong('FARMS BENEFIT LIMITED', dartStyle: brandNameStyle),
            Text.small(
              'From Farm to Market',
              dartStyle: brandTaglineStyle,
            ),
          ],
        ),
      ],
    );
  }
}

class HeroSection extends StatelessComponent {
  @override
  FlintNode build() {
    return Container(
      props: const {'id': 'home'},
      dartStyle: heroSectionStyle,
      child: Shell(
        child: Container(
          dartStyle: const DartStyle(
            display: Display.grid,
            gap: 42,
            alignItems: AlignItems.center,
            padding: EdgeInsets.symmetric(vertical: 58),
            lg: DartStyle(
              gridTemplateColumns: GridTemplateColumns('1.02fr .98fr'),
              padding: EdgeInsets.symmetric(vertical: 92),
            ),
          ),
          children: [
            Container(
              children: [
                Container(
                  dartStyle: heroBadgeStyle,
                  child: Text.span(
                    'From Farm to Market, We Deliver Value.',
                    dartStyle: const DartStyle(fontWeight: 900),
                  ),
                ),
                Text.h1(
                  'Growing Agriculture. Creating Value. Feeding Communities.',
                  dartStyle: heroTitleStyle,
                ),
                Text.p(
                  'FARMS BENEFIT LIMITED provides quality agricultural products, reliable farm produce supply, and sustainable agribusiness solutions for individuals, businesses, and communities.',
                  dartStyle: leadStyle,
                ),
                Container(
                  dartStyle: const DartStyle(
                    display: Display.flex,
                    flexWrap: FlexWrap.wrap,
                    gap: 14,
                    margin: EdgeInsets.only(top: 30),
                  ),
                  children: [
                    Link(
                      href: '/services',
                      child: 'Our Services',
                      variant: ButtonVariant.solid,
                      dartStyle: primaryButtonStyle,
                    ),
                    Link(
                      href: '/contact-us',
                      child: 'Contact Us',
                      variant: ButtonVariant.outline,
                      dartStyle: secondaryButtonStyle,
                    ),
                  ],
                ),
                Container(
                  dartStyle: const DartStyle(
                    display: Display.grid,
                    gap: 12,
                    margin: EdgeInsets.only(top: 34),
                    md: DartStyle(
                      gridTemplateColumns: GridTemplateColumns('1fr 1fr 1fr'),
                    ),
                  ),
                  children: [
                    HeroProof('Reliable', 'Produce supply'),
                    HeroProof('Sustainable', 'Farm practices'),
                    HeroProof('Business-ready', 'Agribusiness support'),
                  ],
                ),
              ],
            ),
            HeroVisual(),
          ],
        ),
      ),
    );
  }
}

class ValueStripSection extends StatelessComponent {
  @override
  FlintNode build() {
    return Container(
      dartStyle: const DartStyle(background: cream),
      child: Shell(
        child: Container(
          dartStyle: valueStripStyle,
          children: [
            ValueStripItem(
                'Crop & livestock operations', 'Farm-led production'),
            ValueStripItem('Fresh and seasonal produce', 'Market-ready supply'),
            ValueStripItem(
              'Processing and distribution',
              'Value chain support',
            ),
          ],
        ),
      ),
    );
  }
}

class HeroVisual extends StatelessComponent {
  @override
  FlintNode build() {
    return Container(
      dartStyle: heroVisualStyle,
      children: [
        Container(
          dartStyle: heroImagePanelStyle,
          children: [
            Container(
              dartStyle: heroImageOverlayStyle,
              children: [
                Text.small(
                  'Fresh produce supply',
                  dartStyle: const DartStyle(
                    color: 'rgba(255,255,255,.78)',
                    fontWeight: 800,
                  ),
                ),
                Text.strong(
                  'Quality from farm gate to market shelves',
                  dartStyle: const DartStyle(
                    color: white,
                    fontSize: 28,
                    lineHeight: 1.12,
                  ),
                ),
              ],
            ),
          ],
        ),
        Container(
          dartStyle: heroFloatingCardStyle,
          children: [
            Text.small('Supply focus', dartStyle: heroMiniLabelStyle),
            Text.strong('Vegetables, grains, livestock products'),
            Text.p(
              'Coordinated sourcing, handling, and delivery for dependable buyers.',
              dartStyle: compactBodyStyle,
            ),
          ],
        ),
        Container(
          dartStyle: heroStatsStyle,
          children: [
            Metric('7+', 'Service lines'),
            Metric('5', 'Produce categories'),
            Metric('24/7', 'Market focus'),
          ],
        ),
      ],
    );
  }
}

class HeroProof extends StatelessComponent {
  HeroProof(this.title, this.label);

  final String title;
  final String label;

  @override
  FlintNode build() {
    return Container(
      dartStyle: heroProofStyle,
      children: [
        Text.strong(title, dartStyle: const DartStyle(display: Display.block)),
        Text.small(label, dartStyle: const DartStyle(color: muted)),
      ],
    );
  }
}

class ValueStripItem extends StatelessComponent {
  ValueStripItem(this.title, this.label);

  final String title;
  final String label;

  @override
  FlintNode build() {
    return Container(
      dartStyle: const DartStyle(
        display: Display.flex,
        flexDirection: FlexDirection.column,
        gap: 6,
      ),
      children: [
        Text.strong(title, dartStyle: const DartStyle(color: ink)),
        Text.small(
          label,
          dartStyle: const DartStyle(color: muted, fontWeight: 700),
        ),
      ],
    );
  }
}

class PageHero extends StatelessComponent {
  PageHero({
    required this.eyebrow,
    required this.title,
    required this.body,
    this.primaryHref = '/contact-us',
    this.primaryLabel = 'Contact Us',
  });

  final String eyebrow;
  final String title;
  final String body;
  final String primaryHref;
  final String primaryLabel;

  @override
  FlintNode build() {
    return Container(
      props: const {'id': 'page-top'},
      dartStyle: pageHeroStyle,
      child: Shell(
        child: Container(
          dartStyle: const DartStyle(
            maxWidth: 820,
            padding: EdgeInsets.symmetric(vertical: 70),
            md: DartStyle(padding: EdgeInsets.symmetric(vertical: 92)),
          ),
          children: [
            Eyebrow(eyebrow),
            Text.h1(title, dartStyle: pageTitleStyle),
            Text.p(body, dartStyle: leadStyle),
            Container(
              dartStyle: const DartStyle(
                display: Display.flex,
                flexWrap: FlexWrap.wrap,
                gap: 14,
                margin: EdgeInsets.only(top: 28),
              ),
              children: [
                Link(
                  href: primaryHref,
                  child: primaryLabel,
                  variant: ButtonVariant.solid,
                  dartStyle: primaryButtonStyle,
                ),
                Link(
                  href: '/',
                  child: 'Back to Home',
                  variant: ButtonVariant.outline,
                  dartStyle: secondaryButtonStyle,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class AboutSection extends StatelessComponent {
  @override
  FlintNode build() {
    return SiteSection(
      id: 'about',
      child: Shell(
        child: Container(
          dartStyle: const DartStyle(
            display: Display.grid,
            gap: 28,
            alignItems: AlignItems.start,
            lg: DartStyle(gridTemplateColumns: GridTemplateColumns('1fr 1fr')),
          ),
          children: [
            SectionIntro(
              eyebrow: 'About Us',
              title:
                  'A dependable agribusiness partner from production to market.',
              body:
                  'FARMS BENEFIT LIMITED supports food value chains with practical farming, quality farm produce, and business-minded agricultural services.',
            ),
            Container(
              dartStyle: panelStyle,
              children: [
                CheckItem('Quality-focused produce handling'),
                CheckItem('Sustainable farm and supply practices'),
                CheckItem('Business-ready service delivery'),
                CheckItem(
                    'Support for individuals, retailers, and institutions'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ServicesSection extends StatelessComponent {
  @override
  FlintNode build() {
    return CardSection(
      id: 'services',
      tone: SectionTone.soft,
      eyebrow: 'Services',
      title: 'Complete agricultural services for modern food supply.',
      body:
          'We combine field operations, produce handling, advisory support, and distribution into services built for dependable value.',
      cards: services,
      accent: green,
    );
  }
}

class ProductsSection extends StatelessComponent {
  @override
  FlintNode build() {
    return CardSection(
      id: 'products',
      eyebrow: 'Products / Farm Produce',
      title: 'Farm produce selected for freshness, usefulness, and value.',
      body:
          'Our product mix supports daily food needs and commercial supply with clean handling and market-aware availability.',
      cards: products,
      accent: gold,
    );
  }
}

class WhyChooseUsSection extends StatelessComponent {
  @override
  FlintNode build() {
    return SiteSection(
      id: 'why',
      tone: SectionTone.green,
      child: Shell(
        child: Container(
          dartStyle: const DartStyle(
            display: Display.grid,
            gap: 28,
            alignItems: AlignItems.center,
            lg: DartStyle(
                gridTemplateColumns: GridTemplateColumns('.9fr 1.1fr')),
          ),
          children: [
            SectionIntro(
              eyebrow: 'Why Choose Us',
              title:
                  'Built on trust, quality, and practical agricultural value.',
              body:
                  'We understand that agriculture is both a livelihood and a supply chain. Our work is designed to be reliable, transparent, and useful from farm gate to market.',
            ),
            Container(
              dartStyle: const DartStyle(
                display: Display.grid,
                gap: 14,
                md: DartStyle(
                    gridTemplateColumns: GridTemplateColumns('1fr 1fr')),
              ),
              children: [
                Reason('Quality produce standards'),
                Reason('Responsive supply coordination'),
                Reason('Sustainable agribusiness mindset'),
                Reason('Professional communication'),
                Reason('Community and market focus'),
                Reason('Flexible support for different buyers'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class GallerySection extends StatelessComponent {
  @override
  FlintNode build() {
    return SiteSection(
      id: 'gallery',
      child: Shell(
        child: Column(
          children: [
            SectionIntro(
              eyebrow: 'Gallery',
              title: 'A visual snapshot of our agricultural focus.',
              body:
                  'Use this section for real farm, produce, processing, and distribution photos as the business media library grows.',
              centered: true,
            ),
            Container(
              dartStyle: const DartStyle(
                display: Display.grid,
                gap: 16,
                margin: EdgeInsets.only(top: 30),
                md: DartStyle(
                    gridTemplateColumns: GridTemplateColumns('1fr 1fr')),
                lg: DartStyle(
                    gridTemplateColumns: GridTemplateColumns('1fr 1fr 1fr')),
              ),
              children: [
                for (final item in galleryItems) GalleryCard(item),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ContactSection extends StatelessComponent {
  @override
  FlintNode build() {
    return SiteSection(
      id: 'contact',
      tone: SectionTone.soft,
      child: Shell(
        child: Container(
          dartStyle: const DartStyle(
            display: Display.grid,
            gap: 28,
            alignItems: AlignItems.start,
            lg: DartStyle(
                gridTemplateColumns: GridTemplateColumns('.9fr 1.1fr')),
          ),
          children: [
            Column(
              children: [
                SectionIntro(
                  eyebrow: 'Contact Us',
                  title:
                      'Let us discuss your agriculture or farm produce needs.',
                  body:
                      'Reach out for produce supply, consultation, investment support, or distribution conversations.',
                ),
                Container(
                  dartStyle: contactDetailsStyle,
                  children: [
                    ContactLine(
                        'Business Address', 'Your business address here'),
                    ContactLine('Phone', '+234 000 000 0000'),
                    ContactLine('Email', 'info@farmsbenefit.com'),
                    Link(
                      href: 'https://wa.me/2340000000000',
                      target: '_blank',
                      rel: 'noopener',
                      child: 'WhatsApp Us',
                      variant: ButtonVariant.solid,
                      dartStyle: const DartStyle(
                        width: SizeValue('fit-content'),
                        background: '#25d366',
                        border: Border(color: '#25d366'),
                        color: white,
                        radius: 999,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Container(
              dartStyle: formPanelStyle,
              child: Form(
                method: 'post',
                action: '/contact-us',
                children: [
                  TextField(
                    label: 'Name',
                    name: 'name',
                    placeholder: 'Your full name',
                    required: true,
                  ),
                  TextField(
                    label: 'Email',
                    name: 'email',
                    type: 'email',
                    placeholder: 'you@example.com',
                    required: true,
                  ),
                  TextField(
                    label: 'Phone',
                    name: 'phone',
                    type: 'tel',
                    placeholder: '+234 000 000 0000',
                  ),
                  TextArea(
                    label: 'Message',
                    name: 'message',
                    placeholder: 'Tell us how we can help',
                    rows: 5,
                    required: true,
                  ),
                  Button(
                    child: 'Send Message',
                    props: const {'type': 'submit'},
                    dartStyle: primaryButtonStyle,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SiteFooter extends StatelessComponent {
  @override
  FlintNode build() {
    return Container(
      props: const {'role': 'contentinfo'},
      dartStyle: const DartStyle(
        background: ink,
        color: white,
        padding: EdgeInsets.symmetric(vertical: 40),
      ),
      child: Shell(
        child: Container(
          dartStyle: const DartStyle(
            display: Display.grid,
            gap: 28,
            md: DartStyle(
                gridTemplateColumns: GridTemplateColumns('1.2fr .8fr .8fr')),
          ),
          children: [
            Column(
              children: [
                Text.h3('FARMS BENEFIT LIMITED', dartStyle: footerTitleStyle),
                Text.p(
                  'From Farm to Market, We Deliver Value.',
                  dartStyle: footerTextStyle,
                ),
              ],
            ),
            Column(
              children: [
                Text.strong('Quick Links', dartStyle: footerHeadingStyle),
                for (final item in navItems)
                  Link(
                      href: item.href,
                      child: item.label,
                      dartStyle: footerLinkStyle),
              ],
            ),
            Column(
              children: [
                Text.strong('Contact Details', dartStyle: footerHeadingStyle),
                Text.p('Your business address here',
                    dartStyle: footerTextStyle),
                Text.p('+234 000 000 0000', dartStyle: footerTextStyle),
                Text.p('info@farmsbenefit.com', dartStyle: footerTextStyle),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class CardSection extends StatelessComponent {
  CardSection({
    required this.id,
    required this.eyebrow,
    required this.title,
    required this.body,
    required this.cards,
    required this.accent,
    this.tone = SectionTone.light,
  });

  final String id;
  final String eyebrow;
  final String title;
  final String body;
  final List<CardInfo> cards;
  final String accent;
  final SectionTone tone;

  @override
  FlintNode build() {
    return SiteSection(
      id: id,
      tone: tone,
      child: Shell(
        child: Column(
          children: [
            SectionIntro(
                eyebrow: eyebrow, title: title, body: body, centered: true),
            Container(
              dartStyle: const DartStyle(
                display: Display.grid,
                gap: 18,
                margin: EdgeInsets.only(top: 34),
                md: DartStyle(
                    gridTemplateColumns: GridTemplateColumns('1fr 1fr')),
                lg: DartStyle(
                    gridTemplateColumns: GridTemplateColumns('1fr 1fr 1fr')),
              ),
              children: [
                for (final card in cards)
                  InfoCard(
                    title: card.title,
                    body: card.body,
                    marker: card.title.substring(0, 1),
                    accent: accent,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class Shell extends StatelessComponent {
  Shell({required this.child});

  final Object child;

  @override
  FlintNode build() {
    return Container(
      dartStyle: const DartStyle(
        width: SizeValue.full,
        maxWidth: 1180,
        margin: EdgeInsets.symmetric(horizontal: SizeValue.auto),
        padding: EdgeInsets.symmetric(horizontal: 20),
        md: DartStyle(padding: EdgeInsets.symmetric(horizontal: 28)),
      ),
      child: child,
    );
  }
}

class SiteSection extends StatelessComponent {
  SiteSection(
      {required this.child, required this.id, this.tone = SectionTone.light});

  final Object child;
  final String id;
  final SectionTone tone;

  @override
  FlintNode build() {
    return Container(
      props: {'id': id},
      dartStyle: DartStyle(
        padding: const EdgeInsets.symmetric(vertical: 72),
        background: tone.background,
        md: const DartStyle(padding: EdgeInsets.symmetric(vertical: 88)),
      ),
      child: child,
    );
  }
}

class SectionIntro extends StatelessComponent {
  SectionIntro({
    required this.eyebrow,
    required this.title,
    required this.body,
    this.centered = false,
  });

  final String eyebrow;
  final String title;
  final String body;
  final bool centered;

  @override
  FlintNode build() {
    return Container(
      dartStyle: DartStyle(
        maxWidth: centered ? 760 : 620,
        margin: centered
            ? const EdgeInsets.symmetric(horizontal: SizeValue.auto)
            : const EdgeInsets.all(0),
        textAlign: centered ? TextAlign.center : TextAlign.left,
      ),
      children: [
        Eyebrow(eyebrow),
        Text.h2(title, dartStyle: sectionTitleStyle),
        Text.p(body, dartStyle: bodyStyle),
      ],
    );
  }
}

class InfoCard extends StatelessComponent {
  InfoCard({
    required this.title,
    required this.body,
    required this.marker,
    required this.accent,
  });

  final String title;
  final String body;
  final String marker;
  final String accent;

  @override
  FlintNode build() {
    return Container(
      dartStyle: cardStyle,
      children: [
        Container(
          dartStyle: DartStyle(
            width: 44,
            height: 44,
            display: Display.flex,
            alignItems: AlignItems.center,
            justifyContent: JustifyContent.center,
            radius: 14,
            background: accent,
            color: white,
            fontWeight: 800,
          ),
          child: Text.span(marker),
        ),
        Text.h3(title, dartStyle: cardTitleStyle),
        Text.p(body, dartStyle: cardBodyStyle),
      ],
    );
  }
}

class MobileMenu extends StatelessComponent {
  MobileMenu({required this.activeComponent});

  final String activeComponent;

  @override
  FlintNode build() {
    return FlintElement(
      'details',
      props: mergeComponentProps(const {}, dartStyle: mobileMenuStyle),
      children: [
        FlintElement(
          'summary',
          props: mergeComponentProps(
            const {'aria-label': 'Open navigation menu'},
            dartStyle: menuSummaryStyle,
          ),
          children: [
            Text.span('Menu'),
            Text.span('|||', dartStyle: menuSummaryIconStyle),
          ],
        ),
        Container(
          dartStyle: mobileMenuPanelStyle,
          children: [
            for (final item in navItems)
              NavAnchor(item: item, active: item.component == activeComponent),
          ],
        ),
      ],
    );
  }
}

class NavAnchor extends StatelessComponent {
  NavAnchor({required this.item, required this.active});

  final NavItem item;
  final bool active;

  @override
  FlintNode build() {
    return Link(
      href: item.href,
      child: item.label,
      dartStyle: active ? activeNavLinkStyle : navLinkStyle,
    );
  }
}

class Eyebrow extends StatelessComponent {
  Eyebrow(this.value);

  final String value;

  @override
  FlintNode build() => Text.span(value, dartStyle: eyebrowStyle);
}

class ProduceTile extends StatelessComponent {
  ProduceTile(this.top, this.bottom, this.color);

  final String top;
  final String bottom;
  final String color;

  @override
  FlintNode build() {
    return Container(
      dartStyle: DartStyle(
        minHeight: 128,
        padding: const EdgeInsets.all(18),
        display: Display.flex,
        flexDirection: FlexDirection.column,
        justifyContent: JustifyContent.end,
        radius: 20,
        background: color,
        color: white,
      ),
      children: [
        Text.small(top,
            dartStyle: const DartStyle(opacity: .78, fontWeight: 700)),
        Text.strong(bottom,
            dartStyle: const DartStyle(fontSize: 22, lineHeight: 1.1)),
      ],
    );
  }
}

class Metric extends StatelessComponent {
  Metric(this.value, this.label);

  final String value;
  final String label;

  @override
  FlintNode build() {
    return Container(
      children: [
        Text.strong(value,
            dartStyle: const DartStyle(display: Display.block, fontSize: 24)),
        Text.small(label,
            dartStyle: const DartStyle(color: muted, fontWeight: 700)),
      ],
    );
  }
}

class CheckItem extends StatelessComponent {
  CheckItem(this.textValue);

  final String textValue;

  @override
  FlintNode build() {
    return Container(
      dartStyle: const DartStyle(
          display: Display.flex, gap: 12, alignItems: AlignItems.start),
      children: [
        Text.span('+', dartStyle: checkStyle),
        Text.p(textValue, dartStyle: compactBodyStyle),
      ],
    );
  }
}

class Reason extends StatelessComponent {
  Reason(this.value);

  final String value;

  @override
  FlintNode build() {
    return Container(
      dartStyle: const DartStyle(
        padding: EdgeInsets.all(18),
        radius: 18,
        background: 'rgba(255, 255, 255, .78)',
        border: Border(color: 'rgba(255, 255, 255, .72)'),
      ),
      child: Text.strong(value,
          dartStyle: const DartStyle(color: ink, lineHeight: 1.35)),
    );
  }
}

class GalleryCard extends StatelessComponent {
  GalleryCard(this.item);

  final GalleryInfo item;

  @override
  FlintNode build() {
    return Container(
      dartStyle: DartStyle(
        minHeight: 210,
        padding: const EdgeInsets.all(18),
        display: Display.flex,
        alignItems: AlignItems.end,
        radius: 22,
        background:
            'linear-gradient(135deg, ${item.color}, rgba(255, 253, 247, .74))',
        shadow: softShadow,
      ),
      child: Text.strong(
        item.title,
        dartStyle: const DartStyle(color: white, fontSize: 20, lineHeight: 1.2),
      ),
    );
  }
}

class ContactLine extends StatelessComponent {
  ContactLine(this.label, this.value);

  final String label;
  final String value;

  @override
  FlintNode build() {
    return Container(
      children: [
        Text.small(label, dartStyle: contactLabelStyle),
        Text.p(value, dartStyle: compactBodyStyle),
      ],
    );
  }
}

enum SectionTone {
  light(white),
  soft(softGreen),
  green('linear-gradient(135deg, #f5fbef 0%, #e3f0d6 100%)');

  const SectionTone(this.background);

  final String background;
}
