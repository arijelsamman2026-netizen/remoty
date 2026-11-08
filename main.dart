import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'tv.dart';

void main() => runApp(const App());

const bg = Color(0xFF0C0E13), sf = Color(0xFF1B1F28), sf2 = Color(0xFF12151C), ac = Color(0xFF35D0C6), mu = Color(0xFF8B919D);
const Map<String, List<Object>> apps = {
  'youtube': ['YouTube', 0xFFF2F2F2],
  'netflix': ['Netflix', 0xFF000000],
  'shahid': ['شاهد', 0xFFFFFFFF],
  'disney': ['Disney+', 0xFF020B3F],
  'prime': ['Prime Video', 0xFFFFFFFF],
  'spotify': ['Spotify', 0xFF000000],
  'osn': ['OSN+', 0xFF000000],
  'appletv': ['Apple TV', 0xFFFFFFFF],
};
// اختصارات كل ماركة (قابلة للتعديل حسب الريموت الأصلي)
const Map<Brand, List<String>> shortcuts = {
  Brand.samsung: ['netflix', 'prime', 'appletv'],
  Brand.lg: ['netflix', 'prime', 'disney', 'appletv'],
  Brand.roku: ['netflix', 'disney', 'prime', 'youtube'],
};

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'ريموتي',
        builder: (c, w) => Directionality(textDirection: TextDirection.rtl, child: w!),
        theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: bg, colorScheme: const ColorScheme.dark(primary: ac)),
        home: const Home(),
      );
}

void say(BuildContext c, String t) => ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(t), duration: const Duration(seconds: 2)));

class B extends StatefulWidget {
  final Widget c;
  final VoidCallback f;
  final double w, h;
  final bool round;
  const B(this.c, this.f, {this.w = 58, this.h = 58, this.round = true, super.key});
  @override
  State<B> createState() => _B();
}

class _B extends State<B> {
  bool d = false;
  @override
  Widget build(BuildContext x) => GestureDetector(
        onTapDown: (_) {
          setState(() => d = true);
          HapticFeedback.lightImpact();
          widget.f();
        },
        onTapUp: (_) => setState(() => d = false),
        onTapCancel: () => setState(() => d = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 70),
          width: widget.w,
          height: widget.h,
          transform: Matrix4.translationValues(0, d ? 4 : 0, 0),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.round ? 99 : 18),
            gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF2A2F3C), sf2]),
            border: Border.all(color: Colors.white10),
            boxShadow: [BoxShadow(color: Colors.black, offset: Offset(0, d ? 1 : 5)), BoxShadow(color: Colors.black54, blurRadius: d ? 4 : 14, offset: Offset(0, d ? 2 : 8))],
          ),
          child: widget.c,
        ),
      );
}

class Ap extends StatelessWidget {
  final String id;
  final VoidCallback f;
  const Ap(this.id, this.f, {super.key});
  @override
  Widget build(BuildContext c) => GestureDetector(
        onTap: f,
        child: Container(
          width: 58,
          height: 58,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: Color(apps[id]![1] as int), borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 4))]),
          child: Image.asset('assets/logos/$id.png', fit: BoxFit.contain),
        ),
      );
}

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _H();
}

class _H extends State<Home> {
  List<Tv> tvs = [];
  bool scan = false;
  Tv? cur;
  Ctl? ctl;
  @override
  void initState() {
    super.initState();
    find();
  }

  Future<void> find() async {
    setState(() => scan = true);
    try {
      tvs = await discover();
    } catch (_) {}
    if (mounted) setState(() => scan = false);
  }

  void connect(Tv t) {
    ctl?.close();
    cur = t;
    ctl = makeCtl(t);
    setState(() {});
    open();
  }

  void open() {
    if (cur == null) return say(context, 'اختر شاشة أولاً');
    Navigator.push(context, MaterialPageRoute(builder: (_) => Remote(cur!, ctl!)));
  }

