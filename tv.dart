import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

enum Brand { samsung, lg, roku }

const brandName = {Brand.samsung: 'Samsung', Brand.lg: 'LG', Brand.roku: 'Roku'};

class Tv {
  final String name, ip;
  final Brand brand;
  Tv(this.name, this.ip, this.brand);
}

// معرّفات التطبيقات لكل ماركة (شاهد وOSN+ غير مدعومين بعد)
const Map<String, Map<Brand, String>> appIds = {
  'youtube': {Brand.roku: '837', Brand.samsung: '111299001912', Brand.lg: 'youtube.leanback.v4'},
  'netflix': {Brand.roku: '12', Brand.samsung: '11101200001', Brand.lg: 'netflix'},
  'prime': {Brand.roku: '13', Brand.samsung: '3201512006785', Brand.lg: 'amazon'},
  'disney': {Brand.roku: '291097', Brand.samsung: '3201901017640', Brand.lg: 'com.disney.disneyplus-prod'},
  'appletv': {Brand.roku: '551012', Brand.samsung: '3201807016597', Brand.lg: 'com.apple.appletv'},
  'spotify': {Brand.roku: '22297', Brand.samsung: '3201606009684', Brand.lg: 'spotify-beehive'},
};

abstract class Ctl {
  Brand get brand;
  Future<void> key(String k);
  Future<void> launch(String id);
  void close();
  Future<void> app(String a) async {
    final id = appIds[a]?[brand];
    if (id == null) throw 'هذا التطبيق غير مدعوم بعد';
    await launch(id);
  }
}

Ctl makeCtl(Tv t) => switch (t.brand) {
      Brand.roku => RokuCtl(t.ip),
      Brand.samsung => SamsungCtl(t.ip),
      Brand.lg => LgCtl(t.ip),
    };

Future<List<Tv>> discover() async {
  final found = <String, String>{};
  final s = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
  s.listen((e) {
    if (e == RawSocketEvent.read) {
      final d = s.receive();
      if (d == null) return;
      final t = utf8.decode(d.data, allowMalformed: true);
      final m = RegExp(r'location:\s*(\S+)', caseSensitive: false).firstMatch(t);
      if (m != null) found[m.group(1)!] = t.toLowerCase();
    }
  });
  for (final st in ['ssdp:all', 'roku:ecp']) {
    s.send(utf8.encode('M-SEARCH * HTTP/1.1\r\nHOST: 239.255.255.250:1900\r\nMAN: "ssdp:discover"\r\nMX: 2\r\nST: $st\r\n\r\n'),
        InternetAddress('239.255.255.250'), 1900);
  }
  await Future.delayed(const Duration(seconds: 4));
  s.close();
  final out = <String, Tv>{};
  for (final e in found.entries) {
    final ip = Uri.parse(e.key).host;
    if (out.containsKey(ip)) continue;
    Brand? b = e.value.contains('roku') ? Brand.roku : null;
    var name = ip;
    try {
      final x = (await http.get(Uri.parse(e.key)).timeout(const Duration(seconds: 2))).body;
      final fn = RegExp(r'<friendlyName>(.*?)</friendlyName>').firstMatch(x);
      if (fn != null) name = fn.group(1)!;
      final l = x.toLowerCase();
      if (b == null) {
        if (l.contains('samsung')) {
          b = Brand.samsung;
        } else if (l.contains('lg electronics') || l.contains('webos')) {
          b = Brand.lg;
        }
      }
    } catch (_) {}
    if (b != null) out[ip] = Tv(name, ip, b);
  }
  return out.values.toList();
}

class RokuCtl extends Ctl {
  final String ip;
  RokuCtl(this.ip);
  @override
  Brand get brand => Brand.roku;
  static const m = {'up': 'Up', 'down': 'Down', 'left': 'Left', 'right': 'Right', 'ok': 'Select', 'back': 'Back', 'home': 'Home', 'menu': 'Info', 'volup': 'VolumeUp', 'voldown': 'VolumeDown', 'mute': 'VolumeMute', 'chup': 'ChannelUp', 'chdown': 'ChannelDown', 'power': 'Power', 'source': 'InputHDMI1'};
  @override
  Future<void> key(String k) async {
    await http.post(Uri.parse('http://$ip:8060/keypress/${m[k] ?? 'Lit_$k'}')).timeout(const Duration(seconds: 4));
  }

  @override
  Future<void> launch(String id) async {
    await http.post(Uri.parse('http://$ip:8060/launch/$id')).timeout(const Duration(seconds: 4));
  }

  @override
  void close() {}
}

