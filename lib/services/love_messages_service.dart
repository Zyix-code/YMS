import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

import 'trusted_time_service.dart';

class LoveMessages {
  static final _rand = Random.secure();

  static const _dateKey = "love_date";
  static const _usedKey = "love_used";

  static const List<String> _openers = [
    "{name} 💛",
    "{name} 🤍",
    "{name} ✨",
    "{name},",
    "{name} selam,",
    "{name} merhaba,",
    "{name} bugün aklıma düştün.",
    "{name} bir şey söylemek istedim.",
    "{name} içimden sana yazmak geldi.",
    "{name} şu an seni düşündüm.",
    "{name} yine kalbime geldin.",
    "{name} iyi ki varsın.",
    "{name} nasılsın?",
    "{name} günün nasıl gidiyor?",
    "{name} sana küçük bir mesajım var.",
    "{name} bir an durdum ve seni düşündüm.",
    "{name} şu an yanında olmayı isterdim.",
    "{name} bugün seni merak ettim.",
    "{name} seni hatırlayınca gülümsedim.",
    "{name} iyi ki hayatımdasın.",
    "{name} yine seni seçtim.",
    "{name} kalbim sana selam söyledi.",
    "{name} bugün de aklımdasın.",
    "{name} bir mesaj kadar yakınım sana.",
    "{name} aklıma düştün.",
    "{name} küçük bir selam bırakıyorum.",
    "{name} içimde sana dair güzel bir his var.",
    "{name} yine seni düşündüm.",
    "{name} bugün sana yazmadan duramadım.",
    "{name} içimden geçenleri yazıyorum.",
    "{name} sadece bil istedim.",
    "{name} kalbim seni çağırdı.",
    "{name} küçük ama gerçek bir duygu.",
    "{name} bugün seni biraz daha özledim.",
    "{name} bir nefeslik mesaj bu.",
    "{name} seni anmadan geçemedim.",
    "{name} bugün de kalbimde yerin aynı.",
    "{name} sen varken dünya daha güzel.",
    "{name} varlığın iyi geliyor.",
    "{name} bir şey itiraf edeyim mi?",
  ];

  static const List<String> _cores = [
    "Seni düşünmek bana iyi geliyor.",
    "Bugün aklım sık sık sana gitti.",
    "Bir an bile aklımdan çıkmadın.",
    "Sana yazmak istedim sadece.",
    "Yanında olmayı isterdim.",
    "Seninle her şey daha anlamlı.",
    "Sen varken dünya daha yumuşak.",
    "Varlığın bana huzur veriyor.",
    "Seni hatırlayınca içim ısınıyor.",
    "Seni düşününce yüzüm gülüyor.",
    "Bugün sana biraz daha özlem var içimde.",
    "Senin enerjin beni toparlıyor.",
    "Kalbim hep sana dönüyor.",
    "Sana her gün yeniden değer veriyorum.",
    "Sen benim en güzel alışkanlığımsın.",
    "Sen benim en güzel tesadüfümsün.",
    "Sen benim kalbimin evi gibisin.",
    "Seninle konuşmak bile yetiyor.",
    "Bir mesaj atıp nefes almak istedim.",
    "Sana sarılma isteğiyle doluyum.",
    "Bugün de iyi ki dedim.",
    "Sen yanımdayken her şey daha kolay.",
    "Seninle her şeye varım.",
    "Seni seviyorum. Gerçekten.",
    "Seni seviyorum hem de çok.",
    "İyi misin? Merak ettim.",
    "Bugün kendine iyi davrandın mı?",
    "Yüzün bugün güldü mü?",
    "Biraz dinlen olur mu?",
    "Kendini yorduysan mola ver.",
    "Şu an ne yapıyorsun merak ettim.",
    "Sana yazmadan gün bitsin istemedim.",
    "Sana yazmadan uyuyamadım.",
    "Bugün seninle gurur duydum.",
    "Sana inanıyorum.",
    "Sana güveniyorum.",
    "Sen çok değerlisin.",
    "Sen olduğun gibi harikasın.",
    "Hayatımda olman büyük şans.",
    "İçimde sana dair hep güzel şeyler var.",
    "Bugün seni daha çok düşündüm.",
    "Kalbimde yerin hep sabit.",
    "Varlığın bana güç veriyor.",
    "Sen yanımdayken içim rahat.",
    "Gülüşün aklıma geldi.",
    "Sesini duymak istedim.",
    "Seni görmek iyi gelirdi.",
    "Seni düşünmek bile huzur.",
    "Birlikte olunca her şey daha güzel.",
    "Sen benim için çok kıymetlisin.",
    "Seninle zaman daha anlamlı.",
    "Hayatımda olman büyük mutluluk.",
    "Bugün de seni seçtim.",
    "Kalbim sana ait gibi hissediyor.",
    "Seni tanımak en güzel şeylerden biri.",
    "Sen olunca her şey tamam.",
    "İçimde sana karşı hep sıcaklık var.",
    "Seni her düşündüğümde içim yumuşuyor.",
    "Sen benim huzurumsun.",
    "Seni sevmenin verdiği sakinlik var içimde.",
  ];

