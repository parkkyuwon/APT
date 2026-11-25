import 'package:flutter/material.dart';
import '../../widgets/vehicle_ocr_input.dart';

class AdminOcrTestScreen extends StatelessWidget {
  const AdminOcrTestScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('번호판 OCR 테스트')),
        body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(children: [
              const Text('차량번호와 사진을 비교합니다. 회원 정보를 저장하거나 승인하지 않습니다.'),
              const SizedBox(height: 16),
              VehicleOcrInput(onChanged: (_) {}),
            ])),
      );
}
