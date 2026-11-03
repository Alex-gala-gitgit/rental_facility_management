Uri tenantSettlementWhatsAppUri({
  required String tenantName,
  required String tenantPhone,
}) {
  final phone = tenantPhone.replaceAll(RegExp(r'\D'), '');
  if (phone.length < 8) {
    throw const FormatException('A valid tenant WhatsApp number is required.');
  }
  final message = 'Hi $tenantName,\n\n'
      'This is a temporary move-out settlement invoice. The final invoice will be issued after the move-out date, once all final charges have been calculated. '
      'You can view the invoice in your HomeOps360 tenant account: https://homeops360.app\n\n'
      'Please let me know if you have any questions. Thank you.';
  return Uri.parse(
      'https://wa.me/$phone?text=${Uri.encodeComponent(message)}');
}

bool hasTenantWhatsAppNumber(String value) =>
    value.replaceAll(RegExp(r'\D'), '').length >= 8;
