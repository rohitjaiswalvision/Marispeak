import 'package:get/get.dart';

import 'lang/ar.dart';
import 'lang/de.dart';
import 'lang/el.dart';
import 'lang/en.dart';
import 'lang/es.dart';
import 'lang/fr.dart';
import 'lang/hi.dart';
import 'lang/id.dart';
import 'lang/it.dart';
import 'lang/ko.dart';
import 'lang/nl.dart';
import 'lang/ru.dart';
import 'lang/vi.dart';
import 'lang/zh.dart';

class AppLanguages extends Translations {

  @override
  // App supported languages
  Map<String, Map<String, String>> get keys {
    return {
      "en": english,
      "fr": french,
      "de": german,
      "ar": arabic,
      "el": greek,
      "es": spanish,
      "hi": hindi,
      "id": indonesian,
      "it": italian,
      "ko": korean,
      "nl": dutch,
      "ru": russian,
      "vi": vietnamese,
      "zh": chinese,
    };
  }
}