  Future<void> launch(String id) async {
    if (ctl == null) return say(context, 'اتصل بشاشة أولاً');
    try {
      await ctl!.app(id);
    } catch (e) {
      if (mounted) say(context, '$e');
    }
  }

  Future<void> manual() async {
    final ip = TextEditingController();
    Brand b = Brand.samsung;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: const Text('إضافة شاشة يدوياً'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: ip, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'عنوان IP مثل 192.168.1.20')),
            const SizedBox(height: 12),
            DropdownButton<Brand>(value: b, isExpanded: true, items: Brand.values.map((e) => DropdownMenuItem(value: e, child: Text(brandName[e]!))).toList(), onChanged: (v) => set(() => b = v!)),
          ]),
          actions: [TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('اتصال'))],
        ),
      ),
    );
    if (ok == true && ip.text.trim().isNotEmpty) connect(Tv('${brandName[b]} (${ip.text.trim()})', ip.text.trim(), b));
  }

  Widget card(Widget child) => Container(width: double.infinity, padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: sf, borderRadius: BorderRadius.circular(22), boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 16, offset: Offset(0, 8))]), child: child);

  Widget sec(String t, String ic, {bool on = false}) => Expanded(
        child: GestureDetector(
          onTap: on ? open : () => say(context, 'قريباً'),
          child: Opacity(
            opacity: on ? 1 : .5,
            child: Container(
              height: 104,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), color: on ? null : sf, gradient: on ? const LinearGradient(colors: [ac, Color(0xFF0A5F6E)]) : null),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(ic, style: const TextStyle(fontSize: 26)), Text(on ? t : '$t · قريباً', style: TextStyle(fontWeight: FontWeight.w700, color: on ? Colors.black : Colors.white))]),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: ListView(padding: const EdgeInsets.fromLTRB(16, 14, 16, 16), children: [
            const Text('ريموتي', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
            const SizedBox(height: 14),
            card(Row(children: [
              CircleAvatar(radius: 5, backgroundColor: cur != null ? const Color(0xFF3DDC97) : mu),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(cur?.name ?? 'لا توجد شاشة متصلة', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)), Text(cur != null ? brandName[cur!.brand]! : 'اختر شاشة من القائمة', style: const TextStyle(color: mu))])),
              if (cur != null) FilledButton(onPressed: open, child: const Text('فتح الريموت')),
            ])),
            const SizedBox(height: 22),
            Row(children: [
              const Text('الشاشات المتاحة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const Spacer(),
              IconButton(onPressed: scan ? null : find, icon: const Icon(Icons.refresh)),
              IconButton(onPressed: manual, icon: const Icon(Icons.add)),
            ]),
            card(scan
                ? const Row(children: [SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)), SizedBox(width: 12), Text('جارٍ البحث على نفس الواي فاي…', style: TextStyle(color: mu))])
                : tvs.isEmpty
                    ? const Text('لم يتم العثور على شاشات. تأكد أن التليفون والشاشة على نفس الشبكة، أو أضف الشاشة يدوياً بزر +', style: TextStyle(color: mu))
                    : Column(children: [
                        for (final t in tvs)
                          ListTile(contentPadding: EdgeInsets.zero, title: Text(t.name), subtitle: Text('${brandName[t.brand]} · ${t.ip}'), trailing: FilledButton.tonal(onPressed: () => connect(t), child: Text(cur?.ip == t.ip ? 'متصل' : 'اتصال'))),
                      ])),
            const SizedBox(height: 22),
            const Text('الأقسام', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Row(children: [sec('التلفزيون', '📺', on: true), const SizedBox(width: 12), sec('التكييف', '❄')]),
            const SizedBox(height: 12),
            Row(children: [sec('الأجهزة الذكية', '💡'), const SizedBox(width: 12), const Expanded(child: SizedBox())]),
          ]),
        ),
        bottomNavigationBar: Container(
          height: 92,
          decoration: const BoxDecoration(color: sf2, border: Border(top: BorderSide(color: Colors.white10))),
          child: SafeArea(child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.all(14), children: [for (final id in apps.keys) Padding(padding: const EdgeInsetsDirectional.only(end: 12), child: Ap(id, () => launch(id)))])),
        ),
      );
}