class SamsungCtl extends Ctl {
  final String ip;
  WebSocket? ws;
  static String? tok;
  SamsungCtl(this.ip);
  @override
  Brand get brand => Brand.samsung;
  static const m = {'up': 'KEY_UP', 'down': 'KEY_DOWN', 'left': 'KEY_LEFT', 'right': 'KEY_RIGHT', 'ok': 'KEY_ENTER', 'back': 'KEY_RETURN', 'home': 'KEY_HOME', 'menu': 'KEY_MENU', 'volup': 'KEY_VOLUP', 'voldown': 'KEY_VOLDOWN', 'mute': 'KEY_MUTE', 'chup': 'KEY_CHUP', 'chdown': 'KEY_CHDOWN', 'power': 'KEY_POWER', 'source': 'KEY_SOURCE'};
  Future<void> conn() async {
    if (ws != null) return;
    final c = HttpClient()..badCertificateCallback = (a, b, c) => true;
    final n = base64Encode(utf8.encode('Remoty'));
    final w = await WebSocket.connect('wss://$ip:8002/api/v2/channels/samsung.remote.control?name=$n${tok != null ? '&token=$tok' : ''}', customClient: c).timeout(const Duration(seconds: 8));
    ws = w;
    w.listen((d) {
      final t = RegExp(r'"token"\s*:\s*"(\d+)"').firstMatch(d.toString());
      if (t != null) tok = t.group(1);
    }, onDone: () => ws = null, onError: (_) => ws = null);
  }

  @override
  Future<void> key(String k) async {
    await conn();
    ws!.add(jsonEncode({'method': 'ms.remote.control', 'params': {'Cmd': 'Click', 'DataOfCmd': m[k] ?? 'KEY_$k', 'Option': 'false', 'TypeOfRemote': 'SendRemoteKey'}}));
  }

  @override
  Future<void> launch(String id) async {
    await http.post(Uri.parse('http://$ip:8001/api/v2/applications/$id')).timeout(const Duration(seconds: 5));
  }

  @override
  void close() => ws?.close();
}

class LgCtl extends Ctl {
  final String ip;
  WebSocket? ws, px;
  String? ck;
  int n = 0;
  LgCtl(this.ip);
  @override
  Brand get brand => Brand.lg;
  Future<void> until(bool Function() f) async {
    for (var i = 0; i < 150 && !f(); i++) {
      await Future.delayed(const Duration(milliseconds: 200));
    }
    if (!f()) throw 'وافق على الاتصال من شاشة التلفزيون ثم أعد المحاولة';
  }

  void req(String uri, [Map? p, String id = '']) => ws!.add(jsonEncode({'type': 'request', 'id': id.isEmpty ? 'r${n++}' : id, 'uri': uri, 'payload': p ?? {}}));
  Future<void> conn() async {
    if (ws != null) return;
    final w = await WebSocket.connect('ws://$ip:3000').timeout(const Duration(seconds: 6));
    ws = w;
    w.listen((d) async {
      final j = jsonDecode(d as String);
      if (j['type'] == 'registered') ck = j['payload']['client-key'];
      if (j['id'] == 'ptr' && j['payload']?['socketPath'] != null) px = await WebSocket.connect(j['payload']['socketPath']);
    }, onDone: () {
      ws = null;
      px = null;
    }, onError: (_) {
      ws = null;
      px = null;
    });
    w.add(jsonEncode({'type': 'register', 'id': 'reg', 'payload': {'forcePairing': false, 'pairingType': 'PROMPT', 'client-key': ck, 'manifest': {'manifestVersion': 1, 'permissions': ['LAUNCH', 'CONTROL_AUDIO', 'CONTROL_POWER', 'CONTROL_INPUT_TEXT', 'CONTROL_MOUSE_AND_KEYBOARD', 'READ_INSTALLED_APPS']}}}));
    await until(() => ck != null);
    req('ssap://com.webos.service.networkinput/getPointerInputSocket', null, 'ptr');
  }

  @override
  Future<void> key(String k) async {
    await conn();
    if (k == 'power') {
      req('ssap://system/turnOff');
      return;
    }
    if (k == 'source') throw 'زر المصدر غير مدعوم في LG حالياً';
    await until(() => px != null);
    const m = {'up': 'UP', 'down': 'DOWN', 'left': 'LEFT', 'right': 'RIGHT', 'ok': 'ENTER', 'back': 'BACK', 'home': 'HOME', 'menu': 'MENU', 'volup': 'VOLUMEUP', 'voldown': 'VOLUMEDOWN', 'mute': 'MUTE', 'chup': 'CHANNELUP', 'chdown': 'CHANNELDOWN'};
    px!.add('type:button\nname:${m[k] ?? k}\n\n');
  }

  @override
  Future<void> launch(String id) async {
    await conn();
    req('ssap://system.launcher/launch', {'id': id});
  }

  @override
  void close() {
    ws?.close();
    px?.close();
  }
}
