class ConstantErrorMessage {
  const ConstantErrorMessage._();

  static const connectionError = 'Tidak ada koneksi internet. Periksa koneksi Anda lalu coba lagi.';
  static const failureServer = 'Terjadi kesalahan pada server. Silakan coba lagi.';
  static const failureParsing = 'Respons server tidak dikenali.';
  static const failureSocket = 'Koneksi chat terputus.';
  static const rateLimited = 'Terlalu banyak pesan. Tunggu sebentar lalu coba lagi.';
}
