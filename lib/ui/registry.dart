import 'package:flint_ui/flint_ui.dart';

import 'pages/about_page.dart';
import 'pages/contact_page.dart';
import 'pages/gallery_page.dart';
import 'pages/home_page.dart';
import 'pages/products_page.dart';
import 'pages/services_page.dart';
import 'pages/why_choose_us_page.dart';

final farmsBenefitRegistry = PageRegistry({
  'Home': (_) => HomePage(),
  'About': (_) => AboutPage(),
  'Services': (_) => ServicesPage(),
  'Products': (_) => ProductsPage(),
  'WhyChooseUs': (_) => WhyChooseUsPage(),
  'Gallery': (_) => GalleryPage(),
  'Contact': (_) => ContactPage(),
});
