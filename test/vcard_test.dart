import 'package:flutter_test/flutter_test.dart';
import 'package:lujo_health_mobile/api/models/contact.dart';
import 'package:lujo_health_mobile/features/people/contact_section.dart';

void main() {
  test('la vCard lleva nombre, cargo, empresa, teléfono, correo y web', () {
    final v = buildVCard(
      name: 'María Pérez; Líder',
      username: 'maria_pro',
      contact: const ContactPublic(
        title: 'Líder de equipo',
        intro: 'Escríbeme',
        phone: '+51 999 888 777',
        email: 'maria@test.local',
        website: 'https://maria.test',
        organization: 'Vive Latam',
        links: [ContactLink(kind: 'whatsapp', url: 'https://wa.me/1')],
      ),
    );
    final lines = v.split('\r\n');
    expect(lines.first, 'BEGIN:VCARD');
    expect(lines.last, 'END:VCARD');
    expect(lines, contains('VERSION:3.0'));
    expect(lines, contains('FN:María Pérez\\; Líder'));
    expect(lines, contains('ORG:Vive Latam'));
    expect(lines, contains('TITLE:Líder de equipo'));
    expect(lines, contains('TEL;TYPE=CELL:+51 999 888 777'));
    expect(lines, contains('EMAIL:maria@test.local'));
    expect(lines, contains('URL:https://maria.test'));
    expect(lines, contains('NICKNAME:maria_pro'));
    // Las redes no van en el QR.
    expect(v.contains('wa.me'), isFalse);
  });

  test('sin datos públicos no hay tarjeta', () {
    const c = ContactPublic(
      title: 'Líder',
      intro: '',
      phone: '',
      email: '',
      website: '',
      organization: '',
      links: [],
    );
    expect(c.hasCard, isFalse);
  });
}
