import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID', null);
  runApp(const KlolaApp());
}

class KlolaApp extends StatelessWidget {
  const KlolaApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Klola',
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFF8F9FA),
        primaryColor: const Color(0xFF0F4C81),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F4C81),
          primary: const Color(0xFF0F4C81),
          secondary: const Color(0xFF1EA896),
        ),
        useMaterial3: true,
      ),
      home: const DashboardScreen(),
    );
  }
}

class RibuanInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue.copyWith(text: '');
    String hanyaAngka = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (hanyaAngka.isEmpty) return newValue.copyWith(text: '');
    int? nilaiInt = int.tryParse(hanyaAngka);
    if (nilaiInt == null) return oldValue;
    final formatter = NumberFormat('#,###', 'id_ID');
    String teksBaru = formatter.format(nilaiInt);
    return newValue.copyWith(
      text: teksBaru,
      selection: TextSelection.collapsed(offset: teksBaru.length),
    );
  }
}

class KategoriConfig {
  final String nama;
  final IconData ikon;
  final Color warna;

  KategoriConfig({required this.nama, required this.ikon, required this.warna});
}

final Map<String, KategoriConfig> daftarKategori = {
  'Makanan & Minuman': KategoriConfig(
      nama: 'Makanan & Minuman',
      ikon: Icons.fastfood_outlined,
      warna: Colors.orange.shade700),
  'Belanja & Kebutuhan': KategoriConfig(
      nama: 'Belanja & Kebutuhan',
      ikon: Icons.shopping_bag_outlined,
      warna: Colors.blue.shade700),
  'Edukasi & Kuliah': KategoriConfig(
      nama: 'Edukasi & Kuliah',
      ikon: Icons.school_outlined,
      warna: Colors.purple.shade700),
  'Bisnis & Kerja': KategoriConfig(
      nama: 'Bisnis & Kerja',
      ikon: Icons.work_outline,
      warna: Colors.teal.shade700),
  'Hiburan & Healing': KategoriConfig(
      nama: 'Hiburan & Healing',
      ikon: Icons.theater_comedy_outlined,
      warna: Colors.pink.shade700),
  'Lain-lain': KategoriConfig(
      nama: 'Lain-lain',
      ikon: Icons.help_outline_rounded,
      warna: Colors.grey.shade600),
};

class Transaksi {
  final String id;
  final String keterangan;
  final int nominal;
  final String jenis;
  final String dompet;
  final String kategori;
  final DateTime tanggal;

  Transaksi({
    required this.id,
    required this.keterangan,
    required this.nominal,
    required this.jenis,
    required this.dompet,
    required this.kategori,
    required this.tanggal,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'keterangan': keterangan,
      'nominal': nominal,
      'jenis': jenis,
      'dompet': dompet,
      'kategori': kategori,
      'tanggal': tanggal.toIso8601String(),
    };
  }