class Remote extends StatefulWidget {
  final Tv tv;
  final Ctl ctl;
  const Remote(this.tv, this.ctl, {super.key});
  @override
  State<Remote> createState() => _R();
}

class _R extends State<Remote> {
  void k(String key) async {
    try {
      await widget.ctl.key(key);
    } catch (e) {
      if (mounted) say(context, '$e');
    }
  }

  void app(String id) async {
    try {
      await widget.ctl.app(id);
    } catch (e) {
      if (mounted) say(context, '$e');
    }
  }

  Widget ic(IconData i, [Color? c]) => Icon(i, color: c, size: 26);
  Widget rock(String up, String dn, String label) => Container(
        width: 74,
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(40), color: sf2),
        child: Column(children: [B(ic(Icons.add), () => k(up), w: 60, h: 60), Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(label, style: const TextStyle(color: mu, fontSize: 12))), B(ic(Icons.remove), () => k(dn), w: 60, h: 60)]),
      );

  void nums() => showModalBottomSheet(
        context: context,
        backgroundColor: sf,
        builder: (c) => Padding(
          padding: const EdgeInsets.all(20),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Wrap(alignment: WrapAlignment.center, spacing: 14, runSpacing: 14, children: [for (final n in [1, 2, 3, 4, 5, 6, 7, 8, 9, 0]) B(Text('$n', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)), () => k('$n'), w: 72, h: 56, round: false)]),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(backgroundColor: bg, title: Column(children: [Text(widget.tv.name, style: const TextStyle(fontSize: 16)), Text(brandName[widget.tv.brand]!, style: const TextStyle(fontSize: 12, color: mu))]), centerTitle: true),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Container(
              padding: const EdgeInsets.fromLTRB(18, 22, 18, 28),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(44), gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [sf, sf2]), border: Border.all(color: Colors.white10), boxShadow: const [BoxShadow(color: Colors.black, blurRadius: 30, offset: Offset(0, 14))]),
              child: Column(children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [B(ic(Icons.power_settings_new, const Color(0xFFFF5A5F)), () => k('power')), B(ic(Icons.input), () => k('source')), B(ic(Icons.volume_off), () => k('mute'))]),
                const SizedBox(height: 18),
                Wrap(spacing: 10, children: [for (final id in shortcuts[widget.tv.brand]!) Ap(id, () => app(id))]),
                const SizedBox(height: 22),
                Container(
                  width: 232,
                  height: 232,
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: sf2, boxShadow: [BoxShadow(color: Colors.black, blurRadius: 14, offset: Offset(0, 6))]),
                  child: Column(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                    GestureDetector(onTap: () => k('up'), child: const Icon(Icons.keyboard_arrow_up, size: 44, color: mu)),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                      GestureDetector(onTap: () => k('left'), child: const Icon(Icons.keyboard_arrow_left, size: 44, color: mu)),
                      B(const Text('OK', style: TextStyle(fontWeight: FontWeight.w800)), () => k('ok'), w: 76, h: 76),
                      GestureDetector(onTap: () => k('right'), child: const Icon(Icons.keyboard_arrow_right, size: 44, color: mu)),
                    ]),
                    GestureDetector(onTap: () => k('down'), child: const Icon(Icons.keyboard_arrow_down, size: 44, color: mu)),
                  ]),
                ),
                const SizedBox(height: 22),
                Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [B(ic(Icons.arrow_back), () => k('back')), B(ic(Icons.home_outlined), () => k('home')), B(ic(Icons.menu), () => k('menu')), B(ic(Icons.dialpad), nums)]),
                const SizedBox(height: 22),
                Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [rock('volup', 'voldown', 'الصوت'), rock('chup', 'chdown', 'القناة')]),
              ]),
            ),
          ),
        ),
      );
}
