import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

// ------------------ Konfigurasi awal (diset agar mirip kode Python) ------------------
String unitKerja = "Citorek Timur";
String alamatDesa = "Jl. Raya Cipanas – Warung Banten KM.032 Kp. Cileler RT.001 RW.001\n"
    "Desa Citorek Timur, Kecamatan Cibeber, Kabupaten Lebak – Banten 42394";
String jabatan = "Kepala Desa";
String namaPejabat = "H. DADANG";
String instansi = "Pemerintahan Desa";
String logoAsset = "assets/images/lebak.png";

// ------------------ Model ------------------
enum FormType { masyarakat, undangan }

class SuratItem {
  final String filename;
  final DateTime createdAt;
  final String path;
  final FormType type;
  SuratItem({
    required this.filename,
    required this.createdAt,
    required this.path,
    required this.type,
  });
}

// ------------------ Helpers ------------------
String toRoman(int number) {
  const romans = {
    1: 'I', 2: 'II', 3: 'III', 4: 'IV', 5: 'V',
    6: 'VI', 7: 'VII', 8: 'VIII', 9: 'IX', 10: 'X',
    11: 'XI', 12: 'XII'
  };
  return romans[number] ?? number.toString();
}

String hashNomorSurat(String nomor) {
  // 32 chars (setengah SHA256)
  return base64Url.encode(nomor.codeUnits).substring(0, 16) +
      base64Url.encode(nomor.runes.toList()).substring(0, 16);
}

String indoDate(DateTime dt) {
  final months = [
    'Januari','Februari','Maret','April','Mei','Juni',
    'Juli','Agustus','September','Oktober','November','Desember'
  ];
  return "${dt.day} ${months[dt.month-1]} ${dt.year}";
}

String indoDay(DateTime dt) {
  const days = ['Senin','Selasa','Rabu','Kamis','Jumat','Sabtu','Minggu'];
  return days[(dt.weekday + 6) % 7];
}

// ------------------ Mulai Aplikasi ------------------
void main() {
  Intl.defaultLocale = 'id_ID';
  runApp(const SuratApp());
}