  factory Transaksi.fromMap(Map<String, dynamic> map) {
    return Transaksi(
      id: map['id'] ?? '',
      keterangan: map['keterangan'] ?? '',
      nominal: map['nominal'] ?? 0,
      jenis: map['jenis'] ?? 'keluar',
      dompet: map['dompet'] ?? 'Tunai',
      kategori: map['kategori'] ?? 'Lain-lain',
      tanggal:
          DateTime.parse(map['tanggal'] ?? DateTime.now().toIso8601String()),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final NumberFormat _formatter = NumberFormat('#,###', 'id_ID');
  final DateFormat _dateFormatter = DateFormat('dd MMMM', 'id_ID');

  Map<String, int> _saldoDompet = {
    'Tunai': 0,
    'Bank/ATM': 0,
    'E-Wallet': 0,
  };

  List<Transaksi> _daftarTransaksi = [];
  final TextEditingController _keteranganController = TextEditingController();
  final TextEditingController _nominalController = TextEditingController();
  String _dompetTerpilih = 'Tunai';
  String _kategoriTerpilih = 'Makanan & Minuman';
  String _filterJenisTerpilih = 'Semua';
  String _filterKategoriTerpilih = 'Semua Kategori';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _muatDataLokal();
  }

  Future<void> _muatDataLokal() async {
    final prefs = await SharedPreferences.getInstance();
    await Future.delayed(const Duration(milliseconds: 1000));

    setState(() {
      String? saldoJson = prefs.getString('saldo_dompet_key');
      if (saldoJson != null) {
        Map<String, dynamic> decoded = json.decode(saldoJson);
        _saldoDompet = decoded.map((key, value) => MapEntry(key, value as int));
      }

      String? transaksiJson = prefs.getString('daftar_transaksi_key');
      if (transaksiJson != null) {
        List<dynamic> decodedList = json.decode(transaksiJson);
        _daftarTransaksi =
            decodedList.map((item) => Transaksi.fromMap(item)).toList();
      }
      _isLoading = false;
    });
  }

  Future<void> _simpanKeMemoriLokal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saldo_dompet_key', json.encode(_saldoDompet));
    List<Map<String, dynamic>> transaksiMapList =
        _daftarTransaksi.map((t) => t.toMap()).toList();
    await prefs.setString(
        'daftar_transaksi_key', json.encode(transaksiMapList));
  }

  int _hitungTotalSaldo() {
    int total = 0;
    for (var saldo in _saldoDompet.values) {
      total += saldo;
    }
    return total;
  }

  Map<String, int> _hitungPengeluaranPerKategori() {
    Map<String, int> dataKategori = {};
    for (var k in daftarKategori.keys) {
      dataKategori[k] = 0;
    }
    for (var t in _daftarTransaksi) {
      if (t.jenis == 'keluar') {
        dataKategori[t.kategori] = (dataKategori[t.kategori] ?? 0) + t.nominal;
      }
    }
    dataKategori.removeWhere((key, value) => value == 0);
    return dataKategori;
  }

