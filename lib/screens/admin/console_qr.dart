import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/qr_payload.dart';
import '../../models/charger_type.dart';
import '../../providers/app_state_provider.dart';

/// [console_qr_k9r2m4x.html] — 슬롯별 QR 생성. 현장 QR은 `/index.html?slot=<slotId>`
/// 형태로 딥링크 역할을 한다.
class ConsoleQr extends StatefulWidget {
  const ConsoleQr({super.key});

  @override
  State<ConsoleQr> createState() => _ConsoleQrState();
}

class _ConsoleQrState extends State<ConsoleQr> {
  String _baseUrl = kAppDefaultBaseUrl;
  late TextEditingController _baseCtrl;

  @override
  void initState() {
    super.initState();
    _baseCtrl = TextEditingController(text: _baseUrl);
  }

  @override
  void dispose() {
    _baseCtrl.dispose();
    super.dispose();
  }

  String _qrPayload(String slotId) =>
      slotQrPayload(slotId, baseUrl: _baseUrl);

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppStateProvider>();
    final s = app.state;
    return Scaffold(
      appBar: AppBar(title: const Text('QR 관리')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('베이스 URL',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _baseCtrl,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: () => setState(() => _baseUrl = _baseCtrl.text.trim()),
                        child: const Text('적용'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          for (final t in chargerTypes) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.name,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (final slot in s.slots[t.id] ?? const [])
                          _qrCard(slot.id),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _qrCard(String slotId) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          QrImageView(
            data: _qrPayload(slotId),
            version: QrVersions.auto,
            size: 128,
            backgroundColor: Colors.white,
          ),
          const SizedBox(height: 6),
          Text(slotId, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          Text(
            _qrPayload(slotId),
            style: const TextStyle(fontSize: 9, color: Colors.black54),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
