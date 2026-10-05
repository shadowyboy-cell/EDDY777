import 'package:url_launcher/url_launcher.dart';

class ShoppingService {
  static Uri d4dSearch(String query) => Uri.parse(
        'https://om.d4donline.com/en/oman/muscat/products/34/products?search=${Uri.encodeQueryComponent(query)}',
      );

  static Uri d4dOffers(String query) => Uri.parse(
        'https://om.d4donline.com/en/oman/muscat/offers?search=${Uri.encodeQueryComponent(query)}',
      );

  static Uri clicFlyerSearch(String query) => Uri.parse(
        'https://www.google.com/search?q=${Uri.encodeQueryComponent('site:clicflyer.com $query Oman offers')}',
      );

  static Uri webSearch(String query) => Uri.parse(
        'https://www.google.com/search?q=${Uri.encodeQueryComponent('$query Oman price offers')}',
      );

  static Future<bool> open(Uri uri) => launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
}
