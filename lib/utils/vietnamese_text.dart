// lib/utils/vietnamese_text.dart
//
// Bỏ dấu tiếng Việt để so sánh / sắp xếp. Chỉ dùng cho khoá so sánh — không
// bao giờ hiển thị chuỗi đã bỏ dấu cho người dùng.

const _vietnameseMap = <String, String>{
  'a': 'àáạảãâầấậẩẫăằắặẳẵ',
  'e': 'èéẹẻẽêềếệểễ',
  'i': 'ìíịỉĩ',
  'o': 'òóọỏõôồốộổỗơờớợởỡ',
  'u': 'ùúụủũưừứựửữ',
  'y': 'ỳýỵỷỹ',
  'd': 'đ',
  'A': 'ÀÁẠẢÃÂẦẤẬẨẪĂẰẮẶẲẴ',
  'E': 'ÈÉẸẺẼÊỀẾỆỂỄ',
  'I': 'ÌÍỊỈĨ',
  'O': 'ÒÓỌỎÕÔỒỐỘỔỖƠỜỚỢỞỠ',
  'U': 'ÙÚỤỦŨƯỪỨỰỬỮ',
  'Y': 'ỲÝỴỶỸ',
  'D': 'Đ',
};

final Map<int, String> _lookup = () {
  final m = <int, String>{};
  _vietnameseMap.forEach((plain, accented) {
    for (final r in accented.runes) {
      m[r] = plain;
    }
  });
  return m;
}();

String stripVietnamese(String s) {
  final b = StringBuffer();
  for (final r in s.runes) {
    b.write(_lookup[r] ?? String.fromCharCode(r));
  }
  return b.toString();
}