  void _tampilkanDialogSaldoAwal() {
    String tunaiAwal = _formatter.format(_saldoDompet['Tunai']);
    String bankAwal = _formatter.format(_saldoDompet['Bank/ATM']);
    String eWalletAwal = _formatter.format(_saldoDompet['E-Wallet']);

    final TextEditingController tunaiCtrl =
        TextEditingController(text: tunaiAwal)
          ..selection =
              TextSelection(baseOffset: 0, extentOffset: tunaiAwal.length);
    final TextEditingController bankCtrl = TextEditingController(text: bankAwal)
      ..selection = TextSelection(baseOffset: 0, extentOffset: bankAwal.length);
    final TextEditingController eWalletCtrl =
        TextEditingController(text: eWalletAwal)
          ..selection =
              TextSelection(baseOffset: 0, extentOffset: eWalletAwal.length);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFFF8F9FA),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Atur Saldo Awal',
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: Color(0xFF0F4C81))),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Masukkan nominal uang awal kamu saat ini.',
                    style: TextStyle(fontSize: 13, color: Colors.black54)),
                const SizedBox(height: 16),
                TextField(
                  controller: tunaiCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    RibuanInputFormatter()
                  ],
                  autofocus: true,
                  decoration: InputDecoration(
                      labelText: 'Saldo Tunai (Cash)',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none),
                      prefixIcon:
                          const Icon(Icons.money, color: Colors.orange)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: bankCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    RibuanInputFormatter()
                  ],
                  decoration: InputDecoration(
                      labelText: 'Saldo Bank / ATM',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none),
                      prefixIcon:
                          const Icon(Icons.credit_card, color: Colors.blue)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: eWalletCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    RibuanInputFormatter()
                  ],
                  decoration: InputDecoration(
                      labelText: 'Saldo E-Wallet',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none),
                      prefixIcon: const Icon(Icons.account_balance_wallet,
                          color: Colors.purple)),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child:
                    const Text('Batal', style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F4C81),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
              onPressed: () {
                setState(() {
                  _saldoDompet['Tunai'] =
                      int.tryParse(tunaiCtrl.text.replaceAll('.', '')) ?? 0;
                  _saldoDompet['Bank/ATM'] =
                      int.tryParse(bankCtrl.text.replaceAll('.', '')) ?? 0;
                  _saldoDompet['E-Wallet'] =
                      int.tryParse(eWalletCtrl.text.replaceAll('.', '')) ?? 0;
                });
                _simpanKeMemoriLokal();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Saldo awal berhasil diperbarui! 🚀'),
                    behavior: SnackBarBehavior.floating));
              },
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
  }

  void _simpanTransaksi(String jenis) {
    String ket = _keteranganController.text;
    int? nom = int.tryParse(_nominalController.text.replaceAll('.', ''));

    if (ket.isEmpty || nom == null || nom <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Isi data dengan benar ya!'),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
      return;
    }

    if (jenis == 'keluar' && nom > (_saldoDompet[_dompetTerpilih] ?? 0)) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFFF8F9FA),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red),
              SizedBox(width: 8), // DI-FIX: Kembali menggunakan SizedBox asli
              Text('Saldo Tidak Cukup',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(
              'Uang di $_dompetTerpilih tidak cukup untuk melakukan transaksi sebesar Rp ${_formatter.format(nom)}. Silakan isi saldo atau gunakan dompet lain.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Mengerti',
                    style: TextStyle(color: Color(0xFF0F4C81))))
          ],
        ),
      );
      return;
    }

    setState(() {
      if (jenis == 'masuk') {
        _saldoDompet[_dompetTerpilih] =
            (_saldoDompet[_dompetTerpilih] ?? 0) + nom;
      } else {
        _saldoDompet[_dompetTerpilih] =
            (_saldoDompet[_dompetTerpilih] ?? 0) - nom;
      }

      _daftarTransaksi.insert(
        0,
        Transaksi(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          keterangan: ket,
          nominal: nom,
          jenis: jenis,
          dompet: _dompetTerpilih,
          kategori: _kategoriTerpilih,
          tanggal: DateTime.now(),
        ),
      );
    });

    _simpanKeMemoriLokal();

    _keteranganController.clear();
    _nominalController.clear();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Tersimpan permanen di dompet $_dompetTerpilih! ✨'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1EA896),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _hapusTransaksi(Transaksi transaksi) {
    setState(() {
      if (transaksi.jenis == 'masuk') {
        _saldoDompet[transaksi.dompet] =
            (_saldoDompet[transaksi.dompet] ?? 0) - transaksi.nominal;
      } else {
        _saldoDompet[transaksi.dompet] =
            (_saldoDompet[transaksi.dompet] ?? 0) + transaksi.nominal;
      }
      _daftarTransaksi.removeWhere((t) => t.id == transaksi.id);
    });

    _simpanKeMemoriLokal();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text('Transaksi "${transaksi.keterangan}" terhapus! 🗑️'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2)),
    );
  }

  Widget _buildFilterJenisChip(String label) {
    final isSelected = _filterJenisTerpilih == label;
    return GestureDetector(
      onTap: () {
        setState(() {
          _filterJenisTerpilih = label;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0F4C81) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: isSelected ? Colors.transparent : const Color(0xFFEAEAEA)),
        ),
        child: Text(label,
            style: TextStyle(
                color: isSelected ? Colors.white : Colors.black54,
                fontWeight: FontWeight.bold,
                fontSize: 12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    List<Transaksi> transaksiTerfilter = _daftarTransaksi.where((t) {
      bool cocokJenis = true;
      bool cocokKategori = true;

      if (_filterJenisTerpilih == 'Uang Masuk')
        cocokJenis = (t.jenis == 'masuk');
      if (_filterJenisTerpilih == 'Uang Keluar')
        cocokJenis = (t.jenis == 'keluar');

      if (_filterKategoriTerpilih != 'Semua Kategori')
        cocokKategori = (t.kategori == _filterKategoriTerpilih);

      return cocokJenis && cocokKategori;
    }).toList();

    Map<String, int> dataGrafik = _hitungPengeluaranPerKategori();
    int totalPengeluaranGrafik =
        dataGrafik.values.fold(0, (sum, item) => sum + item);

    List<MapEntry<String, int>> dataGrafikTerurut = dataGrafik.entries.toList();
    dataGrafikTerurut.sort((b, a) => a.value.compareTo(b.value));

    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F4C81),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('klola.',
                  style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      fontSize: 52,
                      letterSpacing: -1.5)),
              const SizedBox(height: 20),
              const SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2.5)),
              const SizedBox(height: 35),
              Text('Memuat catatan keuanganmu...',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 12,
                      letterSpacing: 0.5)),
            ],
          ),
        ),
      );
    }

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('klola.',
              style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF111111),
                  fontSize: 24,
                  letterSpacing: -0.5)),
          backgroundColor: const Color(0xFFF8F9FA),
          elevation: 0,
          centerTitle: false,
          bottom: const TabBar(
            labelColor: Color(0xFF0F4C81),
            unselectedLabelColor: Colors.black38,
            indicatorColor: Color(0xFF0F4C81),
            indicatorSize: TabBarIndicatorSize.label,
            indicatorWeight: 3,
            dividerColor: Colors.transparent,
            labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            tabs: [
              Tab(text: 'Overview'),
              Tab(text: 'Riwayat'),
              Tab(text: 'Analisis'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // --- TAB 1: OVERVIEW ---
            SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: const LinearGradient(
                          colors: [Color(0xFF0F4C81), Color(0xFF1D639B)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Total Kekayaan Kamu',
                            style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                fontWeight: FontWeight.w500)),
                        const SizedBox(height: 6),
                        Text('Rp ${_formatter.format(_hitungTotalSaldo())}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 30,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.5)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Dompet Saya',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF222222))),
                      IconButton(
                          onPressed: _tampilkanDialogSaldoAwal,
                          icon: const Icon(Icons.settings_outlined,
                              color: Color(0xFF0F4C81), size: 20),
                          tooltip: 'Atur Saldo Awal'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 95,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: _saldoDompet.entries.map((entry) {
                        return Container(
                          width: 140,
                          margin: const EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border:
                                  Border.all(color: const Color(0xFFEAEAEA))),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(entry.key,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black45,
                                        fontSize: 12)),
                                const SizedBox(height: 6),
                                Text('Rp ${_formatter.format(entry.value)}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: Color(0xFF0F4C81)),
                                    overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 28),
                  const Text('Catat Aktivitas Baru',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF222222))),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: _dompetTerpilih,
                    decoration: InputDecoration(
                        labelText: 'Pilih Sumber Dompet',
                        labelStyle: const TextStyle(
                            color: Colors.black54, fontSize: 13),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none),
                        prefixIcon: const Icon(
                            Icons.account_balance_wallet_outlined,
                            color: Color(0xFF0F4C81),
                            size: 20)),
                    items: _saldoDompet.keys
                        .map((String value) => DropdownMenuItem<String>(
                            value: value,
                            child: Text(value,
                                style: const TextStyle(fontSize: 13))))
                        .toList(),
                    onChanged: (newValue) {
                      setState(() {
                        _dompetTerpilih = newValue!;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: _kategoriTerpilih,
                    decoration: InputDecoration(
                        labelText: 'Pilih Kategori Transaksi',
                        labelStyle: const TextStyle(
                            color: Colors.black54, fontSize: 13),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none),
                        prefixIcon: const Icon(Icons.category_outlined,
                            color: Color(0xFF0F4C81), size: 20)),
                    items: daftarKategori.keys.map((String value) {
                      return DropdownMenuItem<String>(
                          value: value,
                          child: Text(daftarKategori[value]!.nama,
                              style: const TextStyle(fontSize: 13)));
                    }).toList(),
                    onChanged: (newValue) {
                      setState(() {
                        _kategoriTerpilih = newValue!;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _keteranganController,
                    decoration: InputDecoration(
                        labelText: 'Keperluan / Keterangan',
                        labelStyle: const TextStyle(color: Colors.black54),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none),
                        prefixIcon: const Icon(Icons.edit_note_outlined,
                            color: Color(0xFF0F4C81))),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _nominalController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      RibuanInputFormatter()
                    ],
                    decoration: InputDecoration(
                        labelText: 'Jumlah Uang (Rp)',
                        labelStyle: const TextStyle(color: Colors.black54),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none),
                        prefixIcon: const Icon(Icons.payments_outlined,
                            color: Color(0xFF0F4C81))),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 50,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFE8F5E9),
                                foregroundColor: Colors.green.shade800,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14))),
                            onPressed: () => _simpanTransaksi('masuk'),
                            child: const Text('Uang Masuk',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SizedBox(
                          height: 50,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFFEBEE),
                                foregroundColor: Colors.red.shade800,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14))),
                            onPressed: () => _simpanTransaksi('keluar'),
                            child: const Text('Uang Keluar',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // --- TAB 2: RIWAYAT TRANSAKSI ---
            Column(
              children: [
                Container(
                  height: 50,
                  padding: const EdgeInsets.only(top: 10, left: 16, right: 16),
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _buildFilterJenisChip('Semua'),
                      _buildFilterJenisChip('Uang Masuk'),
                      _buildFilterJenisChip('Uang Keluar'),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 8.0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFEAEAEA))),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: _filterKategoriTerpilih,
                        style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 12,
                            fontWeight: FontWeight.bold),
                        items: ['Semua Kategori', ...daftarKategori.keys]
                            .map((String val) {
                          return DropdownMenuItem<String>(
                              value: val, child: Text(val));
                        }).toList(),
                        onChanged: (newVal) {
                          setState(() {
                            _filterKategoriTerpilih = newVal!;
                          });
                        },
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: transaksiTerfilter.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.bubble_chart_outlined,
                                  size: 60, color: Colors.black12),
                              SizedBox(height: 12),
                              Text('Tidak ada riwayat transaksi.',
                                  style: TextStyle(
                                      color: Colors.black38,
                                      fontWeight: FontWeight.w500)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          itemCount: transaksiTerfilter.length,
                          itemBuilder: (context, index) {
                            final item = transaksiTerfilter[index];
                            final isMasuk = item.jenis == 'masuk';
                            final cfg = daftarKategori[item.kategori] ??
                                daftarKategori['Lain-lain']!;

                            return Dismissible(
                              key: Key(item.id),
                              direction: DismissDirection.endToStart,
                              confirmDismiss: (direction) async {
                                return await showDialog(
                                  context: context,
                                  builder: (BuildContext context) {
                                    return AlertDialog(
                                      backgroundColor: const Color(0xFFF8F9FA),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(16)),
                                      title: const Text('Hapus Transaksi',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold)),
                                      content: Text(
                                          'Kamu yakin ingin menghapus catatan "${item.keterangan}" ini?'),
                                      actions: [
                                        TextButton(
                                            onPressed: () =>
                                                Navigator.of(context)
                                                    .pop(false),
                                            child: const Text('Batal',
                                                style: TextStyle(
                                                    color: Colors.grey))),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  const Color(0xFFC62828),
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          8))),
                                          onPressed: () =>
                                              Navigator.of(context).pop(true),
                                          child: const Text('Hapus'),
                                        ),
                                      ],
                                    );
                                  },
                                );
                              },
                              onDismissed: (direction) {
                                _hapusTransaksi(item);
                              },
                              background: Container(
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                padding: const EdgeInsets.only(right: 20),
                                decoration: BoxDecoration(
                                    color: const Color(0xFFC62828),
                                    borderRadius: BorderRadius.circular(16)),
                                alignment: Alignment.centerRight,
                                child: const Icon(Icons.delete_sweep,
                                    color: Colors.white, size: 28),
                              ),
                              child: Container(
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                          color: Colors.black.withOpacity(0.02),
                                          spreadRadius: 1,
                                          blurRadius: 6,
                                          offset: const Offset(0, 2))
                                    ]),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 6),
                                  leading: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                        color: isMasuk
                                            ? const Color(0xFFE8F5E9)
                                            : cfg.warna.withOpacity(0.12),
                                        shape: BoxShape.circle),
                                    child: Icon(
                                        isMasuk ? Icons.south_west : cfg.ikon,
                                        size: 18,
                                        color: isMasuk
                                            ? Colors.green.shade700
                                            : cfg.warna),
                                  ),
                                  title: Text(item.keterangan,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: Color(0xFF2D3142))),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                        "${_dateFormatter.format(item.tanggal)} • ${item.dompet} • ${cfg.nama}",
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: Colors.black38,
                                            fontWeight: FontWeight.w500)),
                                  ),
                                  trailing: Text(
                                    '${isMasuk ? "+" : "-"} Rp ${_formatter.format(item.nominal)}',
                                    style: TextStyle(
                                        color: isMasuk
                                            ? const Color(0xFF2E7D32)
                                            : const Color(0xFFC62828),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),

            // --- TAB 3: ANALISIS PENGELUARAN ---
            SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Analisis Pengeluaran',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF222222))),
                  const SizedBox(height: 6),
                  const Text(
                      'Persentase ke mana saja uang keluar kamu dialokasikan.',
                      style: TextStyle(fontSize: 12, color: Colors.black38)),
                  const SizedBox(height: 20),
                  totalPengeluaranGrafik == 0
                      ? Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              vertical: 60, horizontal: 20),
                          decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border:
                                  Border.all(color: const Color(0xFFEAEAEA))),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.pie_chart_outline_rounded,
                                  size: 50, color: Colors.black12),
                              SizedBox(height: 14),
                              Text('Belum ada data analisis.',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black45,
                                      fontSize: 14)),
                              SizedBox(height: 4),
                              Text(
                                'Diagram akan muncul setelah kamu mencatat transaksi "Uang Keluar".',
                                style: TextStyle(
                                    color: Colors.black38, fontSize: 12),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      : Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border:
                                  Border.all(color: const Color(0xFFEAEAEA))),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  CustomPaint(
                                    size: const Size(100, 100),
                                    painter: DonutChartPainter(
                                        data: dataGrafik,
                                        total: totalPengeluaranGrafik),
                                  ),
                                  const SizedBox(width: 20),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: dataGrafikTerurut.map((entry) {
                                        final persen = (entry.value /
                                                totalPengeluaranGrafik *
                                                100)
                                            .toStringAsFixed(0);
                                        final cfg = daftarKategori[entry.key]!;
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 3.0),
                                          child: Row(
                                            children: [
                                              Container(
                                                  width: 10,
                                                  height: 10,
                                                  decoration: BoxDecoration(
                                                      color: cfg.warna,
                                                      shape: BoxShape.circle)),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                  child: Text(cfg.nama,
                                                      style: TextStyle(
                                                          fontSize: 11,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                          color: Colors.black
                                                              .withOpacity(
                                                                  0.8)),
                                                      overflow: TextOverflow
                                                          .ellipsis)),
                                              Text('$persen%',
                                                  style: const TextStyle(
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Colors.black54)),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  )
                                ],
                              ),
                              const Divider(
                                  height: 30, color: Color(0xFFF1F1F1)),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Total Pengeluaran Bulan Ini:',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.black54,
                                          fontWeight: FontWeight.w500)),
                                  Text(
                                      'Rp ${_formatter.format(totalPengeluaranGrafik)}',
                                      style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFFC62828))),
                                ],
                              ),
                            ],
                          ),
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

class DonutChartPainter extends CustomPainter {
  final Map<String, int> data;
  final int total;

  DonutChartPainter({required this.data, required this.total});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(center: center, radius: radius);

    double startAngle = -pi / 2;

    List<MapEntry<String, int>> dataTerurut = data.entries.toList();
    dataTerurut.sort((b, a) => a.value.compareTo(b.value));

    for (var entry in dataTerurut) {
      final sweepAngle = (entry.value / total) * 2 * pi;
      final cfg = daftarKategori[entry.key]!;

      final paint = Paint()
        ..color = cfg.warna
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