class SuratApp extends StatelessWidget {
  const SuratApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Surat Desa',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF833AB4)), // Instagram-ish
        textTheme: GoogleFonts.interTextTheme(),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

// ------------------ UI mirip WhatsApp Business + warna Instagram ------------------
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final List<SuratItem> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final dir = await _outputDir();
    final list = <SuratItem>[];
    for (var f in dir.listSync().whereType<File>().where((f) => f.path.endsWith(".pdf"))) {
      final stat = await f.stat();
      list.add(SuratItem(
        filename: f.uri.pathSegments.last,
        createdAt: stat.modified,
        path: f.path,
        type: f.uri.pathSegments.last.toLowerCase().contains("undangan")
            ? FormType.undangan
            : FormType.masyarakat,
      ));
    }
    list.sort((a,b)=>b.createdAt.compareTo(a.createdAt));
    setState(() {
      _items
        ..clear()
        ..addAll(list);
      _loading = false;
    });
  }

  Future<Directory> _outputDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final out = Directory("${appDir.path}/hasil_surat");
    if (!out.existsSync()) out.createSync(recursive: true);
    return out;
  }

  void _openForm(FormType type) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => FormPage(type: type),
    )).then((_) => _loadSaved());
  }

  PreferredSizeWidget _gradientAppBar() {
    return AppBar(
      elevation: 0,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF833AB4), Color(0xFFF77737), Color(0xFFE1306C)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
      title: const Text("Surat Desa"),
      centerTitle: false,
      actions: [
        IconButton(
          onPressed: ()=>_openForm(FormType.masyarakat),
          icon: const Icon(Icons.note_add_outlined),
          tooltip: "Surat Pengajuan Masyarakat",
        ),
        IconButton(
          onPressed: ()=>_openForm(FormType.undangan),
          icon: const Icon(Icons.mail_outline),
          tooltip: "Surat Undangan",
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _gradientAppBar(),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? const Center(child: Text("Belum ada surat. Tap + untuk membuat."))
              : ListView.builder(
                  itemCount: _items.length,
                  itemBuilder: (ctx, i) {
                    final it = _items[i];
                    return ListTile(
                      leading: CircleAvatar(
                        child: Icon(it.type == FormType.undangan ? Icons.mail : Icons.description),
                      ),
                      title: Text(it.filename, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(DateFormat('dd MMM yyyy, HH:mm').format(it.createdAt)),
                      trailing: PopupMenuButton<String>(
                        onSelected: (v) async {
                          if (v == 'open') {
                            await OpenFilex.open(it.path);
                          } else if (v == 'share') {
                            await Share.shareXFiles([XFile(it.path)], text: it.filename);
                          }
                        },
                        itemBuilder: (ctx)=>[
                          const PopupMenuItem(value:'open', child: Text('Buka')),
                          const PopupMenuItem(value:'share', child: Text('Bagikan/Print')),
                        ],
                      ),
                      onTap: () => OpenFilex.open(it.path),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: ()=>_openForm(FormType.masyarakat),
        label: const Text("Buat Surat"),
        icon: const Icon(Icons.add),
      ),
    );
  }
}

// ------------------ Halaman Form ------------------
class FormPage extends StatefulWidget {
  final FormType type;
  const FormPage({super.key, required this.type});

  @override
  State<FormPage> createState() => _FormPageState();
}

class _FormPageState extends State<FormPage> {
  final _formKey = GlobalKey<FormState>();
  // masyarakat
  final judulCtl = TextEditingController(text: "SURAT KETERANGAN");
  final nomorCtl = TextEditingController();
  final namaCtl = TextEditingController();
  final tempatCtl = TextEditingController();
  final tglCtl = TextEditingController(); // dd-mm-yyyy
  final nikCtl = TextEditingController();
  final alamatCtl = TextEditingController();
  final agamaCtl = TextEditingController();
  final pekerjaanCtl = TextEditingController();
  final isiCtl = TextEditingController();

  // undangan
  final sifatCtl = TextEditingController();
  final lampiranCtl = TextEditingController();
  final halCtl = TextEditingController(text: "Undangan");
  final undanganNamaCtl = TextEditingController();
  final suratDariCtl = TextEditingController();
  final nomorLanjutanCtl = TextEditingController();
  final tentangCtl = TextEditingController();
  final hariCtl = TextEditingController();
  final tanggalAcaraCtl = TextEditingController();
  final waktuCtl = TextEditingController();
  final tempatAcaraCtl = TextEditingController();
  final catatanCtl = TextEditingController();
  final tembusanCtl = TextEditingController();

  bool showQr = true;

  @override
  Widget build(BuildContext context) {
    final isMasy = widget.type == FormType.masyarakat;
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF833AB4), Color(0xFFF77737), Color(0xFFE1306C)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: Text(isMasy ? "Surat Pengajuan Masyarakat" : "Surat Undangan"),
        actions: [
          IconButton(
            onPressed: () => setState(()=> showQr = !showQr),
            icon: Icon(showQr ? Icons.qr_code_2 : Icons.qr_code_2_outlined),
            tooltip: "Tampilkan QR",
          )
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (isMasy) ..._masyarakatFields() else ..._undanganFields(),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _savePdf,
              icon: const Icon(Icons.save),
              label: const Text("Simpan sebagai PDF"),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _masyarakatFields() {
    return [
      _ti("Judul Surat", judulCtl, required: true),
      _ti("Nomor Surat", nomorCtl, required: true),
      _ti("Nama Lengkap", namaCtl, required: true),
      _ti("Tempat Lahir", tempatCtl, required: true),
      _ti("Tanggal Lahir (DD-MM-YYYY)", tglCtl, required: true,
          validator: (v){ final r=RegExp(r'^\d{2}-\d{2}-\d{4}$'); return r.hasMatch(v??"")?null:"Gunakan format DD-MM-YYYY"; }),
      _ti("NIK (16 digit)", nikCtl, required: true,
          validator: (v){ final r=RegExp(r'^\d{16}$'); return r.hasMatch(v??"")?null:"NIK harus 16 digit"; }),
      _ti("Alamat", alamatCtl, required: true, maxLines: 2),
      _ti("Agama", agamaCtl, required: true),
      _ti("Pekerjaan", pekerjaanCtl, required: true),
      _ti("Isi/Keperluan Surat", isiCtl, required: true, maxLines: 3),
      SwitchListTile(
        value: showQr,
        onChanged: (v)=>setState(()=>showQr=v),
        title: const Text("Tampilkan QR Code pada Tanda Tangan"),
      ),
    ];
  }

  List<Widget> _undanganFields() {
    return [
      _ti("Nomor Surat", nomorCtl, required: true),
      _ti("Sifat", sifatCtl, required: true),
      _ti("Lampiran", lampiranCtl, required: true),
      _ti("Hal", halCtl, required: true),
      _ti("Yth. Sdr/Sdri.", undanganNamaCtl, required: true),
      _ti("Surat dari (lanjutan)", suratDariCtl, required: true),
      _ti("Nomor surat (lanjutan)", nomorLanjutanCtl, required: true),
      _ti("Tentang", tentangCtl, required: true),
      _ti("Hari (Acara)", hariCtl, required: true),
      _ti("Tanggal (Acara)", tanggalAcaraCtl, required: true),
      _ti("Waktu", waktuCtl, required: true),
      _ti("Tempat", tempatAcaraCtl, required: true),
      _ti("Catatan", catatanCtl),
      _ti("Daftar Tembusan (pisah baris)", tembusanCtl, maxLines: 3),
      SwitchListTile(
        value: showQr,
        onChanged: (v)=>setState(()=>showQr=v),
        title: const Text("Tampilkan QR Code pada Tanda Tangan"),
      ),
    ];
  }

  Widget _ti(String label, TextEditingController ctl, {bool required=false, int maxLines=1, String? Function(String?)? validator}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: ctl,
        maxLines: maxLines,
        validator: validator ?? (required ? (v)=> (v==null||v.trim().isEmpty) ? "Wajib diisi" : null : null),
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Future<void> _savePdf() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final dir = await getApplicationDocumentsDirectory();
    final outDir = Directory("${dir.path}/hasil_surat");
    if (!outDir.existsSync()) outDir.createSync(recursive: true);

    final now = DateTime.now();
    final roman = toRoman(now.month);
    final nomor = nomorCtl.text.trim();
    final hash = hashNomorSurat(nomor);
    final qrLink = "https://srikandi-arsip.netlify.app/?hash=$hash";

    final pdf = pw.Document();
    final pageTheme = await _pageTheme(FPDFSize.f4);

    if (widget.type == FormType.masyarakat) {
      final judul = judulCtl.text.trim().toUpperCase();
      final fname = "${judul.replaceAll(' ', '_')}_${namaCtl.text.trim().replaceAll(' ', '_')}_${DateFormat('yyyyMMdd_HHmmss').format(now)}.pdf";
      final file = File("${outDir.path}/$fname");
      pdf.addPage(pw.MultiPage(
        pageTheme: pageTheme,
        build: (ctx) => _buildMasyarakat(judul, roman, now, qrLink),
      ));
      await file.writeAsBytes(await pdf.save());
      await _afterSave(file.path);
    } else {
      final nomorSafe = nomor.replaceAll('/', '_');
      final fname = "Undangan_${nomorSafe}_${DateFormat('yyyyMMdd_HHmmss').format(now)}.pdf";
      final file = File("${outDir.path}/$fname");
      pdf.addPage(pw.MultiPage(
        pageTheme: pageTheme,
        build: (ctx) => _buildUndangan(roman, now, qrLink),
      ));
      await file.writeAsBytes(await pdf.save());
      await _afterSave(file.path);
    }
  }

  Future<void> _afterSave(String path) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Disimpan: $path"))
    );
    await Share.shareXFiles([XFile(path)], text: "PDF Surat");
    Navigator.of(context).pop();
  }

  List<pw.Widget> _kop() {
    return [
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Container(
            width: 60, height: 70,
            child: pw.Image(pw.MemoryImage(
              File('assets/images/lebak.png').readAsBytesSync(),
            ), fit: pw.BoxFit.contain),
          ),
          pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Text("PEMERINTAH KABUPATEN LEBAK", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.Text("KECAMATAN CIBEBER", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.Text("DESA ${unitKerja.toUpperCase()}", style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 6),
              pw.Text("Jl. Raya Cipanas – Warung Banten KM.032 Kp. Cileler RT.001 RW.001", style: const pw.TextStyle(fontSize: 8)),
              pw.Text("Desa $unitKerja, Kecamatan Cibeber, Kabupaten Lebak – Banten 42394", style: const pw.TextStyle(fontSize: 8)),
            ],
          ),
          pw.SizedBox(width: 60, height: 70),
        ],
      ),
      pw.SizedBox(height: 4),
      pw.Divider(thickness: 2),
      pw.SizedBox(height: 12),
    ];
  }

  List<pw.Widget> _buildMasyarakat(String judul, String roman, DateTime now, String qrLink) {
    final tgl = indoDate(now);
    return [
      ..._kop(),
      pw.Center(child: pw.Text(judul, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold))),
      pw.SizedBox(height: 8),
      pw.Center(child: pw.Text("Nomor: ${nomorCtl.text.trim()}/$roman/${now.year}")),
      pw.SizedBox(height: 12),
      pw.Text("Yang bertanda tangan di bawah ini $jabatan $unitKerja, Kecamatan Cibeber, Kabupaten Lebak, menerangkan bahwa:"),
      pw.SizedBox(height: 12),
      _kv("Nama Lengkap", namaCtl.text),
      _kv("Tempat/Tanggal Lahir", "${tempatCtl.text}, ${tglCtl.text}"),
      _kv("NIK", nikCtl.text),
      _kv("Alamat", alamatCtl.text),
      _kv("Agama", agamaCtl.text),
      _kv("Pekerjaan", pekerjaanCtl.text),
      pw.SizedBox(height: 12),
      pw.Text("Bahwa orang tersebut benar warga Desa $unitKerja Kecamatan Cibeber, Kabupaten Lebak."),
      pw.SizedBox(height: 8),
      pw.Text(isiCtl.text),
      pw.SizedBox(height: 8),
      pw.Text("Demikian surat ini dibuat dengan sebenarnya untuk dapat dipergunakan sebagaimana mestinya."),
      pw.SizedBox(height: 24),
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.end,
        children: [
          pw.Column(children: [
            pw.Text("$unitKerja, $tgl"),
            pw.SizedBox(height: 8),
            pw.Text("$jabatan $unitKerja"),
            if (showQr) ...[
              pw.SizedBox(height: 8),
              pw.Container(
                width: 80, height: 80,
                child: pw.BarcodeWidget(
                  barcode: pw.Barcode.qrCode(),
                  data: qrLink,
                ),
              ),
            ],
            pw.SizedBox(height: 90),
            pw.Text(namaPejabat),
          ]),
        ],
      ),
    ];
  }

  List<pw.Widget> _buildUndangan(String roman, DateTime now, String qrLink) {
    final tgl = indoDate(now);
    return [
      ..._kop(),
      pw.Align(
        alignment: pw.Alignment.centerLeft,
        child: pw.Text("$unitKerja, $tgl"),
      ),
      pw.SizedBox(height: 16),
      _kv("Nomor", nomorCtl.text),
      _kv("Sifat", sifatCtl.text),
      _kv("Lampiran", lampiranCtl.text),
      _kv("Hal", halCtl.text),
      pw.SizedBox(height: 12),
      pw.Text("Yth. Sdr/Sdri."),
      pw.Padding(padding: const pw.EdgeInsets.only(left: 20), child: pw.Text(undanganNamaCtl.text)),
      pw.Text("di"),
      pw.Padding(padding: const pw.EdgeInsets.only(left: 20), child: pw.Text("Tempat")),
      pw.SizedBox(height: 16),
      pw.Text("Menindaklanjuti Surat dari ${suratDariCtl.text}, nomor surat ${nomorLanjutanCtl.text} tentang ${tentangCtl.text}, yang akan dilaksanakan pada :"),
      pw.SizedBox(height: 8),
      _kv("Hari", hariCtl.text),
      _kv("Tanggal", tanggalAcaraCtl.text),
      _kv("Waktu", waktuCtl.text),
      _kv("Tempat", tempatAcaraCtl.text),
      if (catatanCtl.text.trim().isNotEmpty) ...[
        pw.SizedBox(height: 8),
        pw.Text("Catatan: ${catatanCtl.text}"),
      ],
      pw.SizedBox(height: 16),
      pw.Text("Demikian undangan ini disampaikan, atas perhatian dan kerjasamanya diucapkan terima kasih."),
      pw.SizedBox(height: 24),
      pw.Center(child: pw.Column(children: [
        pw.Text("Ditetapkan di $unitKerja"),
        pw.Text("Pada ${indoDay(now)}, ${indoDate(now)}"),
        pw.SizedBox(height: 8),
        pw.Text("$jabatan $unitKerja"),
        if (showQr) ...[
          pw.SizedBox(height: 8),
          pw.Container(
            width: 80, height: 80,
            child: pw.BarcodeWidget(
              barcode: pw.Barcode.qrCode(),
              data: qrLink,
            ),
          ),
        ],
        pw.SizedBox(height: 90),
        pw.Text(namaPejabat),
      ])),
      pw.SizedBox(height: 16),
      if (tembusanCtl.text.trim().isNotEmpty) ...[
        pw.Text("Tembusan :"),
        pw.SizedBox(height: 6),
        for (var i=0; i<tembusanCtl.text.split('\n').length; i++)
          pw.Text("${i+1}. ${tembusanCtl.text.split('\n')[i]}"),
      ],
    ];
  }

  pw.Widget _kv(String k, String v) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(width: 180, child: pw.Text(k)),
          pw.Text(": "),
          pw.Expanded(child: pw.Text(v)),
        ],
      ),
    );
  }
}

// ------------------ Helper untuk F4 ------------------
enum FPDFSize { f4 }

extension on FPDFSize {
  PdfPageFormat get pageFormat {
    // F4 = 8.5in x 13in
    const inch = 72.0;
    return const PdfPageFormat(8.5 * inch, 13 * inch,
      marginAll: inch * 0.5
    );
  }
}

Future<pw.PageTheme> _pageTheme(FPDFSize size) async {
  return pw.PageTheme(
    pageFormat: size.pageFormat,
    theme: pw.ThemeData.withFont(base: await PdfGoogleFonts.robotoRegular(), bold: await PdfGoogleFonts.robotoBold()),
  );
}
