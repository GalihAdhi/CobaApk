import 'package:mysql1/mysql1.dart';

class MySQLService {
  static Future<MySqlConnection> getConnection() async {
    return await MySqlConnection.connect(ConnectionSettings(
      host: '50.2.2.2',
      port: 3307,
      user: 'root',
      password: 'kadal12',
      db: 'kebisingan',
    ));
  }

  static Future<List<Map<String, dynamic>>> getKodeTandon() async {
    final conn = await getConnection();
    var results = await conn.query('SELECT kode_tandon, nama_tandon FROM kode_tandon');
    final list = results.map((row) => {
      'kode_tandon': row[0],
      'nama_tandon': row[1],
    }).toList();    await conn.close();
    return list;
  }

  static Future<List<Map<String, dynamic>>> getKodeRuanganKebisingan() async {
    final conn = await getConnection();
    var results = await conn.query('''
      SELECT r.nama_ruang AS nama_ruang, 
             tk.kode_ruang AS kode_ruang
      FROM tingkat_kebisingan AS tk
      JOIN ruangan AS r ON tk.kode_ruang = r.kode_ruang
    ''');

    final list = results
        .map((row) => {
              'nama_ruang': row[0],
              'kode_ruang': row[1],
            })
        .toList();

    await conn.close();
    return list;
  }

  static Future<List<Map<String, dynamic>>> getKodeRuanganSuhu() async {
    final conn = await getConnection();
    var results = await conn.query('''
      SELECT distinct r.nama_ruang AS nama_ruang, 
             s.kode_ruang AS kode_ruang
      FROM suhu s
      JOIN ruangan r ON s.kode_ruang = r.kode_ruang
    ''');

    final list = results
        .map((row) => {
              'nama_ruang': row[0],
              'kode_ruang': row[1],
            })
        .toList();

    await conn.close();
    return list;
  }

  static Future<List<Map<String, dynamic>>> getTingkatKebisingan(String kodeRuang) async {
    final conn = await getConnection();
    var results = await conn.query(
      'SELECT r.nama_ruang as nama_ruang, tk.kode_ruang, tk.dbSound as tingkat_kebisingan, tk.`date-time` as waktu '
      'FROM tingkat_kebisingan as tk '
      'JOIN ruangan as r ON tk.kode_ruang = r.kode_ruang '
      'WHERE tk.kode_ruang = ? ',
      [kodeRuang],
    );
    final list = results.map((row) => {
          'nama_ruang': row['nama_ruang'],
          'kode_ruang': row['kode_ruang'],
          'tingkat_kebisingan': row['tingkat_kebisingan'],
          'waktu': row['waktu'].toString(),
        }).toList();
    await conn.close();
    return list;
  }

  static Future<List<Map<String, dynamic>>> getSuhu(String kodeRuang) async {
    final conn = await getConnection();
    var results = await conn.query(
      'SELECT s.kode_ruang AS kode_ruang, r.nama_ruang AS nama_ruang, s.suhu AS suhu, s.`timestamp` AS waktu '
      'FROM suhu s '
      'JOIN ruangan r ON r.kode_ruang = s.kode_ruang '
      'WHERE s.kode_ruang = ? '
      'ORDER BY s.`timestamp` DESC '
      'LIMIT 1',
      [kodeRuang],
    );
    final list = results.map((row) => {
          'nama_ruang': row['nama_ruang'],
          'kode_ruang': row['kode_ruang'],
          'suhu': row['suhu'],
          'waktu': row['waktu'].toString(),
        }).toList();
    await conn.close();
    return list;
  }

  static Future<List<Map<String, dynamic>>> getParameter() async {
    final conn = await getConnection();
    var results = await conn.query(
      'SELECT *'
      'FROM parameter '
    );
    final list = results.map((row) => {
          'hening': row['hening'],
          'tenang': row['tenang'],
          'bising': row['bising'],
          'hot': row['hot'],
          'cold': row['cold'],
          'tinggi_max': row['tinggi_max'],
          'tinggi_min': row['tinggi_min'],
        }).toList();
    await conn.close();
    return list;
  }

  static Future<List<Map<String, dynamic>>> getParameterTandon(int kodeTandon) async {
    final conn = await getConnection();
    var results = await conn.query(
      'SELECT pt.tinggi_max, pt.tinggi_min, pt.tinggi_tandon '
      'FROM parameter_tandon pt '
      'JOIN kode_tandon kt ON kt.id = pt.tandon_id '
      'WHERE pt.tandon_id = ?',
       [kodeTandon],
    );
    final list = results.map((row) => {
          'tinggimax': row['tinggi_max'],
          'tinggimin': row['tinggi_min'],
          'tinggitandon': row['tinggi_tandon'],
        }).toList();
    await conn.close();
    return list;
  }

  static Future<void> updateParameterTingkatKebisingan(int tenang, int bising) async {
    final conn = await getConnection();

    await conn.query(
      'UPDATE parameter SET tenang = ?, bising = ? WHERE id = 1',
      [tenang, bising],
    );

    await conn.close();
  }

  static Future<void> updateParameterSuhu(int hot, int cold) async {
    final conn = await getConnection();

    await conn.query(
      'UPDATE parameter SET hot = ?, cold = ? WHERE id = 1',
      [hot, cold],
    );

    await conn.close();
  }

  static Future<void> updateParameterWaterLevel(int tinggimax, int tinggimin, int tinggiTandon, int kodeTandon) async {
    final conn = await getConnection();

    await conn.query(
      'UPDATE parameter_tandon SET tinggi_max = ?, tinggi_min = ?, tinggi_tandon = ? WHERE tandon_id = ?',
      [tinggimax, tinggimin, tinggiTandon, kodeTandon],
    );

    await conn.close();
  }

  static Future<Map<String, dynamic>?> login(String username, String password) async {
    final conn = await getConnection();

    var results = await conn.query(
      'SELECT * FROM users WHERE username = ? AND password = ? LIMIT 1',
      [username, password],
    );

    await conn.close();

    if (results.isNotEmpty) {
      final row = results.first;
      return {
        'id': row['id'],
        'username': row['username'],
      };
    }
    return null;
  }

  static Future<void> saveFCMToken(int userId, String token) async {
    final conn = await getConnection();

    await conn.query(
      'insert into fcm_token (user_id, fcm_token) values (?, ?)',
      [userId, token],
    );

    await conn.close();
  }
}