  static const List<String> _closers = [
    "Sadece bil istedim.",
    "Bir gülümseme bırakıyorum.",
    "Küçük bir kalp yolladım.",
    "Bugün de seni seçtiğim için.",
    "Buradayım, tamam mı?",
    "Kendine iyi bak lütfen.",
    "Biraz su içmeyi unutma.",
    "Dinlenmeyi ihmal etme.",
    "Güzel uyu, güzel uyan.",
    "Sana güzel rüyalar.",
    "Yanındayım.",
    "Hadi biraz gülümse.",
    "Bir nefes al, geçecek.",
    "Bugün de kalbim sende.",
    "İyi ki varsın.",
    "İyi ki hayatımdasın.",
    "Seni seviyorum.",
    "Her şeyin en güzeli senin olsun.",
    "Sana kocaman bir sarılma.",
    "Sana güzel bir gün diliyorum.",
    "Günün aydınlık geçsin.",
    "Yarın yine yazacağım.",
    "Bugün de sevgiyle.",
    "Bugün de özlemle.",
    "Sen yeter ki iyi ol.",
    "İçimden sana kocaman bir iyi ki yolladım.",
    "Kalbim hep sende.",
    "Seni düşündüğümü unutma.",
    "Bir sarılma gönderiyorum.",
    "Bugün de yanındayım.",
    "Her şey yoluna girecek.",
    "Kendine nazik davran.",
    "Bir kahve molası ver.",
    "Bugün kendini yorma.",
    "Gülümsemeyi unutma.",
    "İç huzurun yüksek olsun.",
    "Yüzün hep gülsün.",
    "İyi hisset diye.",
    "Sen değerlisin.",
    "Bunu bil yeter.",
  ];

  static const List<String> _emojis = [
    "❤️",
    "🤍",
    "💛",
    "💚",
    "💙",
    "💜",
    "🩷",
    "🫶",
    "✨",
    "🌸",
    "🌿",
    "🌙",
    "🦋",
    "🌞",
    "🌈",
    "⭐",
    "🌼",
    "🎀",
    "🧿",
    "💌",
    "🫂",
    "🥰",
    "😊",
    "😌",
  ];
  static List<String> _filteredCores(int hour) {

    if (hour >= 5 && hour < 11) {
      return _cores
          .where((c) =>
              c.contains("gün") ||
              c.contains("iyi") ||
              c.contains("inan") ||
              c.contains("güzel"))
          .toList();
    }

    if (hour >= 18 && hour < 23) {
      return _cores
          .where((c) =>
              c.contains("özlem") ||
              c.contains("sarıl") ||
              c.contains("yanında") ||
              c.contains("sev"))
          .toList();
    }

    if (hour >= 23 || hour < 5) {
      return _cores
          .where((c) =>
              c.contains("kalb") ||
              c.contains("uy") ||
              c.contains("huzur") ||
              c.contains("sev"))
          .toList();
    }

    return _cores;
  }

  static Future<String> randomFor(String name) async {
    final prefs = await SharedPreferences.getInstance();
    final now = await TrustedTimeService.instance.nowOrSync();
    final today = TrustedTimeService.instance.dayKeyTR(now);

    final lastDate = prefs.getString(_dateKey);

    if (lastDate != today) {
      await prefs.setString(_dateKey, today);
      await prefs.remove(_usedKey);
    }

    final used = prefs.getStringList(_usedKey) ?? [];
    final cores = _filteredCores(TrustedTimeService.instance.hourTR(now));

    late int o, c, cl, e;
    String key;

    do {
      o = _rand.nextInt(_openers.length);
      c = _rand.nextInt(cores.length);
      cl = _rand.nextInt(_closers.length);
      e = _rand.nextInt(_emojis.length);

      key = "$o-$c-$cl-$e";
    } while (used.contains(key));

    used.add(key);
    await prefs.setStringList(_usedKey, used);

    final target = name.trim().isEmpty ? 'Sen' : name.trim();

    final message = "${_openers[o].replaceAll('{name}', target)} "
        "${cores[c]} "
        "${_closers[cl]} "
        "${_emojis[e]}";

    return message.replaceAll(RegExp(r"\s+"), " ").trim();
  }
}
