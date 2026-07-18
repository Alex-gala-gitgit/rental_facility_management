import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:excel/excel.dart' as xlsx;
import 'package:image/image.dart' as image_tools;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'cloud/supabase_config.dart';
import 'rentflow/rentflow_app.dart';

import 'cloud/supabase_auth_service.dart';
import 'cloud/meter_reading_service.dart';
import 'cloud/supabase_workspace_service.dart';
import 'file_upload/image_file_picker.dart';
import 'file_upload/document_file_picker.dart';
import 'file_upload/payment_proof_picker.dart';
import 'file_download/file_downloader.dart';
import 'local_ocr/local_meter_ocr.dart';
import 'persistence/persistence_contract.dart';
import 'update/app_update_gate.dart';

const oceanSky = Color(0xFF4EA8EC);
const oceanBlue = Color(0xFF2E86E0);
const oceanDeep = Color(0xFF1C67CF);
const oceanCanvas = Color(0xFFF3F6FA);
const oceanSoft = Color(0xFFE8F2FF);
const oceanText = Color(0xFF0F172A);
const oceanMuted = Color(0xFF64748B);

(Color, Color) facilityCardColors(int index) {
  const palettes = [
    (Color(0xFFEAF4FF), Color(0xFF2563EB)),
    (Color(0xFFEFFAF6), Color(0xFF0F9F7A)),
    (Color(0xFFFFF4E8), Color(0xFFEA7A1A)),
    (Color(0xFFF3ECFF), Color(0xFF7C3AED)),
    (Color(0xFFFFEEF3), Color(0xFFE11D48)),
  ];
  return palettes[index % palettes.length];
}

class MalaysiaAddressOption {
  const MalaysiaAddressOption({
    required this.state,
    required this.city,
    required this.postcode,
  });

  final String state;
  final String city;
  final String postcode;
}

const malaysiaAddressOptions = <MalaysiaAddressOption>[
  MalaysiaAddressOption(state: 'Johor', city: 'Batu Pahat', postcode: '83000'),
  MalaysiaAddressOption(state: 'Johor', city: 'Johor Bahru', postcode: '80000'),
  MalaysiaAddressOption(state: 'Johor', city: 'Johor Bahru', postcode: '81100'),
  MalaysiaAddressOption(state: 'Johor', city: 'Kluang', postcode: '86000'),
  MalaysiaAddressOption(state: 'Johor', city: 'Kota Tinggi', postcode: '81900'),
  MalaysiaAddressOption(state: 'Johor', city: 'Kulai', postcode: '81000'),
  MalaysiaAddressOption(state: 'Johor', city: 'Muar', postcode: '84000'),
  MalaysiaAddressOption(state: 'Johor', city: 'Pontian', postcode: '82000'),
  MalaysiaAddressOption(state: 'Johor', city: 'Segamat', postcode: '85000'),
  MalaysiaAddressOption(state: 'Johor', city: 'Skudai', postcode: '81300'),
  MalaysiaAddressOption(state: 'Kedah', city: 'Alor Setar', postcode: '05000'),
  MalaysiaAddressOption(state: 'Kedah', city: 'Kulim', postcode: '09000'),
  MalaysiaAddressOption(state: 'Kedah', city: 'Langkawi', postcode: '07000'),
  MalaysiaAddressOption(
      state: 'Kedah', city: 'Sungai Petani', postcode: '08000'),
  MalaysiaAddressOption(
      state: 'Kelantan', city: 'Gua Musang', postcode: '18300'),
  MalaysiaAddressOption(
      state: 'Kelantan', city: 'Kota Bharu', postcode: '15000'),
  MalaysiaAddressOption(
      state: 'Kelantan', city: 'Pasir Mas', postcode: '17000'),
  MalaysiaAddressOption(state: 'Kelantan', city: 'Tumpat', postcode: '16200'),
  MalaysiaAddressOption(state: 'Melaka', city: 'Ayer Keroh', postcode: '75450'),
  MalaysiaAddressOption(state: 'Melaka', city: 'Melaka', postcode: '75000'),
  MalaysiaAddressOption(state: 'Melaka', city: 'Melaka', postcode: '75200'),
  MalaysiaAddressOption(
      state: 'Negeri Sembilan', city: 'Nilai', postcode: '71800'),
  MalaysiaAddressOption(
      state: 'Negeri Sembilan', city: 'Port Dickson', postcode: '71000'),
  MalaysiaAddressOption(
      state: 'Negeri Sembilan', city: 'Seremban', postcode: '70000'),
  MalaysiaAddressOption(
      state: 'Negeri Sembilan', city: 'Seremban', postcode: '70300'),
  MalaysiaAddressOption(state: 'Pahang', city: 'Bentong', postcode: '28700'),
  MalaysiaAddressOption(
      state: 'Pahang', city: 'Cameron Highlands', postcode: '39000'),
  MalaysiaAddressOption(state: 'Pahang', city: 'Kuantan', postcode: '25000'),
  MalaysiaAddressOption(state: 'Pahang', city: 'Temerloh', postcode: '28000'),
  MalaysiaAddressOption(state: 'Perak', city: 'Ipoh', postcode: '30000'),
  MalaysiaAddressOption(state: 'Perak', city: 'Ipoh', postcode: '31400'),
  MalaysiaAddressOption(state: 'Perak', city: 'Kampar', postcode: '31900'),
  MalaysiaAddressOption(state: 'Perak', city: 'Lumut', postcode: '32200'),
  MalaysiaAddressOption(state: 'Perak', city: 'Taiping', postcode: '34000'),
  MalaysiaAddressOption(state: 'Perak', city: 'Teluk Intan', postcode: '36000'),
  MalaysiaAddressOption(state: 'Perlis', city: 'Arau', postcode: '02600'),
  MalaysiaAddressOption(state: 'Perlis', city: 'Kangar', postcode: '01000'),
  MalaysiaAddressOption(
      state: 'Pulau Pinang', city: 'Bayan Lepas', postcode: '11900'),
  MalaysiaAddressOption(
      state: 'Pulau Pinang', city: 'Bukit Mertajam', postcode: '14000'),
  MalaysiaAddressOption(
      state: 'Pulau Pinang', city: 'Butterworth', postcode: '12000'),
  MalaysiaAddressOption(
      state: 'Pulau Pinang', city: 'George Town', postcode: '10300'),
  MalaysiaAddressOption(
      state: 'Pulau Pinang', city: 'George Town', postcode: '10450'),
  MalaysiaAddressOption(
      state: 'Pulau Pinang', city: 'Tanjung Bungah', postcode: '11200'),
  MalaysiaAddressOption(state: 'Sabah', city: 'Keningau', postcode: '89000'),
  MalaysiaAddressOption(
      state: 'Sabah', city: 'Kota Kinabalu', postcode: '88000'),
  MalaysiaAddressOption(state: 'Sabah', city: 'Lahad Datu', postcode: '91100'),
  MalaysiaAddressOption(state: 'Sabah', city: 'Sandakan', postcode: '90000'),
  MalaysiaAddressOption(state: 'Sabah', city: 'Tawau', postcode: '91000'),
  MalaysiaAddressOption(state: 'Sarawak', city: 'Bintulu', postcode: '97000'),
  MalaysiaAddressOption(state: 'Sarawak', city: 'Kuching', postcode: '93000'),
  MalaysiaAddressOption(state: 'Sarawak', city: 'Miri', postcode: '98000'),
  MalaysiaAddressOption(state: 'Sarawak', city: 'Sibu', postcode: '96000'),
  MalaysiaAddressOption(state: 'Selangor', city: 'Ampang', postcode: '68000'),
  MalaysiaAddressOption(state: 'Selangor', city: 'Bangi', postcode: '43650'),
  MalaysiaAddressOption(
      state: 'Selangor', city: 'Cyberjaya', postcode: '63000'),
  MalaysiaAddressOption(state: 'Selangor', city: 'Kajang', postcode: '43000'),
  MalaysiaAddressOption(state: 'Selangor', city: 'Klang', postcode: '41000'),
  MalaysiaAddressOption(
      state: 'Selangor', city: 'Kota Damansara', postcode: '47810'),
  MalaysiaAddressOption(state: 'Selangor', city: 'Puchong', postcode: '47100'),
  MalaysiaAddressOption(
      state: 'Selangor', city: 'Petaling Jaya', postcode: '46000'),
  MalaysiaAddressOption(
      state: 'Selangor', city: 'Petaling Jaya', postcode: '47301'),
  MalaysiaAddressOption(
      state: 'Selangor', city: 'Petaling Jaya', postcode: '47800'),
  MalaysiaAddressOption(state: 'Selangor', city: 'Rawang', postcode: '48000'),
  MalaysiaAddressOption(state: 'Selangor', city: 'Sepang', postcode: '43900'),
  MalaysiaAddressOption(
      state: 'Selangor', city: 'Shah Alam', postcode: '40100'),
  MalaysiaAddressOption(
      state: 'Selangor', city: 'Shah Alam', postcode: '40400'),
  MalaysiaAddressOption(
      state: 'Selangor', city: 'Subang Jaya', postcode: '47500'),
  MalaysiaAddressOption(
      state: 'Selangor', city: 'Sungai Buloh', postcode: '47000'),
  MalaysiaAddressOption(state: 'Terengganu', city: 'Dungun', postcode: '23000'),
  MalaysiaAddressOption(
      state: 'Terengganu', city: 'Kemaman', postcode: '24000'),
  MalaysiaAddressOption(
      state: 'Terengganu', city: 'Kuala Terengganu', postcode: '20000'),
  MalaysiaAddressOption(
      state: 'Wilayah Persekutuan Kuala Lumpur',
      city: 'Bukit Bintang',
      postcode: '55100'),
  MalaysiaAddressOption(
      state: 'Wilayah Persekutuan Kuala Lumpur',
      city: 'Cheras',
      postcode: '56000'),
  MalaysiaAddressOption(
      state: 'Wilayah Persekutuan Kuala Lumpur',
      city: 'Kepong',
      postcode: '52100'),
  MalaysiaAddressOption(
      state: 'Wilayah Persekutuan Kuala Lumpur',
      city: 'Kuala Lumpur',
      postcode: '50000'),
  MalaysiaAddressOption(
      state: 'Wilayah Persekutuan Kuala Lumpur',
      city: 'Kuala Lumpur',
      postcode: '50450'),
  MalaysiaAddressOption(
      state: 'Wilayah Persekutuan Kuala Lumpur',
      city: 'Kuala Lumpur',
      postcode: '50480'),
  MalaysiaAddressOption(
      state: 'Wilayah Persekutuan Kuala Lumpur',
      city: 'Mont Kiara',
      postcode: '50480'),
  MalaysiaAddressOption(
      state: 'Wilayah Persekutuan Kuala Lumpur',
      city: 'Setapak',
      postcode: '53300'),
  MalaysiaAddressOption(
      state: 'Wilayah Persekutuan Kuala Lumpur',
      city: 'Wangsa Maju',
      postcode: '53300'),
  MalaysiaAddressOption(
      state: 'Wilayah Persekutuan Labuan', city: 'Labuan', postcode: '87000'),
  MalaysiaAddressOption(
      state: 'Wilayah Persekutuan Putrajaya',
      city: 'Putrajaya',
      postcode: '62000'),
  MalaysiaAddressOption(
      state: 'Wilayah Persekutuan Putrajaya',
      city: 'Putrajaya',
      postcode: '62502'),
  MalaysiaAddressOption(state: 'Johor', city: 'Ayer Hitam', postcode: '86100'),
  MalaysiaAddressOption(
      state: 'Johor', city: 'Bandar Penawar', postcode: '81930'),
  MalaysiaAddressOption(
      state: 'Johor', city: 'Gelang Patah', postcode: '81550'),
  MalaysiaAddressOption(
      state: 'Johor', city: 'Iskandar Puteri', postcode: '79100'),
  MalaysiaAddressOption(state: 'Johor', city: 'Labis', postcode: '85300'),
  MalaysiaAddressOption(state: 'Johor', city: 'Masai', postcode: '81750'),
  MalaysiaAddressOption(state: 'Johor', city: 'Mersing', postcode: '86800'),
  MalaysiaAddressOption(
      state: 'Johor', city: 'Pasir Gudang', postcode: '81700'),
  MalaysiaAddressOption(
      state: 'Johor', city: 'Simpang Renggam', postcode: '86200'),
  MalaysiaAddressOption(state: 'Johor', city: 'Tangkak', postcode: '84900'),
  MalaysiaAddressOption(state: 'Kedah', city: 'Baling', postcode: '09100'),
  MalaysiaAddressOption(state: 'Kedah', city: 'Bedong', postcode: '08100'),
  MalaysiaAddressOption(state: 'Kedah', city: 'Changlun', postcode: '06010'),
  MalaysiaAddressOption(state: 'Kedah', city: 'Gurun', postcode: '08300'),
  MalaysiaAddressOption(state: 'Kedah', city: 'Jitra', postcode: '06000'),
  MalaysiaAddressOption(state: 'Kedah', city: 'Kuala Kedah', postcode: '06600'),
  MalaysiaAddressOption(state: 'Kedah', city: 'Pendang', postcode: '06700'),
  MalaysiaAddressOption(state: 'Kedah', city: 'Sik', postcode: '08200'),
  MalaysiaAddressOption(state: 'Kelantan', city: 'Bachok', postcode: '16300'),
  MalaysiaAddressOption(state: 'Kelantan', city: 'Jeli', postcode: '17600'),
  MalaysiaAddressOption(
      state: 'Kelantan', city: 'Kuala Krai', postcode: '18000'),
  MalaysiaAddressOption(state: 'Kelantan', city: 'Machang', postcode: '18500'),
  MalaysiaAddressOption(
      state: 'Kelantan', city: 'Pasir Puteh', postcode: '16800'),
  MalaysiaAddressOption(
      state: 'Kelantan', city: 'Tanah Merah', postcode: '17500'),
  MalaysiaAddressOption(state: 'Melaka', city: 'Alor Gajah', postcode: '78000'),
  MalaysiaAddressOption(
      state: 'Melaka', city: 'Batu Berendam', postcode: '75350'),
  MalaysiaAddressOption(state: 'Melaka', city: 'Jasin', postcode: '77000'),
  MalaysiaAddressOption(
      state: 'Melaka', city: 'Masjid Tanah', postcode: '78300'),
  MalaysiaAddressOption(state: 'Melaka', city: 'Merlimau', postcode: '77300'),
  MalaysiaAddressOption(
      state: 'Negeri Sembilan', city: 'Bahau', postcode: '72100'),
  MalaysiaAddressOption(
      state: 'Negeri Sembilan', city: 'Kuala Pilah', postcode: '72000'),
  MalaysiaAddressOption(
      state: 'Negeri Sembilan', city: 'Mantin', postcode: '71700'),
  MalaysiaAddressOption(
      state: 'Negeri Sembilan', city: 'Rembau', postcode: '71300'),
  MalaysiaAddressOption(
      state: 'Negeri Sembilan', city: 'Senawang', postcode: '70450'),
  MalaysiaAddressOption(
      state: 'Negeri Sembilan', city: 'Tampin', postcode: '73000'),
  MalaysiaAddressOption(state: 'Pahang', city: 'Jerantut', postcode: '27000'),
  MalaysiaAddressOption(
      state: 'Pahang', city: 'Kuala Lipis', postcode: '27200'),
  MalaysiaAddressOption(state: 'Pahang', city: 'Maran', postcode: '26500'),
  MalaysiaAddressOption(state: 'Pahang', city: 'Mentakab', postcode: '28400'),
  MalaysiaAddressOption(state: 'Pahang', city: 'Pekan', postcode: '26600'),
  MalaysiaAddressOption(state: 'Pahang', city: 'Raub', postcode: '27600'),
  MalaysiaAddressOption(state: 'Pahang', city: 'Rompin', postcode: '26800'),
  MalaysiaAddressOption(state: 'Perak', city: 'Bagan Serai', postcode: '34300'),
  MalaysiaAddressOption(state: 'Perak', city: 'Batu Gajah', postcode: '31000'),
  MalaysiaAddressOption(state: 'Perak', city: 'Bidor', postcode: '35500'),
  MalaysiaAddressOption(state: 'Perak', city: 'Gerik', postcode: '33300'),
  MalaysiaAddressOption(state: 'Perak', city: 'Gopeng', postcode: '31600'),
  MalaysiaAddressOption(
      state: 'Perak', city: 'Kuala Kangsar', postcode: '33000'),
  MalaysiaAddressOption(
      state: 'Perak', city: 'Parit Buntar', postcode: '34200'),
  MalaysiaAddressOption(state: 'Perak', city: 'Sitiawan', postcode: '32000'),
  MalaysiaAddressOption(state: 'Perak', city: 'Slim River', postcode: '35800'),
  MalaysiaAddressOption(
      state: 'Perak', city: 'Tanjung Malim', postcode: '35900'),
  MalaysiaAddressOption(state: 'Perak', city: 'Tapah', postcode: '35000'),
  MalaysiaAddressOption(state: 'Perak', city: 'Tapah Road', postcode: '35400'),
  MalaysiaAddressOption(
      state: 'Pulau Pinang', city: 'Air Itam', postcode: '11500'),
  MalaysiaAddressOption(
      state: 'Pulau Pinang', city: 'Balik Pulau', postcode: '11000'),
  MalaysiaAddressOption(
      state: 'Pulau Pinang', city: 'Gelugor', postcode: '11700'),
  MalaysiaAddressOption(
      state: 'Pulau Pinang', city: 'Jelutong', postcode: '11600'),
  MalaysiaAddressOption(
      state: 'Pulau Pinang', city: 'Nibong Tebal', postcode: '14300'),
  MalaysiaAddressOption(
      state: 'Pulau Pinang', city: 'Perai', postcode: '13600'),
  MalaysiaAddressOption(
      state: 'Pulau Pinang', city: 'Simpang Ampat', postcode: '14100'),
  MalaysiaAddressOption(state: 'Sabah', city: 'Beaufort', postcode: '89800'),
  MalaysiaAddressOption(state: 'Sabah', city: 'Kota Belud', postcode: '89150'),
  MalaysiaAddressOption(state: 'Sabah', city: 'Kudat', postcode: '89050'),
  MalaysiaAddressOption(state: 'Sabah', city: 'Papar', postcode: '89600'),
  MalaysiaAddressOption(state: 'Sabah', city: 'Penampang', postcode: '89500'),
  MalaysiaAddressOption(state: 'Sabah', city: 'Ranau', postcode: '89300'),
  MalaysiaAddressOption(state: 'Sabah', city: 'Semporna', postcode: '91300'),
  MalaysiaAddressOption(state: 'Sabah', city: 'Tuaran', postcode: '89200'),
  MalaysiaAddressOption(state: 'Sarawak', city: 'Bau', postcode: '94000'),
  MalaysiaAddressOption(state: 'Sarawak', city: 'Kapit', postcode: '96800'),
  MalaysiaAddressOption(state: 'Sarawak', city: 'Limbang', postcode: '98700'),
  MalaysiaAddressOption(state: 'Sarawak', city: 'Mukah', postcode: '96400'),
  MalaysiaAddressOption(state: 'Sarawak', city: 'Samarahan', postcode: '94300'),
  MalaysiaAddressOption(state: 'Sarawak', city: 'Sarikei', postcode: '96100'),
  MalaysiaAddressOption(state: 'Sarawak', city: 'Sri Aman', postcode: '95000'),
  MalaysiaAddressOption(
      state: 'Selangor', city: 'Bandar Baru Bangi', postcode: '43650'),
  MalaysiaAddressOption(state: 'Selangor', city: 'Banting', postcode: '42700'),
  MalaysiaAddressOption(
      state: 'Selangor', city: 'Batang Kali', postcode: '44300'),
  MalaysiaAddressOption(
      state: 'Selangor', city: 'Damansara', postcode: '47820'),
  MalaysiaAddressOption(state: 'Selangor', city: 'Dengkil', postcode: '43800'),
  MalaysiaAddressOption(state: 'Selangor', city: 'Gombak', postcode: '68100'),
  MalaysiaAddressOption(
      state: 'Selangor', city: 'Hulu Langat', postcode: '43100'),
  MalaysiaAddressOption(
      state: 'Selangor', city: 'Kuala Selangor', postcode: '45000'),
  MalaysiaAddressOption(
      state: 'Selangor', city: 'Seri Kembangan', postcode: '43300'),
  MalaysiaAddressOption(state: 'Selangor', city: 'Semenyih', postcode: '43500'),
  MalaysiaAddressOption(
      state: 'Selangor', city: 'Setia Alam', postcode: '40170'),
  MalaysiaAddressOption(
      state: 'Selangor', city: 'Tanjong Karang', postcode: '45500'),
  MalaysiaAddressOption(state: 'Terengganu', city: 'Besut', postcode: '22000'),
  MalaysiaAddressOption(state: 'Terengganu', city: 'Kerteh', postcode: '24300'),
  MalaysiaAddressOption(
      state: 'Terengganu', city: 'Kuala Besut', postcode: '22300'),
  MalaysiaAddressOption(state: 'Terengganu', city: 'Marang', postcode: '21600'),
  MalaysiaAddressOption(state: 'Terengganu', city: 'Paka', postcode: '23100'),
  MalaysiaAddressOption(state: 'Terengganu', city: 'Setiu', postcode: '22100'),
  MalaysiaAddressOption(
      state: 'Wilayah Persekutuan Kuala Lumpur',
      city: 'Bangsar',
      postcode: '59000'),
  MalaysiaAddressOption(
      state: 'Wilayah Persekutuan Kuala Lumpur',
      city: 'Brickfields',
      postcode: '50470'),
  MalaysiaAddressOption(
      state: 'Wilayah Persekutuan Kuala Lumpur',
      city: 'Desa Pandan',
      postcode: '55100'),
  MalaysiaAddressOption(
      state: 'Wilayah Persekutuan Kuala Lumpur',
      city: 'Old Klang Road',
      postcode: '58200'),
  MalaysiaAddressOption(
      state: 'Wilayah Persekutuan Kuala Lumpur',
      city: 'Pudu',
      postcode: '55200'),
  MalaysiaAddressOption(
      state: 'Wilayah Persekutuan Kuala Lumpur',
      city: 'Segambut',
      postcode: '51200'),
  MalaysiaAddressOption(
      state: 'Wilayah Persekutuan Kuala Lumpur',
      city: 'Sri Petaling',
      postcode: '57000'),
  MalaysiaAddressOption(
      state: 'Wilayah Persekutuan Kuala Lumpur',
      city: 'Taman Desa',
      postcode: '58100'),
  MalaysiaAddressOption(
      state: 'Wilayah Persekutuan Kuala Lumpur',
      city: 'Titiwangsa',
      postcode: '53200'),
  MalaysiaAddressOption(
      state: 'Wilayah Persekutuan Putrajaya',
      city: 'Presint 1',
      postcode: '62000'),
  MalaysiaAddressOption(
      state: 'Wilayah Persekutuan Putrajaya',
      city: 'Presint 8',
      postcode: '62250'),
  MalaysiaAddressOption(
      state: 'Wilayah Persekutuan Putrajaya',
      city: 'Presint 11',
      postcode: '62300'),
];

List<String> malaysiaStates() =>
    malaysiaAddressOptions.map((item) => item.state).toSet().toList()..sort();

List<String> malaysiaCitiesForState(String? state) => malaysiaAddressOptions
    .where((item) => state == null || item.state == state)
    .map((item) => item.city)
    .toSet()
    .toList()
  ..sort();

List<String> malaysiaPostcodesFor(String? state, String? city) =>
    malaysiaAddressOptions
        .where((item) =>
            (state == null || item.state == state) &&
            (city == null || item.city == city))
        .map((item) => item.postcode)
        .toSet()
        .toList()
      ..sort();

const malaysiaPostcodeRanges = <String, List<(int, int)>>{
  'Johor': [(79000, 86999)],
  'Kedah': [(5000, 9899)],
  'Kelantan': [(15000, 18599)],
  'Melaka': [(75000, 78999)],
  'Negeri Sembilan': [(70000, 73999)],
  'Pahang': [(25000, 28999), (39000, 39200), (49000, 49099), (69000, 69099)],
  'Perak': [(30000, 36899)],
  'Perlis': [(1000, 2999)],
  'Pulau Pinang': [(10000, 14999)],
  'Sabah': [(88000, 91399)],
  'Sarawak': [(93000, 98899)],
  'Selangor': [(40000, 48999), (63000, 68199)],
  'Terengganu': [(20000, 24399)],
  'Wilayah Persekutuan Kuala Lumpur': [(50000, 60000)],
  'Wilayah Persekutuan Labuan': [(87000, 87099)],
  'Wilayah Persekutuan Putrajaya': [(62000, 62999)],
};

bool isPostcodeInStateRange(String state, String postcode) {
  final code = int.tryParse(postcode);
  if (code == null) return false;
  final ranges = malaysiaPostcodeRanges[state] ?? const <(int, int)>[];
  return ranges.any((range) => code >= range.$1 && code <= range.$2);
}

bool isValidMalaysiaLocation({
  required String state,
  required String city,
  required String postcode,
}) {
  final exact = malaysiaAddressOptions.any((item) =>
      item.state == state && item.city == city && item.postcode == postcode);
  if (exact) return true;
  final cityBelongsToState = malaysiaAddressOptions
      .any((item) => item.state == state && item.city == city);
  return cityBelongsToState && isPostcodeInStateRange(state, postcode);
}

String combineAddress({
  required String line1,
  String line2 = '',
  required String postcode,
  required String city,
  required String state,
}) {
  return [
    line1.trim(),
    if (line2.trim().isNotEmpty) line2.trim(),
    postcode.trim(),
    city.trim(),
    state.trim(),
  ].where((part) => part.isNotEmpty).join(', ');
}

String _xml(Object? value) {
  return (value?.toString() ?? '')
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');
}

String _excelCell(Object? value) {
  if (value == null) {
    return '<Cell><Data ss:Type="String"></Data></Cell>';
  }
  if (value is num) {
    final number = value.isFinite ? value.toString() : '0';
    return '<Cell><Data ss:Type="Number">$number</Data></Cell>';
  }
  return '<Cell><Data ss:Type="String">${_xml(value)}</Data></Cell>';
}

xlsx.CellValue? _xlsxCell(Object? value) {
  if (value == null) return null;
  if (value is String && value.isEmpty) return null;
  if (value is int) return xlsx.IntCellValue(value);
  if (value is double) return xlsx.DoubleCellValue(value);
  if (value is num) return xlsx.DoubleCellValue(value.toDouble());
  if (value is bool) return xlsx.BoolCellValue(value);
  if (value is DateTime) return xlsx.DateTimeCellValue.fromDateTime(value);
  return xlsx.TextCellValue(value.toString());
}

Uint8List buildRentalManagerXlsx(Map<String, List<List<Object?>>> sheets) {
  final workbook = xlsx.Excel.createExcel();
  var first = true;
  for (final entry in sheets.entries) {
    final sheetName =
        entry.key.length > 31 ? entry.key.substring(0, 31) : entry.key;
    if (first) {
      workbook.rename('Sheet1', sheetName);
      first = false;
    }
    final sheet = workbook[sheetName];
    for (final row in entry.value) {
      sheet.appendRow(row.map(_xlsxCell).toList());
    }
    if (entry.value.isNotEmpty) {
      final headerRowIndex = entry.value.indexWhere((row) => row.length > 1);
      if (headerRowIndex >= 0) {
        for (var col = 0; col < entry.value[headerRowIndex].length; col++) {
          sheet
              .cell(xlsx.CellIndex.indexByColumnRow(
                columnIndex: col,
                rowIndex: headerRowIndex,
              ))
              .cellStyle = xlsx.CellStyle(
            bold: true,
            fontColorHex: xlsx.ExcelColor.white,
            backgroundColorHex: xlsx.ExcelColor.blue,
            horizontalAlign: xlsx.HorizontalAlign.Center,
          );
        }
      }
      for (var col = 0; col < 18; col++) {
        sheet.setColumnWidth(col, col < 3 ? 22 : 16);
      }
    }
  }
  return Uint8List.fromList(workbook.save() ?? const <int>[]);
}

String insuranceFrequencyLabel(InsuranceFrequency frequency) {
  return switch (frequency) {
    InsuranceFrequency.yearly => 'Yearly',
    InsuranceFrequency.halfYearly => 'Half-yearly',
  };
}

String commitmentFrequencyLabel(CommitmentFrequency frequency) {
  return switch (frequency) {
    CommitmentFrequency.monthly => 'Monthly',
    CommitmentFrequency.quarterly => 'Quarterly',
    CommitmentFrequency.halfYearly => 'Half-yearly',
    CommitmentFrequency.yearly => 'Yearly',
  };
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.publishableKey,
  );
  runApp(Uri.base.queryParameters.containsKey('invoice')
      ? const RentFlowApp()
      : const RentalFacilityApp());
}

enum UserRole { owner, propertyAgent, tenant }

enum AppLanguage { english, chinese, malay }

enum UtilityPackage { included, excluded }

enum PaymentStatus {
  notSubmitted,
  pendingTenantPayment,
  pendingApproval,
  approved,
  rejected,
}

enum FacilityStatus { active, sold }

enum InsuranceFrequency { halfYearly, yearly }

enum CommitmentFrequency { monthly, quarterly, halfYearly, yearly }

class ElectricityTariffOption {
  const ElectricityTariffOption({
    required this.name,
    required this.rate,
    required this.description,
  });

  final String name;
  final double rate;
  final String description;
}

class ElectricityTariffTier {
  const ElectricityTariffTier({
    required this.fromKwh,
    required this.toKwh,
    required this.ratePerKwh,
  });

  final double fromKwh;
  final double? toKwh;
  final double ratePerKwh;

  bool get isOpenEnded => toKwh == null;

  Map<String, dynamic> toJson() => {
        'fromKwh': fromKwh,
        'toKwh': toKwh,
        'ratePerKwh': ratePerKwh,
      };

  static ElectricityTariffTier fromJson(Map<String, dynamic> json) =>
      ElectricityTariffTier(
        fromKwh: RentalStore._number(json['fromKwh']),
        toKwh:
            json['toKwh'] == null ? null : RentalStore._number(json['toKwh']),
        ratePerKwh: RentalStore._number(json['ratePerKwh']),
      );
}

const customElectricityTariffName = 'Custom tariff';

const electricityTariffOptions = [
  ElectricityTariffOption(
    name: RentalStore.defaultElectricityTariffName,
    rate: RentalStore.defaultElectricityRatePerKwh,
    description: 'Current flat billing rate used by this app',
  ),
  ElectricityTariffOption(
    name: 'TNB Tariff A - Domestic',
    rate: RentalStore.defaultElectricityRatePerKwh,
    description: 'Residential tenant billing tariff',
  ),
  ElectricityTariffOption(
    name: 'TNB Tariff B - Commercial',
    rate: RentalStore.defaultElectricityRatePerKwh,
    description: 'Commercial / shop-lot billing tariff',
  ),
  ElectricityTariffOption(
    name: 'Management bulk meter tariff',
    rate: RentalStore.defaultElectricityRatePerKwh,
    description: 'Flat rate decided by building management',
  ),
  ElectricityTariffOption(
    name: customElectricityTariffName,
    rate: RentalStore.defaultElectricityRatePerKwh,
    description: 'Owner-defined tariff and rate',
  ),
];

const customCommitmentType = 'Custom Commitment';

const commitmentTypeOptions = [
  'Fire Insurance',
  'Indah Water',
  'DBKL Assessment',
  'Security Service',
  'Cleaning Service',
  'Lift Service',
  'Pest Control',
  customCommitmentType,
];

class RecurringCommitment {
  RecurringCommitment({
    required this.id,
    required this.name,
    required this.amount,
    required this.frequency,
    required this.firstDueMonth,
  });

  final String id;
  String name;
  double amount;
  CommitmentFrequency frequency;
  int firstDueMonth;
}

class FacilityCostVersion {
  FacilityCostVersion({
    required this.id,
    required this.effectiveMonth,
    required this.recordedAt,
    required this.installmentAmount,
    required this.extraInstallmentPayment,
    required this.maintenanceFee,
    required this.insuranceFee,
    required this.insuranceFrequency,
    required this.insuranceDueMonth,
    this.initial = false,
  });

  final String id;
  final DateTime effectiveMonth;
  final DateTime recordedAt;
  final double installmentAmount;
  final double extraInstallmentPayment;
  final double maintenanceFee;
  final double insuranceFee;
  final InsuranceFrequency insuranceFrequency;
  final int insuranceDueMonth;
  final bool initial;

  double get monthlyRecurringTotal =>
      installmentAmount + extraInstallmentPayment + maintenanceFee;
}

class AppUser {
  AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.phoneNumber = '',
    this.originAddress,
    this.dateOfBirth,
    this.sex,
    this.accountStatus = 'Active',
    this.profileComplete = true,
    this.invitationSentAt,
    this.accountCreatedAt,
    this.lastLoginAt,
    this.avatarStyle = 0,
    this.paymentReminderAfterDays = 3,
    this.paymentReminderFrequencyDays = 2,
  });

  final String id;
  String name;
  String email;
  String phoneNumber;
  final UserRole role;
  String? originAddress;
  DateTime? dateOfBirth;
  String? sex;
  String accountStatus;
  bool profileComplete;
  DateTime? invitationSentAt;
  DateTime? accountCreatedAt;
  DateTime? lastLoginAt;
  int avatarStyle;
  int paymentReminderAfterDays;
  int paymentReminderFrequencyDays;

  bool get invitationSent => invitationSentAt != null;
  bool get accountCreated => profileComplete || accountCreatedAt != null;
}

class Facility {
  Facility({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.addressLine,
    required this.postcode,
    required this.city,
    required this.state,
    required this.installmentAmount,
    required this.maintenanceFee,
    required this.insuranceFee,
    this.insuranceFrequency = InsuranceFrequency.yearly,
    this.insuranceDueMonth = 1,
    List<RecurringCommitment>? extraCommitments,
    this.extraInstallmentPayment = 0,
    this.status = FacilityStatus.active,
    this.soldAt,
    DateTime? initialCostEffectiveMonth,
  }) : extraCommitments = extraCommitments ?? <RecurringCommitment>[] {
    costHistory.add(
      FacilityCostVersion(
        id: 'cost_${id}_initial',
        effectiveMonth: initialCostEffectiveMonth ?? DateTime(2026, 1),
        recordedAt: initialCostEffectiveMonth ?? DateTime(2026, 1),
        installmentAmount: installmentAmount,
        extraInstallmentPayment: extraInstallmentPayment,
        maintenanceFee: maintenanceFee,
        insuranceFee: insuranceFee,
        insuranceFrequency: insuranceFrequency,
        insuranceDueMonth: insuranceDueMonth,
        initial: true,
      ),
    );
  }

  final String id;
  final String ownerId;
  String name;
  final String addressLine;
  final String postcode;
  final String city;
  final String state;
  double installmentAmount;
  double maintenanceFee;
  double insuranceFee;
  InsuranceFrequency insuranceFrequency;
  int insuranceDueMonth;
  final List<RecurringCommitment> extraCommitments;
  final List<FacilityCostVersion> costHistory = [];
  double extraInstallmentPayment;
  FacilityStatus status;
  DateTime? soldAt;

  String get address => '$addressLine, $postcode $city, $state';
}

class Tenancy {
  Tenancy({
    required this.id,
    required this.facilityId,
    required this.tenantId,
    required this.unitName,
    required this.monthlyRent,
    required this.electricityPackage,
    required this.electricityCharge,
    required this.waterPackage,
    required this.waterCharge,
    required this.internetPackage,
    required this.internetCharge,
    required this.leaseStart,
    required this.leaseEnd,
    this.carParkIncluded = false,
    this.carParkDetails = 'Not included',
    this.agreementFileName,
    this.agreementUploadedAt,
    this.active = true,
  });

  final String id;
  final String facilityId;
  final String tenantId;
  String unitName;
  double monthlyRent;
  UtilityPackage electricityPackage;
  double electricityCharge;
  UtilityPackage waterPackage;
  double waterCharge;
  UtilityPackage internetPackage;
  double internetCharge;
  DateTime leaseStart;
  DateTime leaseEnd;
  bool carParkIncluded;
  String carParkDetails;
  String? agreementFileName;
  DateTime? agreementUploadedAt;
  bool active;

  bool get utilitiesFullyIncluded =>
      electricityPackage == UtilityPackage.included &&
      waterPackage == UtilityPackage.included &&
      internetPackage == UtilityPackage.included;
}

class MonthlyBill {
  MonthlyBill({
    required this.id,
    required this.facilityId,
    required this.tenantId,
    required this.month,
    required this.rentAmount,
    required this.electricityAmount,
    required this.waterAmount,
    required this.internetAmount,
    this.electricityUsageKwh = 0,
    this.generalElectricAmount = 0,
    this.parkingRentalAmount = 0,
    this.utilityEvidenceFileName,
    this.utilityEvidenceBytes,
    this.status = PaymentStatus.notSubmitted,
    this.slipFileName,
    this.slipBytes,
    this.amountPaid = 0,
    this.paymentDate,
    this.paymentReference,
    this.submittedAt,
    this.rejectReason,
    this.reviewedAt,
  });

  final String id;
  final String facilityId;
  final String tenantId;
  final DateTime month;
  final double rentAmount;
  double electricityUsageKwh;
  double electricityAmount;
  double waterAmount;
  double internetAmount;
  double generalElectricAmount;
  double parkingRentalAmount;
  String? utilityEvidenceFileName;
  Uint8List? utilityEvidenceBytes;
  PaymentStatus status;
  String? slipFileName;
  Uint8List? slipBytes;
  double amountPaid;
  DateTime? paymentDate;
  String? paymentReference;
  DateTime? submittedAt;
  String? rejectReason;
  DateTime? reviewedAt;

  double get totalAmount =>
      rentAmount +
      electricityAmount +
      generalElectricAmount +
      waterAmount +
      internetAmount +
      parkingRentalAmount;

  double get totalUtilityAmount =>
      electricityAmount + generalElectricAmount + waterAmount + internetAmount;
}

class MonthlyFinancialSummary {
  const MonthlyFinancialSummary({
    required this.month,
    required this.collection,
    required this.expenses,
  });

  final int month;
  final double collection;
  final double expenses;
}

class FinancialBreakdownItem {
  const FinancialBreakdownItem({
    required this.label,
    required this.amount,
  });

  final String label;
  final double amount;
}

class FacilityReport {
  FacilityReport({
    required this.facility,
    required this.inflow,
    required this.outflow,
    required this.netCashflow,
  });

  final Facility facility;
  final double inflow;
  final double outflow;
  final double netCashflow;
}

class TenantRequest {
  TenantRequest({
    required this.id,
    required this.tenantId,
    required this.facilityId,
    required this.title,
    required this.message,
    required this.createdAt,
    this.requestType = 'General Enquiry',
    this.attachmentFileName,
    this.attachmentBase64,
    this.attachmentSizeBytes,
    this.status = 'Open',
    this.reviewedAt,
  });

  final String id;
  final String tenantId;
  final String facilityId;
  final String title;
  final String message;
  final DateTime createdAt;
  final String requestType;
  final String? attachmentFileName;
  final String? attachmentBase64;
  final int? attachmentSizeBytes;
  String status;
  DateTime? reviewedAt;

  bool get hasAttachment =>
      (attachmentFileName ?? '').trim().isNotEmpty ||
      (attachmentBase64 ?? '').trim().isNotEmpty;
}

class AppNotification {
  AppNotification({
    required this.id,
    required this.message,
    required this.createdAt,
    String? category,
    this.isRead = false,
  }) : category = category ?? notificationCategoryFor(message);

  final String id;
  final String message;
  final DateTime createdAt;
  final String category;
  bool isRead;
}

class LocalAuthAccount {
  LocalAuthAccount({
    required this.userId,
    required this.email,
    required this.password,
    required this.role,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String userId;
  String email;
  String password;
  UserRole role;
  DateTime createdAt;
}

class ActivityHistoryEvent {
  ActivityHistoryEvent({
    required this.id,
    required this.action,
    required this.timestamp,
  });

  final String id;
  final String action;
  final DateTime timestamp;
}

class PaymentReviewEvent {
  PaymentReviewEvent({
    required this.id,
    required this.billId,
    required this.status,
    required this.timestamp,
    this.reason,
  });

  final String id;
  final String billId;
  final PaymentStatus status;
  final DateTime timestamp;
  final String? reason;
}

class AdditionalIncome {
  AdditionalIncome({
    required this.id,
    required this.facilityId,
    required this.month,
    required this.category,
    required this.amount,
    required this.note,
  });

  final String id;
  final String facilityId;
  final DateTime month;
  final String category;
  final double amount;
  final String note;
}

class AdditionalExpense {
  AdditionalExpense({
    required this.id,
    required this.facilityId,
    required this.month,
    required this.category,
    required this.amount,
    required this.note,
  });

  final String id;
  final String facilityId;
  final DateTime month;
  final String category;
  final double amount;
  final String note;
}

class RentalStore extends ChangeNotifier {
  static const double defaultElectricityRatePerKwh = 0.516;
  static const String defaultElectricityTariffName = 'TNB default tariff';
  static const List<ElectricityTariffTier> defaultElectricityTariffTiers = [
    ElectricityTariffTier(fromKwh: 0, toKwh: 100, ratePerKwh: 0.516),
    ElectricityTariffTier(fromKwh: 101, toKwh: 200, ratePerKwh: 0.516),
    ElectricityTariffTier(fromKwh: 201, toKwh: null, ratePerKwh: 0.516),
  ];

  RentalStore({
    DateTime? now,
    AppPersistence? persistence,
    SupabaseAuthService? cloudAuth,
    SupabaseWorkspaceService? cloudWorkspace,
    bool seedDemoData = true,
  })  : _now = now ?? DateTime.now(),
        _persistence = persistence,
        cloudAuth = cloudAuth,
        cloudWorkspace = cloudWorkspace {
    if (seedDemoData) _seed();
  }

  final DateTime _now;
  final AppPersistence? _persistence;
  final SupabaseAuthService? cloudAuth;
  final SupabaseWorkspaceService? cloudWorkspace;
  Timer? _saveTimer;
  Timer? _cloudSaveTimer;
  Timer? _publicPaymentSyncTimer;
  bool _restoring = false;
  bool _cloudRestoring = false;
  String? _tenantSnapshotOwnerId;
  bool _persistenceReady = false;
  String? persistenceError;
  CloudProfile? cloudProfile;
  final List<AppUser> users = [];
  final List<Facility> facilities = [];
  final List<Tenancy> tenancies = [];
  final List<MonthlyBill> bills = [];
  final List<TenantRequest> tenantRequests = [];
  final List<AppNotification> notifications = [];
  final List<ActivityHistoryEvent> activityHistory = [];
  final List<PaymentReviewEvent> paymentReviewHistory = [];
  final List<AdditionalIncome> additionalIncomes = [];
  final List<AdditionalExpense> additionalExpenses = [];
  final List<LocalAuthAccount> localAuthAccounts = [];
  AppLanguage appLanguage = AppLanguage.english;
  String electricityTariffName = defaultElectricityTariffName;
  double electricityRatePerKwh = defaultElectricityRatePerKwh;
  final List<ElectricityTariffTier> electricityTariffTiers = [
    ...defaultElectricityTariffTiers,
  ];

  AppUser? currentUser;

  bool get isLoggedIn => currentUser != null;
  bool get isOwner => currentUser?.role == UserRole.owner;
  bool get isPropertyAgent => currentUser?.role == UserRole.propertyAgent;
  bool get isManager => isOwner || isPropertyAgent;
  int get unreadNotificationCount =>
      notifications.where((notification) => !notification.isRead).length;
  int get elapsedMonthsThisYear => _now.month;
  DateTime get currentMonth => DateTime(_now.year, _now.month);
  bool get persistenceReady => _persistenceReady || _persistence == null;
  bool get cloudAuthEnabled => cloudAuth != null;
  String get storageDescription =>
      _persistence?.storageDescription ?? 'in-memory test store';

  void updateLanguage(AppLanguage language) {
    appLanguage = language;
    _recordActivity('Application language changed to ${language.name}.');
    notifyListeners();
  }

  void updateElectricityTariff({
    required String tariffName,
    required double rate,
  }) {
    if (rate <= 0) return;
    electricityTariffName = tariffName.trim().isEmpty
        ? defaultElectricityTariffName
        : tariffName.trim();
    electricityRatePerKwh = rate;
    _recordActivity(
      'Billing configuration updated: $electricityTariffName set to RM ${rate.toStringAsFixed(3)} per kWh.',
    );
    notifyListeners();
  }

  void updateElectricityTariffTiers(List<ElectricityTariffTier> tiers) {
    final normalized = [...tiers]
      ..sort((a, b) => a.fromKwh.compareTo(b.fromKwh));
    if (normalized.isEmpty || normalized.any((tier) => tier.ratePerKwh <= 0)) {
      return;
    }
    electricityTariffTiers
      ..clear()
      ..addAll(normalized);
    electricityTariffName = 'Tiered electricity tariff';
    electricityRatePerKwh = normalized.first.ratePerKwh;
    _recordActivity(
      'Billing configuration updated: ${electricityTariffSummary()}.',
    );
    notifyListeners();
  }

  double calculateElectricityCharge(double usageKwh) {
    if (usageKwh <= 0) return 0;
    final tiers = electricityTariffTiers.isEmpty
        ? defaultElectricityTariffTiers
        : electricityTariffTiers;
    var total = 0.0;
    for (final tier in tiers) {
      final start = tier.fromKwh;
      final end = tier.toKwh;
      if (usageKwh < start) continue;
      final upper = end == null ? usageKwh : math.min(usageKwh, end);
      final units = math.max(0, upper - start + (start == 0 ? 0 : 1));
      total += units * tier.ratePerKwh;
      if (end == null || usageKwh <= end) break;
    }
    return (total * 100).round() / 100;
  }

  String electricityTariffSummary() {
    final tiers = electricityTariffTiers.isEmpty
        ? defaultElectricityTariffTiers
        : electricityTariffTiers;
    return tiers.map((tier) {
      final from = tier.fromKwh.toStringAsFixed(0);
      final to = tier.toKwh == null ? 'above' : tier.toKwh!.toStringAsFixed(0);
      return '$from-$to kWh @ RM ${tier.ratePerKwh.toStringAsFixed(3)}';
    }).join(', ');
  }

  bool isCurrentOrPastMonth(DateTime month) {
    final normalizedMonth = DateTime(month.year, month.month);
    final currentMonth = DateTime(_now.year, _now.month);
    return !normalizedMonth.isAfter(currentMonth);
  }

  List<Facility> get ownerFacilities {
    final user = currentUser;
    if (user == null) return [];
    if (user.role == UserRole.propertyAgent) {
      return facilities.toList();
    }
    return facilities.where((facility) => facility.ownerId == user.id).toList();
  }

  List<Tenancy> get tenantTenancies {
    final user = currentUser;
    if (user == null) return [];
    return tenancies.where((tenancy) => tenancy.tenantId == user.id).toList();
  }

  List<MonthlyBill> get tenantBills {
    final user = currentUser;
    if (user == null) return [];
    return bills.where((bill) => bill.tenantId == user.id).toList()
      ..sort((a, b) => b.month.compareTo(a.month));
  }

  List<MonthlyBill> get tenantPaymentHistory {
    return tenantBills
        .where((bill) =>
            bill.status == PaymentStatus.pendingApproval ||
            bill.status == PaymentStatus.approved ||
            bill.status == PaymentStatus.rejected)
        .toList()
      ..sort((a, b) => b.month.compareTo(a.month));
  }

  List<MonthlyBill> get tenantPayableBills {
    return tenantBills
        .where((bill) =>
            bill.status == PaymentStatus.pendingTenantPayment ||
            bill.status == PaymentStatus.rejected)
        .toList()
      ..sort((a, b) => a.month.compareTo(b.month));
  }

  List<TenantRequest> get currentTenantRequests {
    final user = currentUser;
    if (user == null) return [];
    return tenantRequests
        .where((request) => request.tenantId == user.id)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  double get totalInflow {
    final facilityIds = ownerFacilities.map((facility) => facility.id).toSet();
    final rentalIncome = bills
        .where((bill) =>
            facilityIds.contains(bill.facilityId) &&
            isCurrentOrPastMonth(bill.month) &&
            bill.status == PaymentStatus.approved)
        .fold<double>(0, (sum, bill) => sum + bill.totalAmount);
    final otherIncome = additionalIncomes
        .where((income) =>
            facilityIds.contains(income.facilityId) &&
            isCurrentOrPastMonth(income.month))
        .fold<double>(0, (sum, income) => sum + income.amount);
    return rentalIncome + otherIncome;
  }

  double get monthlyRecurringOutflow {
    return ownerFacilities.fold<double>(
      0,
      (sum, facility) => sum + monthlyFacilityOutflow(facility),
    );
  }

  double get totalOutflow {
    return ownerFacilities.fold<double>(
      0,
      (sum, facility) => sum + facilityOutflow(facility),
    );
  }

  double get netCashflow => totalInflow - totalOutflow;

  double facilityInflow(String facilityId) {
    final rentalIncome = bills.where((bill) {
      return bill.facilityId == facilityId &&
          isCurrentOrPastMonth(bill.month) &&
          bill.status == PaymentStatus.approved;
    }).fold<double>(0, (sum, bill) => sum + bill.totalAmount);
    final otherIncome = additionalIncomes
        .where((income) =>
            income.facilityId == facilityId &&
            isCurrentOrPastMonth(income.month))
        .fold<double>(0, (sum, income) => sum + income.amount);
    return rentalIncome + otherIncome;
  }

  double facilityInflowForYear(String facilityId, int year) {
    final rentalIncome = bills.where((bill) {
      return bill.facilityId == facilityId &&
          bill.month.year == year &&
          isCurrentOrPastMonth(bill.month) &&
          bill.status == PaymentStatus.approved;
    }).fold<double>(0, (sum, bill) => sum + bill.totalAmount);
    final otherIncome = additionalIncomes
        .where((income) =>
            income.facilityId == facilityId &&
            income.month.year == year &&
            isCurrentOrPastMonth(income.month))
        .fold<double>(0, (sum, income) => sum + income.amount);
    return rentalIncome + otherIncome;
  }

  DateTime get nextCostEffectiveMonth => DateTime(_now.year, _now.month + 1);

  FacilityCostVersion costVersionForMonth(
    Facility facility,
    DateTime month,
  ) {
    final normalized = DateTime(month.year, month.month);
    final eligible = facility.costHistory.where(
      (version) => !DateTime(
        version.effectiveMonth.year,
        version.effectiveMonth.month,
      ).isAfter(normalized),
    );
    if (eligible.isEmpty) return facility.costHistory.first;
    return eligible.reduce(
      (current, next) =>
          next.effectiveMonth.isAfter(current.effectiveMonth) ? next : current,
    );
  }

  double monthlyFacilityOutflow(Facility facility, {DateTime? month}) {
    final targetMonth = month ?? _now;
    final version = costVersionForMonth(facility, targetMonth);
    final extraRecurring = facility.extraCommitments.fold<double>(
      0,
      (sum, commitment) =>
          sum +
          scheduledCommitmentAmount(
            commitment.amount,
            commitment.frequency,
            commitment.firstDueMonth,
            targetMonth.month,
          ),
    );
    return version.monthlyRecurringTotal + extraRecurring;
  }

  bool isInsuranceDue(Facility facility, int month) {
    if (month == facility.insuranceDueMonth) return true;
    if (facility.insuranceFrequency == InsuranceFrequency.halfYearly) {
      return month == ((facility.insuranceDueMonth + 5) % 12) + 1;
    }
    return false;
  }

  bool isHalfYearlyDue(int firstDueMonth, int month) {
    return isCommitmentDue(
      CommitmentFrequency.halfYearly,
      firstDueMonth,
      month,
    );
  }

  bool isCommitmentDue(
    CommitmentFrequency frequency,
    int firstDueMonth,
    int month,
  ) {
    final normalizedFirstMonth = ((firstDueMonth - 1) % 12) + 1;
    final offset = (month - normalizedFirstMonth) % 12;
    return switch (frequency) {
      CommitmentFrequency.monthly => true,
      CommitmentFrequency.quarterly => offset % 3 == 0,
      CommitmentFrequency.halfYearly => offset % 6 == 0,
      CommitmentFrequency.yearly => offset == 0,
    };
  }

  double scheduledCommitmentAmount(
    double amount,
    CommitmentFrequency frequency,
    int firstDueMonth,
    int month,
  ) {
    return isCommitmentDue(frequency, firstDueMonth, month) ? amount : 0;
  }

  double facilityExpenseForMonth(Facility facility, int year, int month) {
    if (!isCurrentOrPastMonth(DateTime(year, month))) return 0;
    final version = costVersionForMonth(facility, DateTime(year, month));
    final insuranceDue = month == version.insuranceDueMonth ||
        (version.insuranceFrequency == InsuranceFrequency.halfYearly &&
            month == ((version.insuranceDueMonth + 5) % 12) + 1);
    final oneTimeExpenses = additionalExpenses
        .where((expense) =>
            expense.facilityId == facility.id &&
            expense.month.year == year &&
            expense.month.month == month)
        .fold<double>(0, (sum, expense) => sum + expense.amount);
    return monthlyFacilityOutflow(facility, month: DateTime(year, month)) +
        (insuranceDue ? version.insuranceFee : 0) +
        oneTimeExpenses;
  }

  double facilityOutflow(Facility facility) {
    return List.generate(elapsedMonthsThisYear, (index) => index + 1)
        .fold<double>(
      0,
      (sum, month) => sum + facilityExpenseForMonth(facility, _now.year, month),
    );
  }

  double facilityOutflowForYear(Facility facility, int year) {
    final monthsToInclude = year == _now.year ? elapsedMonthsThisYear : 12;
    return List.generate(monthsToInclude, (index) => index + 1).fold<double>(
      0,
      (sum, month) => sum + facilityExpenseForMonth(facility, year, month),
    );
  }

  List<MonthlyBill> facilityBills(String facilityId) {
    return bills.where((bill) => bill.facilityId == facilityId).toList()
      ..sort((a, b) => b.month.compareTo(a.month));
  }

  List<FacilityReport> get facilityReports {
    return ownerFacilities.map((facility) {
      final inflow = facilityInflow(facility.id);
      final outflow = facilityOutflow(facility);
      return FacilityReport(
        facility: facility,
        inflow: inflow,
        outflow: outflow,
        netCashflow: inflow - outflow,
      );
    }).toList();
  }

  List<FacilityReport> facilityReportsForYear(int year) {
    return ownerFacilities.map((facility) {
      final inflow = facilityInflowForYear(facility.id, year);
      final outflow = facilityOutflowForYear(facility, year);
      return FacilityReport(
        facility: facility,
        inflow: inflow,
        outflow: outflow,
        netCashflow: inflow - outflow,
      );
    }).toList();
  }

  Map<String, dynamic> exportSnapshot() => _snapshotMap();

  String exportCsv() {
    String cell(Object? value) {
      final raw = value?.toString() ?? '';
      final escaped = raw.replaceAll('"', '""');
      return '"$escaped"';
    }

    final rows = <List<Object?>>[
      [
        'section',
        'id',
        'facility',
        'tenant',
        'month',
        'type',
        'amount',
        'status'
      ],
      ...bills.map((bill) {
        final facility = facilityFor(bill.facilityId);
        final tenant = userFor(bill.tenantId);
        return [
          'payment',
          bill.id,
          facility.name,
          tenant.name,
          monthLabel(bill.month),
          'bill',
          bill.totalAmount.toStringAsFixed(2),
          paymentStatusLabel(bill.status),
        ];
      }),
      ...additionalIncomes.map((income) {
        final facility = facilityFor(income.facilityId);
        return [
          'income',
          income.id,
          facility.name,
          '',
          monthLabel(income.month),
          income.category,
          income.amount.toStringAsFixed(2),
          income.note,
        ];
      }),
      ...additionalExpenses.map((expense) {
        final facility = facilityFor(expense.facilityId);
        return [
          'expense',
          expense.id,
          facility.name,
          '',
          monthLabel(expense.month),
          expense.category,
          expense.amount.toStringAsFixed(2),
          expense.note,
        ];
      }),
      ...tenancies.map((tenancy) {
        final facility = facilityFor(tenancy.facilityId);
        final tenant = userFor(tenancy.tenantId);
        return [
          'tenant',
          tenancy.id,
          facility.name,
          tenant.name,
          '',
          tenancy.unitName,
          tenancy.monthlyRent.toStringAsFixed(2),
          tenant.accountStatus,
        ];
      }),
    ];
    return rows.map((row) => row.map(cell).join(',')).join('\n');
  }

  String exportBackupExcelWorkbookXml() {
    String row(List<Object?> cells) =>
        '<Row>${cells.map(_excelCell).join()}</Row>';

    final rows = <List<Object?>>[
      [
        'section',
        'id',
        'facility',
        'tenant',
        'month',
        'type',
        'amount',
        'status'
      ],
      ...bills.map((bill) {
        final facility = facilityFor(bill.facilityId);
        final tenant = userFor(bill.tenantId);
        return [
          'payment',
          bill.id,
          facility.name,
          tenant.name,
          monthLabel(bill.month),
          'bill',
          bill.totalAmount,
          paymentStatusLabel(bill.status),
        ];
      }),
      ...additionalIncomes.map((income) {
        final facility = facilityFor(income.facilityId);
        return [
          'income',
          income.id,
          facility.name,
          '',
          monthLabel(income.month),
          income.category,
          income.amount,
          income.note,
        ];
      }),
      ...additionalExpenses.map((expense) {
        final facility = facilityFor(expense.facilityId);
        return [
          'expense',
          expense.id,
          facility.name,
          '',
          monthLabel(expense.month),
          expense.category,
          expense.amount,
          expense.note,
        ];
      }),
      ...tenancies.map((tenancy) {
        final facility = facilityFor(tenancy.facilityId);
        final tenant = userFor(tenancy.tenantId);
        return [
          'tenant',
          tenancy.id,
          facility.name,
          tenant.name,
          '',
          tenancy.unitName,
          tenancy.monthlyRent,
          tenant.accountStatus,
        ];
      }),
    ];

    return '''<?xml version="1.0"?>
<?mso-application progid="Excel.Sheet"?>
<Workbook xmlns="urn:schemas-microsoft-com:office:spreadsheet"
 xmlns:o="urn:schemas-microsoft-com:office:office"
 xmlns:x="urn:schemas-microsoft-com:office:excel"
 xmlns:ss="urn:schemas-microsoft-com:office:spreadsheet">
 <Worksheet ss:Name="Backup Summary">
  <Table>
   ${rows.map(row).join('\n   ')}
  </Table>
 </Worksheet>
</Workbook>''';
  }

  Uint8List exportBackupExcelWorkbookXlsx() {
    final rows = <List<Object?>>[
      [
        'section',
        'id',
        'facility',
        'tenant',
        'month',
        'type',
        'amount',
        'status'
      ],
      ...bills.map((bill) {
        final facility = facilityFor(bill.facilityId);
        final tenant = userFor(bill.tenantId);
        return [
          'payment',
          bill.id,
          facility.name,
          tenant.name,
          monthLabel(bill.month),
          'bill',
          bill.totalAmount,
          paymentStatusLabel(bill.status),
        ];
      }),
      ...additionalIncomes.map((income) {
        final facility = facilityFor(income.facilityId);
        return [
          'income',
          income.id,
          facility.name,
          '',
          monthLabel(income.month),
          income.category,
          income.amount,
          income.note,
        ];
      }),
      ...additionalExpenses.map((expense) {
        final facility = facilityFor(expense.facilityId);
        return [
          'expense',
          expense.id,
          facility.name,
          '',
          monthLabel(expense.month),
          expense.category,
          expense.amount,
          expense.note,
        ];
      }),
      ...tenancies.map((tenancy) {
        final facility = facilityFor(tenancy.facilityId);
        final tenant = userFor(tenancy.tenantId);
        return [
          'tenant',
          tenancy.id,
          facility.name,
          tenant.name,
          '',
          tenancy.unitName,
          tenancy.monthlyRent,
          tenant.accountStatus,
        ];
      }),
    ];
    return buildRentalManagerXlsx({'Backup Summary': rows});
  }

  String exportExcelWorkbookXml() {
    final years = <int>{
      _now.year,
      ...bills.map((bill) => bill.month.year),
      ...additionalIncomes.map((income) => income.month.year),
      ...additionalExpenses.map((expense) => expense.month.year),
    }.toList()
      ..sort();

    String row(List<Object?> cells) =>
        '<Row>${cells.map(_excelCell).join()}</Row>';

    String worksheet(String name, List<List<Object?>> rows) {
      return '''
 <Worksheet ss:Name="${_xml(name)}">
  <Table>
   ${rows.map(row).join('\n   ')}
  </Table>
 </Worksheet>''';
    }

    final currentYearReports = facilityReportsForYear(_now.year);
    final totalIn =
        currentYearReports.fold<double>(0, (sum, r) => sum + r.inflow);
    final totalOut =
        currentYearReports.fold<double>(0, (sum, r) => sum + r.outflow);
    final dashboardRows = <List<Object?>>[
      ['Rental Facility Management Export'],
      ['Generated', dateTimeLabel(DateTime.now())],
      [],
      ['Metric', 'Total'],
      ['Total Rental Collection', totalIn],
      ['Total Expenses', totalOut],
      ['Net Rental Income', totalIn - totalOut],
      ['Properties', ownerFacilities.length],
      ['Active Tenants', tenancies.where((item) => item.active).length],
      [],
      ['Facility', 'Tenants', 'Inflow', 'Outflow', 'Net Cashflow', 'Margin %'],
      ...currentYearReports.map((report) => [
            report.facility.name,
            tenancies
                .where((tenancy) => tenancy.facilityId == report.facility.id)
                .length,
            report.inflow,
            report.outflow,
            report.netCashflow,
            report.inflow == 0 ? 0 : report.netCashflow / report.inflow,
          ]),
      [],
      ['Year', 'Month', 'Collection', 'Expenses', 'Net Cashflow'],
      for (final year in years)
        for (final summary in yearlyFinancialSummary(year))
          [
            year,
            FinancialChartPainter.monthNames[summary.month - 1],
            summary.collection,
            summary.expenses,
            summary.collection - summary.expenses,
          ],
    ];

    final propertyRows = <List<Object?>>[
      [
        'Facility',
        'Address',
        'Status',
        'Installment',
        'Extra Payment',
        'Maintenance',
        'Insurance',
        'Insurance Frequency',
        'Insurance Month',
        'Tenant',
        'Unit',
        'Monthly Rent',
        'Lease Start',
        'Lease End',
        'Electricity Package',
        'Water Package',
        'Internet Package',
        'Car Park',
        'Agreement File',
      ],
      for (final facility in ownerFacilities)
        ...tenancies
            .where((tenancy) => tenancy.facilityId == facility.id)
            .map((tenancy) {
          final tenant = userFor(tenancy.tenantId);
          final version = costVersionForMonth(facility, _now);
          return [
            facility.name,
            facility.address,
            facilityStatusText(facility),
            version.installmentAmount,
            version.extraInstallmentPayment,
            version.maintenanceFee,
            version.insuranceFee,
            insuranceFrequencyLabel(version.insuranceFrequency),
            FinancialChartPainter.monthNames[version.insuranceDueMonth - 1],
            tenant.name,
            tenancy.unitName,
            tenancy.monthlyRent,
            dateLabel(tenancy.leaseStart),
            dateLabel(tenancy.leaseEnd),
            tenancy.electricityPackage.name,
            tenancy.waterPackage.name,
            tenancy.internetPackage.name,
            tenancy.carParkIncluded ? tenancy.carParkDetails : 'Not included',
            tenancy.agreementFileName ?? '',
          ];
        }),
    ];

    final billRows = <List<Object?>>[
      [
        'Bill ID',
        'Facility',
        'Tenant',
        'Unit',
        'Month',
        'Rent',
        'Air-con Electricity kWh',
        'Air-con Electricity',
        'General Electricity',
        'Water',
        'Internet',
        'Parking Rental',
        'Total Utilities',
        'Total Due',
        'Amount Paid',
        'Payment Date',
        'Payment Reference',
        'Status',
        'Submitted At',
        'Reviewed At',
        'Slip File',
        'Reject Reason',
      ],
      ...bills.map((bill) {
        final facility = facilityFor(bill.facilityId);
        final tenant = userFor(bill.tenantId);
        final tenancy = tenancies.firstWhere(
          (item) =>
              item.facilityId == bill.facilityId &&
              item.tenantId == bill.tenantId,
          orElse: () => Tenancy(
            id: '',
            facilityId: bill.facilityId,
            tenantId: bill.tenantId,
            unitName: '',
            monthlyRent: bill.rentAmount,
            leaseStart: bill.month,
            leaseEnd: bill.month,
            electricityPackage: UtilityPackage.excluded,
            electricityCharge: 0,
            waterPackage: UtilityPackage.excluded,
            waterCharge: 0,
            internetPackage: UtilityPackage.excluded,
            internetCharge: 0,
          ),
        );
        return [
          bill.id,
          facility.name,
          tenant.name,
          tenancy.unitName,
          monthLabel(bill.month),
          bill.rentAmount,
          bill.electricityUsageKwh,
          bill.electricityAmount,
          bill.generalElectricAmount,
          bill.waterAmount,
          bill.internetAmount,
          bill.parkingRentalAmount,
          bill.totalUtilityAmount,
          bill.totalAmount,
          bill.amountPaid,
          bill.paymentDate == null ? '' : dateLabel(bill.paymentDate!),
          bill.paymentReference ?? '',
          paymentStatusLabel(bill.status),
          bill.submittedAt == null ? '' : dateTimeLabel(bill.submittedAt!),
          bill.reviewedAt == null ? '' : dateTimeLabel(bill.reviewedAt!),
          bill.slipFileName ?? '',
          bill.rejectReason ?? '',
        ];
      }),
    ];

    final cashflowRows = <List<Object?>>[
      [
        'Year',
        'Month',
        'Facility',
        'Rent Inflow',
        'Electricity Inflow',
        'Water Inflow',
        'Internet Inflow',
        'Parking Inflow',
        'Other Inflow',
        'Total Inflow',
        'Installment',
        'Extra Payment',
        'Maintenance',
        'Insurance',
        'Recurring Commitments',
        'One-time Expenses',
        'Total Outflow',
        'Net Cashflow',
      ],
      for (final year in years)
        for (var month = 1; month <= 12; month++)
          for (final facility in ownerFacilities)
            _monthlyCashflowExportRow(facility, year, month),
    ];

    final expenseRows = <List<Object?>>[
      ['Month', 'Facility', 'Category', 'Amount', 'Type', 'Note'],
      for (final year in years)
        for (var month = 1; month <= 12; month++)
          for (final facility in ownerFacilities)
            ..._monthlyExpenseExportRows(facility, year, month),
    ];

    final requestRows = <List<Object?>>[
      [
        'Request ID',
        'Facility',
        'Tenant',
        'Type',
        'Title',
        'Message',
        'Status',
        'Created At',
        'Reviewed At',
        'Attachment',
        'Attachment Size',
      ],
      ...tenantRequests.map((request) {
        final facility = facilityFor(request.facilityId);
        final tenant = userFor(request.tenantId);
        return [
          request.id,
          facility.name,
          tenant.name,
          request.requestType,
          request.title,
          request.message,
          request.status,
          dateTimeLabel(request.createdAt),
          request.reviewedAt == null ? '' : dateTimeLabel(request.reviewedAt!),
          request.attachmentFileName ?? '',
          request.attachmentSizeBytes == null
              ? ''
              : fileSizeLabel(request.attachmentSizeBytes!),
        ];
      }),
    ];

    final reviewRows = <List<Object?>>[
      ['Review ID', 'Bill ID', 'Status', 'Timestamp', 'Reason'],
      ...paymentReviewHistory.map((event) => [
            event.id,
            event.billId,
            paymentStatusLabel(event.status),
            dateTimeLabel(event.timestamp),
            event.reason ?? '',
          ]),
    ];

    return '''<?xml version="1.0"?>
<?mso-application progid="Excel.Sheet"?>
<Workbook xmlns="urn:schemas-microsoft-com:office:spreadsheet"
 xmlns:o="urn:schemas-microsoft-com:office:office"
 xmlns:x="urn:schemas-microsoft-com:office:excel"
 xmlns:ss="urn:schemas-microsoft-com:office:spreadsheet">
 <Styles>
  <Style ss:ID="Default" ss:Name="Normal">
   <Alignment ss:Vertical="Center"/>
   <Font ss:FontName="Arial" ss:Size="10"/>
  </Style>
 </Styles>
 ${worksheet('Dashboard', dashboardRows)}
 ${worksheet('Properties & Tenants', propertyRows)}
 ${worksheet('Tenant Rent Schedule', billRows)}
 ${worksheet('Monthly Cashflow', cashflowRows)}
 ${worksheet('Expense Log', expenseRows)}
 ${worksheet('Tenant Requests', requestRows)}
 ${worksheet('Payment Reviews', reviewRows)}
</Workbook>''';
  }

  Uint8List exportDetailedExcelWorkbookXlsx() {
    final years = <int>{
      _now.year,
      ...bills.map((bill) => bill.month.year),
      ...additionalIncomes.map((income) => income.month.year),
      ...additionalExpenses.map((expense) => expense.month.year),
    }.toList()
      ..sort();

    final currentYearReports = facilityReportsForYear(_now.year);
    final totalIn =
        currentYearReports.fold<double>(0, (sum, r) => sum + r.inflow);
    final totalOut =
        currentYearReports.fold<double>(0, (sum, r) => sum + r.outflow);
    final dashboardRows = <List<Object?>>[
      ['Rental Facility Management Export'],
      ['Generated', dateTimeLabel(DateTime.now())],
      [],
      ['Metric', 'Total'],
      ['Total Rental Collection', totalIn],
      ['Total Expenses', totalOut],
      ['Net Rental Income', totalIn - totalOut],
      ['Properties', ownerFacilities.length],
      ['Active Tenants', tenancies.where((item) => item.active).length],
      [],
      ['Facility', 'Tenants', 'Inflow', 'Outflow', 'Net Cashflow', 'Margin %'],
      ...currentYearReports.map((report) => [
            report.facility.name,
            tenancies
                .where((tenancy) => tenancy.facilityId == report.facility.id)
                .length,
            report.inflow,
            report.outflow,
            report.netCashflow,
            report.inflow == 0 ? 0 : report.netCashflow / report.inflow,
          ]),
      [],
      ['Year', 'Month', 'Collection', 'Expenses', 'Net Cashflow'],
      for (final year in years)
        for (final summary in yearlyFinancialSummary(year))
          [
            year,
            FinancialChartPainter.monthNames[summary.month - 1],
            summary.collection,
            summary.expenses,
            summary.collection - summary.expenses,
          ],
    ];

    final propertyRows = <List<Object?>>[
      [
        'Facility',
        'Address',
        'Status',
        'Installment',
        'Extra Payment',
        'Maintenance',
        'Insurance',
        'Insurance Frequency',
        'Insurance Month',
        'Tenant',
        'Unit',
        'Monthly Rent',
        'Lease Start',
        'Lease End',
        'Electricity Package',
        'Water Package',
        'Internet Package',
        'Car Park',
        'Agreement File',
      ],
      for (final facility in ownerFacilities)
        ...tenancies
            .where((tenancy) => tenancy.facilityId == facility.id)
            .map((tenancy) {
          final tenant = userFor(tenancy.tenantId);
          final version = costVersionForMonth(facility, _now);
          return [
            facility.name,
            facility.address,
            facilityStatusText(facility),
            version.installmentAmount,
            version.extraInstallmentPayment,
            version.maintenanceFee,
            version.insuranceFee,
            insuranceFrequencyLabel(version.insuranceFrequency),
            FinancialChartPainter.monthNames[version.insuranceDueMonth - 1],
            tenant.name,
            tenancy.unitName,
            tenancy.monthlyRent,
            dateLabel(tenancy.leaseStart),
            dateLabel(tenancy.leaseEnd),
            tenancy.electricityPackage.name,
            tenancy.waterPackage.name,
            tenancy.internetPackage.name,
            tenancy.carParkIncluded ? tenancy.carParkDetails : 'Not included',
            tenancy.agreementFileName ?? '',
          ];
        }),
    ];

    final billRows = <List<Object?>>[
      [
        'Bill ID',
        'Facility',
        'Tenant',
        'Unit',
        'Month',
        'Rent',
        'Air-con Electricity kWh',
        'Air-con Electricity',
        'General Electricity',
        'Water',
        'Internet',
        'Parking Rental',
        'Total Utilities',
        'Total Due',
        'Amount Paid',
        'Payment Date',
        'Payment Reference',
        'Status',
        'Submitted At',
        'Reviewed At',
        'Slip File',
        'Reject Reason',
      ],
      ...bills.map((bill) {
        final facility = facilityFor(bill.facilityId);
        final tenant = userFor(bill.tenantId);
        final tenancy = tenancies.firstWhere(
          (item) =>
              item.facilityId == bill.facilityId &&
              item.tenantId == bill.tenantId,
          orElse: () => Tenancy(
            id: '',
            facilityId: bill.facilityId,
            tenantId: bill.tenantId,
            unitName: '',
            monthlyRent: bill.rentAmount,
            leaseStart: bill.month,
            leaseEnd: bill.month,
            electricityPackage: UtilityPackage.excluded,
            electricityCharge: 0,
            waterPackage: UtilityPackage.excluded,
            waterCharge: 0,
            internetPackage: UtilityPackage.excluded,
            internetCharge: 0,
          ),
        );
        return [
          bill.id,
          facility.name,
          tenant.name,
          tenancy.unitName,
          monthLabel(bill.month),
          bill.rentAmount,
          bill.electricityUsageKwh,
          bill.electricityAmount,
          bill.generalElectricAmount,
          bill.waterAmount,
          bill.internetAmount,
          bill.parkingRentalAmount,
          bill.totalUtilityAmount,
          bill.totalAmount,
          bill.amountPaid,
          bill.paymentDate == null ? '' : dateLabel(bill.paymentDate!),
          bill.paymentReference ?? '',
          paymentStatusLabel(bill.status),
          bill.submittedAt == null ? '' : dateTimeLabel(bill.submittedAt!),
          bill.reviewedAt == null ? '' : dateTimeLabel(bill.reviewedAt!),
          bill.slipFileName ?? '',
          bill.rejectReason ?? '',
        ];
      }),
    ];

    final cashflowRows = <List<Object?>>[
      [
        'Year',
        'Month',
        'Facility',
        'Rent Inflow',
        'Electricity Inflow',
        'Water Inflow',
        'Internet Inflow',
        'Parking Inflow',
        'Other Inflow',
        'Total Inflow',
        'Installment',
        'Extra Payment',
        'Maintenance',
        'Insurance',
        'Recurring Commitments',
        'One-time Expenses',
        'Total Outflow',
        'Net Cashflow',
      ],
      for (final year in years)
        for (var month = 1; month <= 12; month++)
          for (final facility in ownerFacilities)
            _monthlyCashflowExportRow(facility, year, month),
    ];

    final expenseRows = <List<Object?>>[
      ['Month', 'Facility', 'Category', 'Amount', 'Type', 'Note'],
      for (final year in years)
        for (var month = 1; month <= 12; month++)
          for (final facility in ownerFacilities)
            ..._monthlyExpenseExportRows(facility, year, month),
    ];

    final requestRows = <List<Object?>>[
      [
        'Request ID',
        'Facility',
        'Tenant',
        'Type',
        'Title',
        'Message',
        'Status',
        'Created At',
        'Reviewed At',
        'Attachment',
        'Attachment Size',
      ],
      ...tenantRequests.map((request) {
        final facility = facilityFor(request.facilityId);
        final tenant = userFor(request.tenantId);
        return [
          request.id,
          facility.name,
          tenant.name,
          request.requestType,
          request.title,
          request.message,
          request.status,
          dateTimeLabel(request.createdAt),
          request.reviewedAt == null ? '' : dateTimeLabel(request.reviewedAt!),
          request.attachmentFileName ?? '',
          request.attachmentSizeBytes == null
              ? ''
              : fileSizeLabel(request.attachmentSizeBytes!),
        ];
      }),
    ];

    final reviewRows = <List<Object?>>[
      ['Review ID', 'Bill ID', 'Status', 'Timestamp', 'Reason'],
      ...paymentReviewHistory.map((event) => [
            event.id,
            event.billId,
            paymentStatusLabel(event.status),
            dateTimeLabel(event.timestamp),
            event.reason ?? '',
          ]),
    ];

    return buildRentalManagerXlsx({
      'Dashboard': dashboardRows,
      'Properties & Tenants': propertyRows,
      'Tenant Rent Schedule': billRows,
      'Monthly Cashflow': cashflowRows,
      'Expense Log': expenseRows,
      'Tenant Requests': requestRows,
      'Payment Reviews': reviewRows,
    });
  }

  List<Object?> _monthlyCashflowExportRow(
      Facility facility, int year, int month) {
    final monthDate = DateTime(year, month);
    final facilityBills = bills.where((bill) =>
        bill.facilityId == facility.id &&
        bill.month.year == year &&
        bill.month.month == month &&
        bill.status == PaymentStatus.approved);
    final rent =
        facilityBills.fold<double>(0, (sum, bill) => sum + bill.rentAmount);
    final electricity = facilityBills.fold<double>(
      0,
      (sum, bill) => sum + bill.electricityAmount + bill.generalElectricAmount,
    );
    final water =
        facilityBills.fold<double>(0, (sum, bill) => sum + bill.waterAmount);
    final internet =
        facilityBills.fold<double>(0, (sum, bill) => sum + bill.internetAmount);
    final parking = facilityBills.fold<double>(
        0, (sum, bill) => sum + bill.parkingRentalAmount);
    final otherIncome = additionalIncomes
        .where((income) =>
            income.facilityId == facility.id &&
            income.month.year == year &&
            income.month.month == month)
        .fold<double>(0, (sum, income) => sum + income.amount);
    final version = costVersionForMonth(facility, monthDate);
    final insuranceDue = month == version.insuranceDueMonth ||
        (version.insuranceFrequency == InsuranceFrequency.halfYearly &&
            month == ((version.insuranceDueMonth + 5) % 12) + 1);
    final recurringCommitments = facility.extraCommitments.fold<double>(
      0,
      (sum, commitment) =>
          sum +
          scheduledCommitmentAmount(
            commitment.amount,
            commitment.frequency,
            commitment.firstDueMonth,
            month,
          ),
    );
    final oneTimeExpenses = additionalExpenses
        .where((expense) =>
            expense.facilityId == facility.id &&
            expense.month.year == year &&
            expense.month.month == month)
        .fold<double>(0, (sum, expense) => sum + expense.amount);
    final totalInflow =
        rent + electricity + water + internet + parking + otherIncome;
    final totalOutflow = version.installmentAmount +
        version.extraInstallmentPayment +
        version.maintenanceFee +
        (insuranceDue ? version.insuranceFee : 0) +
        recurringCommitments +
        oneTimeExpenses;
    return [
      year,
      FinancialChartPainter.monthNames[month - 1],
      facility.name,
      rent,
      electricity,
      water,
      internet,
      parking,
      otherIncome,
      totalInflow,
      version.installmentAmount,
      version.extraInstallmentPayment,
      version.maintenanceFee,
      insuranceDue ? version.insuranceFee : 0,
      recurringCommitments,
      oneTimeExpenses,
      totalOutflow,
      totalInflow - totalOutflow,
    ];
  }

  List<List<Object?>> _monthlyExpenseExportRows(
    Facility facility,
    int year,
    int month,
  ) {
    final monthDate = DateTime(year, month);
    final version = costVersionForMonth(facility, monthDate);
    final insuranceDue = month == version.insuranceDueMonth ||
        (version.insuranceFrequency == InsuranceFrequency.halfYearly &&
            month == ((version.insuranceDueMonth + 5) % 12) + 1);
    final rows = <List<Object?>>[
      [
        monthLabel(monthDate),
        facility.name,
        'Installment',
        version.installmentAmount,
        'Recurring',
        ''
      ],
      [
        monthLabel(monthDate),
        facility.name,
        'Extra Payment',
        version.extraInstallmentPayment,
        'Recurring',
        ''
      ],
      [
        monthLabel(monthDate),
        facility.name,
        'Maintenance',
        version.maintenanceFee,
        'Recurring',
        ''
      ],
      if (insuranceDue)
        [
          monthLabel(monthDate),
          facility.name,
          'Insurance',
          version.insuranceFee,
          insuranceFrequencyLabel(version.insuranceFrequency),
          ''
        ],
      ...facility.extraCommitments.where((commitment) {
        return isCommitmentDue(
            commitment.frequency, commitment.firstDueMonth, month);
      }).map((commitment) => [
            monthLabel(monthDate),
            facility.name,
            commitment.name,
            commitment.amount,
            commitmentFrequencyLabel(commitment.frequency),
            '',
          ]),
      ...additionalExpenses
          .where((expense) =>
              expense.facilityId == facility.id &&
              expense.month.year == year &&
              expense.month.month == month)
          .map((expense) => [
                monthLabel(expense.month),
                facility.name,
                expense.category,
                expense.amount,
                'One-time',
                expense.note,
              ]),
    ];
    return rows.where((row) => (row[3] as num).toDouble() != 0).toList();
  }

  List<MonthlyBill> get pendingBills {
    return bills
        .where((bill) => bill.status == PaymentStatus.pendingApproval)
        .toList()
      ..sort((a, b) => b.submittedAt?.compareTo(a.submittedAt ?? b.month) ?? 0);
  }

  List<MonthlyBill> get pendingUtilityBillsThisMonth {
    final facilityIds = ownerFacilities.map((item) => item.id).toSet();
    return bills.where((bill) {
      return facilityIds.contains(bill.facilityId) &&
          bill.month.year == currentMonth.year &&
          bill.month.month == currentMonth.month &&
          (bill.status == PaymentStatus.notSubmitted ||
              bill.status == PaymentStatus.rejected);
    }).toList()
      ..sort((a, b) => a.facilityId.compareTo(b.facilityId));
  }

  List<MonthlyBill> billsForTenant(String tenantId) {
    return bills.where((bill) => bill.tenantId == tenantId).toList()
      ..sort((a, b) => b.month.compareTo(a.month));
  }

  List<MonthlyFinancialSummary> yearlyFinancialSummary(int year) {
    final facilityIds = ownerFacilities.map((facility) => facility.id).toSet();
    return List.generate(12, (index) {
      final month = index + 1;
      final isFutureMonth = DateTime(year, month).isAfter(
        DateTime(_now.year, _now.month),
      );
      if (isFutureMonth) {
        return MonthlyFinancialSummary(
          month: month,
          collection: 0,
          expenses: 0,
        );
      }
      final monthlyCollection = bills.where((bill) {
        return facilityIds.contains(bill.facilityId) &&
            bill.month.year == year &&
            bill.month.month == month &&
            bill.status == PaymentStatus.approved;
      }).fold<double>(0, (sum, bill) => sum + bill.totalAmount);
      final otherIncome = additionalIncomes.where((income) {
        return facilityIds.contains(income.facilityId) &&
            income.month.year == year &&
            income.month.month == month;
      }).fold<double>(0, (sum, income) => sum + income.amount);
      return MonthlyFinancialSummary(
        month: month,
        collection: monthlyCollection + otherIncome,
        expenses: ownerFacilities.fold<double>(
          0,
          (sum, facility) =>
              sum + facilityExpenseForMonth(facility, year, month),
        ),
      );
    });
  }

  List<FinancialBreakdownItem> monthlyCollectionBreakdown(
    int year,
    int month,
  ) {
    if (!isCurrentOrPastMonth(DateTime(year, month))) return [];
    final facilityIds = ownerFacilities.map((facility) => facility.id).toSet();
    final items = <FinancialBreakdownItem>[];
    for (final bill in bills.where((bill) {
      return facilityIds.contains(bill.facilityId) &&
          bill.month.year == year &&
          bill.month.month == month &&
          bill.status == PaymentStatus.approved;
    })) {
      final tenancy = tenancies.firstWhere(
        (item) =>
            item.tenantId == bill.tenantId &&
            item.facilityId == bill.facilityId,
      );
      items.add(
        FinancialBreakdownItem(
          label:
              '${userFor(bill.tenantId).name} • ${tenancy.unitName} • ${facilityFor(bill.facilityId).name}',
          amount: bill.totalAmount,
        ),
      );
    }
    for (final income in additionalIncomes.where((income) {
      return facilityIds.contains(income.facilityId) &&
          income.month.year == year &&
          income.month.month == month;
    })) {
      items.add(
        FinancialBreakdownItem(
          label: '${income.category} • ${facilityFor(income.facilityId).name}',
          amount: income.amount,
        ),
      );
    }
    return items;
  }

  List<FinancialBreakdownItem> monthlyExpenseBreakdown(int year, int month) {
    if (!isCurrentOrPastMonth(DateTime(year, month))) return [];
    final items = <FinancialBreakdownItem>[];
    for (final facility in ownerFacilities) {
      final version = costVersionForMonth(facility, DateTime(year, month));
      final insuranceDue = month == version.insuranceDueMonth ||
          (version.insuranceFrequency == InsuranceFrequency.halfYearly &&
              month == ((version.insuranceDueMonth + 5) % 12) + 1);
      final costs = <(String, double)>[
        ('Installment', version.installmentAmount),
        ('Extra installment', version.extraInstallmentPayment),
        ('Maintenance', version.maintenanceFee),
        if (insuranceDue)
          (
            'Fire insurance (${insuranceFrequencyText(version.insuranceFrequency)})',
            version.insuranceFee,
          ),
        for (final commitment in facility.extraCommitments)
          if (isCommitmentDue(
            commitment.frequency,
            commitment.firstDueMonth,
            month,
          ))
            (
              '${commitment.name} (${commitmentFrequencyText(commitment.frequency)})',
              commitment.amount,
            ),
        for (final expense in additionalExpenses.where((expense) =>
            expense.facilityId == facility.id &&
            expense.month.year == year &&
            expense.month.month == month))
          ('${expense.category} (one-time)', expense.amount),
      ];
      for (final cost in costs.where((cost) => cost.$2 > 0)) {
        items.add(
          FinancialBreakdownItem(
            label: '${facility.name} • ${cost.$1}',
            amount: cost.$2,
          ),
        );
      }
    }
    return items;
  }

  void loginAs(UserRole role) {
    currentUser = users.firstWhere((user) => user.role == role);
    currentUser!.lastLoginAt = DateTime.now();
    _startPublicPaymentSync();
    notifyListeners();
  }

  bool signInLocalAccount({
    required String email,
    required String password,
    required UserRole role,
  }) {
    final normalizedEmail = email.trim().toLowerCase();
    final matches = localAuthAccounts.where(
      (account) =>
          account.email.toLowerCase() == normalizedEmail &&
          account.role == role,
    );
    if (matches.isEmpty) {
      throw StateError(
          'Account not found. Please create an owner account first.');
    }
    final account = matches.first;
    if (account.password != password) {
      throw StateError('Incorrect password.');
    }
    final userMatches = users.where((user) => user.id == account.userId);
    if (userMatches.isEmpty) {
      throw StateError('Account profile is missing.');
    }
    currentUser = userMatches.first;
    currentUser!.lastLoginAt = DateTime.now();
    _recordActivity('${currentUser!.name} signed in.');
    _startPublicPaymentSync();
    notifyListeners();
    return true;
  }

  void createLocalOwnerAccount({
    required String fullName,
    required String email,
    required String password,
  }) {
    final normalizedEmail = email.trim().toLowerCase();
    if (localAuthAccounts.any(
      (account) => account.email.toLowerCase() == normalizedEmail,
    )) {
      throw StateError('This email already has an account.');
    }
    final owner = users.firstWhere(
      (user) => user.role == UserRole.owner,
      orElse: () {
        final created = AppUser(
          id: 'owner_${users.length + 1}',
          name: fullName.trim(),
          email: normalizedEmail,
          role: UserRole.owner,
        );
        users.add(created);
        return created;
      },
    );
    owner.name = fullName.trim();
    owner.email = normalizedEmail;
    localAuthAccounts.add(
      LocalAuthAccount(
        userId: owner.id,
        email: normalizedEmail,
        password: password,
        role: UserRole.owner,
      ),
    );
    currentUser = owner;
    currentUser!.lastLoginAt = DateTime.now();
    _startPublicPaymentSync();
    _notify('Owner account was created for ${owner.email}.');
    notifyListeners();
  }

  void changeLocalAccountPassword({
    required String email,
    required UserRole role,
    required String currentPassword,
    required String newPassword,
  }) {
    final normalizedEmail = email.trim().toLowerCase();
    final matches = localAuthAccounts.where(
      (account) =>
          account.email.toLowerCase() == normalizedEmail &&
          account.role == role,
    );
    if (matches.isEmpty) {
      throw StateError('Account not found.');
    }
    final account = matches.first;
    if (account.password != currentPassword) {
      throw StateError('Current password is incorrect.');
    }
    if (newPassword.length < 8) {
      throw StateError('New password must be at least 8 characters.');
    }
    if (newPassword == currentPassword) {
      throw StateError('New password must be different from current password.');
    }
    account.password = newPassword;
    _notify('Owner account password was changed.');
    notifyListeners();
  }

  bool hasLocalAccount(String email, UserRole role) {
    final normalizedEmail = email.trim().toLowerCase();
    return localAuthAccounts.any(
      (account) =>
          account.email.toLowerCase() == normalizedEmail &&
          account.role == role,
    );
  }

  Future<void> restoreCloudSession() async {
    final auth = cloudAuth;
    if (auth == null || auth.currentSession == null) return;
    try {
      final profile = await auth.currentProfile();
      if (profile != null) {
        _applyCloudProfile(profile);
        await restoreCloudWorkspace(profile);
      }
    } catch (_) {
      await auth.signOut();
      currentUser = null;
      cloudProfile = null;
    }
  }

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final auth = cloudAuth;
    if (auth == null) throw StateError('Cloud authentication is unavailable.');
    final profile = await auth.signIn(email: email, password: password);
    _applyCloudProfile(profile);
    await restoreCloudWorkspace(profile);
  }

  Future<bool> registerCloudAccount({
    required String fullName,
    required String email,
    required String password,
    required String role,
  }) async {
    final auth = cloudAuth;
    if (auth == null) throw StateError('Cloud authentication is unavailable.');
    final signedIn = await auth.registerAccount(
      fullName: fullName,
      email: email,
      password: password,
      role: role,
    );
    if (signedIn) {
      final profile = await auth.currentProfile();
      if (profile != null) {
        _applyCloudProfile(profile);
        await restoreCloudWorkspace(profile);
      }
    }
    return signedIn;
  }

  Future<void> sendPasswordReset(String email) async {
    final auth = cloudAuth;
    if (auth == null) throw StateError('Cloud authentication is unavailable.');
    await auth.sendPasswordReset(email);
  }

  Future<void> cloudLogout() async {
    await cloudAuth?.signOut();
    logout();
  }

  void _applyCloudProfile(CloudProfile profile) {
    cloudProfile = profile;
    final role = switch (profile.role) {
      'owner' => UserRole.owner,
      'property_agent' => UserRole.propertyAgent,
      _ => UserRole.tenant,
    };
    if (role == UserRole.tenant) {
      final matches = users.where(
        (user) =>
            user.role == role &&
            user.email.toLowerCase() == profile.email.toLowerCase(),
      );
      currentUser = matches.isNotEmpty
          ? matches.first
          : AppUser(
              id: profile.id,
              name: profile.fullName,
              email: profile.email,
              role: role,
            );
    } else {
      final templates = users.where((user) => user.role == role);
      final template = templates.isEmpty ? null : templates.first;
      currentUser = AppUser(
        id: template?.id ?? profile.id,
        name: profile.fullName,
        email: profile.email,
        role: role,
        avatarStyle: template?.avatarStyle ?? 0,
        paymentReminderAfterDays: template?.paymentReminderAfterDays ?? 3,
        paymentReminderFrequencyDays:
            template?.paymentReminderFrequencyDays ?? 2,
      );
    }
    _startPublicPaymentSync();
    notifyListeners();
  }

  void addTenantToFacility({
    required Facility facility,
    required String fullName,
    required String email,
    String phoneNumber = '',
    required String originAddress,
    required DateTime dateOfBirth,
    required String sex,
    required String unitName,
    required double monthlyRent,
    required DateTime leaseStart,
    required DateTime leaseEnd,
    required UtilityPackage electricityPackage,
    required UtilityPackage waterPackage,
    required UtilityPackage internetPackage,
    required bool carParkIncluded,
    required String carParkDetails,
  }) {
    final tenantId = 'tenant_${users.length + 1}';
    final tenant = AppUser(
      id: tenantId,
      name: fullName,
      email: email,
      phoneNumber: phoneNumber,
      role: UserRole.tenant,
      originAddress: originAddress,
      dateOfBirth: dateOfBirth,
      sex: sex,
      profileComplete: false,
    );
    users.add(tenant);
    tenancies.add(
      Tenancy(
        id: 'tenancy_${tenancies.length + 1}',
        facilityId: facility.id,
        tenantId: tenantId,
        unitName: unitName,
        monthlyRent: monthlyRent,
        electricityPackage: electricityPackage,
        electricityCharge: 0,
        waterPackage: waterPackage,
        waterCharge: 0,
        internetPackage: internetPackage,
        internetCharge: 0,
        leaseStart: leaseStart,
        leaseEnd: leaseEnd,
        carParkIncluded: carParkIncluded,
        carParkDetails:
            carParkIncluded ? carParkDetails : 'Not included in agreement',
      ),
    );
    _ensureCurrentMonthUtilityBills();
    _ensureMonthlyInvoicePreparationNotification();
    _notify('$fullName was added to ${facility.name}, $unitName.');
    notifyListeners();
  }

  void sendTenantInvitation(AppUser tenant) {
    tenant.invitationSentAt = DateTime.now();
    _notify(
        'Profile invitation prepared for ${tenant.name} at ${tenant.email}.');
    notifyListeners();
  }

  Future<void> sendSecureTenantInvitation(AppUser tenant) async {
    final auth = cloudAuth;
    if (auth == null) {
      sendTenantInvitation(tenant);
      return;
    }
    await flushCloudPersistence();
    await auth.inviteTenant(email: tenant.email, fullName: tenant.name);
    sendTenantInvitation(tenant);
  }

  void acceptTenantInvitation(AppUser tenant) {
    if (!tenant.invitationSent) return;
    tenant.accountCreatedAt = DateTime.now();
    tenant.profileComplete = true;
    _notify(
        '${tenant.name} accepted the invitation and created a tenant account.');
    notifyListeners();
  }

  void logout() {
    _publicPaymentSyncTimer?.cancel();
    currentUser = null;
    cloudProfile = null;
    notifyListeners();
  }

  Facility? addFacility({
    required String name,
    required String addressLine,
    required String postcode,
    required String city,
    required String state,
    required double installmentAmount,
    required double maintenanceFee,
    required double insuranceFee,
    InsuranceFrequency insuranceFrequency = InsuranceFrequency.yearly,
    int insuranceDueMonth = 1,
    List<RecurringCommitment>? extraCommitments,
  }) {
    final owner = currentUser;
    if (owner == null) return null;
    final facility = Facility(
      id: 'facility_${facilities.length + 1}',
      ownerId: owner.id,
      name: name,
      addressLine: addressLine,
      postcode: postcode,
      city: city,
      state: state,
      installmentAmount: installmentAmount,
      maintenanceFee: maintenanceFee,
      insuranceFee: insuranceFee,
      insuranceFrequency: insuranceFrequency,
      insuranceDueMonth: insuranceDueMonth,
      extraCommitments: extraCommitments,
      initialCostEffectiveMonth: DateTime(_now.year, _now.month),
    );
    facilities.add(facility);
    _notify('Owner created a new facility: $name.');
    notifyListeners();
    return facility;
  }

  void updateFacilityCosts(
    Facility facility, {
    required double installmentAmount,
    required double extraInstallmentPayment,
    required double maintenanceFee,
    required double insuranceFee,
    required InsuranceFrequency insuranceFrequency,
    required int insuranceDueMonth,
  }) {
    final effectiveMonth = currentMonth;
    facility.costHistory.removeWhere(
      (version) =>
          !version.initial &&
          version.effectiveMonth.year == effectiveMonth.year &&
          version.effectiveMonth.month == effectiveMonth.month,
    );
    facility.costHistory.add(
      FacilityCostVersion(
        id: 'cost_${facility.id}_${facility.costHistory.length + 1}',
        effectiveMonth: effectiveMonth,
        recordedAt: _now,
        installmentAmount: installmentAmount,
        extraInstallmentPayment: extraInstallmentPayment,
        maintenanceFee: maintenanceFee,
        insuranceFee: insuranceFee,
        insuranceFrequency: insuranceFrequency,
        insuranceDueMonth: insuranceDueMonth,
      ),
    );
    facility.installmentAmount = installmentAmount;
    facility.extraInstallmentPayment = extraInstallmentPayment;
    facility.maintenanceFee = maintenanceFee;
    facility.insuranceFee = insuranceFee;
    facility.insuranceFrequency = insuranceFrequency;
    facility.insuranceDueMonth = insuranceDueMonth;
    _notify(
      '${facility.name} cost changes were applied from ${monthLabel(effectiveMonth)}.',
    );
    notifyListeners();
  }

  void addRecurringCommitment({
    required Facility facility,
    required String name,
    required double amount,
    required CommitmentFrequency frequency,
    required int firstDueMonth,
  }) {
    if (name.trim().isEmpty || amount <= 0) return;
    facility.extraCommitments.add(
      RecurringCommitment(
        id: 'commitment_${facility.id}_${facility.extraCommitments.length + 1}',
        name: name.trim(),
        amount: amount,
        frequency: frequency,
        firstDueMonth: firstDueMonth,
      ),
    );
    _notify('${name.trim()} commitment was added to ${facility.name}.');
    notifyListeners();
  }

  void updateRecurringCommitment(
    RecurringCommitment commitment, {
    required String name,
    required double amount,
    required CommitmentFrequency frequency,
    required int firstDueMonth,
  }) {
    if (name.trim().isEmpty || amount <= 0) return;
    commitment.name = name.trim();
    commitment.amount = amount;
    commitment.frequency = frequency;
    commitment.firstDueMonth = firstDueMonth;
    _notify('${commitment.name} commitment was updated.');
    notifyListeners();
  }

  void markFacilitySold(Facility facility) {
    facility.status = FacilityStatus.sold;
    facility.soldAt = DateTime.now();
    for (final tenancy in tenancies.where((item) {
      return item.facilityId == facility.id;
    })) {
      tenancy.active = false;
    }
    _notify('${facility.name} was marked as sold and inactive.');
    notifyListeners();
  }

  void removeSoldFacility(Facility facility) {
    if (facility.status != FacilityStatus.sold) return;
    bills.removeWhere((bill) => bill.facilityId == facility.id);
    tenancies.removeWhere((tenancy) => tenancy.facilityId == facility.id);
    tenantRequests.removeWhere((request) => request.facilityId == facility.id);
    additionalIncomes.removeWhere((income) => income.facilityId == facility.id);
    additionalExpenses
        .removeWhere((expense) => expense.facilityId == facility.id);
    facilities.removeWhere((item) => item.id == facility.id);
    _notify('${facility.name} was removed after confirmation.');
    notifyListeners();
  }

  void updateBillUtilities(
    MonthlyBill bill, {
    required double electricityUsageKwh,
    required double waterAmount,
    required double internetAmount,
    double generalElectricAmount = 0,
    double parkingRentalAmount = 0,
    required String utilityEvidenceFileName,
    Uint8List? utilityEvidenceBytes,
  }) {
    bill.electricityUsageKwh = electricityUsageKwh;
    bill.electricityAmount = calculateElectricityCharge(electricityUsageKwh);
    bill.waterAmount = waterAmount;
    bill.internetAmount = internetAmount;
    bill.generalElectricAmount = generalElectricAmount;
    bill.parkingRentalAmount = parkingRentalAmount;
    bill.utilityEvidenceFileName = utilityEvidenceFileName.trim().isEmpty
        ? null
        : utilityEvidenceFileName.trim();
    bill.utilityEvidenceBytes = utilityEvidenceBytes;
    bill.status = PaymentStatus.pendingTenantPayment;
    final tenant = users.firstWhere((user) => user.id == bill.tenantId);
    _notify(
      '${tenant.name} bill is ready and pending tenant payment: ${money(bill.totalAmount)}.',
    );
    notifyListeners();
  }

  void updateTenantProfile(
    AppUser tenant, {
    required String name,
    required String email,
    required String phoneNumber,
    required String originAddress,
    required DateTime? dateOfBirth,
    required String sex,
    required String accountStatus,
  }) {
    tenant.name = name.trim();
    tenant.email = email.trim().toLowerCase();
    tenant.phoneNumber = phoneNumber.trim();
    tenant.originAddress = originAddress.trim();
    tenant.dateOfBirth = dateOfBirth;
    tenant.sex = sex.trim();
    tenant.accountStatus = accountStatus;
    _notify('${tenant.name} profile was updated.');
    notifyListeners();
  }

  void updateTenantContract(
    Tenancy tenancy, {
    required String unitName,
    required double monthlyRent,
    required DateTime leaseStart,
    required DateTime leaseEnd,
    required UtilityPackage electricityPackage,
    required UtilityPackage waterPackage,
    required UtilityPackage internetPackage,
    required bool carParkIncluded,
    required String carParkDetails,
  }) {
    tenancy.unitName = unitName.trim();
    tenancy.monthlyRent = monthlyRent;
    tenancy.leaseStart = leaseStart;
    tenancy.leaseEnd = leaseEnd;
    tenancy.electricityPackage = electricityPackage;
    tenancy.waterPackage = waterPackage;
    tenancy.internetPackage = internetPackage;
    tenancy.carParkIncluded = carParkIncluded;
    tenancy.carParkDetails = carParkDetails.trim();
    _notify(
        'Contract and package updated for ${userFor(tenancy.tenantId).name}.');
    notifyListeners();
  }

  void submitPaymentSlip(
    MonthlyBill bill,
    String fileName,
    double amountPaid, {
    Uint8List? slipBytes,
  }) {
    bill.slipFileName = fileName;
    bill.slipBytes = slipBytes;
    bill.amountPaid = amountPaid;
    bill.submittedAt = DateTime.now();
    bill.status = PaymentStatus.pendingApproval;
    bill.rejectReason = null;
    final tenant = users.firstWhere((user) => user.id == bill.tenantId);
    _notify(
        '${tenant.name} submitted payment slip for ${monthLabel(bill.month)}.');
    notifyListeners();
  }

  void _startPublicPaymentSync() {
    _publicPaymentSyncTimer?.cancel();
    if (!isOwner || !cloudAuthEnabled) return;
    unawaited(syncPublicInvoicePayments());
    _publicPaymentSyncTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => unawaited(syncPublicInvoicePayments()),
    );
  }

  Future<void> syncPublicInvoicePayments() async {
    if (!isOwner || !cloudAuthEnabled) return;
    try {
      final rows = await Supabase.instance.client
          .from('rentflow_test_invoices')
          .select(
            'id,status,slip_name,slip_path,amount_paid,payment_date,payment_reference,slip_submitted_at',
          )
          .eq('status', 'slipSubmitted');
      var changed = false;
      for (final row in rows) {
        final invoiceId = row['id'] as String?;
        if (invoiceId == null) continue;
        final matches = bills.where(
          (bill) => 'INV-${bill.id.toUpperCase()}' == invoiceId,
        );
        if (matches.isEmpty) continue;
        final bill = matches.first;
        final slipName = row['slip_name'] as String?;
        if (bill.status == PaymentStatus.pendingApproval &&
            bill.slipFileName == slipName) {
          continue;
        }
        final slipPath = row['slip_path'] as String?;
        Uint8List? slipBytes;
        if (slipPath != null && slipPath.isNotEmpty) {
          slipBytes = await Supabase.instance.client.storage
              .from(RentFlowStore.bucket)
              .download(slipPath);
        }
        bill
          ..slipFileName = slipName
          ..slipBytes = slipBytes
          ..amountPaid = (row['amount_paid'] as num?)?.toDouble() ?? 0
          ..paymentDate = row['payment_date'] == null
              ? null
              : DateTime.tryParse(row['payment_date'] as String)
          ..paymentReference = row['payment_reference'] as String?
          ..submittedAt = row['slip_submitted_at'] == null
              ? DateTime.now()
              : DateTime.tryParse(row['slip_submitted_at'] as String)
          ..status = PaymentStatus.pendingApproval
          ..rejectReason = null;
        final tenant = userFor(bill.tenantId);
        _notify(
          '${tenant.name} submitted payment proof for ${monthLabel(bill.month)}. Review is required.',
        );
        changed = true;
      }
      if (changed) notifyListeners();
    } catch (error) {
      persistenceError = 'Payment sync: $error';
      super.notifyListeners();
    }
  }

  Future<void> _updatePublicInvoiceStatus(
    MonthlyBill bill,
    String status, {
    bool clearSlip = false,
  }) async {
    if (!cloudAuthEnabled) return;
    try {
      final values = <String, dynamic>{'status': status};
      if (clearSlip) {
        values.addAll({
          'slip_name': null,
          'slip_path': null,
          'amount_paid': null,
          'payment_date': null,
          'payment_reference': null,
          'slip_submitted_at': null,
        });
      }
      await Supabase.instance.client
          .from('rentflow_test_invoices')
          .update(values)
          .eq('id', 'INV-${bill.id.toUpperCase()}');
    } catch (error) {
      persistenceError = 'Invoice status sync: $error';
      super.notifyListeners();
    }
  }

  void approveBill(MonthlyBill bill) {
    bill.status = PaymentStatus.approved;
    bill.rejectReason = null;
    bill.reviewedAt = DateTime.now();
    paymentReviewHistory.add(
      PaymentReviewEvent(
        id: 'review_${paymentReviewHistory.length + 1}',
        billId: bill.id,
        status: PaymentStatus.approved,
        timestamp: bill.reviewedAt!,
      ),
    );
    final tenant = users.firstWhere((user) => user.id == bill.tenantId);
    _notify('Payment approved for ${tenant.name}, ${monthLabel(bill.month)}.');
    unawaited(_updatePublicInvoiceStatus(bill, 'paid'));
    notifyListeners();
  }

  void rejectBill(MonthlyBill bill, String reason) {
    bill.status = PaymentStatus.rejected;
    bill.rejectReason = reason;
    bill.reviewedAt = DateTime.now();
    paymentReviewHistory.add(
      PaymentReviewEvent(
        id: 'review_${paymentReviewHistory.length + 1}',
        billId: bill.id,
        status: PaymentStatus.rejected,
        timestamp: bill.reviewedAt!,
        reason: reason,
      ),
    );
    final tenant = users.firstWhere((user) => user.id == bill.tenantId);
    _notify(
      'Payment rejected for ${tenant.name}. Please resubmit: $reason',
    );
    unawaited(
      _updatePublicInvoiceStatus(bill, 'sent', clearSlip: true),
    );
    notifyListeners();
  }

  void addTenantRequest({
    required String requestType,
    required String title,
    required String message,
    String? attachmentFileName,
    String? attachmentBase64,
    int? attachmentSizeBytes,
  }) {
    final user = currentUser;
    final tenancy = tenantTenancies.isEmpty ? null : tenantTenancies.first;
    if (user == null || tenancy == null) return;
    tenantRequests.add(
      TenantRequest(
        id: 'request_${tenantRequests.length + 1}',
        tenantId: user.id,
        facilityId: tenancy.facilityId,
        title: title,
        message: message,
        createdAt: DateTime.now(),
        requestType: requestType,
        attachmentFileName: attachmentFileName,
        attachmentBase64: attachmentBase64,
        attachmentSizeBytes: attachmentSizeBytes,
      ),
    );
    _notify('${user.name} submitted a request: $title.');
    notifyListeners();
  }

  void reviewTenantRequest(TenantRequest request, String status) {
    request.status = status;
    request.reviewedAt = DateTime.now();
    final tenant = userFor(request.tenantId);
    _notify('${tenant.name} request "${request.title}" was $status.');
    notifyListeners();
  }

  void addAdditionalIncome({
    required Facility facility,
    required DateTime month,
    required String category,
    required double amount,
    required String note,
  }) {
    additionalIncomes.add(
      AdditionalIncome(
        id: 'income_${additionalIncomes.length + 1}',
        facilityId: facility.id,
        month: DateTime(month.year, month.month),
        category: category,
        amount: amount,
        note: note,
      ),
    );
    _notify(
      '${money(amount)} $category income added to ${facility.name} for ${monthLabel(month)}.',
    );
    notifyListeners();
  }

  void addAdditionalExpense({
    required Facility facility,
    required String category,
    required double amount,
    required String note,
  }) {
    if (category.trim().isEmpty || amount <= 0) return;
    additionalExpenses.add(
      AdditionalExpense(
        id: 'expense_${additionalExpenses.length + 1}',
        facilityId: facility.id,
        month: currentMonth,
        category: category.trim(),
        amount: amount,
        note: note.trim(),
      ),
    );
    _notify(
      '${money(amount)} ${category.trim()} expense added to ${facility.name} for ${monthLabel(currentMonth)}.',
    );
    notifyListeners();
  }

  void updateReminderSettings({
    required int afterDays,
    required int frequencyDays,
  }) {
    final user = currentUser;
    if (user == null) return;
    user.paymentReminderAfterDays = afterDays;
    user.paymentReminderFrequencyDays = frequencyDays;
    _notify('Payment reminder settings were updated.');
    notifyListeners();
  }

  void updateOwnerAccount({
    required String name,
    required String email,
    required String phoneNumber,
    required String originAddress,
    required int avatarStyle,
    required int paymentReminderAfterDays,
    required int paymentReminderFrequencyDays,
  }) {
    final user = currentUser;
    if (user == null) return;
    final previousEmail = user.email.trim().toLowerCase();
    user.name = name.trim();
    user.email = email.trim();
    user.phoneNumber = phoneNumber.trim();
    user.originAddress =
        originAddress.trim().isEmpty ? null : originAddress.trim();
    user.avatarStyle = avatarStyle;
    user.paymentReminderAfterDays = paymentReminderAfterDays;
    user.paymentReminderFrequencyDays = paymentReminderFrequencyDays;
    for (final account in localAuthAccounts.where(
      (account) =>
          account.userId == user.id ||
          (account.email.toLowerCase() == previousEmail &&
              account.role == user.role),
    )) {
      account.email = user.email;
    }
    _notify('Owner account details were updated.');
    notifyListeners();
  }

  void updateAvatar(int avatarStyle) {
    final user = currentUser;
    if (user == null) return;
    user.avatarStyle = avatarStyle;
    _recordActivity('Profile avatar was updated.');
    notifyListeners();
  }

  void updateTenancyAgreement(Tenancy tenancy, String fileName) {
    tenancy.agreementFileName = fileName;
    tenancy.agreementUploadedAt = DateTime.now();
    final tenant = userFor(tenancy.tenantId);
    _notify('Tenancy agreement uploaded for ${tenant.name}.');
    notifyListeners();
  }

  void markNotificationRead(AppNotification notification) {
    notification.isRead = true;
    notifyListeners();
  }

  void markAllNotificationsRead() {
    for (final notification in notifications) {
      notification.isRead = true;
    }
    notifyListeners();
  }

  void _notify(String message) {
    final timestamp = DateTime.now();
    notifications.insert(
      0,
      AppNotification(
        id: 'notification_${notifications.length + 1}',
        message: message,
        createdAt: timestamp,
      ),
    );
    _recordActivity(message, timestamp: timestamp);
  }

  void _recordActivity(String action, {DateTime? timestamp}) {
    final recordedAt = timestamp ?? DateTime.now();
    activityHistory.insert(
      0,
      ActivityHistoryEvent(
        id: 'activity_${recordedAt.microsecondsSinceEpoch}',
        action: action,
        timestamp: recordedAt,
      ),
    );
  }

  Facility facilityFor(String id) {
    return facilities.firstWhere((facility) => facility.id == id);
  }

  AppUser userFor(String id) {
    return users.firstWhere((user) => user.id == id);
  }

  Future<void> restoreCloudWorkspace(CloudProfile profile) async {
    final workspace = cloudWorkspace;
    if (workspace == null) return;
    var clearedDemoData = false;
    _cloudRestoring = true;
    try {
      if (profile.role == 'owner') {
        final remote = await workspace.readOwnerSnapshot(profile.id);
        if (remote == null) {
          _cloudRestoring = false;
          await flushCloudPersistence();
          _cloudRestoring = true;
        } else {
          _restoring = true;
          _restoreSnapshot(remote);
          _restoring = false;
          final tenantSnapshots =
              await workspace.readOwnerTenantSnapshots(profile.id);
          for (final snapshot in tenantSnapshots) {
            _mergeTenantSnapshot(snapshot.payload);
          }
        }
        if (_containsLegacyDemoData) {
          _clearBusinessData();
          await workspace.deleteOwnerTenantSnapshots(profile.id);
          clearedDemoData = true;
        }
      } else if (profile.role == 'tenant') {
        final remote = await workspace.readTenantSnapshot(profile.email);
        if (remote != null && remote.payload.isNotEmpty) {
          _tenantSnapshotOwnerId = remote.ownerId;
          _restoring = true;
          _restoreSnapshot(remote.payload);
          _restoring = false;
        }
      }
      if (profile.role == 'owner') {
        _ensureCurrentMonthUtilityBills();
        _ensureMonthlyInvoicePreparationNotification();
      }
      _applyCloudProfile(profile);
      await flushPersistence();
    } finally {
      _restoring = false;
      _cloudRestoring = false;
    }
    if (clearedDemoData) {
      await flushCloudPersistence();
      await flushPersistence();
    }
    notifyListeners();
  }

  bool get _containsLegacyDemoData => users.any(
        (user) =>
            user.email == 'tenant1a@example.com' ||
            user.email == 'tenant1b@example.com',
      );

  void _clearBusinessData() {
    facilities.clear();
    tenancies.clear();
    bills.clear();
    tenantRequests.clear();
    notifications.clear();
    activityHistory.clear();
    paymentReviewHistory.clear();
    additionalIncomes.clear();
    additionalExpenses.clear();
    users.removeWhere((user) => user.role == UserRole.tenant);
  }

  Future<void> flushCloudPersistence() async {
    final workspace = cloudWorkspace;
    final profile = cloudProfile;
    if (workspace == null || profile == null || _cloudRestoring) return;
    _cloudSaveTimer?.cancel();
    try {
      if (profile.role == 'owner') {
        await workspace.writeOwnerSnapshot(profile.id, _snapshotMap());
        for (final tenant in users.where(
          (user) => user.role == UserRole.tenant,
        )) {
          await workspace.writeTenantSnapshot(
            ownerId: profile.id,
            tenantEmail: tenant.email,
            payload: _tenantSnapshotMap(tenant),
          );
        }
      } else if (profile.role == 'tenant' && _tenantSnapshotOwnerId != null) {
        await workspace.writeTenantSnapshot(
          ownerId: _tenantSnapshotOwnerId!,
          tenantEmail: profile.email,
          payload: _tenantSnapshotMap(currentUser!),
        );
      }
    } catch (error) {
      persistenceError = 'Cloud sync: $error';
      super.notifyListeners();
    }
  }

  Map<String, dynamic> _tenantSnapshotMap(AppUser tenant) {
    final snapshot = _snapshotMap();
    final tenantTenancyIds = tenancies
        .where((item) => item.tenantId == tenant.id)
        .map((item) => item.id)
        .toSet();
    final facilityIds = tenancies
        .where((item) => item.tenantId == tenant.id)
        .map((item) => item.facilityId)
        .toSet();
    final billIds = bills
        .where((item) => item.tenantId == tenant.id)
        .map((item) => item.id)
        .toSet();
    snapshot['users'] = (snapshot['users'] as List<dynamic>)
        .where((item) => (item as Map)['id'] == tenant.id)
        .toList();
    snapshot['facilities'] = (snapshot['facilities'] as List<dynamic>)
        .where((item) => facilityIds.contains((item as Map)['id']))
        .toList();
    snapshot['tenancies'] = (snapshot['tenancies'] as List<dynamic>)
        .where((item) => tenantTenancyIds.contains((item as Map)['id']))
        .toList();
    snapshot['bills'] = (snapshot['bills'] as List<dynamic>)
        .where((item) => (item as Map)['tenantId'] == tenant.id)
        .toList();
    snapshot['tenantRequests'] = (snapshot['tenantRequests'] as List<dynamic>)
        .where((item) => (item as Map)['tenantId'] == tenant.id)
        .toList();
    snapshot['paymentReviewHistory'] =
        (snapshot['paymentReviewHistory'] as List<dynamic>)
            .where((item) => billIds.contains((item as Map)['billId']))
            .toList();
    snapshot['notifications'] = <dynamic>[];
    snapshot['activityHistory'] = <dynamic>[];
    snapshot['additionalIncomes'] = <dynamic>[];
    snapshot['additionalExpenses'] = <dynamic>[];
    return snapshot;
  }

  void _mergeTenantSnapshot(Map<String, dynamic> snapshot) {
    for (final item in _maps(snapshot['bills'])) {
      final matches = bills.where((bill) => bill.id == item['id']);
      if (matches.isEmpty) continue;
      final bill = matches.first;
      bill.electricityUsageKwh = _number(item['electricityUsageKwh']);
      bill.electricityAmount = _number(item['electricityAmount']);
      bill.generalElectricAmount = _number(item['generalElectricAmount']);
      bill.waterAmount = _number(item['waterAmount']);
      bill.internetAmount = _number(item['internetAmount']);
      bill.parkingRentalAmount = _number(item['parkingRentalAmount']);
      bill.utilityEvidenceFileName = item['utilityEvidenceFileName'] as String?;
      bill.status = _enum(
        PaymentStatus.values,
        item['status'],
        bill.status,
      );
      bill.slipFileName = item['slipFileName'] as String?;
      bill.amountPaid = _number(item['amountPaid']);
      bill.paymentDate = _parseDate(item['paymentDate']);
      bill.paymentReference = item['paymentReference'] as String?;
      bill.submittedAt = _parseDate(item['submittedAt']);
      bill.rejectReason = item['rejectReason'] as String?;
      bill.reviewedAt = _parseDate(item['reviewedAt']);
      final slipBytesBase64 = item['slipBytesBase64'] as String?;
      bill.slipBytes = slipBytesBase64 == null
          ? bill.slipBytes
          : Uint8List.fromList(base64Decode(slipBytesBase64));
    }
    for (final item in _maps(snapshot['tenantRequests'])) {
      final matches = tenantRequests.where(
        (request) => request.id == item['id'],
      );
      if (matches.isNotEmpty) {
        matches.first.status =
            item['status'] as String? ?? matches.first.status;
        matches.first.reviewedAt = _parseDate(item['reviewedAt']);
      } else {
        tenantRequests.add(
          TenantRequest(
            id: item['id'] as String,
            tenantId: item['tenantId'] as String,
            facilityId: item['facilityId'] as String,
            title: item['title'] as String,
            message: item['message'] as String,
            createdAt: _parseDate(item['createdAt'])!,
            requestType: item['requestType'] as String? ?? 'General Enquiry',
            attachmentFileName: item['attachmentFileName'] as String?,
            attachmentBase64: item['attachmentBase64'] as String?,
            attachmentSizeBytes: (item['attachmentSizeBytes'] as num?)?.toInt(),
            status: item['status'] as String? ?? 'Open',
            reviewedAt: _parseDate(item['reviewedAt']),
          ),
        );
      }
    }
  }

  Future<void> initializePersistence() async {
    final persistence = _persistence;
    if (persistence == null) return;
    try {
      final snapshot = await persistence.readSnapshot();
      if (snapshot == null || snapshot.isEmpty) {
        await persistence.writeSnapshot(jsonEncode(_snapshotMap()));
      } else {
        _restoring = true;
        _restoreSnapshot(jsonDecode(snapshot) as Map<String, dynamic>);
        _restoring = false;
      }
      _ensureDemoPendingUtilityReadings();
      _ensureCurrentMonthUtilityBills();
      _ensureMonthlyInvoicePreparationNotification();
      _ensureDemoRequestHistory();
      _persistenceReady = true;
    } catch (error) {
      _restoring = false;
      _persistenceReady = true;
      persistenceError = error.toString();
    }
    super.notifyListeners();
  }

  Future<void> flushPersistence() async {
    final persistence = _persistence;
    if (persistence == null || _restoring) return;
    _saveTimer?.cancel();
    try {
      await persistence.writeSnapshot(jsonEncode(_snapshotMap()));
      persistenceError = null;
    } catch (error) {
      persistenceError = error.toString();
      super.notifyListeners();
    }
  }

  Future<void> resetPersistentData() async {
    final persistence = _persistence;
    if (persistence == null) return;
    _restoring = true;
    users.clear();
    facilities.clear();
    tenancies.clear();
    bills.clear();
    tenantRequests.clear();
    notifications.clear();
    activityHistory.clear();
    paymentReviewHistory.clear();
    additionalIncomes.clear();
    additionalExpenses.clear();
    currentUser = null;
    _seed();
    _restoring = false;
    await persistence.clear();
    await flushPersistence();
    notifyListeners();
  }

  @override
  void notifyListeners() {
    super.notifyListeners();
    if (_persistence == null || _restoring || !_persistenceReady) return;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 250), flushPersistence);
    if (cloudProfile != null && !_cloudRestoring) {
      _cloudSaveTimer?.cancel();
      _cloudSaveTimer =
          Timer(const Duration(milliseconds: 900), flushCloudPersistence);
    }
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _cloudSaveTimer?.cancel();
    _publicPaymentSyncTimer?.cancel();
    final persistence = _persistence;
    if (persistence != null) {
      unawaited(flushPersistence().whenComplete(persistence.close));
    }
    super.dispose();
  }

  Map<String, dynamic> _snapshotMap() => {
        'appLanguage': appLanguage.name,
        'electricityTariffName': electricityTariffName,
        'electricityRatePerKwh': electricityRatePerKwh,
        'electricityTariffTiers':
            electricityTariffTiers.map((tier) => tier.toJson()).toList(),
        'schemaVersion': 1,
        'savedAt': DateTime.now().toIso8601String(),
        'users': users
            .map((user) => {
                  'id': user.id,
                  'name': user.name,
                  'email': user.email,
                  'phoneNumber': user.phoneNumber,
                  'role': user.role.name,
                  'originAddress': user.originAddress,
                  'dateOfBirth': _date(user.dateOfBirth),
                  'sex': user.sex,
                  'accountStatus': user.accountStatus,
                  'profileComplete': user.profileComplete,
                  'invitationSentAt': _date(user.invitationSentAt),
                  'accountCreatedAt': _date(user.accountCreatedAt),
                  'lastLoginAt': _date(user.lastLoginAt),
                  'avatarStyle': user.avatarStyle,
                  'paymentReminderAfterDays': user.paymentReminderAfterDays,
                  'paymentReminderFrequencyDays':
                      user.paymentReminderFrequencyDays,
                })
            .toList(),
        'localAuthAccounts': localAuthAccounts
            .map((account) => {
                  'userId': account.userId,
                  'email': account.email,
                  'password': account.password,
                  'role': account.role.name,
                  'createdAt': _date(account.createdAt),
                })
            .toList(),
        'facilities': facilities
            .map((facility) => {
                  'id': facility.id,
                  'ownerId': facility.ownerId,
                  'name': facility.name,
                  'addressLine': facility.addressLine,
                  'postcode': facility.postcode,
                  'city': facility.city,
                  'state': facility.state,
                  'installmentAmount': facility.installmentAmount,
                  'maintenanceFee': facility.maintenanceFee,
                  'insuranceFee': facility.insuranceFee,
                  'insuranceFrequency': facility.insuranceFrequency.name,
                  'insuranceDueMonth': facility.insuranceDueMonth,
                  'extraInstallmentPayment': facility.extraInstallmentPayment,
                  'status': facility.status.name,
                  'soldAt': _date(facility.soldAt),
                  'extraCommitments': facility.extraCommitments
                      .map((item) => {
                            'id': item.id,
                            'name': item.name,
                            'amount': item.amount,
                            'frequency': item.frequency.name,
                            'firstDueMonth': item.firstDueMonth,
                          })
                      .toList(),
                  'costHistory': facility.costHistory
                      .map((item) => {
                            'id': item.id,
                            'effectiveMonth': _date(item.effectiveMonth),
                            'recordedAt': _date(item.recordedAt),
                            'installmentAmount': item.installmentAmount,
                            'extraInstallmentPayment':
                                item.extraInstallmentPayment,
                            'maintenanceFee': item.maintenanceFee,
                            'insuranceFee': item.insuranceFee,
                            'insuranceFrequency': item.insuranceFrequency.name,
                            'insuranceDueMonth': item.insuranceDueMonth,
                            'initial': item.initial,
                          })
                      .toList(),
                })
            .toList(),
        'tenancies': tenancies
            .map((tenancy) => {
                  'id': tenancy.id,
                  'facilityId': tenancy.facilityId,
                  'tenantId': tenancy.tenantId,
                  'unitName': tenancy.unitName,
                  'monthlyRent': tenancy.monthlyRent,
                  'electricityPackage': tenancy.electricityPackage.name,
                  'electricityCharge': tenancy.electricityCharge,
                  'waterPackage': tenancy.waterPackage.name,
                  'waterCharge': tenancy.waterCharge,
                  'internetPackage': tenancy.internetPackage.name,
                  'internetCharge': tenancy.internetCharge,
                  'leaseStart': _date(tenancy.leaseStart),
                  'leaseEnd': _date(tenancy.leaseEnd),
                  'carParkIncluded': tenancy.carParkIncluded,
                  'carParkDetails': tenancy.carParkDetails,
                  'agreementFileName': tenancy.agreementFileName,
                  'agreementUploadedAt': _date(tenancy.agreementUploadedAt),
                  'active': tenancy.active,
                })
            .toList(),
        'bills': bills
            .map((bill) => {
                  'id': bill.id,
                  'facilityId': bill.facilityId,
                  'tenantId': bill.tenantId,
                  'month': _date(bill.month),
                  'rentAmount': bill.rentAmount,
                  'electricityUsageKwh': bill.electricityUsageKwh,
                  'electricityAmount': bill.electricityAmount,
                  'generalElectricAmount': bill.generalElectricAmount,
                  'waterAmount': bill.waterAmount,
                  'internetAmount': bill.internetAmount,
                  'parkingRentalAmount': bill.parkingRentalAmount,
                  'utilityEvidenceFileName': bill.utilityEvidenceFileName,
                  'status': bill.status.name,
                  'slipFileName': bill.slipFileName,
                  'slipBytesBase64': bill.slipBytes == null
                      ? null
                      : base64Encode(bill.slipBytes!),
                  'amountPaid': bill.amountPaid,
                  'paymentDate': _date(bill.paymentDate),
                  'paymentReference': bill.paymentReference,
                  'submittedAt': _date(bill.submittedAt),
                  'rejectReason': bill.rejectReason,
                  'reviewedAt': _date(bill.reviewedAt),
                })
            .toList(),
        'tenantRequests': tenantRequests
            .map((request) => {
                  'id': request.id,
                  'tenantId': request.tenantId,
                  'facilityId': request.facilityId,
                  'title': request.title,
                  'message': request.message,
                  'createdAt': _date(request.createdAt),
                  'requestType': request.requestType,
                  'attachmentFileName': request.attachmentFileName,
                  'attachmentBase64': request.attachmentBase64,
                  'attachmentSizeBytes': request.attachmentSizeBytes,
                  'status': request.status,
                  'reviewedAt': _date(request.reviewedAt),
                })
            .toList(),
        'notifications': notifications
            .map((item) => {
                  'id': item.id,
                  'message': item.message,
                  'createdAt': _date(item.createdAt),
                  'category': item.category,
                  'isRead': item.isRead,
                })
            .toList(),
        'activityHistory': activityHistory
            .map((item) => {
                  'id': item.id,
                  'action': item.action,
                  'timestamp': _date(item.timestamp),
                })
            .toList(),
        'paymentReviewHistory': paymentReviewHistory
            .map((item) => {
                  'id': item.id,
                  'billId': item.billId,
                  'status': item.status.name,
                  'timestamp': _date(item.timestamp),
                  'reason': item.reason,
                })
            .toList(),
        'additionalIncomes': additionalIncomes
            .map((item) => {
                  'id': item.id,
                  'facilityId': item.facilityId,
                  'month': _date(item.month),
                  'category': item.category,
                  'amount': item.amount,
                  'note': item.note,
                })
            .toList(),
        'additionalExpenses': additionalExpenses
            .map((item) => {
                  'id': item.id,
                  'facilityId': item.facilityId,
                  'month': _date(item.month),
                  'category': item.category,
                  'amount': item.amount,
                  'note': item.note,
                })
            .toList(),
      };

  void _restoreSnapshot(Map<String, dynamic> snapshot) {
    appLanguage = _enum(
      AppLanguage.values,
      snapshot['appLanguage'],
      AppLanguage.english,
    );
    final savedElectricityRate = _number(snapshot['electricityRatePerKwh']);
    electricityTariffName = snapshot['electricityTariffName'] as String? ??
        defaultElectricityTariffName;
    electricityRatePerKwh = savedElectricityRate > 0
        ? savedElectricityRate
        : defaultElectricityRatePerKwh;
    final savedTiers = _maps(snapshot['electricityTariffTiers'])
        .map(ElectricityTariffTier.fromJson)
        .where((tier) => tier.ratePerKwh > 0)
        .toList()
      ..sort((a, b) => a.fromKwh.compareTo(b.fromKwh));
    electricityTariffTiers
      ..clear()
      ..addAll(savedTiers.isEmpty
          ? [
              ElectricityTariffTier(
                fromKwh: 0,
                toKwh: 100,
                ratePerKwh: electricityRatePerKwh,
              ),
              ElectricityTariffTier(
                fromKwh: 101,
                toKwh: 200,
                ratePerKwh: electricityRatePerKwh,
              ),
              ElectricityTariffTier(
                fromKwh: 201,
                toKwh: null,
                ratePerKwh: electricityRatePerKwh,
              ),
            ]
          : savedTiers);
    if ((snapshot['schemaVersion'] as num? ?? 0).toInt() > 1) {
      throw const FormatException('Unsupported persistence schema.');
    }
    users
      ..clear()
      ..addAll(_maps(snapshot['users']).map((item) => AppUser(
            id: item['id'] as String,
            name: item['name'] as String,
            email: item['email'] as String,
            phoneNumber: item['phoneNumber'] as String? ?? '',
            role: _enum(UserRole.values, item['role'], UserRole.tenant),
            originAddress: item['originAddress'] as String?,
            dateOfBirth: _parseDate(item['dateOfBirth']),
            sex: item['sex'] as String?,
            accountStatus: item['accountStatus'] as String? ?? 'Active',
            profileComplete: item['profileComplete'] as bool? ?? false,
            invitationSentAt: _parseDate(item['invitationSentAt']),
            accountCreatedAt: _parseDate(item['accountCreatedAt']),
            lastLoginAt: _parseDate(item['lastLoginAt']),
            avatarStyle: (item['avatarStyle'] as num? ?? 0).toInt(),
            paymentReminderAfterDays:
                (item['paymentReminderAfterDays'] as num? ?? 3).toInt(),
            paymentReminderFrequencyDays:
                (item['paymentReminderFrequencyDays'] as num? ?? 2).toInt(),
          )));
    localAuthAccounts
      ..clear()
      ..addAll(_maps(snapshot['localAuthAccounts']).map(
        (item) => LocalAuthAccount(
          userId: item['userId'] as String,
          email: item['email'] as String,
          password: item['password'] as String,
          role: _enum(UserRole.values, item['role'], UserRole.owner),
          createdAt: _parseDate(item['createdAt']),
        ),
      ));
    if (localAuthAccounts.isEmpty) {
      _ensureDefaultLocalOwnerAuth();
    }
    facilities.clear();
    for (final item in _maps(snapshot['facilities'])) {
      final facility = Facility(
        id: item['id'] as String,
        ownerId: item['ownerId'] as String,
        name: item['name'] as String,
        addressLine: item['addressLine'] as String,
        postcode: item['postcode'] as String,
        city: item['city'] as String,
        state: item['state'] as String,
        installmentAmount: _number(item['installmentAmount']),
        maintenanceFee: _number(item['maintenanceFee']),
        insuranceFee: _number(item['insuranceFee']),
        insuranceFrequency: _enum(InsuranceFrequency.values,
            item['insuranceFrequency'], InsuranceFrequency.yearly),
        insuranceDueMonth: (item['insuranceDueMonth'] as num? ?? 1).toInt(),
        extraInstallmentPayment: _number(item['extraInstallmentPayment']),
        status:
            _enum(FacilityStatus.values, item['status'], FacilityStatus.active),
        soldAt: _parseDate(item['soldAt']),
        extraCommitments: _maps(item['extraCommitments'])
            .map((commitment) => RecurringCommitment(
                  id: commitment['id'] as String,
                  name: commitment['name'] as String,
                  amount: _number(commitment['amount']),
                  frequency: _enum(CommitmentFrequency.values,
                      commitment['frequency'], CommitmentFrequency.monthly),
                  firstDueMonth:
                      (commitment['firstDueMonth'] as num? ?? 1).toInt(),
                ))
            .toList(),
      );
      facility.costHistory
        ..clear()
        ..addAll(
            _maps(item['costHistory']).map((version) => FacilityCostVersion(
                  id: version['id'] as String,
                  effectiveMonth: _parseDate(version['effectiveMonth'])!,
                  recordedAt: _parseDate(version['recordedAt'])!,
                  installmentAmount: _number(version['installmentAmount']),
                  extraInstallmentPayment:
                      _number(version['extraInstallmentPayment']),
                  maintenanceFee: _number(version['maintenanceFee']),
                  insuranceFee: _number(version['insuranceFee']),
                  insuranceFrequency: _enum(InsuranceFrequency.values,
                      version['insuranceFrequency'], InsuranceFrequency.yearly),
                  insuranceDueMonth:
                      (version['insuranceDueMonth'] as num? ?? 1).toInt(),
                  initial: version['initial'] as bool? ?? false,
                )));
      facilities.add(facility);
    }
    tenancies
      ..clear()
      ..addAll(_maps(snapshot['tenancies']).map((item) => Tenancy(
            id: item['id'] as String,
            facilityId: item['facilityId'] as String,
            tenantId: item['tenantId'] as String,
            unitName: item['unitName'] as String,
            monthlyRent: _number(item['monthlyRent']),
            electricityPackage: _enum(UtilityPackage.values,
                item['electricityPackage'], UtilityPackage.excluded),
            electricityCharge: _number(item['electricityCharge']),
            waterPackage: _enum(UtilityPackage.values, item['waterPackage'],
                UtilityPackage.excluded),
            waterCharge: _number(item['waterCharge']),
            internetPackage: _enum(UtilityPackage.values,
                item['internetPackage'], UtilityPackage.excluded),
            internetCharge: _number(item['internetCharge']),
            leaseStart: _parseDate(item['leaseStart'])!,
            leaseEnd: _parseDate(item['leaseEnd'])!,
            carParkIncluded: item['carParkIncluded'] as bool? ?? false,
            carParkDetails: item['carParkDetails'] as String? ?? 'Not included',
            agreementFileName: item['agreementFileName'] as String?,
            agreementUploadedAt: _parseDate(item['agreementUploadedAt']),
            active: item['active'] as bool? ?? true,
          )));
    bills
      ..clear()
      ..addAll(_maps(snapshot['bills']).map((item) => MonthlyBill(
            id: item['id'] as String,
            facilityId: item['facilityId'] as String,
            tenantId: item['tenantId'] as String,
            month: _parseDate(item['month'])!,
            rentAmount: _number(item['rentAmount']),
            electricityUsageKwh: _number(item['electricityUsageKwh']),
            electricityAmount: _number(item['electricityAmount']),
            generalElectricAmount: _number(item['generalElectricAmount']),
            waterAmount: _number(item['waterAmount']),
            internetAmount: _number(item['internetAmount']),
            parkingRentalAmount: _number(item['parkingRentalAmount']),
            utilityEvidenceFileName: item['utilityEvidenceFileName'] as String?,
            status: _enum(PaymentStatus.values, item['status'],
                PaymentStatus.notSubmitted),
            slipFileName: item['slipFileName'] as String?,
            slipBytes: item['slipBytesBase64'] == null
                ? null
                : Uint8List.fromList(
                    base64Decode(item['slipBytesBase64'] as String),
                  ),
            amountPaid: _number(item['amountPaid']),
            paymentDate: _parseDate(item['paymentDate']),
            paymentReference: item['paymentReference'] as String?,
            submittedAt: _parseDate(item['submittedAt']),
            rejectReason: item['rejectReason'] as String?,
            reviewedAt: _parseDate(item['reviewedAt']),
          )));
    tenantRequests
      ..clear()
      ..addAll(_maps(snapshot['tenantRequests']).map((item) => TenantRequest(
            id: item['id'] as String,
            tenantId: item['tenantId'] as String,
            facilityId: item['facilityId'] as String,
            title: item['title'] as String,
            message: item['message'] as String,
            createdAt: _parseDate(item['createdAt'])!,
            requestType: item['requestType'] as String? ?? 'General Enquiry',
            attachmentFileName: item['attachmentFileName'] as String?,
            attachmentBase64: item['attachmentBase64'] as String?,
            attachmentSizeBytes: (item['attachmentSizeBytes'] as num?)?.toInt(),
            status: item['status'] as String? ?? 'Open',
            reviewedAt: _parseDate(item['reviewedAt']),
          )));
    notifications
      ..clear()
      ..addAll(_maps(snapshot['notifications']).map((item) => AppNotification(
            id: item['id'] as String,
            message: item['message'] as String,
            createdAt: _parseDate(item['createdAt'])!,
            category: item['category'] as String?,
            isRead: item['isRead'] as bool? ?? false,
          )));
    activityHistory
      ..clear()
      ..addAll(_maps(snapshot['activityHistory']).map(
        (item) => ActivityHistoryEvent(
          id: item['id'] as String,
          action: item['action'] as String,
          timestamp: _parseDate(item['timestamp'])!,
        ),
      ));
    if (activityHistory.isEmpty) {
      activityHistory.addAll(
        notifications.map(
          (item) => ActivityHistoryEvent(
            id: 'activity_${item.id}',
            action: item.message,
            timestamp: item.createdAt,
          ),
        ),
      );
    }
    paymentReviewHistory
      ..clear()
      ..addAll(_maps(snapshot['paymentReviewHistory'])
          .map((item) => PaymentReviewEvent(
                id: item['id'] as String,
                billId: item['billId'] as String,
                status: _enum(PaymentStatus.values, item['status'],
                    PaymentStatus.pendingApproval),
                timestamp: _parseDate(item['timestamp'])!,
                reason: item['reason'] as String?,
              )));
    additionalIncomes
      ..clear()
      ..addAll(
          _maps(snapshot['additionalIncomes']).map((item) => AdditionalIncome(
                id: item['id'] as String,
                facilityId: item['facilityId'] as String,
                month: _parseDate(item['month'])!,
                category: item['category'] as String,
                amount: _number(item['amount']),
                note: item['note'] as String? ?? '',
              )));
    additionalExpenses
      ..clear()
      ..addAll(
          _maps(snapshot['additionalExpenses']).map((item) => AdditionalExpense(
                id: item['id'] as String,
                facilityId: item['facilityId'] as String,
                month: _parseDate(item['month'])!,
                category: item['category'] as String,
                amount: _number(item['amount']),
                note: item['note'] as String? ?? '',
              )));
    _upgradeDemoFacilityNames();
    _ensureDemoHistoricalYearData();
    currentUser = null;
  }

  void _upgradeDemoFacilityNames() {
    const names = {
      'facility_1': 'Harmoni PJ Rooms',
      'facility_2': 'Langit Biru Apartment',
      'facility_3': 'Skyline KL Studio',
    };
    for (final facility in facilities) {
      final upgradedName = names[facility.id];
      if (upgradedName == null) continue;
      if (facility.name == 'Facility 1' ||
          facility.name == 'Facility 2' ||
          facility.name == 'Facility 3') {
        facility.name = upgradedName;
      }
    }
  }

  void _ensureDemoHistoricalYearData() {
    if (bills.any((bill) => bill.id.startsWith('hist_2022_'))) return;
    final demoTenancies = tenancies
        .where(
            (tenancy) => tenancy.id == 'tenancy_1' || tenancy.id == 'tenancy_2')
        .toList();
    if (demoTenancies.isEmpty) return;
    for (final year in [2022, 2023, 2024, 2025]) {
      final yearlyRentFactor = switch (year) {
        2022 => 0.82,
        2023 => 0.9,
        2024 => 0.96,
        _ => 1.04,
      };
      final utilityFactor = switch (year) {
        2022 => 0.7,
        2023 => 0.8,
        2024 => 0.9,
        _ => 1.0,
      };
      for (var month = 1; month <= 12; month++) {
        for (final tenancy in demoTenancies) {
          final seasonal = 1 + ((month % 4) * 0.015);
          final rent = tenancy.monthlyRent * yearlyRentFactor;
          final water = tenancy.waterPackage == UtilityPackage.excluded
              ? tenancy.waterCharge * utilityFactor
              : 0.0;
          final electricity =
              tenancy.electricityPackage == UtilityPackage.excluded
                  ? tenancy.electricityCharge * utilityFactor * seasonal
                  : 0.0;
          final bill = MonthlyBill(
            id: 'hist_${year}_${month}_${tenancy.id}',
            facilityId: tenancy.facilityId,
            tenantId: tenancy.tenantId,
            month: DateTime(year, month),
            rentAmount: rent,
            electricityAmount: electricity,
            electricityUsageKwh:
                electricity == 0 ? 0 : electricity / electricityRatePerKwh,
            waterAmount: water,
            internetAmount: tenancy.internetPackage == UtilityPackage.excluded
                ? tenancy.internetCharge * utilityFactor
                : 0,
            status: PaymentStatus.approved,
          )
            ..amountPaid = rent + electricity + water
            ..slipFileName = 'hist_${year}_${month}_${tenancy.tenantId}.jpg'
            ..submittedAt = DateTime(year, month, 3)
            ..reviewedAt = DateTime(year, month, 4);
          bills.add(bill);
        }
        if (month.isOdd) {
          additionalIncomes.add(
            AdditionalIncome(
              id: 'hist_income_${year}_$month',
              facilityId: 'facility_1',
              month: DateTime(year, month),
              category: 'Parking rental',
              amount: 80 + (year - 2022) * 10,
              note: 'Historical demo income',
            ),
          );
        }
        additionalExpenses.add(
          AdditionalExpense(
            id: 'hist_expense_${year}_$month',
            facilityId: month.isEven ? 'facility_3' : 'facility_1',
            month: DateTime(year, month),
            category: month.isEven ? 'Minor repair' : 'Cleaning',
            amount: (120 + month * 8) * (1 + (year - 2022) * 0.06),
            note: 'Historical demo expense',
          ),
        );
      }
    }
  }

  static String? _date(DateTime? value) => value?.toIso8601String();

  static DateTime? _parseDate(Object? value) =>
      value is String && value.isNotEmpty ? DateTime.parse(value) : null;

  static double _number(Object? value) => (value as num?)?.toDouble() ?? 0;

  static List<Map<String, dynamic>> _maps(Object? value) =>
      (value as List<dynamic>? ?? const [])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();

  static T _enum<T extends Enum>(
    List<T> values,
    Object? name,
    T fallback,
  ) {
    for (final value in values) {
      if (value.name == name) return value;
    }
    return fallback;
  }

  void _ensureDefaultLocalOwnerAuth() {
    if (localAuthAccounts.any((account) => account.role == UserRole.owner)) {
      return;
    }
    final owners = users.where((user) => user.role == UserRole.owner);
    if (owners.isEmpty) return;
    final owner = owners.first;
    if (owner.email == 'owner@example.com') {
      owner.email = 'ahmad.faisal@email.com';
    }
    localAuthAccounts.add(
      LocalAuthAccount(
        userId: owner.id,
        email: owner.email,
        password: 'password',
        role: UserRole.owner,
        createdAt: DateTime(2026, 1),
      ),
    );
  }

  void _seed() {
    users.addAll([
      AppUser(
        id: 'owner_1',
        name: 'Alex',
        email: 'ahmad.faisal@email.com',
        role: UserRole.owner,
      ),
      AppUser(
        id: 'agent_1',
        name: 'Property Agent',
        email: 'agent@example.com',
        role: UserRole.propertyAgent,
      ),
      AppUser(
        id: 'tenant_1',
        name: 'Nur Aisyah Binti Rahman',
        email: 'tenant1a@example.com',
        phoneNumber: '+60165666878',
        role: UserRole.tenant,
        originAddress: '22 Jalan Melur, Shah Alam, Selangor',
        dateOfBirth: DateTime(1996, 5, 14),
        sex: 'Female',
      ),
      AppUser(
        id: 'tenant_2',
        name: 'Daniel Lim Wei Jian',
        email: 'tenant1b@example.com',
        phoneNumber: '+60198765432',
        role: UserRole.tenant,
        originAddress: '18 Lorong Damai, Ipoh, Perak',
        dateOfBirth: DateTime(1992, 11, 2),
        sex: 'Male',
      ),
      AppUser(
        id: 'tenant_3',
        name: 'Mei Lin Tan',
        email: 'tenant2@example.com',
        phoneNumber: '+601122334455',
        role: UserRole.tenant,
        originAddress: '31 Jalan Bukit, Kuala Lumpur',
        dateOfBirth: DateTime(1994, 8, 21),
        sex: 'Female',
      ),
      AppUser(
        id: 'tenant_4',
        name: 'Arif Hakim',
        email: 'tenant3@example.com',
        phoneNumber: '+601177889900',
        role: UserRole.tenant,
        originAddress: '17 Persiaran Murni, Shah Alam, Selangor',
        dateOfBirth: DateTime(1991, 3, 9),
        sex: 'Male',
      ),
    ]);
    _ensureDefaultLocalOwnerAuth();

    facilities.add(
      Facility(
        id: 'facility_1',
        ownerId: 'owner_1',
        name: 'Harmoni PJ Rooms',
        addressLine: '12 Jalan Harmoni 3',
        postcode: '47301',
        city: 'Petaling Jaya',
        state: 'Selangor',
        installmentAmount: 3700,
        maintenanceFee: 450,
        insuranceFee: 230,
        extraCommitments: [
          RecurringCommitment(
            id: 'commitment_facility_1_1',
            name: 'Indah Water',
            amount: 120,
            frequency: CommitmentFrequency.halfYearly,
            firstDueMonth: 1,
          ),
          RecurringCommitment(
            id: 'commitment_facility_1_2',
            name: 'DBKL Assessment',
            amount: 300,
            frequency: CommitmentFrequency.halfYearly,
            firstDueMonth: 1,
          ),
        ],
      ),
    );
    facilities.add(
      Facility(
        id: 'facility_3',
        ownerId: 'owner_1',
        name: 'Skyline KL Studio',
        addressLine: '26 Persiaran Skyline',
        postcode: '55100',
        city: 'Kuala Lumpur',
        state: 'Wilayah Persekutuan',
        installmentAmount: 2850,
        maintenanceFee: 320,
        insuranceFee: 190,
      ),
    );
    facilities.add(
      Facility(
        id: 'facility_2',
        ownerId: 'owner_1',
        name: 'Langit Biru Apartment',
        addressLine: '8 Jalan Langit Biru',
        postcode: '50480',
        city: 'Kuala Lumpur',
        state: 'Wilayah Persekutuan',
        installmentAmount: 0,
        maintenanceFee: 0,
        insuranceFee: 0,
      ),
    );

    tenancies.addAll([
      Tenancy(
        id: 'tenancy_1',
        facilityId: 'facility_1',
        tenantId: 'tenant_1',
        unitName: 'Room A',
        monthlyRent: 1200,
        electricityPackage: UtilityPackage.included,
        electricityCharge: 0,
        waterPackage: UtilityPackage.included,
        waterCharge: 0,
        internetPackage: UtilityPackage.included,
        internetCharge: 0,
        leaseStart: DateTime(2026),
        leaseEnd: DateTime(2026, 12, 31),
        carParkIncluded: true,
        carParkDetails: '1 covered car park bay (A-18)',
      ),
      Tenancy(
        id: 'tenancy_2',
        facilityId: 'facility_1',
        tenantId: 'tenant_2',
        unitName: 'Room B',
        monthlyRent: 600,
        electricityPackage: UtilityPackage.excluded,
        electricityCharge: 80,
        waterPackage: UtilityPackage.excluded,
        waterCharge: 25,
        internetPackage: UtilityPackage.included,
        internetCharge: 0,
        leaseStart: DateTime(2026),
        leaseEnd: DateTime(2026, 12, 31),
        carParkIncluded: false,
        carParkDetails: 'Not included in agreement',
      ),
    ]);

    const seedYear = 2026;
    final lastSeedMonth = _now.year > seedYear
        ? 12
        : _now.year == seedYear
            ? _now.month
            : 0;
    final months = List.generate(
      lastSeedMonth,
      (index) => DateTime(seedYear, index + 1),
    );
    for (final month in months) {
      for (final tenancy in tenancies) {
        bills.add(
          MonthlyBill(
            id: 'bill_${bills.length + 1}',
            facilityId: tenancy.facilityId,
            tenantId: tenancy.tenantId,
            month: month,
            rentAmount: tenancy.monthlyRent,
            electricityAmount:
                tenancy.electricityPackage == UtilityPackage.excluded
                    ? tenancy.electricityCharge
                    : 0,
            electricityUsageKwh:
                tenancy.electricityPackage == UtilityPackage.excluded
                    ? tenancy.electricityCharge / electricityRatePerKwh
                    : 0,
            waterAmount: tenancy.waterPackage == UtilityPackage.excluded
                ? tenancy.waterCharge
                : 0,
            internetAmount: tenancy.internetPackage == UtilityPackage.excluded
                ? tenancy.internetCharge
                : 0,
            status: tenancy.utilitiesFullyIncluded
                ? PaymentStatus.pendingTenantPayment
                : PaymentStatus.notSubmitted,
          ),
        );
      }
    }

    bills[0]
      ..status = PaymentStatus.approved
      ..amountPaid = bills[0].totalAmount
      ..slipFileName = 'jan_room_a_slip.jpg'
      ..submittedAt = DateTime(2026, 1, 3)
      ..reviewedAt = DateTime(2026, 1, 4);
    bills[1]
      ..status = PaymentStatus.pendingApproval
      ..amountPaid = bills[1].totalAmount
      ..slipFileName = 'jan_room_b_slip.jpg'
      ..submittedAt = DateTime(2026, 1, 4);
    bills[3]
      ..status = PaymentStatus.approved
      ..amountPaid = bills[3].totalAmount
      ..slipFileName = 'feb_room_b_slip.jpg'
      ..submittedAt = DateTime(2026, 2, 4)
      ..reviewedAt = DateTime(2026, 2, 5);
    bills[4]
      ..status = PaymentStatus.approved
      ..amountPaid = bills[4].totalAmount
      ..slipFileName = 'mar_room_a_slip.jpg'
      ..submittedAt = DateTime(2026, 3, 3)
      ..reviewedAt = DateTime(2026, 3, 4);
    for (final bill in bills.where((bill) => bill.month.month >= 4)) {
      bill
        ..status = PaymentStatus.approved
        ..amountPaid = bill.totalAmount
        ..slipFileName =
            '${FinancialChartPainter.monthNames[bill.month.month - 1].toLowerCase()}_${bill.tenantId}_slip.jpg'
        ..submittedAt = DateTime(seedYear, bill.month.month, 3)
        ..reviewedAt = DateTime(seedYear, bill.month.month, 4);
    }

    for (final bill in bills.where((bill) {
      return bill.status == PaymentStatus.approved && bill.reviewedAt != null;
    })) {
      paymentReviewHistory.add(
        PaymentReviewEvent(
          id: 'review_${paymentReviewHistory.length + 1}',
          billId: bill.id,
          status: PaymentStatus.approved,
          timestamp: bill.reviewedAt!,
        ),
      );
    }

    for (final year in [2022, 2023, 2024, 2025]) {
      final yearlyRentFactor = switch (year) {
        2022 => 0.82,
        2023 => 0.9,
        2024 => 0.96,
        _ => 1.04,
      };
      final utilityFactor = switch (year) {
        2022 => 0.7,
        2023 => 0.8,
        2024 => 0.9,
        _ => 1.0,
      };
      for (var month = 1; month <= 12; month++) {
        for (final tenancy in tenancies.take(2)) {
          final seasonal = 1 + ((month % 4) * 0.015);
          final rent = tenancy.monthlyRent * yearlyRentFactor;
          final water = tenancy.waterPackage == UtilityPackage.excluded
              ? tenancy.waterCharge * utilityFactor
              : 0.0;
          final electricity =
              tenancy.electricityPackage == UtilityPackage.excluded
                  ? tenancy.electricityCharge * utilityFactor * seasonal
                  : 0.0;
          final historicalBill = MonthlyBill(
            id: 'hist_${year}_${month}_${tenancy.id}',
            facilityId: tenancy.facilityId,
            tenantId: tenancy.tenantId,
            month: DateTime(year, month),
            rentAmount: rent,
            electricityAmount: electricity,
            electricityUsageKwh:
                electricity == 0 ? 0 : electricity / electricityRatePerKwh,
            waterAmount: water,
            internetAmount: tenancy.internetPackage == UtilityPackage.excluded
                ? tenancy.internetCharge * utilityFactor
                : 0,
            status: PaymentStatus.approved,
          )
            ..amountPaid = rent + electricity + water
            ..slipFileName = 'hist_${year}_${month}_${tenancy.tenantId}.jpg'
            ..submittedAt = DateTime(year, month, 3)
            ..reviewedAt = DateTime(year, month, 4);
          bills.add(historicalBill);
        }
        if (month.isOdd) {
          additionalIncomes.add(
            AdditionalIncome(
              id: 'hist_income_${year}_$month',
              facilityId: 'facility_1',
              month: DateTime(year, month),
              category: 'Parking rental',
              amount: 80 + (year - 2022) * 10,
              note: 'Historical demo income',
            ),
          );
        }
        additionalExpenses.add(
          AdditionalExpense(
            id: 'hist_expense_${year}_$month',
            facilityId: month.isEven ? 'facility_3' : 'facility_1',
            month: DateTime(year, month),
            category: month.isEven ? 'Minor repair' : 'Cleaning',
            amount: (120 + month * 8) * (1 + (year - 2022) * 0.06),
            note: 'Historical demo expense',
          ),
        );
      }
    }

    // Additional sample tenancies intentionally start without historical bills.
    tenancies.addAll([
      Tenancy(
        id: 'tenancy_3',
        facilityId: 'facility_2',
        tenantId: 'tenant_3',
        unitName: 'Unit 12-3',
        monthlyRent: 950,
        electricityPackage: UtilityPackage.excluded,
        electricityCharge: 0,
        waterPackage: UtilityPackage.included,
        waterCharge: 0,
        internetPackage: UtilityPackage.included,
        internetCharge: 0,
        leaseStart: DateTime(2026, 7),
        leaseEnd: DateTime(2027, 6, 30),
      ),
      Tenancy(
        id: 'tenancy_4',
        facilityId: 'facility_3',
        tenantId: 'tenant_4',
        unitName: 'Studio 8A',
        monthlyRent: 1100,
        electricityPackage: UtilityPackage.excluded,
        electricityCharge: 0,
        waterPackage: UtilityPackage.excluded,
        waterCharge: 30,
        internetPackage: UtilityPackage.included,
        internetCharge: 0,
        leaseStart: DateTime(2026, 7),
        leaseEnd: DateTime(2027, 6, 30),
      ),
    ]);

    _ensureDemoPendingUtilityReadings();
    _ensureCurrentMonthUtilityBills();
    _ensureMonthlyInvoicePreparationNotification();
    _ensureDemoRequestHistory();

    _notify('Tenant 1B submitted payment slip for Jan 2026.');
    _notify('Monthly bills generated for Facility 1.');

    tenantRequests.add(
      TenantRequest(
        id: 'request_1',
        tenantId: 'tenant_1',
        facilityId: 'facility_1',
        title: 'Air-condition service',
        message: 'The room air-conditioner is not cold enough.',
        createdAt: DateTime(2026, 1, 10),
        requestType: 'Repair & Maintenance',
        attachmentFileName: 'aircon_service_photo.png',
        attachmentBase64:
            'iVBORw0KGgoAAAANSUhEUgAAAEAAAAAoCAIAAADBrGu+AAATtUlEQVR42g3PAYv5DADA4fdD/dOlS5J0XdJ1XZIkXdd1XZJ0XbqkS5KkmZmZmZmZmZmZ4VP9vsR7zzd4/vsnEBO4E4gL3AskBJICKYG0QEbgQeBRICuQE3gSeBZ4EcgLFASKAiWBskBF4FXgTeBd4EPgU6AqUBOoCzQEvgS+BZoCPwItgbbAr0BHoCvQE+gLDASGAoKAKCAJyAKKgCqgCegChoApYAnYAo6AK+AJ+AKBQCgQCfz3b0RsxN2I+Ij7EYkRyRGpEekRmREPIx5HZEfkRjyNeB7xMiI/ojCiOKI0ojyiMuJ1xNuI9xEfIz5HVEfURtRHNEZ8jfge0RzxM6I1oj3id0RnRHdEb0R/xGDEcIQwQhwhjZBHKCPUEdoIfYQxwhxhjbBHOCPcEd4If0QwIhwRjf4CIjGRO5G4yL1IQiQpkhJJi2REHkQeRbIiOZEnkWeRF5G8SEGkKFISKYtURF5F3kTeRT5EPkWqIjWRukhD5EvkW6Qp8iPSEmmL/Ip0RLoiPZG+yEBkKCKIiCKSiCyiiKgimoguYoiYIpaILeKIuCKeiC8SiIQikfgXGBMbczcmPuZ+TGJMckxqTHpMZszDmMcx2TG5MU9jnse8jMmPKYwpjimNKY+pjHkd8zbmfczHmM8x1TG1MfUxjTFfY77HNMf8jGmNaY/5HdMZ0x3TG9MfMxgzHCOMEcdIY+Qxyhh1jDZGH2OMMcdYY+wxzhh3jDfGHxOMCcdE47+AREziTiIucS+RkEhKpCTSEhmJB4lHiaxETuJJ4lniRSIvUZAoSpQkyhIViVeJN4l3iQ+JT4mqRE2iLtGQ+JL4lmhK/Ei0JNoSvxIdia5ET6IvMZAYSggSooQkIUsoEqqEJqFLGBKmhCVhSzgSroQn4UsEEqFEJP0FJsQm3E2IT7ifkJiQnJCakJ6QmfAw4XFCdkJuwtOE5wkvE/ITChOKE0oTyhMqE14nvE14n/Ax4XNCdUJtQn1CY8LXhO8JzQk/E1oT2hN+J3QmdCf0JvQnDCYMJwgTxAnSBHmCMkGdoE3QJxgTzAnWBHuCM8Gd4E3wJwQTwgnR5C8gE5O5k4nL3MskZJIyKZm0TEbmQeZRJiuTk3mSeZZ5kcnLFGSKMiWZskxF5lXmTeZd5kPmU6YqU5OpyzRkvmS+ZZoyPzItmbbMr0xHpivTk+nLDGSGMoKMKCPJyDKKjCqjyegyhowpY8nYMo6MK+PJ+DKBTCgTyX+BKbEpd1PiU+6nJKYkp6SmpKdkpjxMeZySnZKb8jTlecrLlPyUwpTilNKU8pTKlNcpb1Pep3xM+ZxSnVKbUp/SmPI15XtKc8rPlNaU9pTfKZ0p3Sm9Kf0pgynDKcIUcYo0RZ6iTFGnaFP0KcYUc4o1xZ7iTHGneFP8KcGUcEo0/QsoxBTuFOIK9woJhaRCSiGtkFF4UHhUyCrkFJ4UnhVeFPIKBYWiQkmhrFBReFV4U3hX+FD4VKgq1BTqCg2FL4VvhabCj0JLoa3wq9BR6Cr0FPoKA4WhgqAgKkgKsoKioCpoCrqCoWAqWAq2gqPgKngKvkKgECpEyl9gRmzG3Yz4jPsZiRnJGakZ6RmZGQ8zHmdkZ+RmPM14nvEyIz+jMKM4ozSjPKMy43XG24z3GR8zPmdUZ9Rm1Gc0ZnzN+J7RnPEzozWjPeN3RmdGd0ZvRn/GYMZwhjBDnCHNkGcoM9QZ2gx9hjHDnGHNsGc4M9wZ3gx/RjAjnBHN/gIqMZU7lbjKvUpCJamSUkmrZFQeVB5Vsio5lSeVZ5UXlbxKQaWoUlIpq1RUXlXeVN5VPlQ+VaoqNZW6SkPlS+Vbpanyo9JSaav8qnRUuio9lb7KQGWoIqiIKpKKrKKoqCqaiq5iqJgqloqt4qi4Kp6KrxKohCqR+heYE5tzNyc+535OYk5yTmpOek5mzsOcxznZObk5T3Oe57zMyc8pzCnOKc0pz6nMeZ3zNud9zseczznVObU59TmNOV9zvuc05/zMac1pz/md05nTndOb058zmDOcI8wR50hz5DnKHHWONkefY8wx51hz7DnOHHeON8efE8wJ50Tzv4BGTONOI65xr5HQSGqkNNIaGY0HjUeNrEZO40njWeNFI69R0ChqlDTKGhWNV403jXeND41PjapGTaOu0dD40vjWaGr8aLQ02hq/Gh2NrkZPo68x0BhqCBqihqQhaygaqoamoWsYGqaGpWFrOBquhqfhawQaoUak/QUWxBbcLYgvuF+QWJBckFqQXpBZ8LDgcUF2QW7B04LnBS8L8gsKC4oLSgvKCyoLXhe8LXhf8LHgc0F1QW1BfUFjwdeC7wXNBT8LWgvaC34XdBZ0F/QW9BcMFgwXCAvEBdICeYGyQF2gLdAXGAvMBdYCe4GzwF3gLfAXBAvCBdHiL6AT07nTievc6yR0kjopnbRORudB51Enq5PTedJ51nnRyesUdIo6JZ2yTkXnVedN513nQ+dTp6pT06nrNHS+dL51mjo/Oi2dts6vTkenq9PT6esMdIY6go6oI+nIOoqOqqPp6DqGjqlj6dg6jo6r4+n4OoFOqBPpf4ElsSV3S+JL7pckliSXpJakl2SWPCx5XJJdklvytOR5ycuS/JLCkuKS0pLyksqS1yVvS96XfCz5XFJdUltSX9JY8rXke0lzyc+S1pL2kt8lnSXdJb0l/SWDJcMlwhJxibREXqIsUZdoS/QlxhJzibXEXuIscZd4S/wlwZJwSbT8CxjEDO4M4gb3BgmDpEHKIG2QMXgweDTIGuQMngyeDV4M8gYFg6JByaBsUDF4NXgzeDf4MPg0qBrUDOoGDYMvg2+DpsGPQcugbfBr0DHoGvQM+gYDg6GBYCAaSAaygWKgGmgGuoFhYBpYBraBY+AaeAa+QWAQGkTGX2BFbMXdiviK+xWJFckVqRXpFZkVDyseV2RX5FY8rXhe8bIiv6KworiitKK8orLidcXbivcVHys+V1RX1FbUVzRWfK34XtFc8bOitaK94ndFZ0V3RW9Ff8VgxXCFsEJcIa2QVygr1BXaCn2FscJcYa2wVzgr3BXeCn9FsCJcEa3+AiYxkzuTuMm9ScIkaZIySZtkTB5MHk2yJjmTJ5NnkxeTvEnBpGhSMimbVExeTd5M3k0+TD5NqiY1k7pJw+TL5NukafJj0jJpm/yadEy6Jj2TvsnAZGgimIgmkolsopioJpqJbmKYmCaWiW3imLgmnolvEpiEJpH5F1gTW3O3Jr7mfk1iTXJNak16TWbNw5rHNdk1uTVPa57XvKzJrymsKa4prSmvqax5XfO25n3Nx5rPNdU1tTX1NY01X2u+1zTX/KxprWmv+V3TWdNd01vTXzNYM1wjrBHXSGvkNcoadY22Rl9jrDHXWGvsNc4ad423xl8TrAnXROu/gEXM4s4ibnFvkbBIWqQs0hYZiweLR4usRc7iyeLZ4sUib1GwKFqULMoWFYtXizeLd4sPi0+LqkXNom7RsPiy+LZoWvxYtCzaFr8WHYuuRc+ibzGwGFoIFqKFZCFbKBaqhWahWxgWpoVlYVs4Fq6FZ+FbBBahRWT9BTbENtxtiG+435DYkNyQ2pDekNnwsOFxQ3ZDbsPThucNLxvyGwobihtKG8obKhteN7xteN/wseFzQ3VDbUN9Q2PD14bvDc0NPxtaG9obfjd0NnQ39Db0Nww2DDcIG8QN0gZ5g7JB3aBt0DcYG8wN1gZ7g7PB3eBt8DcEG8IN0eYvYBOzubOJ29zbJGySNimbtE3G5sHm0SZrk7N5snm2ebHJ2xRsijYlm7JNxebV5s3m3ebD5tOmalOzqds0bL5svm2aNj82LZu2za9Nx6Zr07Pp2wxshjaCjWgj2cg2io1qo9noNoaNaWPZ2DaOjWvj2fg2gU1oE9l/gS2xLXdb4lvutyS2JLektqS3ZLY8bHnckt2S2/K05XnLy5b8lsKW4pbSlvKWypbXLW9b3rd8bPncUt1S21Lf0tjyteV7S3PLz5bWlvaW3y2dLd0tvS39LYMtwy3CFnGLtEXeomxRt2hb9C3GFnOLtcXe4mxxt3hb/C3BlnBLtP0LOMQc7hziDvcOCYekQ8oh7ZBxeHB4dMg65ByeHJ4dXhzyDgWHokPJoexQcXh1eHN4d/hw+HSoOtQc6g4Nhy+Hb4emw49Dy6Ht8OvQceg69Bz6DgOHoYPgIDpIDrKD4qA6aA66g+FgOlgOtoPj4Dp4Dr5D4BA6RM5fYEdsx92O+I77HYkdyR2pHekdmR0POx53ZHfkdjzteN7xsiO/o7CjuKO0o7yjsuN1x9uO9x0fOz53VHfUdtR3NHZ87fje0dzxs6O1o73jd0dnR3dHb0d/x2DHcIewQ9wh7ZB3KDvUHdoOfYexw9xh7bB3ODvcHd4Of0ewI9wR7f4CLjGXO5e4y71LwiXpknJJu2RcHlweXbIuOZcnl2eXF5e8S8Gl6FJyKbtUXF5d3lzeXT5cPl2qLjWXukvD5cvl26Xp8uPScmm7/Lp0XLouPZe+y8Bl6CK4iC6Si+yiuKgumovuYriYLpaL7eK4uC6ei+8SuIQukfsX2BPbc7cnvud+T2JPck9qT3pPZs/Dnsc92T25PU97nve87MnvKewp7intKe+p7Hnd87bnfc/Hns891T21PfU9jT1fe773NPf87Gntae/53dPZ093T29PfM9gz3CPsEfdIe+Q9yh51j7ZH32PsMfdYe+w9zh53j7fH3xPsCfdE+7+AR8zjziPuce+R8Eh6pDzSHhmPB49Hj6xHzuPJ49njxSPvUfAoepQ8yh4Vj1ePN493jw+PT4+qR82j7tHw+PL49mh6/Hi0PNoevx4dj65Hz6PvMfAYeggeoofkIXsoHqqH5qF7GB6mh+Vhezgerofn4XsEHqFH5P0FDsQO3B2IH7g/kDiQPJA6kD6QOfBw4PFA9kDuwNOB5wMvB/IHCgeKB0oHygcqB14PvB14P/Bx4PNA9UDtQP1A48DXge8DzQM/B1oH2gd+D3QOdA/0DvQPDA4MDwgHxAPSAfmAckA9oB3QDxgHzAPWAfuAc8A94B3wDwQHwgPR4S/gE/O584n73PskfJI+KZ+0T8bnwefRJ+uT83nyefZ58cn7FHyKPiWfsk/F59Xnzefd58Pn06fqU/Op+zR8vny+fZo+Pz4tn7bPr0/Hp+vT8+n7DHyGPoKP6CP5yD6Kj+qj+eg+ho/pY/nYPo6P6+P5+D6BT+gT+X+BI7Ejd0fiR+6PJI4kj6SOpI9kjjwceTySPZI78nTk+cjLkfyRwpHikdKR8pHKkdcjb0fej3wc+TxSPVI7Uj/SOPJ15PtI88jPkdaR9pHfI50j3SO9I/0jgyPDI8IR8Yh0RD6iHFGPaEf0I8YR84h1xD7iHHGPeEf8I8GR8Eh0/AsExALuAuIB9wGJgGRAKiAdkAl4CHgMyAbkAp4CngNeAvIBhYBiQCmgHFAJeA14C3gP+Aj4DKgG1ALqAY2Ar4DvgGbAT0AroB3wG9AJ6Ab0AvoBg4BhgBAgBkgBcoASoAZoAXqAEWAGWAF2gBPgBngBfkAQEAZEwV/gROzE3Yn4ifsTiRPJE6kT6ROZEw8nHk9kT+ROPJ14PvFyIn+icKJ4onSifKJy4vXE24n3Ex8nPk9UT9RO1E80Tnyd+D7RPPFzonWifeL3ROdE90TvRP/E4MTwhHBCPCGdkE8oJ9QT2gn9hHHCPGGdsE84J9wT3gn/RHAiPBGd/gIhsZC7kHjIfUgiJBmSCkmHZEIeQh5DsiG5kKeQ55CXkHxIIaQYUgoph1RCXkPeQt5DPkI+Q6ohtZB6SCPkK+Q7pBnyE9IKaYf8hnRCuiG9kH7IIGQYIoSIIVKIHKKEqCFaiB5ihJghVogd4oS4IV6IHxKEhCFR+Bc4EztzdyZ+5v5M4kzyTOpM+kzmzMOZxzPZM7kzT2eez7ycyZ8pnCmeKZ0pn6mceT3zdub9zMeZzzPVM7Uz9TONM19nvs80z/ycaZ1pn/k90znTPdM70z8zODM8I5wRz0hn5DPKGfWMdkY/Y5wxz1hn7DPOGfeMd8Y/E5wJz0Tnv0BELOIuIh5xH5GISEakItIRmYiHiMeIbEQu4iniOeIlIh9RiChGlCLKEZWI14i3iPeIj4jPiGpELaIe0Yj4iviOaEb8RLQi2hG/EZ2IbkQvoh8xiBhGCBFihBQhRygRaoQWoUcYEWaEFWFHOBFuhBfhRwQRYUQU/QUuxC7cXYhfuL+QuJC8kLqQvpC58HDh8UL2Qu7C04XnCy8X8hcKF4oXShfKFyoXXi+8XXi/8HHh80L1Qu1C/ULjwteF7wvNCz8XWhfaF34vdC50L/Qu9C8MLgwvCBfEC9IF+YJyQb2gXdAvGBfMC9YF+4Jzwb3gXfAvBBfCC9HlL3AlduXuSvzK/ZXEleSV1JX0lcyVhyuPV7JXcleerjxfebmSv1K4UrxSulK+UrnyeuXtyvuVjyufV6pXalfqVxpXvq58X2le+bnSutK+8nulc6V7pXelf2VwZXhFuCJeka7IV5Qr6hXtin7FuGJesa7YV5wr7hXvin8luBJeia5/gRuxG3c34jfubyRuJG+kbqRvZG483Hi8kb2Ru/F04/nGy438jcKN4o3SjfKNyo3XG2833m983Pi8Ub1Ru1G/0bjxdeP7RvPGz43WjfaN3xudG90bvRv9G4MbwxvCDfGGdEO+odxQb2g39BvGDfOGdcO+4dxwb3g3/BvBjfBGdON/4tT8HvrwgpIAAAAASUVORK5CYII=',
        attachmentSizeBytes: 5102,
      ),
    );
    _upgradeDemoFacilityNames();
  }

  void _ensureDemoPendingUtilityReadings() {
    final examples = <({
      String id,
      String facilityId,
      String tenantId,
      double rent,
      double water,
    })>[
      (
        id: 'demo_utility_pending_facility_1',
        facilityId: 'facility_1',
        tenantId: 'tenant_2',
        rent: 600,
        water: 25,
      ),
      (
        id: 'demo_utility_pending_facility_2',
        facilityId: 'facility_2',
        tenantId: 'tenant_3',
        rent: 950,
        water: 0,
      ),
      (
        id: 'demo_utility_pending_facility_3',
        facilityId: 'facility_3',
        tenantId: 'tenant_4',
        rent: 1100,
        water: 30,
      ),
    ];
    for (final example in examples) {
      final hasTenant = users.any((user) => user.id == example.tenantId);
      final hasFacility =
          facilities.any((facility) => facility.id == example.facilityId);
      if (!hasTenant ||
          !hasFacility ||
          bills.any((bill) => bill.id == example.id)) {
        continue;
      }
      bills.add(
        MonthlyBill(
          id: example.id,
          facilityId: example.facilityId,
          tenantId: example.tenantId,
          month: DateTime(2026, 7),
          rentAmount: example.rent,
          electricityAmount: 0,
          electricityUsageKwh: 0,
          waterAmount: example.water,
          internetAmount: 0,
          status: PaymentStatus.notSubmitted,
        ),
      );
    }
  }

  void _ensureCurrentMonthUtilityBills() {
    for (final tenancy in tenancies.where((item) {
      final monthStart = currentMonth;
      final leaseStart = DateTime(item.leaseStart.year, item.leaseStart.month);
      final leaseEnd = DateTime(item.leaseEnd.year, item.leaseEnd.month);
      return item.active &&
          !leaseStart.isAfter(monthStart) &&
          !leaseEnd.isBefore(monthStart);
    })) {
      final alreadyCreated = bills.any((bill) {
        return bill.facilityId == tenancy.facilityId &&
            bill.tenantId == tenancy.tenantId &&
            bill.month.year == currentMonth.year &&
            bill.month.month == currentMonth.month;
      });
      if (alreadyCreated) continue;
      bills.add(
        MonthlyBill(
          id: 'bill_${tenancy.id}_${currentMonth.year}_${currentMonth.month}',
          facilityId: tenancy.facilityId,
          tenantId: tenancy.tenantId,
          month: currentMonth,
          rentAmount: tenancy.monthlyRent,
          electricityAmount: 0,
          electricityUsageKwh: 0,
          waterAmount: tenancy.waterPackage == UtilityPackage.excluded
              ? tenancy.waterCharge
              : 0,
          internetAmount: tenancy.internetPackage == UtilityPackage.excluded
              ? tenancy.internetCharge
              : 0,
          status: tenancy.utilitiesFullyIncluded
              ? PaymentStatus.pendingTenantPayment
              : PaymentStatus.notSubmitted,
        ),
      );
    }
  }

  void _ensureMonthlyInvoicePreparationNotification() {
    final notificationId =
        'invoice_preparation_${currentMonth.year}_${currentMonth.month}';
    if (notifications.any((item) => item.id == notificationId)) return;

    final pendingReadings = bills.where((bill) {
      return bill.month.year == currentMonth.year &&
          bill.month.month == currentMonth.month &&
          bill.status == PaymentStatus.notSubmitted;
    }).length;
    if (pendingReadings == 0) return;

    final message =
        '${monthLabel(currentMonth)} invoices are ready to prepare. $pendingReadings utility reading${pendingReadings == 1 ? '' : 's'} pending.';
    final timestamp = DateTime(
      currentMonth.year,
      currentMonth.month,
      1,
      8,
    );
    notifications.insert(
      0,
      AppNotification(
        id: notificationId,
        message: message,
        createdAt: timestamp,
        category: 'Utility reading',
      ),
    );
    _recordActivity(message, timestamp: timestamp);
  }

  void _ensureDemoRequestHistory() {
    if (!users.any((item) => item.id == 'tenant_2') ||
        !facilities.any((item) => item.id == 'facility_1')) {
      return;
    }
    if (!tenantRequests.any((item) => item.id == 'request_history_1')) {
      tenantRequests.add(
        TenantRequest(
          id: 'request_history_1',
          tenantId: 'tenant_2',
          facilityId: 'facility_1',
          title: 'Bathroom water leak',
          message: 'Water was leaking below the wash basin.',
          createdAt: DateTime(2026, 5, 14),
          requestType: 'Repair & Maintenance',
          status: 'Closed',
          reviewedAt: DateTime(2026, 5, 16),
        ),
      );
    }
    if (!tenantRequests.any((item) => item.id == 'request_history_2')) {
      tenantRequests.add(
        TenantRequest(
          id: 'request_history_2',
          tenantId: 'tenant_1',
          facilityId: 'facility_1',
          title: 'Additional access card',
          message: 'Requested one additional building access card.',
          createdAt: DateTime(2026, 4, 8),
          requestType: 'Access & Security',
          status: 'Rejected',
          reviewedAt: DateTime(2026, 4, 9),
        ),
      );
    }
  }
}

class RentalFacilityApp extends StatefulWidget {
  const RentalFacilityApp({this.initialStore, super.key});

  final RentalStore? initialStore;

  @override
  State<RentalFacilityApp> createState() => _RentalFacilityAppState();
}

class _RentalFacilityAppState extends State<RentalFacilityApp> {
  late final RentalStore store;

  @override
  void initState() {
    super.initState();
    store = widget.initialStore ?? RentalStore();
  }

  @override
  void dispose() {
    store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RentalStoreScope(
      store: store,
      child: AnimatedBuilder(
        animation: store,
        builder: (context, _) {
          final usesSystemCjkFont = store.appLanguage == AppLanguage.chinese;
          final appFontFamily = usesSystemCjkFont ? null : 'Manrope';
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'Rental Facility Manager',
            builder: (context, child) {
              final mediaQuery = MediaQuery.of(context);
              final safeTextScale =
                  mediaQuery.textScaleFactor.clamp(0.85, 1.20).toDouble();
              return MediaQuery(
                data: mediaQuery.copyWith(textScaleFactor: safeTextScale),
                child: AppUpdateGate(
                  child: child ?? const SizedBox.shrink(),
                ),
              );
            },
            theme: ThemeData(
              colorScheme: const ColorScheme.light(
                primary: oceanBlue,
                secondary: oceanSky,
                surface: Colors.white,
                background: oceanCanvas,
                error: Color(0xFFC43D4B),
              ),
              fontFamily: appFontFamily,
              textTheme: Typography.material2021().black.apply(
                    fontFamily: appFontFamily,
                    bodyColor: oceanText,
                    displayColor: oceanText,
                  ),
              useMaterial3: true,
              scaffoldBackgroundColor: oceanCanvas,
              iconTheme: const IconThemeData(
                color: Color(0xFF334155),
                size: 22,
              ),
              iconButtonTheme: IconButtonThemeData(
                style: IconButton.styleFrom(
                  foregroundColor: const Color(0xFF334155),
                  minimumSize: const Size(42, 42),
                  padding: const EdgeInsets.all(9),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              appBarTheme: const AppBarTheme(
                backgroundColor: oceanCanvas,
                foregroundColor: oceanText,
                centerTitle: false,
                elevation: 0,
                scrolledUnderElevation: 0,
                titleTextStyle: TextStyle(
                  color: oceanText,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              cardTheme: CardTheme(
                color: Colors.white,
                elevation: 0,
                shadowColor: oceanText.withOpacity(0.06),
                margin: const EdgeInsets.symmetric(vertical: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: const BorderSide(color: Color(0x0F0F172A)),
                ),
              ),
              navigationBarTheme: NavigationBarThemeData(
                backgroundColor: Colors.white,
                indicatorColor: oceanSoft,
                elevation: 0,
                labelTextStyle: MaterialStateProperty.resolveWith((states) {
                  return TextStyle(
                    color: states.contains(MaterialState.selected)
                        ? oceanDeep
                        : oceanMuted,
                    fontWeight: states.contains(MaterialState.selected)
                        ? FontWeight.w700
                        : FontWeight.w500,
                  );
                }),
              ),
              inputDecorationTheme: InputDecorationTheme(
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFD6DEEB)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFD6DEEB)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: oceanBlue,
                    width: 2,
                  ),
                ),
              ),
              filledButtonTheme: FilledButtonThemeData(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(44, 48),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  backgroundColor: oceanDeep,
                  foregroundColor: Colors.white,
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              outlinedButtonTheme: OutlinedButtonThemeData(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(44, 46),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                  foregroundColor: oceanDeep,
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFFB8C7DB)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              textButtonTheme: TextButtonThemeData(
                style: TextButton.styleFrom(
                  foregroundColor: oceanDeep,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              floatingActionButtonTheme: const FloatingActionButtonThemeData(
                backgroundColor: oceanDeep,
                foregroundColor: Colors.white,
                elevation: 2,
                shape: StadiumBorder(),
              ),
              dialogTheme: DialogTheme(
                backgroundColor: const Color(0xFFF4F7FC),
                surfaceTintColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              bottomSheetTheme: const BottomSheetThemeData(
                backgroundColor: Color(0xFFF4F7FC),
                surfaceTintColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
                ),
              ),
              chipTheme: ChipThemeData(
                backgroundColor: Colors.white,
                selectedColor: oceanSoft,
                side: const BorderSide(color: Color(0xFFDCE5F0)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                labelStyle: const TextStyle(
                  color: oceanText,
                  fontWeight: FontWeight.w600,
                ),
              ),
              listTileTheme: const ListTileThemeData(
                iconColor: oceanDeep,
                textColor: oceanText,
                contentPadding: EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
            home: store.isLoggedIn
                ? store.isManager
                    ? const OwnerHomeScreen()
                    : const TenantHomeScreen()
                : const LoginScreen(),
          );
        },
      ),
    );
  }
}

class RentalStoreScope extends InheritedWidget {
  const RentalStoreScope({
    required this.store,
    required super.child,
    super.key,
  });

  final RentalStore store;

  static RentalStore of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<RentalStoreScope>();
    assert(scope != null, 'RentalStoreScope not found');
    return scope!.store;
  }

  @override
  bool updateShouldNotify(RentalStoreScope oldWidget) =>
      store != oldWidget.store;
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool showSplash = true;
  Timer? splashTimer;

  @override
  void initState() {
    super.initState();
    splashTimer = Timer(const Duration(milliseconds: 2100), () {
      if (mounted) setState(() => showSplash = false);
    });
  }

  @override
  void dispose() {
    splashTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = RentalStoreScope.of(context);
    return Scaffold(
      backgroundColor: oceanCanvas,
      body: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedOpacity(
            opacity: showSplash ? 0 : 1,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
            child: store.cloudAuthEnabled
                ? _CloudLoginExperience(store: store)
                : _LoginExperience(
                    onOwner: () => store.loginAs(UserRole.owner),
                    onAgent: () => store.loginAs(UserRole.propertyAgent),
                    onTenant: () => store.loginAs(UserRole.tenant),
                  ),
          ),
          IgnorePointer(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              switchOutCurve: Curves.easeInCubic,
              child: showSplash
                  ? const _BrandSplash(key: ValueKey('brand_splash'))
                  : const SizedBox(key: ValueKey('splash_complete')),
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandSplash extends StatelessWidget {
  const _BrandSplash({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFBFDFF), Color(0xFFEAF3FC)],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: -190,
            left: -80,
            right: -80,
            child: IgnorePointer(
              child: Container(
                height: 520,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF3E86C9).withOpacity(0.18),
                      const Color(0xFF3E86C9).withOpacity(0.08),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          Center(
            child: TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 1450),
              curve: Curves.easeOutCubic,
              tween: Tween(begin: 0, end: 1),
              builder: (context, value, child) {
                final textOpacity = ((value - 0.28) / 0.55).clamp(0.0, 1.0);
                return Transform.translate(
                  offset: Offset(0, (1 - value) * 18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _DaylightHouseMark(progress: value),
                      const SizedBox(height: 28),
                      Opacity(
                        opacity: textOpacity,
                        child: Column(
                          children: [
                            const Text(
                              'PLATINUM VICTORY',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color(0xFF14243A),
                                fontSize: 30,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 5.5,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'RENTAL FACILITY MANAGER',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color(0xFF3E86C9),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 4,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'MANAGE EVERY PROPERTY, EFFORTLESSLY',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: oceanMuted.withOpacity(0.78),
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 2.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 64,
            child: TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 1450),
              curve: Curves.easeOutCubic,
              tween: Tween(begin: 0, end: 1),
              builder: (context, value, child) => Opacity(
                opacity: ((value - 0.45) / 0.45).clamp(0.0, 1.0),
                child: child,
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      3,
                      (index) => Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.symmetric(horizontal: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3E86C9).withOpacity(
                            index == 1 ? 0.78 : 0.38,
                          ),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  Text(
                    'Version 2.4.0',
                    style: TextStyle(
                      color: oceanMuted.withOpacity(0.7),
                      fontSize: 11,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '© 2026 Platinum Victory',
                    style: TextStyle(
                      color: oceanMuted.withOpacity(0.58),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DaylightHouseMark extends StatelessWidget {
  const _DaylightHouseMark({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final scale = 0.86 + (progress.clamp(0.0, 1.0) * 0.14);
    return Transform.scale(
      scale: scale,
      child: SizedBox(
        width: 136,
        height: 136,
        child: CustomPaint(
          painter: _DaylightHouseMarkPainter(progress),
        ),
      ),
    );
  }
}

class _DaylightHouseMarkPainter extends CustomPainter {
  const _DaylightHouseMarkPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final p = progress.clamp(0.0, 1.0);
    final center = Offset(size.width / 2, size.height / 2);
    final blue = const Color(0xFF3E86C9);
    final shadowPaint = Paint()
      ..color = blue.withOpacity(0.08 + (p * 0.08))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
    canvas.drawCircle(center, 54, shadowPaint);

    final orbitRect = Rect.fromCenter(
      center: center.translate(0, -3),
      width: 118,
      height: 86,
    );
    final orbitPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = blue.withOpacity(0.18 + (0.28 * p));
    canvas.drawOval(orbitRect, orbitPaint);

    final dotAngle = -math.pi * 0.2 + (math.pi * 2 * p);
    final dot = Offset(
      orbitRect.center.dx + math.cos(dotAngle) * orbitRect.width / 2,
      orbitRect.center.dy + math.sin(dotAngle) * orbitRect.height / 2,
    );
    canvas.drawCircle(dot, 4.5, Paint()..color = blue.withOpacity(0.9));

    final iconPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 7
      ..color = blue;

    final roof = Path()
      ..moveTo(41, 73)
      ..lineTo(68, 49)
      ..lineTo(95, 73);
    final walls = Path()
      ..moveTo(47, 72)
      ..lineTo(47, 95)
      ..lineTo(89, 95)
      ..lineTo(89, 72);
    final door = Path()
      ..moveTo(63, 95)
      ..lineTo(63, 80)
      ..lineTo(75, 80)
      ..lineTo(75, 95);
    final building = Path()
      ..moveTo(83, 61)
      ..lineTo(101, 61)
      ..lineTo(101, 94);
    final windows = Path()
      ..moveTo(89, 70)
      ..lineTo(94, 70)
      ..moveTo(89, 80)
      ..lineTo(94, 80);

    _drawPartialPath(
        canvas, roof, iconPaint, ((p - 0.05) / 0.26).clamp(0.0, 1.0));
    _drawPartialPath(
        canvas, walls, iconPaint, ((p - 0.18) / 0.34).clamp(0.0, 1.0));
    _drawPartialPath(
        canvas, door, iconPaint, ((p - 0.36) / 0.28).clamp(0.0, 1.0));
    _drawPartialPath(
        canvas, building, iconPaint, ((p - 0.26) / 0.34).clamp(0.0, 1.0));
    _drawPartialPath(
        canvas, windows, iconPaint, ((p - 0.48) / 0.22).clamp(0.0, 1.0));
  }

  void _drawPartialPath(Canvas canvas, Path path, Paint paint, double amount) {
    if (amount <= 0) return;
    for (final metric in path.computeMetrics()) {
      canvas.drawPath(
        metric.extractPath(0, metric.length * amount.clamp(0.0, 1.0)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DaylightHouseMarkPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _CloudLoginExperience extends StatelessWidget {
  const _CloudLoginExperience({required this.store});

  final RentalStore store;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(child: _LoginBackdrop()),
        SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const _StandardLoginBrand(),
                    const SizedBox(height: 24),
                    _CloudLoginPanel(store: store),
                    const SizedBox(height: 18),
                    const Text(
                      'Secure shared access for owners, agents and tenants',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF667085),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

enum _CompactLoginRole { owner, tenant, technician, agent }

class _CompactRoleLogin extends StatefulWidget {
  const _CompactRoleLogin({
    required this.onOwner,
    required this.onAgent,
    required this.onTenant,
  });

  final VoidCallback onOwner;
  final VoidCallback onAgent;
  final VoidCallback onTenant;

  @override
  State<_CompactRoleLogin> createState() => _CompactRoleLoginState();
}

class _CompactRoleLoginState extends State<_CompactRoleLogin> {
  _CompactLoginRole role = _CompactLoginRole.owner;
  final fullName = TextEditingController();
  final email = TextEditingController(text: 'ahmad.faisal@email.com');
  final password = TextEditingController(text: 'password');
  final confirmPassword = TextEditingController();
  bool createAccount = false;
  bool obscure = true;
  String? errorMessage;

  String get roleName => switch (role) {
        _CompactLoginRole.owner => 'Owner',
        _CompactLoginRole.tenant => 'Tenant',
        _CompactLoginRole.technician => 'Technician',
        _CompactLoginRole.agent => 'Agent',
      };

  @override
  void dispose() {
    fullName.dispose();
    email.dispose();
    password.dispose();
    confirmPassword.dispose();
    super.dispose();
  }

  void login() {
    if (role != _CompactLoginRole.owner) return;
    final store = RentalStoreScope.of(context);
    setState(() => errorMessage = null);
    if (!isValidEmailInput(email.text)) {
      setState(() => errorMessage = 'Please enter a valid email address.');
      return;
    }
    if (password.text.length < 8) {
      setState(() => errorMessage = 'Password must be at least 8 characters.');
      return;
    }
    try {
      if (createAccount) {
        if (!isValidHumanName(fullName.text)) {
          setState(() => errorMessage = 'Full name cannot contain numbers.');
          return;
        }
        if (confirmPassword.text != password.text) {
          setState(() => errorMessage = 'Confirm password does not match.');
          return;
        }
        store.createLocalOwnerAccount(
          fullName: fullName.text,
          email: email.text,
          password: password.text,
        );
      } else {
        store.signInLocalAccount(
          email: email.text,
          password: password.text,
          role: UserRole.owner,
        );
      }
    } catch (error) {
      setState(() =>
          errorMessage = error.toString().replaceFirst('Bad state: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: oceanCanvas,
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              math.max(18, (MediaQuery.sizeOf(context).width - 480) / 2 + 18),
              20,
              math.max(18, (MediaQuery.sizeOf(context).width - 480) / 2 + 18),
              16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  createAccount ? 'Create owner account' : 'Welcome back',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.7,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  createAccount
                      ? 'Fill in your details to create an owner workspace.'
                      : 'Sign in to continue',
                  style: const TextStyle(color: oceanMuted, fontSize: 13),
                ),
                const SizedBox(height: 24),
                const Text(
                  'I AM A',
                  style: TextStyle(
                    color: oceanMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 8),
                const SizedBox(height: 4),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  childAspectRatio: 3.45,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  children: [
                    _roleChoice(
                        _CompactLoginRole.owner, Icons.home_outlined, 'Owner'),
                    _roleChoice(_CompactLoginRole.tenant,
                        Icons.person_outline_rounded, 'Tenant'),
                    _roleChoice(_CompactLoginRole.technician,
                        Icons.bolt_rounded, 'Technician'),
                    _roleChoice(_CompactLoginRole.agent,
                        Icons.work_outline_rounded, 'Agent'),
                  ],
                ),
                const SizedBox(height: 20),
                if (createAccount) ...[
                  const Text('Full name', style: TextStyle(fontSize: 12)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: fullName,
                    textCapitalization: TextCapitalization.words,
                    inputFormatters: [
                      FilteringTextInputFormatter.deny(RegExp(r'[0-9]')),
                    ],
                    decoration: const InputDecoration(
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                    ),
                  ),
                  const SizedBox(height: 13),
                ],
                const Text('Email', style: TextStyle(fontSize: 12)),
                const SizedBox(height: 6),
                TextField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                  ),
                ),
                const SizedBox(height: 13),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final twoColumn =
                        createAccount && constraints.maxWidth >= 430;
                    final passwordField = Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('Password', style: TextStyle(fontSize: 12)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: password,
                          obscureText: obscure,
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 13),
                            suffixIcon: IconButton(
                              onPressed: () =>
                                  setState(() => obscure = !obscure),
                              icon: Icon(obscure
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined),
                            ),
                          ),
                        ),
                      ],
                    );
                    final confirmField = Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('Confirm password',
                            style: TextStyle(fontSize: 12)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: confirmPassword,
                          obscureText: obscure,
                          decoration: const InputDecoration(
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 14, vertical: 13),
                          ),
                        ),
                      ],
                    );
                    if (!createAccount) return passwordField;
                    if (twoColumn) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: passwordField),
                          const SizedBox(width: 12),
                          Expanded(child: confirmField),
                        ],
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        passwordField,
                        const SizedBox(height: 13),
                        confirmField,
                      ],
                    );
                  },
                ),
                if (errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF1F2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFECACA)),
                    ),
                    child: Text(
                      errorMessage!,
                      style: const TextStyle(
                        color: Color(0xFFB42318),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                if (!createAccount)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        if (!isValidEmailInput(email.text)) {
                          setState(() => errorMessage =
                              'Enter your registered email first.');
                          return;
                        }
                        final exists =
                            RentalStoreScope.of(context).hasLocalAccount(
                          email.text,
                          UserRole.owner,
                        );
                        setState(() => errorMessage = exists
                            ? 'Password reset link will be sent when email/SMS service is connected. For now, contact the app owner/admin.'
                            : 'No owner account found for this email.');
                      },
                      child: const Text('Forgot password?',
                          style: TextStyle(fontSize: 12)),
                    ),
                  )
                else
                  const SizedBox(height: 12),
                Center(
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        createAccount
                            ? 'Already have an account? '
                            : 'Don’t have an account? ',
                        style: const TextStyle(
                          color: oceanMuted,
                          fontSize: 12,
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          setState(() {
                            createAccount = !createAccount;
                            errorMessage = null;
                            if (createAccount && password.text == 'password') {
                              password.clear();
                            }
                          });
                        },
                        child: Text(
                          createAccount ? 'Sign in' : 'Create new account',
                          style: const TextStyle(
                            color: oceanDeep,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [oceanSky, oceanBlue, oceanDeep]),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: oceanBlue.withOpacity(0.24),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: login,
                    child: Text(createAccount
                        ? 'Create Owner Account'
                        : 'Log in as $roleName'),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Tenant, technician and agent access remain under maintenance. Owner account creation is enabled for this prototype.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: oceanMuted, fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _roleChoice(_CompactLoginRole value, IconData icon, String label) {
    final active = role == value;
    final enabled = value == _CompactLoginRole.owner;
    return Material(
      color: active
          ? const Color(0xFFEFF6FF)
          : enabled
              ? Colors.white
              : const Color(0xFFF3F4F6),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: enabled ? () => setState(() => role = value) : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: active
                  ? oceanBlue
                  : enabled
                      ? const Color(0xFFE2E8F0)
                      : const Color(0xFFE5E7EB),
              width: active ? 1.4 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 17,
                color: active
                    ? oceanBlue
                    : enabled
                        ? oceanMuted
                        : const Color(0xFFB8C0CC),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: active
                            ? oceanDeep
                            : enabled
                                ? oceanText
                                : const Color(0xFF9CA3AF),
                        fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                      ),
                    ),
                    if (!enabled)
                      const Text(
                        'Under maintenance',
                        maxLines: 1,
                        style: TextStyle(
                          color: Color(0xFFE05A35),
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CloudLoginPanel extends StatefulWidget {
  const _CloudLoginPanel({required this.store});

  final RentalStore store;

  @override
  State<_CloudLoginPanel> createState() => _CloudLoginPanelState();
}

class _CloudLoginPanelState extends State<_CloudLoginPanel> {
  final formKey = GlobalKey<FormState>();
  final fullName = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  bool createAccount = false;
  String accountRole = 'owner';
  bool obscurePassword = true;
  bool loading = false;
  String? errorMessage;

  @override
  void dispose() {
    fullName.dispose();
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!(formKey.currentState?.validate() ?? false)) return;
    setState(() {
      loading = true;
      errorMessage = null;
    });
    try {
      if (createAccount) {
        final signedIn = await widget.store.registerCloudAccount(
          fullName: fullName.text,
          email: email.text,
          password: password.text,
          role: accountRole,
        );
        if (!signedIn && mounted) {
          setState(() {
            createAccount = false;
            errorMessage =
                'Account created. Check your email to confirm it, then sign in.';
          });
        }
      } else {
        await widget.store.signInWithEmail(
          email: email.text,
          password: password.text,
        );
      }
    } on AuthException catch (error) {
      if (mounted) setState(() => errorMessage = error.message);
    } catch (error) {
      if (mounted) {
        setState(() => errorMessage = 'Unable to continue: $error');
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> resetPassword() async {
    final value = email.text.trim();
    if (value.isEmpty) {
      setState(() => errorMessage = 'Enter your email address first.');
      return;
    }
    setState(() {
      loading = true;
      errorMessage = null;
    });
    try {
      await widget.store.sendPasswordReset(value);
      if (mounted) {
        setState(() => errorMessage = 'Password reset email sent.');
      }
    } on AuthException catch (error) {
      if (mounted) setState(() => errorMessage = error.message);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('cloud_login_panel'),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFDCE4F1)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3156A3).withOpacity(0.10),
            blurRadius: 34,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              createAccount ? 'Create your account' : 'Welcome back',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF101828),
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              createAccount
                  ? 'Owners create a workspace; invited tenants connect using the same email supplied by their owner.'
                  : 'Sign in with the account assigned to you.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF667085)),
            ),
            const SizedBox(height: 22),
            if (createAccount) ...[
              DropdownButtonFormField<String>(
                value: accountRole,
                decoration: const InputDecoration(
                  labelText: 'Account type',
                  prefixIcon: Icon(Icons.badge_outlined),
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'owner',
                    child: Text('Property owner'),
                  ),
                  DropdownMenuItem(
                    value: 'tenant',
                    child: Text('Invited tenant'),
                  ),
                ],
                onChanged: (value) => setState(
                  () => accountRole = value ?? accountRole,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: fullName,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Full name',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null || value.trim().length < 2
                    ? 'Enter your full name.'
                    : null,
              ),
              const SizedBox(height: 12),
            ],
            TextFormField(
              controller: email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(
                labelText: 'Email address',
                prefixIcon: Icon(Icons.mail_outline_rounded),
                border: OutlineInputBorder(),
              ),
              validator: (value) => value == null || !value.contains('@')
                  ? 'Enter a valid email address.'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: password,
              obscureText: obscurePassword,
              onFieldSubmitted: (_) => loading ? null : submit(),
              autofillHints: const [AutofillHints.password],
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  onPressed: () => setState(
                    () => obscurePassword = !obscurePassword,
                  ),
                  icon: Icon(
                    obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
              validator: (value) => value == null || value.length < 8
                  ? 'Use at least 8 characters.'
                  : null,
            ),
            if (errorMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F7FC),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  errorMessage!,
                  style: const TextStyle(color: Color(0xFF344054)),
                ),
              ),
            ],
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: loading ? null : submit,
              icon: loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(createAccount
                      ? Icons.person_add_rounded
                      : Icons.login_rounded),
              label: Text(createAccount ? 'Create Account' : 'Sign In'),
            ),
            if (!createAccount)
              TextButton(
                onPressed: loading ? null : resetPassword,
                child: const Text('Forgot password?'),
              ),
            const Divider(height: 24),
            const Text(
              'New accounts are invitation-only. Contact your property owner for access.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF667085), fontSize: 12),
            ),
            const SizedBox(height: 12),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.shield_outlined, size: 15, color: Color(0xFF667085)),
                SizedBox(width: 6),
                Text(
                  'Protected by Supabase Authentication',
                  style: TextStyle(color: Color(0xFF667085), fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LoginExperience extends StatelessWidget {
  const _LoginExperience({
    required this.onOwner,
    required this.onAgent,
    required this.onTenant,
  });

  final VoidCallback onOwner;
  final VoidCallback onAgent;
  final VoidCallback onTenant;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth < 100000) {
        return _CompactRoleLogin(
          onOwner: onOwner,
          onAgent: onAgent,
          onTenant: onTenant,
        );
      }
      return Stack(
        children: [
          const Positioned.fill(child: _LoginBackdrop()),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 680),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const _StandardLoginBrand(),
                      const SizedBox(height: 24),
                      _LoginAccessPanel(
                        onOwner: onOwner,
                        onAgent: onAgent,
                        onTenant: onTenant,
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Collections • Expenses • Utilities • Tenants',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF667085),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    });
  }
}

class _StandardLoginBrand extends StatelessWidget {
  const _StandardLoginBrand();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: const Color(0xFF3156A3),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF3156A3).withOpacity(0.18),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: const Icon(
            Icons.maps_home_work_rounded,
            color: Colors.white,
            size: 32,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Rental Facility Manager',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: const Color(0xFF17233C),
                fontWeight: FontWeight.w900,
                letterSpacing: -0.8,
              ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Property management, simplified.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF667085), fontSize: 15),
        ),
      ],
    );
  }
}

class _LoginBackdrop extends StatelessWidget {
  const _LoginBackdrop();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF8FAFD), Color(0xFFF0F4FB), Color(0xFFE8EEFC)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            left: -120,
            top: -100,
            child: _GlowOrb(
              size: 360,
              color: const Color(0xFF8FAEFF).withOpacity(0.16),
            ),
          ),
          Positioned(
            right: -150,
            bottom: -180,
            child: _GlowOrb(
              size: 460,
              color: const Color(0xFF3156A3).withOpacity(0.10),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withOpacity(0)]),
      ),
    );
  }
}

class _LoginAccessPanel extends StatelessWidget {
  const _LoginAccessPanel({
    required this.onOwner,
    required this.onAgent,
    required this.onTenant,
  });

  final VoidCallback onOwner;
  final VoidCallback onAgent;
  final VoidCallback onTenant;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('login_access_panel'),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFDCE4F1)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3156A3).withOpacity(0.10),
            blurRadius: 34,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 5,
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              color: const Color(0xFF3156A3),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(height: 22),
          Text(
            'Choose your workspace',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF101828),
                  letterSpacing: -0.8,
                ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Continue with the role assigned to your account.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF667085), fontSize: 15),
          ),
          const SizedBox(height: 24),
          _RoleAccessTile(
            icon: Icons.key_rounded,
            title: 'Login as Owner',
            subtitle: 'Manage facilities, finances and approvals',
            onTap: onOwner,
            emphasized: true,
          ),
          const SizedBox(height: 10),
          _RoleAccessTile(
            icon: Icons.real_estate_agent_rounded,
            title: 'Login as Property Agent',
            subtitle: 'Manage daily operations and tenants',
            onTap: onAgent,
            disabled: true,
          ),
          const SizedBox(height: 10),
          _RoleAccessTile(
            icon: Icons.person_rounded,
            title: 'Login as Tenant',
            subtitle: 'View bills, payments and requests',
            onTap: onTenant,
            disabled: true,
          ),
          const SizedBox(height: 20),
          const Row(
            children: [
              Icon(Icons.lock_outline_rounded,
                  size: 15, color: Color(0xFF98A2B3)),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Secure role-based access',
                  style: TextStyle(color: Color(0xFF98A2B3), fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RoleAccessTile extends StatelessWidget {
  const _RoleAccessTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.emphasized = false,
    this.disabled = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool emphasized;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final foreground = disabled
        ? const Color(0xFF98A2B3)
        : emphasized
            ? Colors.white
            : const Color(0xFF17233C);
    return Material(
      color: emphasized
          ? const Color(0xFF3156A3)
          : disabled
              ? const Color(0xFFF4F5F7)
              : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: disabled ? null : onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: emphasized
                  ? const Color(0xFF3156A3)
                  : const Color(0xFFDDE3EC),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: emphasized
                      ? Colors.white.withOpacity(0.14)
                      : disabled
                          ? const Color(0xFFE9ECF1)
                          : const Color(0xFFE8EEFC),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: emphasized
                      ? Colors.white
                      : disabled
                          ? const Color(0xFF98A2B3)
                          : const Color(0xFF3156A3),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: foreground,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: emphasized
                            ? Colors.white.withOpacity(0.7)
                            : const Color(0xFF667085),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (disabled)
                const Text(
                  'Under maintenance',
                  style: TextStyle(
                    color: Color(0xFF98A2B3),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                )
              else
                Icon(Icons.arrow_forward_rounded, color: foreground, size: 19),
            ],
          ),
        ),
      ),
    );
  }
}

class OwnerHomeScreen extends StatefulWidget {
  const OwnerHomeScreen({super.key});

  @override
  State<OwnerHomeScreen> createState() => _OwnerHomeScreenState();
}

class AnimatedTabIndexedStack extends StatefulWidget {
  const AnimatedTabIndexedStack({
    required this.index,
    required this.children,
    super.key,
  });

  final int index;
  final List<Widget> children;

  @override
  State<AnimatedTabIndexedStack> createState() =>
      _AnimatedTabIndexedStackState();
}

class _AnimatedTabIndexedStackState extends State<AnimatedTabIndexedStack>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;
  late int currentIndex;
  late int previousIndex;
  int direction = 1;

  @override
  void initState() {
    super.initState();
    currentIndex = widget.index;
    previousIndex = widget.index;
    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    )..value = 1;
  }

  @override
  void didUpdateWidget(covariant AnimatedTabIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.index == currentIndex) return;
    previousIndex = currentIndex;
    direction = widget.index > currentIndex ? 1 : -1;
    currentIndex = widget.index;
    controller.forward(from: 0);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(
      parent: controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return Stack(
      fit: StackFit.expand,
      children: List.generate(widget.children.length, (index) {
        final child = KeyedSubtree(
          key: ValueKey('tab_$index'),
          child: widget.children[index],
        );
        if (index == currentIndex) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: Offset(0.045 * direction, 0),
              end: Offset.zero,
            ).animate(curved),
            child: FadeTransition(
              opacity: Tween<double>(begin: 0.0, end: 1.0).animate(curved),
              child: child,
            ),
          );
        }
        if (index == previousIndex && controller.value < 1) {
          return IgnorePointer(
            child: SlideTransition(
              position: Tween<Offset>(
                begin: Offset.zero,
                end: Offset(-0.025 * direction, 0),
              ).animate(curved),
              child: FadeTransition(
                opacity: Tween<double>(begin: 1.0, end: 0.0).animate(curved),
                child: child,
              ),
            ),
          );
        }
        return Offstage(
          offstage: true,
          child: TickerMode(enabled: false, child: child),
        );
      }),
    );
  }
}

class NotificationBellIcon extends StatefulWidget {
  const NotificationBellIcon({required this.unreadCount, super.key});

  final int unreadCount;

  @override
  State<NotificationBellIcon> createState() => _NotificationBellIconState();
}

class _NotificationBellIconState extends State<NotificationBellIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;
  late final Animation<double> turns;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 760),
    );
    turns = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -0.055), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -0.055, end: 0.055), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 0.055, end: -0.045), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -0.045, end: 0.035), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 0.035, end: 0), weight: 1),
    ]).animate(CurvedAnimation(parent: controller, curve: Curves.easeInOut));
    if (widget.unreadCount > 0) controller.repeat();
  }

  @override
  void didUpdateWidget(covariant NotificationBellIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.unreadCount > 0 && !controller.isAnimating) {
      controller.repeat();
    }
    if (widget.unreadCount == 0 && controller.isAnimating) {
      controller.stop();
      controller.value = 0;
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bell = RotationTransition(
      turns: widget.unreadCount > 0
          ? turns
          : const AlwaysStoppedAnimation<double>(0),
      child: Icon(
        widget.unreadCount > 0
            ? Icons.notifications_active_rounded
            : Icons.notifications_outlined,
      ),
    );
    if (widget.unreadCount == 0) return bell;
    return Badge(
      label: Text('${widget.unreadCount}'),
      child: bell,
    );
  }
}

class _OwnerHomeScreenState extends State<OwnerHomeScreen> {
  int selectedIndex = 2;

  static const pages = [
    FacilitiesTab(),
    AdvancedReviewTab(),
    OwnerReportTab(),
    OwnerRequestsFeedTab(),
    OwnerAccountTab(),
  ];

  @override
  Widget build(BuildContext context) {
    final store = RentalStoreScope.of(context);
    final titles = [
      tr(context, 'Properties'),
      tr(context, 'Payments'),
      tr(context, 'Home'),
      tr(context, 'Requests'),
      tr(context, 'Profile'),
    ];
    final title = selectedIndex == 2
        ? '${tr(context, timeGreeting(DateTime.now()))}, ${firstName(store.currentUser!.name)}'
        : titles[selectedIndex];
    return Scaffold(
      appBar: AppBar(
        backgroundColor: selectedIndex == 2 ? Colors.white : oceanCanvas,
        foregroundColor: oceanText,
        title: Text(title),
        actions: [
          IconButton(
            tooltip: tr(context, 'Notifications'),
            onPressed: () => showNotifications(context),
            icon: NotificationBellIcon(
              unreadCount: store.unreadNotificationCount,
            ),
          ),
          IconButton(
            tooltip: tr(context, 'Log out'),
            onPressed: () => confirmLogout(context),
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: AnimatedTabIndexedStack(
        index: selectedIndex,
        children: pages,
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: AppBottomNavigator(
          selectedIndex: selectedIndex,
          onSelected: (index) {
            if (index == selectedIndex) return;
            setState(() {
              selectedIndex = index;
            });
          },
          items: [
            AppBottomNavItem(
              icon: Icons.apartment_outlined,
              activeIcon: Icons.apartment_rounded,
              label: tr(context, 'Properties'),
            ),
            AppBottomNavItem(
              icon: Icons.payments_outlined,
              activeIcon: Icons.payments_rounded,
              label: tr(context, 'Payments'),
            ),
            AppBottomNavItem(
              icon: Icons.home_outlined,
              activeIcon: Icons.home_rounded,
              label: tr(context, 'Home'),
            ),
            AppBottomNavItem(
              icon: Icons.bolt_outlined,
              activeIcon: Icons.bolt_rounded,
              label: tr(context, 'Requests'),
            ),
            AppBottomNavItem(
              icon: Icons.person_outline_rounded,
              activeIcon: Icons.person_rounded,
              label: tr(context, 'Profile'),
            ),
          ],
        ),
      ),
    );
  }
}

class AppBottomNavItem {
  const AppBottomNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.badgeLabel,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String? badgeLabel;
}

class AppBottomNavigator extends StatelessWidget {
  const AppBottomNavigator({
    required this.selectedIndex,
    required this.items,
    required this.onSelected,
    super.key,
  });

  final int selectedIndex;
  final List<AppBottomNavItem> items;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.transparent,
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x140F172A),
              blurRadius: 12,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: SizedBox(
          height: 52,
          child: Row(
            children: [
              for (var index = 0; index < items.length; index++)
                Expanded(
                  child: _AppBottomNavTile(
                    item: items[index],
                    selected: index == selectedIndex,
                    onTap: () => onSelected(index),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppBottomNavTile extends StatelessWidget {
  const _AppBottomNavTile({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final AppBottomNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? oceanDeep : const Color(0xFF64748B);
    final labelStyle = TextStyle(
      color: color,
      fontSize: 9,
      height: 1.1,
      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
    );
    final icon = Icon(
      selected ? item.activeIcon : item.icon,
      color: color,
      size: 19,
    );
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              width: selected ? 38 : 0,
              height: 2,
              decoration: BoxDecoration(
                color: selected ? oceanDeep : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (item.badgeLabel == null)
                      icon
                    else
                      Badge(
                        label: Text(item.badgeLabel!),
                        child: icon,
                      ),
                    const SizedBox(height: 2),
                    Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: labelStyle,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DirectionalContentSwitcher extends StatelessWidget {
  const DirectionalContentSwitcher({
    required this.switchKey,
    required this.direction,
    required this.child,
    this.offset = 0.08,
    super.key,
  });

  final Object switchKey;
  final int direction;
  final Widget child;
  final double offset;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 320),
      reverseDuration: const Duration(milliseconds: 260),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        final isIncoming = child.key == ValueKey<Object>(switchKey);
        final signedOffset = offset * (direction == 0 ? 1 : direction);
        final slide = Tween<Offset>(
          begin: Offset(isIncoming ? signedOffset : -signedOffset, 0),
          end: Offset.zero,
        ).animate(animation);
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: slide, child: child),
        );
      },
      child: KeyedSubtree(
        key: ValueKey<Object>(switchKey),
        child: child,
      ),
    );
  }
}

Widget horizontalSwipeArea({
  required Widget child,
  required VoidCallback? onPrevious,
  required VoidCallback? onNext,
}) {
  return GestureDetector(
    behavior: HitTestBehavior.translucent,
    onHorizontalDragEnd: (details) {
      final velocity = details.primaryVelocity ?? 0;
      if (velocity > 250) {
        onPrevious?.call();
      } else if (velocity < -250) {
        onNext?.call();
      }
    },
    child: child,
  );
}

Facility? adjacentFacility(
  List<Facility> facilities,
  String selectedFacilityId,
  int step,
) {
  if (facilities.isEmpty) return null;
  final index = facilities.indexWhere((item) => item.id == selectedFacilityId);
  if (index < 0) return null;
  final nextIndex = index + step;
  if (nextIndex < 0 || nextIndex >= facilities.length) return null;
  return facilities[nextIndex];
}

String? adjacentTenantId(
  List<Tenancy> tenancies,
  String? selectedTenantId,
  int step,
) {
  final ids = <String?>[null, ...tenancies.map((item) => item.tenantId)];
  final index = ids.indexOf(selectedTenantId);
  if (index < 0) return null;
  final nextIndex = index + step;
  if (nextIndex < 0 || nextIndex >= ids.length) return selectedTenantId;
  return ids[nextIndex];
}

class OwnerReportTab extends StatefulWidget {
  const OwnerReportTab({super.key});

  @override
  State<OwnerReportTab> createState() => _OwnerReportTabState();
}

class _OwnerReportTabState extends State<OwnerReportTab> {
  late int reportYear;

  @override
  void initState() {
    super.initState();
    reportYear = DateTime.now().year;
  }

  @override
  Widget build(BuildContext context) {
    final store = RentalStoreScope.of(context);
    final reports = store.facilityReportsForYear(reportYear);
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
      children: [
        OceanBreezeOwnerHero(store: store, year: reportYear),
        const SizedBox(height: 16),
        YearlyFinancialChart(
          year: reportYear,
          summaries: store.yearlyFinancialSummary(reportYear),
          onPreviousYear: () => setState(() => reportYear--),
          onNextYear: reportYear >= DateTime.now().year
              ? null
              : () => setState(() => reportYear++),
        ),
        const SizedBox(height: 20),
        Text(
          '${tr(context, 'Tap a facility for performance')} \u00b7 $reportYear',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        ...reports.indexed.map((entry) {
          final index = entry.$1;
          final report = entry.$2;
          final colors = facilityCardColors(index);
          void openFacility() {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => FacilityMasterDetailScreen(
                  facility: report.facility,
                  year: reportYear,
                ),
              ),
            );
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 430;
              final cardShape = RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(color: colors.$2.withOpacity(0.24)),
              );
              final facilityIcon = Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colors.$2,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.apartment_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              );
              if (!compact) {
                return Card(
                  elevation: 0,
                  color: colors.$1,
                  shape: cardShape,
                  child: ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                    onTap: openFacility,
                    leading: facilityIcon,
                    title: Text(
                      report.facility.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      '${report.facility.address} \u2022 ${facilityStatusText(report.facility)}',
                    ),
                    trailing: SizedBox(
                      width: 108,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            money(report.netCashflow),
                            style: TextStyle(
                              color: report.netCashflow >= 0
                                  ? Colors.green.shade700
                                  : Colors.red.shade700,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '${money(report.inflow)} / ${money(report.outflow)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }
              return Card(
                elevation: 0,
                color: colors.$1,
                shape: cardShape,
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: openFacility,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        facilityIcon,
                        const SizedBox(width: 11),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                report.facility.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${report.facility.address} \u2022 ${facilityStatusText(report.facility)}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 82,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerRight,
                                child: Text(
                                  money(report.netCashflow),
                                  style: TextStyle(
                                    color: report.netCashflow >= 0
                                        ? Colors.green.shade700
                                        : Colors.red.shade700,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Text(
                                '+ ${money(report.inflow)}',
                                maxLines: 1,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              Text(
                                '- ${money(report.outflow)}',
                                maxLines: 1,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        }),
      ],
    );
  }
}

class OceanBreezeOwnerHero extends StatelessWidget {
  const OceanBreezeOwnerHero({
    required this.store,
    required this.year,
    super.key,
  });

  final RentalStore store;
  final int year;

  @override
  Widget build(BuildContext context) {
    final facilityIds = store.ownerFacilities.map((item) => item.id).toSet();
    final portfolioTenancies = store.tenancies
        .where((item) => facilityIds.contains(item.facilityId))
        .toList();
    final activeTenancies =
        portfolioTenancies.where((item) => item.active).length;
    final reports = store.facilityReportsForYear(year);
    final totalInflow =
        reports.fold<double>(0, (sum, report) => sum + report.inflow);
    final totalOutflow =
        reports.fold<double>(0, (sum, report) => sum + report.outflow);
    return Container(
      constraints: const BoxConstraints(maxWidth: 960),
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [oceanSky, oceanBlue, oceanDeep],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: oceanBlue.withOpacity(0.22),
            blurRadius: 32,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                tr(context, 'Portfolio overview'),
                style: const TextStyle(color: Color(0xDDFFFFFF), fontSize: 14),
              ),
              const Spacer(),
              Tooltip(
                message: 'Account details',
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => showOwnerAccountSetupDialog(context),
                  child: CircleAvatar(
                    backgroundColor: Colors.white.withOpacity(0.22),
                    foregroundColor: Colors.white,
                    child: Text(
                      firstName(store.currentUser!.name).substring(0, 1),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _OceanFinancialTotal(
                  label: tr(context, 'Total Rental Collection'),
                  value: money(totalInflow),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => FinancialDetailsScreen(
                        mode: FinancialDetailMode.collection,
                        year: year,
                      ),
                    ),
                  ),
                ),
              ),
              Container(
                width: 1,
                height: 58,
                margin: const EdgeInsets.symmetric(horizontal: 14),
                color: Colors.white.withOpacity(.28),
              ),
              Expanded(
                child: _OceanFinancialTotal(
                  label: tr(context, 'Total Expenses'),
                  value: money(totalOutflow),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => FinancialDetailsScreen(
                        mode: FinancialDetailMode.expenses,
                        year: year,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _OceanHeroChip(
                  value: '${store.ownerFacilities.length}',
                  label: tr(context, 'Properties'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _OceanHeroChip(
                  value: '$activeTenancies',
                  label: tr(context, 'Active tenants'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _OceanHeroChip(
                  value: '${store.pendingUtilityBillsThisMonth.length}',
                  label: tr(context, 'Readings left'),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => Scaffold(
                        appBar: AppBar(title: const Text('Utility readings')),
                        body: const UtilitiesTab(),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Kept for possible future analytics screen use.
// ignore: unused_element
class PortfolioHealthCard extends StatelessWidget {
  const PortfolioHealthCard({required this.store, super.key});

  final RentalStore store;

  @override
  Widget build(BuildContext context) {
    final facilityIds = store.ownerFacilities.map((item) => item.id).toSet();
    final tenancies = store.tenancies
        .where((item) => facilityIds.contains(item.facilityId))
        .toList();
    final active = tenancies.where((item) => item.active).length;
    final occupancy = tenancies.isEmpty ? 0.0 : active / tenancies.length * 100;
    final ratio =
        store.totalOutflow == 0 ? null : store.totalInflow / store.totalOutflow;
    final roi = store.totalOutflow == 0
        ? null
        : store.netCashflow / store.totalOutflow * 100;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: oceanText.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Portfolio health',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _PortfolioHealthMetric(
                  icon: Icons.pie_chart_outline_rounded,
                  value: '${occupancy.toStringAsFixed(1)}%',
                  label: tr(context, 'Occupancy'),
                ),
              ),
              Expanded(
                child: _PortfolioHealthMetric(
                  icon: Icons.compare_arrows_rounded,
                  value: ratio == null ? 'N/A' : '${ratio.toStringAsFixed(2)}x',
                  label: tr(context, 'Inflow / outflow'),
                ),
              ),
              Expanded(
                child: _PortfolioHealthMetric(
                  icon: Icons.trending_up_rounded,
                  value: roi == null ? 'N/A' : '${roi.toStringAsFixed(1)}%',
                  label: tr(context, 'ROI'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PortfolioHealthMetric extends StatelessWidget {
  const _PortfolioHealthMetric({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: oceanSoft,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: oceanDeep, size: 18),
          ),
          const SizedBox(height: 7),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: oceanMuted, fontSize: 10),
          ),
        ],
      );
}

class _OceanFinancialTotal extends StatelessWidget {
  const _OceanFinancialTotal({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(color: Color(0xCCFFFFFF), fontSize: 11)),
              const SizedBox(height: 3),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -.7,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

class _OceanHeroChip extends StatelessWidget {
  const _OceanHeroChip({
    required this.value,
    required this.label,
    this.onTap,
  });

  final String value;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.20)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  label,
                  style:
                      const TextStyle(color: Color(0xCCFFFFFF), fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      );
}

// ignore: unused_element
class _WorkflowShortcut extends StatelessWidget {
  const _WorkflowShortcut({
    required this.icon,
    required this.label,
    required this.onTap,
    // ignore: unused_element_parameter
    this.pendingCount = 0,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int pendingCount;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 154,
        child: Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: onTap,
            child: Stack(
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: oceanSoft,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(icon, color: oceanBlue, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(label,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700)),
                            Text(
                              pendingCount == 0
                                  ? 'All units completed'
                                  : '$pendingCount unit${pendingCount == 1 ? '' : 's'} left this month',
                              style: TextStyle(
                                color: pendingCount == 0
                                    ? const Color(0xFF16835D)
                                    : oceanMuted,
                                fontSize: 9,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (pendingCount > 0)
                  Positioned(
                    right: 7,
                    top: 7,
                    child: Container(
                      constraints:
                          const BoxConstraints(minWidth: 20, minHeight: 20),
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      decoration: const BoxDecoration(
                        color: Color(0xFFDC2626),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$pendingCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
}

class FacilityDetailScreen extends StatefulWidget {
  const FacilityDetailScreen({
    required this.facility,
    required this.year,
    super.key,
  });

  final Facility facility;
  final int year;

  @override
  State<FacilityDetailScreen> createState() => _FacilityDetailScreenState();
}

class _FacilityDetailScreenState extends State<FacilityDetailScreen> {
  String? selectedTenantId;
  int tenantSlideDirection = 1;

  void selectTenant(List<Tenancy> tenancies, String? tenantId) {
    final currentIndex = selectedTenantId == null
        ? -1
        : tenancies.indexWhere((item) => item.tenantId == selectedTenantId);
    final nextIndex = tenantId == null
        ? -1
        : tenancies.indexWhere((item) => item.tenantId == tenantId);
    setState(() {
      tenantSlideDirection =
          currentIndex >= 0 && nextIndex < currentIndex ? -1 : 1;
      selectedTenantId = tenantId;
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = RentalStoreScope.of(context);
    final facility = widget.facility;
    final inflow = store.facilityInflowForYear(facility.id, widget.year);
    final outflow = store.facilityOutflowForYear(facility, widget.year);
    final net = inflow - outflow;
    final tenants = store.tenancies
        .where((tenancy) => tenancy.facilityId == facility.id)
        .toList();
    final facilityBills = store
        .facilityBills(facility.id)
        .where((bill) => bill.month.year == widget.year)
        .toList();
    final displayedBills = selectedTenantId == null
        ? facilityBills
        : facilityBills
            .where((bill) => bill.tenantId == selectedTenantId)
            .toList();
    final selectedTenant =
        selectedTenantId == null ? null : store.userFor(selectedTenantId!);

    return Scaffold(
      appBar: AppBar(title: Text(facility.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(facility.address, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: Row(
              children: [
                Expanded(
                  child: MetricCard(
                    title: tr(context, 'Rental Collection'),
                    value: money(inflow),
                    icon: Icons.payments_rounded,
                    color: const Color(0xFF16856B),
                    fullWidth: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: MetricCard(
                    title: tr(context, 'Facility Expenses'),
                    value: money(outflow),
                    icon: Icons.receipt_long_rounded,
                    color: const Color(0xFFD16432),
                    fullWidth: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: MetricCard(
                    title: tr(context, 'Net Rental Income'),
                    value: money(net),
                    icon: Icons.savings_rounded,
                    positive: net >= 0,
                    fullWidth: true,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Text(tr(context, 'Tenants'),
                  style: Theme.of(context).textTheme.titleLarge),
              const Spacer(),
              if (selectedTenantId != null)
                TextButton.icon(
                  onPressed: () => selectTenant(tenants, null),
                  icon: const Icon(Icons.people_alt_outlined),
                  label: Text(tr(context, 'All Tenants')),
                ),
              if (selectedTenantId != null) const SizedBox(width: 6),
              FilledButton.icon(
                key: const Key('facility_detail_add_tenant_button'),
                onPressed: () => showAddTenantDialog(context, facility),
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                label: const Text('Add Tenant'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 10,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...tenants.map((tenancy) {
            final tenant = store.userFor(tenancy.tenantId);
            final selected = tenant.id == selectedTenantId;
            return Card(
              elevation: 0,
              color: selected ? const Color(0xFFE8EEFC) : null,
              child: ListTile(
                onTap: () {
                  selectTenant(tenants, tenant.id);
                },
                leading: Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.meeting_room_rounded,
                  color: selected ? const Color(0xFF3156A3) : null,
                ),
                title: Text('${tenant.name} • ${tenancy.unitName}'),
                subtitle: Text(
                  'Rent ${money(tenancy.monthlyRent)} • Lease ${dateLabel(tenancy.leaseStart)} to ${dateLabel(tenancy.leaseEnd)}',
                ),
                trailing: IconButton(
                  tooltip: 'View tenant profile',
                  onPressed: () => showTenantProfileDialog(
                    context,
                    tenant: tenant,
                    tenancy: tenancy,
                  ),
                  icon: const Icon(Icons.account_circle_outlined),
                ),
              ),
            );
          }),
          const SizedBox(height: 16),
          Text(
            selectedTenant == null
                ? '${tr(context, 'Bill Performance')} • ${tr(context, 'All Tenants')}'
                : '${tr(context, 'Bill Performance')} • ${selectedTenant.name}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          DirectionalContentSwitcher(
            switchKey: selectedTenantId ?? 'all-tenants',
            direction: tenantSlideDirection,
            child: Column(
              children: [
                if (displayedBills.isEmpty)
                  const EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'No bill records',
                    message: 'This tenant does not have any bill records yet.',
                  )
                else
                  ...displayedBills.map((bill) {
                    final tenant = store.userFor(bill.tenantId);
                    return Card(
                      elevation: 0,
                      child: ListTile(
                        onTap: () => confirmAndShowInvoicePdf(context, bill),
                        leading: const Icon(Icons.receipt_long_rounded),
                        title:
                            Text('${tenant.name} • ${monthLabel(bill.month)}'),
                        subtitle: Text(
                          'Due ${money(bill.totalAmount)}\n'
                          'Payment date: ${bill.submittedAt == null ? 'Not paid yet' : dateTimeLabel(bill.submittedAt!)}\n'
                          'Invoice release date: ${dateLabel(DateTime(bill.month.year, bill.month.month))}\n'
                          'Payment amount: ${bill.amountPaid > 0 ? money(bill.amountPaid) : 'RM 0'}\n'
                          'Tap to view invoice PDF',
                        ),
                        trailing: StatusChip(status: bill.status),
                      ),
                    );
                  }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class FacilityMasterDetailScreen extends StatefulWidget {
  const FacilityMasterDetailScreen({
    required this.facility,
    required this.year,
    super.key,
  });

  final Facility facility;
  final int year;

  @override
  State<FacilityMasterDetailScreen> createState() =>
      _FacilityMasterDetailScreenState();
}

class _FacilityMasterDetailScreenState
    extends State<FacilityMasterDetailScreen> {
  String? selectedTenantId;
  bool sidebarCollapsed = false;
  int tenantSlideDirection = 1;

  void selectTenant(List<Tenancy> tenancies, String? tenantId) {
    final currentIndex = selectedTenantId == null
        ? -1
        : tenancies.indexWhere((item) => item.tenantId == selectedTenantId);
    final nextIndex = tenantId == null
        ? -1
        : tenancies.indexWhere((item) => item.tenantId == tenantId);
    setState(() {
      tenantSlideDirection =
          currentIndex >= 0 && nextIndex < currentIndex ? -1 : 1;
      selectedTenantId = tenantId;
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = RentalStoreScope.of(context);
    final facility = widget.facility;
    final tenants = store.tenancies
        .where((tenancy) => tenancy.facilityId == facility.id)
        .toList();
    final bills = store
        .facilityBills(facility.id)
        .where((bill) =>
            bill.month.year == widget.year &&
            (selectedTenantId == null || bill.tenantId == selectedTenantId))
        .toList();
    final selectedTenant =
        selectedTenantId == null ? null : store.userFor(selectedTenantId!);
    final inflow = store.facilityInflowForYear(facility.id, widget.year);
    final outflow = store.facilityOutflowForYear(facility, widget.year);

    return Scaffold(
      appBar: AppBar(title: Text(facility.name)),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 760) {
            return horizontalSwipeArea(
              onPrevious: () {
                final tenantId =
                    adjacentTenantId(tenants, selectedTenantId, -1);
                if (tenantId != selectedTenantId) {
                  selectTenant(tenants, tenantId);
                }
              },
              onNext: () {
                final tenantId = adjacentTenantId(tenants, selectedTenantId, 1);
                if (tenantId != selectedTenantId) {
                  selectTenant(tenants, tenantId);
                }
              },
              child: DirectionalContentSwitcher(
                switchKey: selectedTenantId ?? 'all-tenants',
                direction: tenantSlideDirection,
                child: _CompactFacilityPerformance(
                  facility: facility,
                  tenants: tenants,
                  bills: bills,
                  selectedTenantId: selectedTenantId,
                  inflow: inflow,
                  outflow: outflow,
                  year: widget.year,
                  onTenantSelected: (tenantId) {
                    selectTenant(tenants, tenantId);
                  },
                ),
              ),
            );
          }
          final detail = horizontalSwipeArea(
            onPrevious: () {
              final tenantId = adjacentTenantId(tenants, selectedTenantId, -1);
              if (tenantId != selectedTenantId) {
                selectTenant(tenants, tenantId);
              }
            },
            onNext: () {
              final tenantId = adjacentTenantId(tenants, selectedTenantId, 1);
              if (tenantId != selectedTenantId) {
                selectTenant(tenants, tenantId);
              }
            },
            child: DirectionalContentSwitcher(
              switchKey: selectedTenantId ?? 'all-tenants',
              direction: tenantSlideDirection,
              child: _FacilityBillPerformance(
                facility: facility,
                bills: bills,
                selectedTenant: selectedTenant,
                year: widget.year,
              ),
            ),
          );
          final expandedWidth = math.min(320.0, constraints.maxWidth * 0.42);
          return Row(
            children: [
              AnimatedContainer(
                key: const Key('facility_performance_sidebar'),
                duration: const Duration(milliseconds: 220),
                width: sidebarCollapsed ? 76 : expandedWidth,
                child: _FacilityPerformanceSidebar(
                  facility: facility,
                  tenants: tenants,
                  selectedTenantId: selectedTenantId,
                  inflow: inflow,
                  outflow: outflow,
                  onToggleCollapsed: () {
                    setState(() => sidebarCollapsed = !sidebarCollapsed);
                  },
                  onTenantSelected: (tenantId) {
                    selectTenant(tenants, tenantId);
                    sidebarCollapsed = true;
                  },
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: Listener(
                  behavior: HitTestBehavior.translucent,
                  onPointerDown: (_) {
                    if (!sidebarCollapsed) {
                      setState(() => sidebarCollapsed = true);
                    }
                  },
                  child: detail,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FacilityPerformanceSidebar extends StatelessWidget {
  const _FacilityPerformanceSidebar({
    required this.facility,
    required this.tenants,
    required this.selectedTenantId,
    required this.inflow,
    required this.outflow,
    required this.onToggleCollapsed,
    required this.onTenantSelected,
  });

  final Facility facility;
  final List<Tenancy> tenants;
  final String? selectedTenantId;
  final double inflow;
  final double outflow;
  final VoidCallback onToggleCollapsed;
  final ValueChanged<String?> onTenantSelected;

  @override
  Widget build(BuildContext context) {
    final store = RentalStoreScope.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 200;
        return ColoredBox(
          color: Colors.white,
          child: Padding(
            padding: EdgeInsets.all(narrow ? 8 : 12),
            child: Column(
              crossAxisAlignment: narrow
                  ? CrossAxisAlignment.center
                  : CrossAxisAlignment.stretch,
              children: [
                if (narrow)
                  IconButton(
                    key: const Key('toggle_performance_sidebar_button'),
                    tooltip: 'Expand summary and tenants',
                    onPressed: onToggleCollapsed,
                    icon: const Icon(Icons.chevron_right_rounded),
                  )
                else
                  Row(
                    children: [
                      const Icon(Icons.dashboard_rounded,
                          color: Color(0xFF3156A3)),
                      const SizedBox(width: 9),
                      const Expanded(
                        child: Text(
                          'FACILITY OVERVIEW',
                          style: TextStyle(
                            color: Color(0xFF667085),
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      IconButton(
                        key: const Key('toggle_performance_sidebar_button'),
                        tooltip: 'Collapse summary and tenants',
                        onPressed: onToggleCollapsed,
                        icon: const Icon(Icons.chevron_left_rounded),
                      ),
                    ],
                  ),
                const SizedBox(height: 6),
                Expanded(
                  child: ListView(
                    children: [
                      if (narrow) ...[
                        _CollapsedSidebarIcon(
                          icon: Icons.payments_rounded,
                          color: const Color(0xFF16856B),
                          tooltip: 'Rental Collection',
                          onTap: onToggleCollapsed,
                        ),
                        _CollapsedSidebarIcon(
                          icon: Icons.receipt_long_rounded,
                          color: const Color(0xFFD16432),
                          tooltip: 'Facility Expenses',
                          onTap: onToggleCollapsed,
                        ),
                        _CollapsedSidebarIcon(
                          icon: Icons.savings_rounded,
                          color: const Color(0xFFC43D4B),
                          tooltip: 'Net Rental Income',
                          onTap: onToggleCollapsed,
                        ),
                        const Divider(height: 20),
                      ] else ...[
                        const _SidebarSectionLabel(label: 'SUMMARY'),
                        Row(
                          children: [
                            Expanded(
                              child: _CompactSummaryMetric(
                                title: tr(context, 'Rental Collection'),
                                value: money(inflow),
                                icon: Icons.payments_rounded,
                                color: const Color(0xFF16856B),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: _CompactSummaryMetric(
                                title: tr(context, 'Facility Expenses'),
                                value: money(outflow),
                                icon: Icons.receipt_long_rounded,
                                color: const Color(0xFFD16432),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: _CompactSummaryMetric(
                                title: tr(context, 'Net Rental Income'),
                                value: money(inflow - outflow),
                                icon: Icons.savings_rounded,
                                color: inflow - outflow >= 0
                                    ? const Color(0xFF16856B)
                                    : const Color(0xFFC43D4B),
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 26),
                        const _SidebarSectionLabel(label: 'TENANTS'),
                      ],
                      if (narrow)
                        Card(
                          color: selectedTenantId == null
                              ? const Color(0xFFE8EEFC)
                              : null,
                          child: InkWell(
                            key: const Key('all_tenants_filter'),
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => onTenantSelected(null),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 14),
                              child: Center(child: Icon(Icons.groups_rounded)),
                            ),
                          ),
                        )
                      else
                        Card(
                          color: selectedTenantId == null
                              ? const Color(0xFFE8EEFC)
                              : null,
                          child: ListTile(
                            key: const Key('all_tenants_filter'),
                            dense: true,
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 10),
                            onTap: () => onTenantSelected(null),
                            leading: const Icon(Icons.groups_rounded),
                            title: Text(tr(context, 'All Tenants')),
                            subtitle: Text('${tenants.length} tenant(s)'),
                          ),
                        ),
                      ...tenants.map((tenancy) {
                        final tenant = store.userFor(tenancy.tenantId);
                        final selected = tenant.id == selectedTenantId;
                        if (narrow) {
                          return Card(
                            color: selected ? const Color(0xFFE8EEFC) : null,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => onTenantSelected(tenant.id),
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                child: Center(
                                  child: Icon(
                                    selected
                                        ? Icons.check_circle_rounded
                                        : Icons.meeting_room_rounded,
                                    color: selected
                                        ? const Color(0xFF3156A3)
                                        : null,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }
                        return Card(
                          color: selected ? const Color(0xFFE8EEFC) : null,
                          child: ListTile(
                            dense: true,
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 10),
                            onTap: () => onTenantSelected(tenant.id),
                            leading: selected
                                ? const Icon(
                                    Icons.check_circle_rounded,
                                    color: Color(0xFF3156A3),
                                  )
                                : TenantGenderAvatar(
                                    tenant: tenant,
                                    radius: 16,
                                  ),
                            title: narrow ? null : Text(tenant.name),
                            subtitle: narrow
                                ? null
                                : Text(
                                    '${tenancy.unitName} • ${money(tenancy.monthlyRent)}',
                                  ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SidebarSectionLabel extends StatelessWidget {
  const _SidebarSectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 7),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF98A2B3),
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

class _CompactSummaryMetric extends StatelessWidget {
  const _CompactSummaryMetric({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final veryNarrow = constraints.maxWidth < 76;
        final phoneCompact = constraints.maxWidth < 110;
        return Container(
          constraints: const BoxConstraints(minHeight: 74),
          padding: EdgeInsets.symmetric(
            horizontal: phoneCompact ? 7 : 10,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: color.withOpacity(0.07),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.22)),
          ),
          child: veryNarrow
              ? Center(child: Icon(icon, color: color, size: 18))
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: phoneCompact ? 24 : 28,
                      height: phoneCompact ? 24 : 28,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Icon(icon,
                          color: color, size: phoneCompact ? 14 : 16),
                    ),
                    SizedBox(width: phoneCompact ? 5 : 7),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Color(0xFF667085),
                              fontSize: phoneCompact ? 9 : 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 3),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              value,
                              maxLines: 1,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}

class _CollapsedSidebarIcon extends StatelessWidget {
  const _CollapsedSidebarIcon({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '$tooltip • click to expand',
      child: IconButton(
        onPressed: onTap,
        icon: Icon(icon, color: color, size: 23),
      ),
    );
  }
}

class _FacilityBillPerformance extends StatelessWidget {
  const _FacilityBillPerformance({
    required this.facility,
    required this.bills,
    required this.selectedTenant,
    required this.year,
  });

  final Facility facility;
  final List<MonthlyBill> bills;
  final AppUser? selectedTenant;
  final int year;

  @override
  Widget build(BuildContext context) {
    final store = RentalStoreScope.of(context);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          facility.name,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 3),
        Text(facility.address,
            style: const TextStyle(color: Color(0xFF667085))),
        const SizedBox(height: 4),
        Text(
          'Performance year: $year',
          style: const TextStyle(
            color: Color(0xFF667085),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 22),
        Text(
          selectedTenant == null
              ? '${tr(context, 'Bill Performance')} • ${tr(context, 'All Tenants')}'
              : '${tr(context, 'Bill Performance')} • ${selectedTenant!.name}',
          key: const Key('bill_performance_detail'),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 8),
        if (bills.isEmpty)
          EmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'No bill records for $year',
            message: 'This tenant does not have bill records for this year.',
          )
        else
          ...bills.map((bill) {
            final tenant = store.userFor(bill.tenantId);
            return Card(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth >= 340) {
                    return ListTile(
                      onTap: () => confirmAndShowInvoicePdf(context, bill),
                      leading: const Icon(Icons.receipt_long_rounded),
                      title: Text('${tenant.name} • ${monthLabel(bill.month)}'),
                      subtitle: Text(
                        'Due ${money(bill.totalAmount)}\n'
                        'Payment date: ${bill.submittedAt == null ? 'Not paid yet' : dateTimeLabel(bill.submittedAt!)}\n'
                        'Invoice release date: ${dateLabel(DateTime(bill.month.year, bill.month.month))}\n'
                        'Payment amount: ${bill.amountPaid > 0 ? money(bill.amountPaid) : 'RM 0'}\n'
                        'Tap to view invoice PDF',
                      ),
                      trailing: StatusChip(status: bill.status),
                    );
                  }
                  return Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.receipt_long_rounded, size: 20),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Text(
                                '${tenant.name} • ${monthLabel(bill.month)}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text('Due ${money(bill.totalAmount)}'),
                        const SizedBox(height: 4),
                        Text(
                          'Payment date: ${bill.submittedAt == null ? 'Not paid yet' : dateTimeLabel(bill.submittedAt!)}',
                        ),
                        Text(
                          'Invoice release date: ${dateLabel(DateTime(bill.month.year, bill.month.month))}',
                        ),
                        Text(
                          'Payment amount: ${bill.amountPaid > 0 ? money(bill.amountPaid) : 'RM 0'}',
                        ),
                        TextButton.icon(
                          onPressed: () =>
                              confirmAndShowInvoicePdf(context, bill),
                          icon: const Icon(Icons.picture_as_pdf_outlined,
                              size: 18),
                          label: const Text('View invoice PDF'),
                        ),
                        const SizedBox(height: 9),
                        Align(
                          alignment: Alignment.centerRight,
                          child: StatusChip(status: bill.status),
                        ),
                      ],
                    ),
                  );
                },
              ),
            );
          }),
      ],
    );
  }
}

class _CompactFacilityPerformance extends StatelessWidget {
  const _CompactFacilityPerformance({
    required this.facility,
    required this.tenants,
    required this.bills,
    required this.selectedTenantId,
    required this.inflow,
    required this.outflow,
    required this.year,
    required this.onTenantSelected,
  });

  final Facility facility;
  final List<Tenancy> tenants;
  final List<MonthlyBill> bills;
  final String? selectedTenantId;
  final double inflow;
  final double outflow;
  final int year;
  final ValueChanged<String?> onTenantSelected;

  @override
  Widget build(BuildContext context) {
    final store = RentalStoreScope.of(context);
    final selectedTenant =
        selectedTenantId == null ? null : store.userFor(selectedTenantId!);
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Text(facility.address,
            style: const TextStyle(color: Color(0xFF667085))),
        const SizedBox(height: 4),
        Text(
          'Performance year: $year',
          style: const TextStyle(
            color: Color(0xFF667085),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _CompactSummaryMetric(
                title: tr(context, 'Rental Collection'),
                value: money(inflow),
                icon: Icons.payments_rounded,
                color: const Color(0xFF16856B),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _CompactSummaryMetric(
                title: tr(context, 'Facility Expenses'),
                value: money(outflow),
                icon: Icons.receipt_long_rounded,
                color: const Color(0xFFD16432),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _CompactSummaryMetric(
                title: tr(context, 'Net Rental Income'),
                value: money(inflow - outflow),
                icon: Icons.savings_rounded,
                color: inflow - outflow >= 0
                    ? const Color(0xFF16856B)
                    : const Color(0xFFC43D4B),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(tr(context, 'Tenants'),
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w800)),
        Card(
          color: selectedTenantId == null ? const Color(0xFFE8EEFC) : null,
          child: ListTile(
            key: const Key('all_tenants_filter'),
            onTap: () => onTenantSelected(null),
            leading: const Icon(Icons.groups_rounded),
            title: Text(tr(context, 'All Tenants')),
          ),
        ),
        ...tenants.map((tenancy) {
          final tenant = store.userFor(tenancy.tenantId);
          return Card(
            color:
                selectedTenantId == tenant.id ? const Color(0xFFE8EEFC) : null,
            child: ListTile(
              onTap: () => onTenantSelected(tenant.id),
              leading: TenantGenderAvatar(tenant: tenant, radius: 18),
              title: Text(tenant.name),
              subtitle:
                  Text('${tenancy.unitName} • ${money(tenancy.monthlyRent)}'),
            ),
          );
        }),
        const SizedBox(height: 14),
        Text(
          selectedTenant == null
              ? '${tr(context, 'Bill Performance')} • ${tr(context, 'All Tenants')}'
              : '${tr(context, 'Bill Performance')} • ${selectedTenant.name}',
          key: const Key('bill_performance_detail'),
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        ...bills.map((bill) {
          final tenant = store.userFor(bill.tenantId);
          return Card(
            child: ListTile(
              onTap: () => confirmAndShowInvoicePdf(context, bill),
              leading: const Icon(Icons.receipt_long_rounded),
              title: Text('${tenant.name} • ${monthLabel(bill.month)}'),
              subtitle: Text(
                'Due ${money(bill.totalAmount)}\n'
                'Payment date: ${bill.submittedAt == null ? 'Not paid yet' : dateTimeLabel(bill.submittedAt!)}\n'
                'Invoice release date: ${dateLabel(DateTime(bill.month.year, bill.month.month))}\n'
                'Payment amount: ${bill.amountPaid > 0 ? money(bill.amountPaid) : 'RM 0'}\n'
                'Tap to view invoice PDF',
              ),
              trailing: StatusChip(status: bill.status),
            ),
          );
        }),
      ],
    );
  }
}

enum FinancialDetailMode { collection, expenses, netIncome }

class FinancialDetailsScreen extends StatefulWidget {
  const FinancialDetailsScreen({
    required this.mode,
    required this.year,
    super.key,
  });

  final FinancialDetailMode mode;
  final int year;

  @override
  State<FinancialDetailsScreen> createState() => _FinancialDetailsScreenState();
}

class _FinancialDetailsScreenState extends State<FinancialDetailsScreen> {
  String? selectedFacilityId;
  bool sidebarCollapsed = false;
  int facilitySlideDirection = 1;

  void selectFacility(List<Facility> facilities, Facility facility) {
    final currentIndex =
        facilities.indexWhere((item) => item.id == selectedFacilityId);
    final nextIndex = facilities.indexWhere((item) => item.id == facility.id);
    setState(() {
      facilitySlideDirection =
          currentIndex >= 0 && nextIndex < currentIndex ? -1 : 1;
      selectedFacilityId = facility.id;
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = RentalStoreScope.of(context);
    final mode = widget.mode;
    final facilities = store.ownerFacilities;
    final selectedFacility = facilities.firstWhere(
      (facility) => facility.id == selectedFacilityId,
      orElse: () => facilities.first,
    );
    final title = switch (mode) {
      FinancialDetailMode.collection => 'Rental Collection Details',
      FinancialDetailMode.expenses => 'Expense Details',
      FinancialDetailMode.netIncome => 'Net Rental Income Details',
    };
    final reports = store.facilityReportsForYear(widget.year);
    final yearInflow =
        reports.fold<double>(0, (sum, report) => sum + report.inflow);
    final yearOutflow =
        reports.fold<double>(0, (sum, report) => sum + report.outflow);
    final total = switch (mode) {
      FinancialDetailMode.collection => yearInflow,
      FinancialDetailMode.expenses => yearOutflow,
      FinancialDetailMode.netIncome => yearInflow - yearOutflow,
    };

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final detail = ListView(
            padding: const EdgeInsets.all(18),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(selectedFacility.name,
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w900)),
                        Text(selectedFacility.address,
                            style: const TextStyle(color: Color(0xFF667085))),
                      ],
                    ),
                  ),
                  if (mode == FinancialDetailMode.collection)
                    FilledButton.icon(
                      onPressed: () =>
                          showAddIncomeDialog(context, selectedFacility),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add One-time Income'),
                    ),
                  if (mode == FinancialDetailMode.expenses)
                    FilledButton.icon(
                      onPressed: () =>
                          showAddExpenseDialog(context, selectedFacility),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add One-time Expense'),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Card(
                child: ListTile(
                  leading: Icon(switch (mode) {
                    FinancialDetailMode.collection => Icons.payments_rounded,
                    FinancialDetailMode.expenses => Icons.receipt_long_rounded,
                    FinancialDetailMode.netIncome => Icons.savings_rounded,
                  }),
                  title: Text('All Facilities Total · ${widget.year}'),
                  trailing: Text(money(total),
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w900)),
                ),
              ),
              const SizedBox(height: 8),
              switch (mode) {
                FinancialDetailMode.collection => _CollectionFacilitySection(
                    facility: selectedFacility,
                    year: widget.year,
                  ),
                FinancialDetailMode.expenses => _ExpenseFacilitySection(
                    facility: selectedFacility,
                    year: widget.year,
                  ),
                FinancialDetailMode.netIncome => _NetFacilitySection(
                    facility: selectedFacility,
                    year: widget.year,
                  ),
              },
            ],
          );
          final animatedDetail = horizontalSwipeArea(
            onPrevious: () {
              final facility = adjacentFacility(
                facilities,
                selectedFacility.id,
                -1,
              );
              if (facility != null) selectFacility(facilities, facility);
            },
            onNext: () {
              final facility = adjacentFacility(
                facilities,
                selectedFacility.id,
                1,
              );
              if (facility != null) selectFacility(facilities, facility);
            },
            child: DirectionalContentSwitcher(
              switchKey: selectedFacility.id,
              direction: facilitySlideDirection,
              child: detail,
            ),
          );
          if (constraints.maxWidth < 680) return animatedDetail;
          return Row(
            children: [
              AnimatedContainer(
                key: const Key('financial_detail_sidebar'),
                duration: const Duration(milliseconds: 220),
                width: sidebarCollapsed ? 76 : 230,
                child: _FinancialFacilitySidebar(
                  facilities: facilities,
                  selectedFacilityId: selectedFacility.id,
                  collapsed: sidebarCollapsed,
                  onToggle: () =>
                      setState(() => sidebarCollapsed = !sidebarCollapsed),
                  onSelected: (facility) {
                    selectFacility(facilities, facility);
                    sidebarCollapsed = false;
                  },
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: Listener(
                  behavior: HitTestBehavior.translucent,
                  onPointerDown: (_) {
                    if (!sidebarCollapsed) {
                      setState(() => sidebarCollapsed = true);
                    }
                  },
                  child: animatedDetail,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FinancialFacilitySidebar extends StatelessWidget {
  const _FinancialFacilitySidebar({
    required this.facilities,
    required this.selectedFacilityId,
    required this.collapsed,
    required this.onToggle,
    required this.onSelected,
  });

  final List<Facility> facilities;
  final String selectedFacilityId;
  final bool collapsed;
  final VoidCallback onToggle;
  final ValueChanged<Facility> onSelected;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            if (collapsed)
              IconButton(
                tooltip: 'Expand facilities',
                onPressed: onToggle,
                icon: const Icon(Icons.chevron_right_rounded),
              )
            else
              Row(
                children: [
                  const Expanded(
                    child: Text('FACILITIES',
                        style: TextStyle(
                            color: Color(0xFF667085),
                            fontWeight: FontWeight.w900,
                            letterSpacing: .8)),
                  ),
                  IconButton(
                    tooltip: 'Collapse facilities',
                    onPressed: onToggle,
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                ],
              ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                children: facilities.map((facility) {
                  final selected = facility.id == selectedFacilityId;
                  return Card(
                    color: selected ? const Color(0xFFE8EEFC) : null,
                    child: ListTile(
                      dense: true,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 10),
                      leading: const Icon(Icons.apartment_rounded),
                      title: collapsed ? null : Text(facility.name),
                      onTap: () => onSelected(facility),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CollectionFacilitySection extends StatelessWidget {
  const _CollectionFacilitySection({
    required this.facility,
    required this.year,
  });

  final Facility facility;
  final int year;

  @override
  Widget build(BuildContext context) {
    final store = RentalStoreScope.of(context);
    final approvedBills = store
        .facilityBills(facility.id)
        .where((bill) =>
            bill.status == PaymentStatus.approved &&
            bill.month.year == year &&
            store.isCurrentOrPastMonth(bill.month))
        .toList();
    final tenantIds = approvedBills.map((bill) => bill.tenantId).toSet();
    final otherIncome = store.additionalIncomes
        .where((income) =>
            income.facilityId == facility.id &&
            income.month.year == year &&
            store.isCurrentOrPastMonth(income.month))
        .toList()
      ..sort((a, b) => b.month.compareTo(a.month));

    return Card(
      child: ExpansionTile(
        initiallyExpanded: true,
        leading: const CircleAvatar(child: Icon(Icons.apartment_rounded)),
        title: Text(facility.name),
        subtitle: Text(facility.address),
        trailing: Text(
          money(store.facilityInflowForYear(facility.id, year)),
          style: const TextStyle(
            color: Color(0xFF16856B),
            fontWeight: FontWeight.w800,
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        children: [
          if (approvedBills.isEmpty)
            const ListTile(
              title: Text('No approved rental collections yet.'),
            )
          else
            ...tenantIds.map((tenantId) {
              final tenant = store.userFor(tenantId);
              final tenancy = store.tenancies.firstWhere(
                (item) =>
                    item.tenantId == tenantId && item.facilityId == facility.id,
              );
              final tenantBills = approvedBills
                  .where((bill) => bill.tenantId == tenantId)
                  .toList();
              final tenantTotal = tenantBills.fold<double>(
                0,
                (sum, bill) => sum + bill.totalAmount,
              );
              return Card(
                color: const Color(0xFFF8FAFD),
                child: ExpansionTile(
                  leading: TenantGenderAvatar(tenant: tenant, radius: 18),
                  title: Text('${tenant.name} • ${tenancy.unitName}'),
                  subtitle: Text('${tenantBills.length} approved payment(s)'),
                  trailing: Text(
                    money(tenantTotal),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  children: tenantBills.map((bill) {
                    return ListTile(
                      leading: const Icon(Icons.receipt_rounded),
                      title: Text(monthLabel(bill.month)),
                      subtitle: Text(
                        bill.submittedAt == null
                            ? 'Approved payment'
                            : 'Submitted ${dateTimeLabel(bill.submittedAt!)}',
                      ),
                      trailing: Text(
                        money(bill.totalAmount),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    );
                  }).toList(),
                ),
              );
            }),
          if (otherIncome.isNotEmpty) ...[
            const Divider(),
            const ListTile(
              leading: Icon(Icons.add_circle_outline_rounded),
              title: Text(
                'Other Monthly Income',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            ...otherIncome.map(
              (income) => ListTile(
                leading: const Icon(Icons.payments_outlined),
                title: Text('${income.category} • ${monthLabel(income.month)}'),
                subtitle: Text(income.note),
                trailing: Text(
                  money(income.amount),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ExpenseFacilitySection extends StatelessWidget {
  const _ExpenseFacilitySection({
    required this.facility,
    required this.year,
  });

  final Facility facility;
  final int year;

  @override
  Widget build(BuildContext context) {
    final store = RentalStoreScope.of(context);
    final elapsedMonths =
        year == store.currentMonth.year ? store.elapsedMonthsThisYear : 12;
    final versions = List.generate(
      elapsedMonths,
      (index) => store.costVersionForMonth(
        facility,
        DateTime(year, index + 1),
      ),
    );
    final items = <(String, double, IconData)>[
      (
        'Installment',
        versions.fold<double>(0, (sum, item) => sum + item.installmentAmount),
        Icons.account_balance_rounded
      ),
      (
        'Extra installment',
        versions.fold<double>(
            0, (sum, item) => sum + item.extraInstallmentPayment),
        Icons.add_card_rounded,
      ),
      (
        'Maintenance',
        versions.fold<double>(0, (sum, item) => sum + item.maintenanceFee),
        Icons.handyman_rounded
      ),
      (
        'Fire Insurance',
        List.generate(elapsedMonths, (index) => index + 1).fold<double>(0,
            (sum, month) {
          final version = versions[month - 1];
          final due = month == version.insuranceDueMonth ||
              (version.insuranceFrequency == InsuranceFrequency.halfYearly &&
                  month == ((version.insuranceDueMonth + 5) % 12) + 1);
          return sum + (due ? version.insuranceFee : 0);
        }),
        Icons.local_fire_department_rounded
      ),
      for (final commitment in facility.extraCommitments)
        (
          '${commitment.name} (${commitmentFrequencyText(commitment.frequency)})',
          List.generate(elapsedMonths, (index) => index + 1)
                  .where(
                    (month) => store.isCommitmentDue(
                      commitment.frequency,
                      commitment.firstDueMonth,
                      month,
                    ),
                  )
                  .length *
              commitment.amount,
          Icons.receipt_long_rounded,
        ),
      for (final expense in store.additionalExpenses.where((expense) =>
          expense.facilityId == facility.id && expense.month.year == year))
        (
          '${expense.category} • ${monthLabel(expense.month)}',
          expense.amount,
          Icons.add_circle_outline_rounded,
        ),
    ];

    return Card(
      child: ExpansionTile(
        initiallyExpanded: true,
        leading: const CircleAvatar(child: Icon(Icons.apartment_rounded)),
        title: Text(facility.name),
        subtitle: Text(
          '${facility.address} • $year • January to ${FinancialChartPainter.monthNames[elapsedMonths - 1]}',
        ),
        trailing: Text(
          money(store.facilityOutflowForYear(facility, year)),
          style: const TextStyle(
            color: Color(0xFFD16432),
            fontWeight: FontWeight.w800,
          ),
        ),
        children: items.map((item) {
          return ListTile(
            leading: Icon(item.$3),
            title: Text(item.$1),
            trailing: Text(
              money(item.$2),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _NetFacilitySection extends StatelessWidget {
  const _NetFacilitySection({
    required this.facility,
    required this.year,
  });

  final Facility facility;
  final int year;

  @override
  Widget build(BuildContext context) {
    final store = RentalStoreScope.of(context);
    final collection = store.facilityInflowForYear(facility.id, year);
    final expenses = store.facilityOutflowForYear(facility, year);
    final net = collection - expenses;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              facility.name,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            Text(
              facility.address,
              style: const TextStyle(color: Color(0xFF667085)),
            ),
            const SizedBox(height: 12),
            AmountRow(
                label: tr(context, 'Rental collection'), value: collection),
            AmountRow(label: tr(context, 'Expenses'), value: expenses),
            const Divider(),
            AmountRow(label: 'Net rental income', value: net, bold: true),
          ],
        ),
      ),
    );
  }
}

class FacilitiesTab extends StatefulWidget {
  const FacilitiesTab({super.key});

  @override
  State<FacilitiesTab> createState() => _FacilitiesTabState();
}

class _FacilitiesTabState extends State<FacilitiesTab> {
  String? selectedFacilityId;
  int facilitySlideDirection = 1;

  void selectFacility(List<Facility> facilities, Facility facility) {
    final currentIndex =
        facilities.indexWhere((item) => item.id == selectedFacilityId);
    final nextIndex = facilities.indexWhere((item) => item.id == facility.id);
    setState(() {
      facilitySlideDirection =
          currentIndex >= 0 && nextIndex < currentIndex ? -1 : 1;
      selectedFacilityId = facility.id;
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = RentalStoreScope.of(context);
    final facilities = store.ownerFacilities;
    if (facilities.isEmpty) {
      return EmptyState(
        icon: Icons.apartment_rounded,
        title: 'No facilities yet',
        message: 'Create your first facility to begin managing tenants.',
        action: FilledButton.icon(
          onPressed: () async {
            final facility = await showAddFacilityDialog(context);
            if (facility != null && mounted) {
              setState(() => selectedFacilityId = facility.id);
            }
          },
          icon: const Icon(Icons.add_rounded),
          label: const Text('Create Facility'),
        ),
      );
    }

    final selectedFacility = facilities.firstWhere(
      (facility) => facility.id == selectedFacilityId,
      orElse: () => facilities.first,
    );

    return Column(
      children: [
        _CompactFacilitySelector(
          facilities: facilities,
          selectedFacilityId: selectedFacility.id,
          onSelected: (facility) {
            selectFacility(facilities, facility);
          },
          onCreateFacility: () async {
            final facility = await showAddFacilityDialog(context);
            if (facility != null && mounted) {
              selectFacility(facilities, facility);
            }
          },
        ),
        const Divider(height: 1),
        Expanded(
          child: horizontalSwipeArea(
            onPrevious: () {
              final facility = adjacentFacility(
                facilities,
                selectedFacility.id,
                -1,
              );
              if (facility != null) selectFacility(facilities, facility);
            },
            onNext: () {
              final facility = adjacentFacility(
                facilities,
                selectedFacility.id,
                1,
              );
              if (facility != null) selectFacility(facilities, facility);
            },
            child: DirectionalContentSwitcher(
              switchKey: selectedFacility.id,
              direction: facilitySlideDirection,
              child: _FacilityWorkspace(
                facility: selectedFacility,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CompactFacilitySelector extends StatelessWidget {
  const _CompactFacilitySelector({
    required this.facilities,
    required this.selectedFacilityId,
    required this.onSelected,
    required this.onCreateFacility,
  });

  final List<Facility> facilities;
  final String selectedFacilityId;
  final ValueChanged<Facility> onSelected;
  final Future<void> Function() onCreateFacility;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.white,
      child: SizedBox(
        height: 98,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          scrollDirection: Axis.horizontal,
          itemCount: facilities.length + 1,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (context, index) {
            if (index == facilities.length) {
              return _FacilityCircleButton(
                label: 'Add',
                icon: Icons.add_rounded,
                selected: false,
                onTap: () => onCreateFacility(),
              );
            }
            final facility = facilities[index];
            return _FacilityCircleButton(
              label: facility.name,
              icon: Icons.apartment_rounded,
              selected: facility.id == selectedFacilityId,
              onTap: () => onSelected(facility),
            );
          },
        ),
      ),
    );
  }
}

class _FacilityCircleButton extends StatelessWidget {
  const _FacilityCircleButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? oceanDeep : const Color(0xFF94A3B8);
    return SizedBox(
      width: 64,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: selected ? Colors.white : const Color(0xFFF3F6FA),
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? oceanDeep : const Color(0xFFD6DEEB),
                  width: selected ? 2 : 1,
                ),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 5),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Retained for wide-screen migration compatibility.
// ignore: unused_element
class _FacilitySidebar extends StatelessWidget {
  const _FacilitySidebar({
    required this.facilities,
    required this.selectedFacilityId,
    required this.onSelected,
    required this.onCreateFacility,
    required this.collapsed,
    required this.onToggleCollapsed,
  });

  final List<Facility> facilities;
  final String selectedFacilityId;
  final ValueChanged<Facility> onSelected;
  final Future<void> Function() onCreateFacility;
  final bool collapsed;
  final VoidCallback onToggleCollapsed;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: collapsed
              ? CrossAxisAlignment.center
              : CrossAxisAlignment.stretch,
          children: [
            if (collapsed)
              IconButton(
                key: const Key('toggle_facility_sidebar_button'),
                tooltip: 'Expand facilities',
                onPressed: onToggleCollapsed,
                icon: const Icon(Icons.chevron_right_rounded),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => onCreateFacility(),
                      icon: const Icon(Icons.add_business_rounded),
                      label: const Text('New Facility'),
                    ),
                  ),
                  IconButton(
                    key: const Key('toggle_facility_sidebar_button'),
                    tooltip: 'Collapse facilities',
                    onPressed: onToggleCollapsed,
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                ],
              ),
            const SizedBox(height: 10),
            if (!collapsed)
              Text(
                'MY FACILITIES',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: const Color(0xFF667085),
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
              ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.separated(
                itemCount: facilities.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (context, index) {
                  final facility = facilities[index];
                  final selected = facility.id == selectedFacilityId;
                  return Material(
                    color:
                        selected ? const Color(0xFFE8EEFC) : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    child: ListTile(
                      dense: true,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 10),
                      selected: selected,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      leading: Icon(
                        Icons.apartment_rounded,
                        color: selected ? const Color(0xFF3156A3) : null,
                      ),
                      title: collapsed
                          ? null
                          : Text(
                              facility.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                      onTap: () => onSelected(facility),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FacilityWorkspace extends StatelessWidget {
  const _FacilityWorkspace({
    required this.facility,
    // ignore: unused_element_parameter
    this.compact = false,
  });

  final Facility facility;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final store = RentalStoreScope.of(context);
    final tenants = store.tenancies
        .where((tenancy) => tenancy.facilityId == facility.id)
        .toList();

    return ListView(
      padding: EdgeInsets.all(compact ? 12 : 20),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    facility.name,
                    style: (compact
                            ? Theme.of(context).textTheme.titleLarge
                            : Theme.of(context).textTheme.headlineSmall)
                        ?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    facility.address,
                    style: const TextStyle(color: Color(0xFF667085)),
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: compact ? 10 : 16),
        Card(
          child: Padding(
            padding: EdgeInsets.all(compact ? 12 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Facility Costs',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () =>
                          showPropertyExpenseEditorDialog(context, facility),
                      icon: const Icon(Icons.edit_rounded, size: 18),
                      label: Text(tr(context, 'Edit')),
                    ),
                  ],
                ),
                SizedBox(height: compact ? 6 : 10),
                CostSummary(facility: facility),
              ],
            ),
          ),
        ),
        SizedBox(height: compact ? 10 : 18),
        Row(
          children: [
            Text(
              'Tenants',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(width: 8),
            Chip(label: Text('${tenants.length}')),
            const Spacer(),
            FilledButton.icon(
              key: const Key('add_tenant_button'),
              onPressed: () => showAddTenantDialog(context, facility),
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: Text(tr(context, compact ? 'Add' : 'New Tenant')),
              style: compact
                  ? FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      visualDensity: VisualDensity.compact,
                    )
                  : null,
            ),
          ],
        ),
        SizedBox(height: compact ? 4 : 8),
        if (tenants.isEmpty)
          Card(
            child: Padding(
              padding: EdgeInsets.all(compact ? 14 : 24),
              child: Column(
                children: [
                  Icon(
                    Icons.person_add_alt_rounded,
                    size: compact ? 30 : 42,
                  ),
                  SizedBox(height: compact ? 4 : 8),
                  Text(tr(context, 'No tenants assigned to this facility.')),
                  SizedBox(height: compact ? 8 : 12),
                  FilledButton(
                    onPressed: () => showAddTenantDialog(context, facility),
                    child: Text(tr(context, 'Create Tenant')),
                  ),
                ],
              ),
            ),
          )
        else
          ...tenants.map((tenancy) {
            final tenant = store.userFor(tenancy.tenantId);
            return Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  onTap: () => showTenantProfileDialog(
                    context,
                    tenant: tenant,
                    tenancy: tenancy,
                  ),
                  leading: TenantGenderAvatar(tenant: tenant),
                  title: Text('${tenant.name} • ${tenancy.unitName}'),
                  subtitle: Text(
                      '${tr(context, 'Rent')} ${money(tenancy.monthlyRent)}'),
                  trailing: TenantStatusChip(
                    label: tenantStatusText(tenant, tenancy),
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }
}

class PaymentApprovalsTab extends StatelessWidget {
  const PaymentApprovalsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final store = RentalStoreScope.of(context);
    final pending = store.pendingBills;
    if (pending.isEmpty) {
      return const EmptyState(
        icon: Icons.check_circle,
        title: 'No pending approvals',
        message: 'Tenant payment slips will appear here after submission.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: pending.length,
      itemBuilder: (context, index) {
        final bill = pending[index];
        final tenant = store.userFor(bill.tenantId);
        final facility = store.facilityFor(bill.facilityId);
        return Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${tenant.name} • ${monthLabel(bill.month)}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text('${facility.name} • ${bill.slipFileName}'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 16,
                  runSpacing: 6,
                  children: [
                    Text('Paid: ${money(bill.amountPaid)}'),
                    Text('Due: ${money(bill.totalAmount)}'),
                    Text(
                      'Submitted: ${bill.submittedAt == null ? 'Not recorded' : dateTimeLabel(bill.submittedAt!)}',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () => showPaymentReviewDialog(context, bill),
                  icon: const Icon(Icons.image_search_rounded),
                  label: const Text('View Attachment & Review'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class AdvancedReviewTab extends StatefulWidget {
  const AdvancedReviewTab({super.key});

  @override
  State<AdvancedReviewTab> createState() => _AdvancedReviewTabState();
}

class _AdvancedReviewTabState extends State<AdvancedReviewTab>
    with SingleTickerProviderStateMixin {
  late final TabController controller;
  String? selectedFacilityId;
  int facilitySlideDirection = 1;

  @override
  void initState() {
    super.initState();
    controller = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void selectFacility(List<Facility> facilities, Facility facility) {
    final currentIndex =
        facilities.indexWhere((item) => item.id == selectedFacilityId);
    final nextIndex = facilities.indexWhere((item) => item.id == facility.id);
    setState(() {
      facilitySlideDirection =
          currentIndex >= 0 && nextIndex < currentIndex ? -1 : 1;
      selectedFacilityId = facility.id;
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = RentalStoreScope.of(context);
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final facilities = store.ownerFacilities;
        if (facilities.isEmpty) {
          return const EmptyState(
            icon: Icons.apartment_rounded,
            title: 'No facilities yet',
            message: 'Add a facility before reviewing tenant activity.',
          );
        }
        final selectedFacility = facilities.firstWhere(
          (facility) => facility.id == selectedFacilityId,
          orElse: () => facilities.first,
        );
        final pendingBills = store.pendingBills
            .where((bill) => bill.facilityId == selectedFacility.id)
            .toList();
        final paymentHistory = store.paymentReviewHistory.where((event) {
          final bill = store.bills.firstWhere(
            (bill) => bill.id == event.billId,
          );
          return bill.facilityId == selectedFacility.id;
        }).toList()
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

        final detail = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    selectedFacility.name,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    selectedFacility.address,
                    style: const TextStyle(color: Color(0xFF667085)),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: TabBar(
                controller: controller,
                tabs: [
                  Tab(
                      text:
                          '${tr(context, 'Pending Action')} (${pendingBills.length})'),
                  Tab(
                      text:
                          '${tr(context, 'History')} (${paymentHistory.length})'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: controller,
                children: [
                  _PendingReviewList(
                    bills: pendingBills,
                    requests: const <TenantRequest>[],
                  ),
                  _ReviewHistoryList(
                    paymentEvents: paymentHistory,
                    requests: const <TenantRequest>[],
                  ),
                ],
              ),
            ),
          ],
        );

        return Column(
          children: [
            _CompactPaymentFacilitySelector(
              facilities: facilities,
              selectedFacility: selectedFacility,
              pendingBills: pendingBills,
              badgeCount: (facility) => store.pendingBills
                  .where((bill) => bill.facilityId == facility.id)
                  .length,
              onSelected: (facility) {
                selectFacility(facilities, facility);
              },
            ),
            const Divider(height: 1),
            Expanded(
              child: horizontalSwipeArea(
                onPrevious: () {
                  final facility = adjacentFacility(
                    facilities,
                    selectedFacility.id,
                    -1,
                  );
                  if (facility != null) selectFacility(facilities, facility);
                },
                onNext: () {
                  final facility = adjacentFacility(
                    facilities,
                    selectedFacility.id,
                    1,
                  );
                  if (facility != null) selectFacility(facilities, facility);
                },
                child: DirectionalContentSwitcher(
                  switchKey: selectedFacility.id,
                  direction: facilitySlideDirection,
                  child: detail,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// Retained for wide-screen migration compatibility.
// ignore: unused_element
class _ReviewFacilitySidebar extends StatelessWidget {
  const _ReviewFacilitySidebar({
    required this.facilities,
    required this.selectedFacility,
    required this.onSelected,
    required this.collapsed,
    required this.onToggleCollapsed,
    // ignore: unused_element_parameter
    this.badgeCount,
  });

  final List<Facility> facilities;
  final Facility selectedFacility;
  final ValueChanged<Facility> onSelected;
  final bool collapsed;
  final VoidCallback onToggleCollapsed;
  final int Function(Facility facility)? badgeCount;

  @override
  Widget build(BuildContext context) {
    final store = RentalStoreScope.of(context);
    return ColoredBox(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: collapsed
              ? CrossAxisAlignment.center
              : CrossAxisAlignment.stretch,
          children: [
            if (collapsed)
              IconButton(
                key: const Key('toggle_review_sidebar_button'),
                tooltip: 'Expand review facilities',
                onPressed: onToggleCollapsed,
                icon: const Icon(Icons.chevron_right_rounded),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'REVIEW FACILITIES',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: const Color(0xFF667085),
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                    ),
                  ),
                  IconButton(
                    key: const Key('toggle_review_sidebar_button'),
                    tooltip: 'Collapse review facilities',
                    onPressed: onToggleCollapsed,
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                ],
              ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.separated(
                itemCount: facilities.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (context, index) {
                  final facility = facilities[index];
                  final selected = facility.id == selectedFacility.id;
                  final pendingCount = badgeCount?.call(facility) ??
                      store.pendingBills
                          .where((bill) => bill.facilityId == facility.id)
                          .length;
                  return Material(
                    color:
                        selected ? const Color(0xFFE8EEFC) : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    child: ListTile(
                      dense: true,
                      selected: selected,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      leading: Icon(
                        Icons.apartment_rounded,
                        color: selected ? const Color(0xFF3156A3) : null,
                      ),
                      title: Text(
                        collapsed ? '' : facility.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: collapsed || pendingCount == 0
                          ? null
                          : Badge(label: Text('$pendingCount')),
                      onTap: () => onSelected(facility),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ignore: unused_element
class _CompactReviewFacilitySelector extends StatelessWidget {
  const _CompactReviewFacilitySelector({
    required this.facilities,
    required this.selectedFacility,
    required this.onSelected,
  });

  final List<Facility> facilities;
  final Facility selectedFacility;
  final ValueChanged<Facility> onSelected;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: DropdownButtonFormField<Facility>(
          value: selectedFacility,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Review facility',
            prefixIcon: Icon(Icons.apartment_rounded),
            border: OutlineInputBorder(),
          ),
          items: facilities
              .map(
                (facility) => DropdownMenuItem(
                  value: facility,
                  child: Text(facility.name),
                ),
              )
              .toList(),
          onChanged: (facility) {
            if (facility != null) onSelected(facility);
          },
        ),
      ),
    );
  }
}

// ignore: unused_element
class _CompactPaymentFacilitySelector extends StatelessWidget {
  const _CompactPaymentFacilitySelector({
    required this.facilities,
    required this.selectedFacility,
    // ignore: unused_element_parameter
    this.pendingBills = const [],
    // ignore: unused_element_parameter
    this.badgeCount,
    required this.onSelected,
  });

  final List<Facility> facilities;
  final Facility selectedFacility;
  final List<MonthlyBill> pendingBills;
  final int Function(Facility facility)? badgeCount;
  final ValueChanged<Facility> onSelected;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.white,
      child: SizedBox(
        height: 98,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          scrollDirection: Axis.horizontal,
          itemCount: facilities.length,
          separatorBuilder: (_, __) => const SizedBox(width: 14),
          itemBuilder: (context, index) {
            final facility = facilities[index];
            final selected = facility.id == selectedFacility.id;
            final count = badgeCount?.call(facility) ??
                pendingBills
                    .where((bill) => bill.facilityId == facility.id)
                    .length;
            return SizedBox(
              width: 68,
              child: InkWell(
                onTap: () => onSelected(facility),
                borderRadius: BorderRadius.circular(34),
                child: Column(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: selected
                                ? Colors.white
                                : const Color(0xFFF3F6FA),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: selected
                                  ? oceanDeep
                                  : const Color(0x00FFFFFF),
                              width: selected ? 2 : 1,
                            ),
                          ),
                          child: Icon(
                            Icons.apartment_rounded,
                            color:
                                selected ? oceanDeep : const Color(0xFF94A3B8),
                          ),
                        ),
                        if (count > 0)
                          Positioned(
                            right: -5,
                            top: -4,
                            child: Badge(label: Text('$count')),
                          ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      facility.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: selected ? oceanDeep : const Color(0xFF94A3B8),
                        fontSize: 10,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PendingReviewList extends StatelessWidget {
  const _PendingReviewList({required this.bills, required this.requests});

  final List<MonthlyBill> bills;
  final List<TenantRequest> requests;

  @override
  Widget build(BuildContext context) {
    final store = RentalStoreScope.of(context);
    if (bills.isEmpty && requests.isEmpty) {
      return const EmptyState(
        icon: Icons.check_circle_rounded,
        title: 'No pending actions',
        message: 'Payment slips and tenant requests will appear here.',
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ...bills.map((bill) {
          final tenant = store.userFor(bill.tenantId);
          final facility = store.facilityFor(bill.facilityId);
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ReviewTypeBadge(
                    label: 'PAYMENT SLIP',
                    icon: Icons.receipt_long_rounded,
                    color: Color(0xFF3156A3),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${tenant.name} • ${monthLabel(bill.month)}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  Text('${facility.name} • ${bill.slipFileName}'),
                  const SizedBox(height: 8),
                  Text(
                    'Paid ${money(bill.amountPaid)} • Due ${money(bill.totalAmount)} • ${bill.submittedAt == null ? 'Time not recorded' : dateTimeLabel(bill.submittedAt!)}',
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () => showPaymentReviewDialog(context, bill),
                    icon: const Icon(Icons.image_search_rounded),
                    label: Text(tr(context, 'Review Payment')),
                  ),
                ],
              ),
            ),
          );
        }),
        ...requests.map((request) {
          final tenant = store.userFor(request.tenantId);
          final facility = store.facilityFor(request.facilityId);
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ReviewTypeBadge(
                    label: 'TENANT REQUEST',
                    icon: Icons.handyman_rounded,
                    color: Color(0xFFD16432),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    request.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  Text('${tenant.name} • ${facility.name}'),
                  const SizedBox(height: 6),
                  Text(request.message),
                  const SizedBox(height: 6),
                  Text('Submitted ${dateTimeLabel(request.createdAt)}'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: () =>
                            store.reviewTenantRequest(request, 'Approved'),
                        icon: const Icon(Icons.check_rounded),
                        label: const Text('Approve'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () =>
                            store.reviewTenantRequest(request, 'Rejected'),
                        icon: const Icon(Icons.close_rounded),
                        label: const Text('Reject'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _ReviewHistoryList extends StatelessWidget {
  const _ReviewHistoryList({
    required this.paymentEvents,
    required this.requests,
  });

  final List<PaymentReviewEvent> paymentEvents;
  final List<TenantRequest> requests;

  @override
  Widget build(BuildContext context) {
    final store = RentalStoreScope.of(context);
    final items = <({DateTime time, Widget widget})>[
      ...paymentEvents.map((event) {
        final bill = store.bills.firstWhere((bill) => bill.id == event.billId);
        final tenant = store.userFor(bill.tenantId);
        return (
          time: event.timestamp,
          widget: ListTile(
            onTap: () => showPaymentReviewDialog(
              context,
              bill,
              readOnly: true,
              reviewedAt: event.timestamp,
              reviewReason: event.reason,
            ),
            leading: const Icon(Icons.receipt_long_rounded),
            title: Text('${tenant.name} • ${monthLabel(bill.month)}'),
            subtitle: Text(
              'PAYMENT SLIP • ${dateTimeLabel(event.timestamp)}${event.reason == null ? '' : '\n${event.reason}'}',
            ),
            trailing: StatusChip(status: event.status),
          ),
        );
      }),
      ...requests.map((request) {
        final tenant = store.userFor(request.tenantId);
        final time = request.reviewedAt ?? request.createdAt;
        return (
          time: time,
          widget: ListTile(
            leading: const Icon(Icons.handyman_rounded),
            title: Text(request.title),
            subtitle: Text(
              'TENANT REQUEST • ${tenant.name}\n${dateTimeLabel(time)}',
            ),
            trailing: StatusChipText(label: request.status),
          ),
        );
      }),
    ]..sort((a, b) => b.time.compareTo(a.time));

    if (items.isEmpty) {
      return const EmptyState(
        icon: Icons.history_rounded,
        title: 'No review history',
        message: 'Approved and rejected items will appear here.',
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: items.map((item) => Card(child: item.widget)).toList(),
    );
  }
}

class ReviewTypeBadge extends StatelessWidget {
  const ReviewTypeBadge({
    required this.label,
    required this.icon,
    required this.color,
    super.key,
  });

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class UtilitiesTab extends StatefulWidget {
  const UtilitiesTab({super.key});

  @override
  State<UtilitiesTab> createState() => _UtilitiesTabState();
}

class _UtilitiesTabState extends State<UtilitiesTab>
    with SingleTickerProviderStateMixin {
  String? selectedFacilityId;
  bool sidebarCollapsed = false;
  late final TabController controller;
  int facilitySlideDirection = 1;

  @override
  void initState() {
    super.initState();
    controller = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void selectFacility(List<Facility> facilities, Facility facility) {
    final currentIndex =
        facilities.indexWhere((item) => item.id == selectedFacilityId);
    final nextIndex = facilities.indexWhere((item) => item.id == facility.id);
    setState(() {
      facilitySlideDirection =
          currentIndex >= 0 && nextIndex < currentIndex ? -1 : 1;
      selectedFacilityId = facility.id;
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = RentalStoreScope.of(context);
    final facilities = store.ownerFacilities;
    if (facilities.isEmpty) {
      return const EmptyState(
        icon: Icons.apartment_rounded,
        title: 'No facilities',
        message: 'Create a facility before entering utilities.',
      );
    }
    final facility = facilities.firstWhere(
      (item) => item.id == selectedFacilityId,
      orElse: () => facilities.first,
    );
    final pendingBills = store.bills
        .where(
          (bill) =>
              bill.facilityId == facility.id &&
              bill.status == PaymentStatus.notSubmitted,
        )
        .toList()
      ..sort((a, b) => a.month.compareTo(b.month));
    final historyBills = store.bills.where((bill) {
      if (bill.facilityId != facility.id ||
          bill.status == PaymentStatus.notSubmitted) {
        return false;
      }
      final tenancy = store.tenancies.firstWhere(
        (tenancy) => tenancy.tenantId == bill.tenantId,
      );
      return bill.utilityEvidenceFileName != null ||
          tenancy.utilitiesFullyIncluded;
    }).toList()
      ..sort((a, b) => b.month.compareTo(a.month));

    return LayoutBuilder(
      builder: (context, constraints) {
        final detail = _UtilityFacilityDetail(
          facility: facility,
          pendingBills: pendingBills,
          historyBills: historyBills,
          controller: controller,
        );
        final animatedDetail = horizontalSwipeArea(
          onPrevious: () {
            final previous = adjacentFacility(facilities, facility.id, -1);
            if (previous != null) selectFacility(facilities, previous);
          },
          onNext: () {
            final next = adjacentFacility(facilities, facility.id, 1);
            if (next != null) selectFacility(facilities, next);
          },
          child: DirectionalContentSwitcher(
            switchKey: facility.id,
            direction: facilitySlideDirection,
            child: detail,
          ),
        );
        if (constraints.maxWidth < 760) {
          return Column(
            children: [
              _CompactFacilitySelector(
                facilities: facilities,
                selectedFacilityId: facility.id,
                onSelected: (value) {
                  selectFacility(facilities, value);
                },
                onCreateFacility: () async {},
              ),
              const Divider(height: 1),
              Expanded(child: animatedDetail),
            ],
          );
        }
        return Row(
          children: [
            AnimatedContainer(
              key: const Key('utility_facility_sidebar'),
              duration: const Duration(milliseconds: 220),
              width: sidebarCollapsed ? 76 : 220,
              child: _UtilityFacilitySidebar(
                facilities: facilities,
                selectedFacilityId: facility.id,
                collapsed: sidebarCollapsed,
                onToggleCollapsed: () {
                  setState(() => sidebarCollapsed = !sidebarCollapsed);
                },
                onSelected: (value) {
                  selectFacility(facilities, value);
                  sidebarCollapsed = true;
                },
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: Listener(
                behavior: HitTestBehavior.translucent,
                onPointerDown: (_) {
                  if (!sidebarCollapsed) {
                    setState(() => sidebarCollapsed = true);
                  }
                },
                child: animatedDetail,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _UtilityFacilitySidebar extends StatelessWidget {
  const _UtilityFacilitySidebar({
    required this.facilities,
    required this.selectedFacilityId,
    required this.onSelected,
    required this.collapsed,
    required this.onToggleCollapsed,
  });

  final List<Facility> facilities;
  final String selectedFacilityId;
  final ValueChanged<Facility> onSelected;
  final bool collapsed;
  final VoidCallback onToggleCollapsed;

  @override
  Widget build(BuildContext context) {
    final store = RentalStoreScope.of(context);
    return ColoredBox(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment:
              collapsed ? CrossAxisAlignment.center : CrossAxisAlignment.start,
          children: [
            if (collapsed)
              IconButton(
                key: const Key('toggle_utility_sidebar_button'),
                tooltip: 'Expand facilities',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 36,
                  height: 36,
                ),
                onPressed: onToggleCollapsed,
                icon: const Icon(Icons.chevron_right_rounded),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'UTILITY FACILITIES',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: const Color(0xFF667085),
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                    ),
                  ),
                  IconButton(
                    key: const Key('toggle_utility_sidebar_button'),
                    tooltip: 'Collapse facilities',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 36,
                      height: 36,
                    ),
                    onPressed: onToggleCollapsed,
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                ],
              ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.separated(
                itemCount: facilities.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (context, index) {
                  final facility = facilities[index];
                  final selected = facility.id == selectedFacilityId;
                  final pendingCount = store.bills
                      .where(
                        (bill) =>
                            bill.facilityId == facility.id &&
                            bill.status == PaymentStatus.notSubmitted,
                      )
                      .length;
                  return Material(
                    color:
                        selected ? const Color(0xFFE8EEFC) : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    child: ListTile(
                      dense: true,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 10),
                      onTap: () => onSelected(facility),
                      leading: Icon(
                        Icons.apartment_rounded,
                        color: selected ? const Color(0xFF3156A3) : null,
                      ),
                      title: collapsed ? null : Text(facility.name),
                      trailing: collapsed || pendingCount == 0
                          ? null
                          : Badge(label: Text('$pendingCount')),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UtilityFacilityDetail extends StatelessWidget {
  const _UtilityFacilityDetail({
    required this.facility,
    required this.pendingBills,
    required this.historyBills,
    required this.controller,
  });

  final Facility facility;
  final List<MonthlyBill> pendingBills;
  final List<MonthlyBill> historyBills;
  final TabController controller;

  @override
  Widget build(BuildContext context) {
    final store = RentalStoreScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                facility.name,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 3),
              Text(
                facility.address,
                style: const TextStyle(color: Color(0xFF667085)),
              ),
              const SizedBox(height: 3),
              Text(
                'Electricity is calculated using tariff tiers: ${store.electricityTariffSummary()}.',
                style: const TextStyle(color: Color(0xFF667085)),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: TabBar(
            controller: controller,
            tabs: [
              Tab(
                  text:
                      '${tr(context, 'Pending Action')} (${pendingBills.length})'),
              Tab(text: '${tr(context, 'History')} (${historyBills.length})'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: controller,
            children: [
              _PendingUtilityList(bills: pendingBills),
              _UtilityHistoryList(bills: historyBills),
            ],
          ),
        ),
      ],
    );
  }
}

class _PendingUtilityList extends StatelessWidget {
  const _PendingUtilityList({required this.bills});

  final List<MonthlyBill> bills;

  @override
  Widget build(BuildContext context) {
    final store = RentalStoreScope.of(context);
    if (bills.isEmpty) {
      return const EmptyState(
        icon: Icons.task_alt_rounded,
        title: 'No pending utility actions',
        message: 'All required utility entries have been submitted.',
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: bills.map((bill) {
        final tenant = store.userFor(bill.tenantId);
        final tenancy = store.tenancies.firstWhere(
          (tenancy) => tenancy.tenantId == bill.tenantId,
        );
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ReviewTypeBadge(
                  label: 'UTILITY ENTRY',
                  icon: Icons.electric_meter_rounded,
                  color: Color(0xFF3156A3),
                ),
                const SizedBox(height: 10),
                Text(
                  '${tenant.name} • ${monthLabel(bill.month)}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                Text(
                    '${tenancy.unitName} • Meter reading and attachment required'),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () => showUtilityDialog(context, bill),
                  icon: const Icon(Icons.upload_file_rounded),
                  label: const Text('Enter & Upload'),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _UtilityHistoryList extends StatelessWidget {
  const _UtilityHistoryList({required this.bills});

  final List<MonthlyBill> bills;

  @override
  Widget build(BuildContext context) {
    final store = RentalStoreScope.of(context);
    if (bills.isEmpty) {
      return const EmptyState(
        icon: Icons.history_rounded,
        title: 'No utility history',
        message: 'Submitted monthly utility records will appear here.',
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: bills.map((bill) {
        final tenant = store.userFor(bill.tenantId);
        final tenancy = store.tenancies.firstWhere(
          (tenancy) => tenancy.tenantId == bill.tenantId,
        );
        final included = tenancy.utilitiesFullyIncluded;
        return Card(
          child: ListTile(
            onTap: () => showGeneratedInvoicePreview(context, bill),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 10,
            ),
            leading: const CircleAvatar(
              child: Icon(Icons.electric_meter_rounded),
            ),
            title: Text('${tenant.name} • ${monthLabel(bill.month)}'),
            subtitle: Text(
              included
                  ? '${tenancy.unitName} • Utilities included in package • No attachment required'
                  : '${tenancy.unitName} • ${bill.electricityUsageKwh.toStringAsFixed(1)} kWh • Utilities ${money(bill.totalUtilityAmount)}\nAttachment: ${bill.utilityEvidenceFileName}',
            ),
            isThreeLine: !included,
            trailing: StatusChip(status: bill.status),
          ),
        );
      }).toList(),
    );
  }
}

// ignore: unused_element
class _LegacyUtilitiesTab extends StatelessWidget {
  const _LegacyUtilitiesTab();

  @override
  Widget build(BuildContext context) {
    final store = RentalStoreScope.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Owner Utility Entry',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 4),
        Text(
          'Expand a facility and tenant to enter electricity usage in kWh. Electricity is calculated using tariff tiers: ${store.electricityTariffSummary()}.',
        ),
        const SizedBox(height: 12),
        ...store.ownerFacilities.map((facility) {
          final facilityTenancies = store.tenancies
              .where((tenancy) => tenancy.facilityId == facility.id)
              .toList();
          return Card(
            child: ExpansionTile(
              leading: const CircleAvatar(
                child: Icon(Icons.apartment_rounded),
              ),
              title: Text(facility.name),
              subtitle: Text(
                '${facility.address} • ${facilityTenancies.length} tenants',
              ),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: facilityTenancies.map((tenancy) {
                final tenant = store.userFor(tenancy.tenantId);
                final tenantBills = store.bills
                    .where((bill) =>
                        bill.tenantId == tenancy.tenantId &&
                        bill.facilityId == facility.id &&
                        (bill.status == PaymentStatus.notSubmitted ||
                            bill.status == PaymentStatus.rejected))
                    .toList()
                  ..sort((a, b) => a.month.compareTo(b.month));
                return Card(
                  color: const Color(0xFFF8FAFD),
                  child: ExpansionTile(
                    leading: TenantGenderAvatar(tenant: tenant, radius: 18),
                    title: Text('${tenant.name} • ${tenancy.unitName}'),
                    subtitle: Text(
                      '${tenantBills.length} bill${tenantBills.length == 1 ? '' : 's'} awaiting utility entry',
                    ),
                    children: tenantBills.isEmpty
                        ? const [
                            ListTile(
                              title: Text('No open bills for this tenant.'),
                            ),
                          ]
                        : tenantBills.map((bill) {
                            return ListTile(
                              leading: const Icon(Icons.electric_meter_rounded),
                              title: Text(monthLabel(bill.month)),
                              subtitle: Text(
                                '${bill.electricityUsageKwh.toStringAsFixed(1)} kWh = ${money(bill.electricityAmount)} • Total utilities ${money(bill.totalUtilityAmount)}',
                              ),
                              trailing: OutlinedButton.icon(
                                onPressed: () =>
                                    showUtilityDialog(context, bill),
                                icon: const Icon(Icons.edit_rounded),
                                label: const Text('Enter'),
                              ),
                            );
                          }).toList(),
                  ),
                );
              }).toList(),
            ),
          );
        }),
      ],
    );
  }
}

class OwnerRequestsFeedTab extends StatefulWidget {
  const OwnerRequestsFeedTab({super.key});

  @override
  State<OwnerRequestsFeedTab> createState() => _OwnerRequestsFeedTabState();
}

class _OwnerRequestsFeedTabState extends State<OwnerRequestsFeedTab>
    with SingleTickerProviderStateMixin {
  late final TabController controller;
  String? selectedFacilityId;
  int facilitySlideDirection = 1;

  @override
  void initState() {
    super.initState();
    controller = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void selectFacility(List<Facility> facilities, Facility facility) {
    final currentIndex =
        facilities.indexWhere((item) => item.id == selectedFacilityId);
    final nextIndex = facilities.indexWhere((item) => item.id == facility.id);
    setState(() {
      facilitySlideDirection =
          currentIndex >= 0 && nextIndex < currentIndex ? -1 : 1;
      selectedFacilityId = facility.id;
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = RentalStoreScope.of(context);
    final facilities = store.ownerFacilities;
    if (facilities.isEmpty) {
      return const EmptyState(
        icon: Icons.handyman_rounded,
        title: 'No facilities',
        message: 'Tenant requests will appear after a facility is created.',
      );
    }
    final facility = facilities.firstWhere(
      (item) => item.id == selectedFacilityId,
      orElse: () => facilities.first,
    );
    final requests = store.tenantRequests
        .where((item) => item.facilityId == facility.id)
        .toList();
    final pending = requests.where((item) => item.status == 'Open').toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final history = requests.where((item) => item.status != 'Open').toList()
      ..sort((a, b) =>
          (b.reviewedAt ?? b.createdAt).compareTo(a.reviewedAt ?? a.createdAt));

    final detail = Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: TabBar(
            controller: controller,
            tabs: [
              Tab(text: '${tr(context, 'Pending Action')} (${pending.length})'),
              Tab(text: '${tr(context, 'History')} (${history.length})'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: controller,
            children: [
              _OwnerRequestList(
                requests: pending,
                pending: true,
                onActionCompleted: () {
                  setState(() {});
                  controller.animateTo(1);
                },
              ),
              _OwnerRequestList(requests: history, pending: false),
            ],
          ),
        ),
      ],
    );
    return Column(
      children: [
        _CompactPaymentFacilitySelector(
          facilities: facilities,
          selectedFacility: facility,
          badgeCount: (item) => store.tenantRequests
              .where((request) =>
                  request.facilityId == item.id && request.status == 'Open')
              .length,
          onSelected: (value) {
            selectFacility(facilities, value);
          },
        ),
        const Divider(height: 1),
        Expanded(
          child: horizontalSwipeArea(
            onPrevious: () {
              final previous = adjacentFacility(facilities, facility.id, -1);
              if (previous != null) selectFacility(facilities, previous);
            },
            onNext: () {
              final next = adjacentFacility(facilities, facility.id, 1);
              if (next != null) selectFacility(facilities, next);
            },
            child: DirectionalContentSwitcher(
              switchKey: facility.id,
              direction: facilitySlideDirection,
              child: detail,
            ),
          ),
        ),
      ],
    );
  }
}

class _OwnerRequestList extends StatelessWidget {
  const _OwnerRequestList({
    required this.requests,
    required this.pending,
    this.onActionCompleted,
  });

  final List<TenantRequest> requests;
  final bool pending;
  final VoidCallback? onActionCompleted;

  @override
  Widget build(BuildContext context) {
    final store = RentalStoreScope.of(context);
    if (requests.isEmpty) {
      return EmptyState(
        icon: pending ? Icons.task_alt_rounded : Icons.history_rounded,
        title: pending ? 'No pending requests' : 'No request history',
        message: pending
            ? 'All tenant requests have been handled.'
            : 'Closed and rejected requests will appear here.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: requests.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final request = requests[index];
        final tenant = store.userFor(request.tenantId);
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ReviewTypeBadge(
                      label: request.requestType.toUpperCase(),
                      icon: Icons.handyman_rounded,
                      color: pending
                          ? const Color(0xFFD25B2A)
                          : const Color(0xFF64748B),
                    ),
                    const Spacer(),
                    StatusChipText(label: request.status),
                  ],
                ),
                const SizedBox(height: 12),
                Text(request.title,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(
                  '${tenant.name} • ${dateTimeLabel(request.createdAt)}',
                  style: const TextStyle(color: oceanMuted, fontSize: 11),
                ),
                const SizedBox(height: 9),
                Text(request.message),
                if (request.hasAttachment) ...[
                  const SizedBox(height: 12),
                  InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => showTenantRequestAttachmentDialog(
                      context,
                      request,
                      tenant.name,
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: oceanSoft.withOpacity(0.75),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.image_rounded,
                            color: oceanDeep,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Tenant picture attached',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  [
                                    request.attachmentFileName,
                                    if (request.attachmentSizeBytes != null)
                                      fileSizeLabel(
                                        request.attachmentSizeBytes!,
                                      ),
                                  ].whereType<String>().join(' • '),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: oceanMuted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.visibility_rounded,
                            color: oceanDeep,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                if (request.reviewedAt != null) ...[
                  const SizedBox(height: 8),
                  Text('Updated ${dateTimeLabel(request.reviewedAt!)}',
                      style: const TextStyle(color: oceanMuted, fontSize: 10)),
                ],
                if (pending) ...[
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (request.status == 'Open')
                        FilledButton.icon(
                          onPressed: () async {
                            final confirmed = await showActionConfirmation(
                              context,
                              title: 'Accept this request?',
                              message:
                                  '${request.title} will move to request history as Accepted.',
                              confirmLabel: 'Accept',
                            );
                            if (confirmed) {
                              store.reviewTenantRequest(request, 'Accepted');
                              onActionCompleted?.call();
                            }
                          },
                          icon: const Icon(Icons.check_rounded),
                          label: const Text('Accept'),
                        ),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final confirmed = await showActionConfirmation(
                            context,
                            title: 'Close this request?',
                            message:
                                '${request.title} will move to request history.',
                            confirmLabel: 'Close Request',
                          );
                          if (confirmed) {
                            store.reviewTenantRequest(request, 'Closed');
                            onActionCompleted?.call();
                          }
                        },
                        icon: const Icon(Icons.task_alt_rounded),
                        label: const Text('Close'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

// Retained temporarily while older screenshots are migrated.
// ignore: unused_element
class _LegacyOwnerRequestsFeedTab extends StatelessWidget {
  const _LegacyOwnerRequestsFeedTab();

  @override
  Widget build(BuildContext context) {
    final store = RentalStoreScope.of(context);
    final requests = [...store.tenantRequests]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Maintenance requests',
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        const Text(
          'Review active requests and follow their history.',
          style: TextStyle(color: oceanMuted),
        ),
        const SizedBox(height: 14),
        if (requests.isEmpty)
          const EmptyState(
            icon: Icons.handyman_rounded,
            title: 'No requests',
            message: 'Tenant requests will appear here.',
          )
        else
          ...requests.map((request) {
            final open = request.status == 'Open';
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(17),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: open
                                ? const Color(0xFFFEF3C7)
                                : const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: Icon(
                            Icons.handyman_rounded,
                            color: open
                                ? const Color(0xFFB45309)
                                : const Color(0xFF15803D),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                request.title,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                '${store.userFor(request.tenantId).name} · ${store.facilityFor(request.facilityId).name}',
                                style: const TextStyle(
                                  color: oceanMuted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        StatusChipText(label: request.status),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(request.message),
                    if (open) ...[
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        children: [
                          FilledButton.icon(
                            onPressed: () => store.reviewTenantRequest(
                              request,
                              'In Progress',
                            ),
                            icon: const Icon(Icons.check_rounded),
                            label: const Text('Accept'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => store.reviewTenantRequest(
                              request,
                              'Closed',
                            ),
                            icon: const Icon(Icons.task_alt_rounded, size: 19),
                            label: const Text('Close'),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}

class OwnerAccountTab extends StatelessWidget {
  const OwnerAccountTab({super.key});

  @override
  Widget build(BuildContext context) {
    final store = RentalStoreScope.of(context);
    final user = store.currentUser!;
    final roleLabel = user.role == UserRole.owner
        ? tr(context, 'Owner')
        : tr(context, 'Property Agent');

    return ColoredBox(
      color: oceanCanvas,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(22, 34, 22, 34),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF3188D7), Color(0xFF173758)],
              ),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => showAvatarPickerDialog(context),
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      shape: BoxShape.circle,
                    ),
                    child: ProfileAvatar(user: user, radius: 29),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$roleLabel · ${trCount(context, store.ownerFacilities.length, 'property', 'properties')}',
                        style: const TextStyle(
                          color: Color(0xDDFFFFFF),
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Last login: ${user.lastLoginAt == null ? 'Not recorded' : dateTimeLabel(user.lastLoginAt!)}',
                        style: const TextStyle(
                          color: Color(0xCCFFFFFF),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
            child: Column(
              children: [
                _ProfileMenuGroup(
                  children: [
                    _ProfileMenuItem(
                      icon: Icons.person_outline_rounded,
                      label: 'Account details',
                      onTap: () => showOwnerAccountSetupDialog(context),
                    ),
                    _ProfileMenuItem(
                      icon: Icons.electric_bolt_outlined,
                      label: 'Billing configuration',
                      meta: '${store.electricityTariffTiers.length} tier(s)',
                      onTap: () => showBillingConfigurationDialog(context),
                    ),
                    _ProfileMenuItem(
                      icon: Icons.notifications_none_rounded,
                      label: 'Notifications',
                      onTap: () => showNotifications(context),
                    ),
                    _ProfileMenuItem(
                      icon: Icons.notifications_active_outlined,
                      label: 'Payment reminders',
                      meta: trDayStart(context, user.paymentReminderAfterDays),
                      onTap: () => showReminderSettingsDialog(context),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _ProfileMenuGroup(
                  children: [
                    _ProfileMenuItem(
                      icon: Icons.apartment_outlined,
                      label: 'Facility configuration',
                      onTap: () => showFacilityConfigurationDialog(context),
                    ),
                    _ProfileMenuItem(
                      icon: Icons.storage_outlined,
                      label: 'Data & backup',
                      onTap: () => showDataExportDialog(context),
                    ),
                    _ProfileMenuItem(
                      icon: Icons.language_rounded,
                      label: 'Language',
                      onTap: () async {
                        await Navigator.of(context).push<void>(
                          MaterialPageRoute<void>(
                            builder: (_) => const _LanguageScreen(),
                          ),
                        );
                      },
                    ),
                    _ProfileMenuItem(
                      icon: Icons.info_outline_rounded,
                      label: 'Help & support',
                      onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Support centre will open here.'),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _ProfileMenuGroup(
                  children: [
                    _ProfileMenuItem(
                      icon: Icons.add_card_outlined,
                      label: 'Other monthly income',
                      onTap: () => showAddIncomeDialog(context),
                    ),
                    _ProfileMenuItem(
                      icon: Icons.history_outlined,
                      label: 'Activity history',
                      meta: trCount(
                        context,
                        store.activityHistory.length,
                        'record',
                        'records',
                      ),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const ActivityHistoryScreen(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ActivityHistoryScreen extends StatelessWidget {
  const ActivityHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = RentalStoreScope.of(context);
    final records = [...store.activityHistory]
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return Scaffold(
      appBar: AppBar(title: const Text('Activity History')),
      body: records.isEmpty
          ? const EmptyState(
              icon: Icons.history_rounded,
              title: 'No history yet',
              message: 'Added and edited records will appear here.',
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: records.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final record = records[index];
                final lower = record.action.toLowerCase();
                final icon = lower.contains('payment')
                    ? Icons.payments_rounded
                    : lower.contains('tenant') || lower.contains('profile')
                        ? Icons.person_rounded
                        : lower.contains('facility') ||
                                lower.contains('cost') ||
                                lower.contains('commitment')
                            ? Icons.apartment_rounded
                            : lower.contains('request')
                                ? Icons.handyman_rounded
                                : Icons.edit_note_rounded;
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(child: Icon(icon)),
                    title: Text(record.action),
                    subtitle: Text(dateTimeLabel(record.timestamp)),
                  ),
                );
              },
            ),
    );
  }
}

class _ProfileMenuGroup extends StatelessWidget {
  const _ProfileMenuGroup({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: oceanText.withOpacity(0.035),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            for (var index = 0; index < children.length; index++) ...[
              children[index],
              if (index != children.length - 1)
                const Divider(height: 1, indent: 50, endIndent: 14),
            ],
          ],
        ),
      );
}

class _ProfileMenuItem extends StatelessWidget {
  const _ProfileMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.meta,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String? meta;

  @override
  Widget build(BuildContext context) => ListTile(
        dense: true,
        minVerticalPadding: 13,
        leading: Icon(icon, color: oceanDeep, size: 20),
        title: Text(
          tr(context, label),
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (meta != null)
              Text(
                meta!,
                style: const TextStyle(color: oceanDeep, fontSize: 10),
              ),
            if (meta != null) const SizedBox(width: 7),
            const Icon(Icons.chevron_right_rounded,
                color: Color(0xFFCBD5E1), size: 20),
          ],
        ),
        onTap: onTap,
      );
}

class _LanguageScreen extends StatefulWidget {
  const _LanguageScreen();

  @override
  State<_LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends State<_LanguageScreen> {
  AppLanguage? selected;

  // ignore: unused_field
  static const options = [
    ('GB', 'English', 'English', AppLanguage.english),
    ('CN', '中文', 'Chinese (Simplified)', AppLanguage.chinese),
    ('MY', 'Bahasa Melayu', 'Malay', AppLanguage.malay),
  ];

  @override
  Widget build(BuildContext context) {
    final store = RentalStoreScope.of(context);
    selected ??= store.appLanguage;
    const options = [
      ('GB', 'English', 'English', AppLanguage.english),
      ('CN', '中文', 'Chinese (Simplified)', AppLanguage.chinese),
      ('MY', 'Bahasa Melayu', 'Malay', AppLanguage.malay),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(tr(context, 'Language'))),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: Text(
                  tr(context, 'Applies across the whole app'),
                  style: const TextStyle(color: oceanMuted, fontSize: 12),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  children: [
                    for (var index = 0; index < options.length; index++) ...[
                      _LanguageChoice(
                        code: options[index].$1,
                        title: tr(context, options[index].$2),
                        subtitle: tr(context, options[index].$3),
                        selected: selected == options[index].$4,
                        onTap: () => setState(
                          () => selected = options[index].$4,
                        ),
                      ),
                      if (index != options.length - 1)
                        const Divider(height: 1, indent: 54),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [oceanSky, oceanBlue, oceanDeep],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
              ),
              onPressed: () {
                store.updateLanguage(selected!);
                Navigator.pop(context);
              },
              child: Text(tr(context, 'Apply')),
            ),
          ),
        ),
      ),
    );
  }
}

class _LanguageChoice extends StatelessWidget {
  const _LanguageChoice({
    required this.code,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String code;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        leading: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: switch (code) {
              'GB' => const Color(0xFFEFF6FF),
              'CN' => const Color(0xFFFFF1F2),
              _ => const Color(0xFFFFFBEA),
            },
            borderRadius: BorderRadius.circular(11),
          ),
          child: Text(code,
              style:
                  const TextStyle(fontSize: 10, fontWeight: FontWeight.w800)),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 11)),
        trailing: selected
            ? const Icon(Icons.check_circle_rounded, color: oceanBlue)
            : const Icon(Icons.radio_button_unchecked_rounded,
                color: Color(0xFFCBD5E1)),
        onTap: onTap,
      );
}

class TenantHomeScreen extends StatefulWidget {
  const TenantHomeScreen({super.key});

  @override
  State<TenantHomeScreen> createState() => _TenantHomeScreenState();
}

class _TenantHomeScreenState extends State<TenantHomeScreen> {
  int selectedIndex = 0;

  static const pages = [
    TenantFigmaHomeTab(),
    TenantPayTab(),
    TenantRequestsTab(),
    TenantAccountTab(),
  ];

  static const titles = [
    'Home',
    'Pay',
    'Requests',
    'Profile',
  ];

  @override
  Widget build(BuildContext context) {
    final store = RentalStoreScope.of(context);
    final user = store.currentUser!;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${tr(context, timeGreeting(DateTime.now()))}, ${firstName(user.name)} • ${titles[selectedIndex]}',
        ),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            onPressed: () => showNotifications(context),
            icon: NotificationBellIcon(
              unreadCount: store.unreadNotificationCount,
            ),
          ),
          IconButton(
            tooltip: 'Logout',
            onPressed: () => confirmLogout(context),
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: AnimatedTabIndexedStack(index: selectedIndex, children: pages),
      bottomNavigationBar: SafeArea(
        top: false,
        child: AppBottomNavigator(
          selectedIndex: selectedIndex,
          onSelected: (index) {
            if (index == selectedIndex) return;
            setState(() {
              selectedIndex = index;
            });
          },
          items: const [
            AppBottomNavItem(
              icon: Icons.home_outlined,
              activeIcon: Icons.home_rounded,
              label: 'Home',
            ),
            AppBottomNavItem(
              icon: Icons.payments_outlined,
              activeIcon: Icons.payments_rounded,
              label: 'Pay',
              badgeLabel: '!',
            ),
            AppBottomNavItem(
              icon: Icons.handyman_outlined,
              activeIcon: Icons.handyman_rounded,
              label: 'Requests',
            ),
            AppBottomNavItem(
              icon: Icons.account_circle_outlined,
              activeIcon: Icons.account_circle_rounded,
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

class TenantFigmaHomeTab extends StatelessWidget {
  const TenantFigmaHomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    final store = RentalStoreScope.of(context);
    final tenancy =
        store.tenantTenancies.isEmpty ? null : store.tenantTenancies.first;
    final payable = store.tenantPayableBills;
    final amountDue = payable.fold<double>(
      0,
      (total, bill) => total + bill.totalAmount,
    );
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [oceanSky, oceanBlue, oceanDeep],
            ),
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: oceanBlue.withOpacity(0.20),
                blurRadius: 26,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tenancy == null
                    ? 'Your tenancy'
                    : '${store.facilityFor(tenancy.facilityId).name} · ${tenancy.unitName}',
                style: const TextStyle(color: Color(0xDDFFFFFF)),
              ),
              const SizedBox(height: 18),
              const Text(
                'Amount due',
                style: TextStyle(color: Color(0xCCFFFFFF), fontSize: 13),
              ),
              Text(
                money(amountDue),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 38,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _TenantHomeAction(
                icon: Icons.payments_rounded,
                label: 'Pay rent',
                onTap: payable.isEmpty
                    ? null
                    : () => showSubmitSlipDialog(context, payable.first),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _TenantHomeAction(
                icon: Icons.history_rounded,
                label: 'Receipts',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => Scaffold(
                      appBar: AppBar(title: const Text('Payment history')),
                      body: const TenantPaymentHistoryTab(),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          'Active requests',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        if (store.currentTenantRequests.isEmpty)
          const Card(
            child: ListTile(
              leading: Icon(Icons.check_circle_outline_rounded),
              title: Text('No active requests'),
            ),
          )
        else
          ...store.currentTenantRequests.take(2).map(
                (request) => Card(
                  child: ListTile(
                    leading:
                        const Icon(Icons.handyman_rounded, color: oceanBlue),
                    title: Text(request.title),
                    subtitle: Text(request.status),
                    trailing: StatusChipText(label: request.status),
                  ),
                ),
              ),
      ],
    );
  }
}

class _TenantHomeAction extends StatelessWidget {
  const _TenantHomeAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Column(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: oceanSoft,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: oceanBlue),
                ),
                const SizedBox(height: 8),
                Text(label,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      );
}

class TenantPayTab extends StatelessWidget {
  const TenantPayTab({super.key});

  @override
  Widget build(BuildContext context) {
    final store = RentalStoreScope.of(context);
    return _TenantYearBillsView(
      title: 'Pending Actions',
      bills: store.tenantPayableBills,
      showPayAction: true,
      emptyTitle: 'All paid',
      emptyMessage: 'Approved bills remain available in Payment History.',
    );
  }
}

class TenantPaymentHistoryTab extends StatelessWidget {
  const TenantPaymentHistoryTab({super.key});

  @override
  Widget build(BuildContext context) {
    final store = RentalStoreScope.of(context);
    return _TenantYearBillsView(
      title: 'Payment History',
      bills: store.tenantPaymentHistory,
      emptyTitle: 'No payment history yet',
      emptyMessage: 'Submitted and approved payments will appear here.',
    );
  }
}

class _TenantYearBillsView extends StatefulWidget {
  const _TenantYearBillsView({
    required this.title,
    required this.bills,
    required this.emptyTitle,
    required this.emptyMessage,
    this.showPayAction = false,
  });

  final String title;
  final List<MonthlyBill> bills;
  final String emptyTitle;
  final String emptyMessage;
  final bool showPayAction;

  @override
  State<_TenantYearBillsView> createState() => _TenantYearBillsViewState();
}

class _TenantYearBillsViewState extends State<_TenantYearBillsView> {
  int? selectedYear;
  bool collapsed = false;

  @override
  Widget build(BuildContext context) {
    final years = widget.bills.map((bill) => bill.month.year).toSet().toList()
      ..sort((a, b) => b.compareTo(a));
    final year =
        selectedYear ?? (years.isEmpty ? DateTime.now().year : years.first);
    final bills =
        widget.bills.where((bill) => bill.month.year == year).toList();
    final detail = bills.isEmpty
        ? EmptyState(
            icon: Icons.history_rounded,
            title: widget.emptyTitle,
            message: widget.emptyMessage,
          )
        : ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('${widget.title} • $year',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              ...bills.map((bill) => TenantBillCard(
                    bill: bill,
                    showPayAction: widget.showPayAction,
                  )),
            ],
          );
    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth < 680) return detail;
      return Row(
        children: [
          AnimatedContainer(
            key: Key(widget.showPayAction
                ? 'tenant_pay_year_sidebar'
                : 'tenant_history_year_sidebar'),
            duration: const Duration(milliseconds: 220),
            width: collapsed ? 76 : 210,
            color: Colors.white,
            child: Column(
              children: [
                Align(
                  alignment:
                      collapsed ? Alignment.center : Alignment.centerRight,
                  child: IconButton(
                    onPressed: () => setState(() => collapsed = !collapsed),
                    icon: Icon(collapsed
                        ? Icons.chevron_right_rounded
                        : Icons.chevron_left_rounded),
                  ),
                ),
                if (!collapsed)
                  const Padding(
                    padding: EdgeInsets.all(10),
                    child: Text('GROUP BY YEAR',
                        style: TextStyle(
                            color: Color(0xFF667085),
                            fontWeight: FontWeight.w900)),
                  ),
                ...years.map((item) => ListTile(
                      selected: item == year,
                      leading: const Icon(Icons.calendar_month_rounded),
                      title: collapsed ? null : Text('$item'),
                      onTap: () => setState(() {
                        selectedYear = item;
                        collapsed = false;
                      }),
                    )),
              ],
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (_) {
                if (!collapsed) setState(() => collapsed = true);
              },
              child: detail,
            ),
          ),
        ],
      );
    });
  }
}

class TenantRequestsTab extends StatelessWidget {
  const TenantRequestsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final store = RentalStoreScope.of(context);
    final requests = store.currentTenantRequests;
    final active =
        requests.where((request) => request.status == 'Open').toList();
    final history =
        requests.where((request) => request.status != 'Open').toList();
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: TabBar(tabs: [
                    Tab(text: 'Active (${active.length})'),
                    Tab(text: '${tr(context, 'History')} (${history.length})'),
                  ]),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: () => showAddRequestDialog(context),
                  icon: const Icon(Icons.add_comment_rounded),
                  label: const Text('New Request'),
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(children: [
              _TenantRequestList(requests: active, active: true),
              _TenantRequestList(requests: history),
            ]),
          ),
        ],
      ),
    );
  }
}

class _TenantRequestList extends StatelessWidget {
  const _TenantRequestList({required this.requests, this.active = false});

  final List<TenantRequest> requests;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final store = RentalStoreScope.of(context);
    if (requests.isEmpty) {
      return EmptyState(
        icon: active ? Icons.task_alt_rounded : Icons.history_rounded,
        title: active ? 'No active requests' : 'No request history',
        message: active
            ? 'Create a request whenever you need owner assistance.'
            : 'Closed requests will appear here.',
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: requests.map((request) {
        final facility = store.facilityFor(request.facilityId);
        return Card(
          child: ListTile(
            leading: const Icon(Icons.chat_bubble_outline_rounded),
            title: Text(request.title),
            subtitle: Text(
              '${request.requestType} • ${facility.name}\n${request.message}\n${dateLabel(request.createdAt)}',
            ),
            isThreeLine: true,
            trailing: StatusChipText(label: request.status),
          ),
        );
      }).toList(),
    );
  }
}

class TenantAccountTab extends StatelessWidget {
  const TenantAccountTab({super.key});

  @override
  Widget build(BuildContext context) {
    final store = RentalStoreScope.of(context);
    final user = store.currentUser!;
    final tenancies = store.tenantTenancies;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                ProfileAvatar(user: user, radius: 34),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.name,
                          style: Theme.of(context).textTheme.titleLarge),
                      Text(user.email),
                      Text('${store.unreadNotificationCount} unread messages'),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => showAvatarPickerDialog(context),
                  icon: const Icon(Icons.add_a_photo_rounded),
                  label: const Text('Avatar'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.notifications_rounded),
                title: const Text('Messages & notifications'),
                subtitle: Text('${store.unreadNotificationCount} unread'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => showNotifications(context),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.storage_rounded),
                title: const Text('Data export'),
                subtitle: const Text('Prepare Excel workbook or SQLite backup'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => showDataExportDialog(context),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.logout_rounded),
                title: const Text('Logout'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => confirmLogout(context),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text('Tenancy Agreements',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        if (tenancies.isEmpty)
          const Card(
            child: ListTile(
              leading: Icon(Icons.description_rounded),
              title: Text('No tenancy found'),
              subtitle: Text('Your agreement will appear once assigned.'),
            ),
          ),
        ...tenancies.map((tenancy) {
          final facility = store.facilityFor(tenancy.facilityId);
          return Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(facility.name,
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Text(facility.address),
                  const Divider(height: 24),
                  AmountRow(label: 'Monthly Rent', value: tenancy.monthlyRent),
                  Text('Unit / Room: ${tenancy.unitName}'),
                  Text(
                    'Lease Period: ${dateLabel(tenancy.leaseStart)} to ${dateLabel(tenancy.leaseEnd)}',
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Utilities: Electricity ${packageText(tenancy.electricityPackage)}, Water ${packageText(tenancy.waterPackage)}, Internet ${packageText(tenancy.internetPackage)}',
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.file_open_rounded),
                    label: const Text('View Agreement File'),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

class TenantBillCard extends StatelessWidget {
  const TenantBillCard({
    required this.bill,
    this.showPayAction = false,
    super.key,
  });

  final MonthlyBill bill;
  final bool showPayAction;

  @override
  Widget build(BuildContext context) {
    final store = RentalStoreScope.of(context);
    final facility = store.facilityFor(bill.facilityId);
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${facility.name} • ${monthLabel(bill.month)}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                StatusChip(status: bill.status),
              ],
            ),
            const SizedBox(height: 12),
            BillBreakdown(bill: bill),
            if (showPayAction) ...[
              const SizedBox(height: 12),
              if (bill.status == PaymentStatus.rejected)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: const Text(
                    'Payment was rejected. Please correct the issue and submit a new slip.',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: () => showSubmitSlipDialog(context, bill),
                  icon: const Icon(Icons.upload_file_rounded),
                  label: Text(
                    bill.status == PaymentStatus.rejected
                        ? 'Resubmit Payment Slip'
                        : 'Submit Payment Slip',
                  ),
                ),
              ),
            ],
            if (bill.slipFileName != null) ...[
              const SizedBox(height: 8),
              Text('Uploaded slip: ${bill.slipFileName}'),
            ],
            if (bill.utilityEvidenceFileName != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.photo_camera_rounded, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Meter evidence: ${bill.utilityEvidenceFileName}',
                    ),
                  ),
                ],
              ),
            ],
            if (bill.rejectReason != null) ...[
              const SizedBox(height: 8),
              Text(
                'Reject reason: ${bill.rejectReason}',
                style: TextStyle(color: Colors.red.shade700),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class YearlyFinancialChart extends StatefulWidget {
  const YearlyFinancialChart({
    required this.year,
    required this.summaries,
    required this.onPreviousYear,
    required this.onNextYear,
    super.key,
  });

  final int year;
  final List<MonthlyFinancialSummary> summaries;
  final VoidCallback onPreviousYear;
  final VoidCallback? onNextYear;

  @override
  State<YearlyFinancialChart> createState() => _YearlyFinancialChartState();
}

class _YearlyFinancialChartState extends State<YearlyFinancialChart> {
  int? hoveredMonthIndex;
  int? selectedMonthIndex;

  @override
  void didUpdateWidget(covariant YearlyFinancialChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.year != widget.year) {
      selectedMonthIndex = null;
      hoveredMonthIndex = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = RentalStoreScope.of(context);
    final selectedSummary = selectedMonthIndex == null
        ? null
        : widget.summaries[selectedMonthIndex!];
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 380;
                    final yearButtonStyle = IconButton.styleFrom(
                      minimumSize: Size.square(compact ? 34 : 42),
                      padding: EdgeInsets.all(compact ? 4 : 9),
                    );
                    final title = Text(
                      '${widget.year} ${tr(context, 'Collection & Expenses')}',
                      maxLines: compact ? 1 : 2,
                      style: (compact
                              ? Theme.of(context).textTheme.titleMedium
                              : Theme.of(context).textTheme.titleLarge)
                          ?.copyWith(fontWeight: FontWeight.w700),
                    );
                    return Row(
                      children: [
                        Icon(Icons.bar_chart_rounded, size: compact ? 20 : 22),
                        SizedBox(width: compact ? 6 : 8),
                        Expanded(
                          child: compact
                              ? FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: title,
                                )
                              : title,
                        ),
                        IconButton(
                          style: yearButtonStyle,
                          tooltip: tr(context, 'Previous year'),
                          onPressed: widget.onPreviousYear,
                          icon: const Icon(Icons.chevron_left_rounded),
                        ),
                        IconButton(
                          style: yearButtonStyle,
                          tooltip: tr(context, 'Next year'),
                          onPressed: widget.onNextYear,
                          icon: const Icon(Icons.chevron_right_rounded),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 6),
                Text(
                  tr(context,
                      'Monthly amounts; select a month to see its breakdown'),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF667085),
                      ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 18,
                  children: [
                    ChartLegend(
                      color: Color(0xFF16856B),
                      label: tr(context, 'Rental collection'),
                    ),
                    ChartLegend(
                      color: Color(0xFFD16432),
                      label: tr(context, 'Expenses'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 155,
                  width: double.infinity,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth;
                      final hovered = hoveredMonthIndex == null
                          ? null
                          : widget.summaries[hoveredMonthIndex!];
                      final tooltipWidth = width < 180 ? width : 180.0;
                      final groupWidth = (width - 16) / widget.summaries.length;
                      final tooltipLeft = hoveredMonthIndex == null
                          ? 0.0
                          : (8 +
                                  groupWidth * hoveredMonthIndex! +
                                  groupWidth / 2 -
                                  tooltipWidth / 2)
                              .clamp(0.0, width - tooltipWidth);

                      return MouseRegion(
                        cursor: SystemMouseCursors.click,
                        onHover: (event) {
                          final index = financialChartMonthIndex(
                            event.localPosition.dx,
                            width,
                            widget.summaries.length,
                          );
                          if (index != hoveredMonthIndex) {
                            setState(() => hoveredMonthIndex = index);
                          }
                        },
                        onExit: (_) {
                          if (hoveredMonthIndex != null) {
                            setState(() => hoveredMonthIndex = null);
                          }
                        },
                        child: GestureDetector(
                          key: const Key('financial_chart_touch_area'),
                          behavior: HitTestBehavior.opaque,
                          onTapDown: (details) {
                            final index = financialChartMonthIndex(
                              details.localPosition.dx,
                              width,
                              widget.summaries.length,
                            );
                            setState(() {
                              selectedMonthIndex =
                                  selectedMonthIndex == index ? null : index;
                            });
                          },
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Positioned.fill(
                                child: CustomPaint(
                                  painter: FinancialChartPainter(
                                    widget.summaries,
                                    highlightedIndex:
                                        hoveredMonthIndex ?? selectedMonthIndex,
                                    monthLabels: List.generate(
                                      12,
                                      (index) => localizedMonthShort(
                                          context, index + 1),
                                    ),
                                  ),
                                ),
                              ),
                              if (hovered != null)
                                Positioned(
                                  left: tooltipLeft,
                                  top: 2,
                                  width: tooltipWidth,
                                  child: IgnorePointer(
                                    child: _FinancialChartTooltip(
                                      year: widget.year,
                                      summary: hovered,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                if (selectedSummary == null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4F7FB),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      tr(context,
                          'Select a month above to view its collection and expense charts.'),
                      style: const TextStyle(color: Color(0xFF667085)),
                    ),
                  )
                else ...[
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${localizedMonthYear(context, DateTime(widget.year, selectedSummary.month))} ${tr(context, 'Breakdown')}',
                          key: const Key('inline_month_breakdown_title'),
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                        ),
                      ),
                      IconButton(
                        key: const Key('hide_month_breakdown_button'),
                        tooltip: tr(context, 'Hide breakdown'),
                        onPressed: () =>
                            setState(() => selectedMonthIndex = null),
                        icon: const Icon(Icons.expand_less_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tr(context,
                        'See who contributed to collection and where expenses went.'),
                    style: const TextStyle(color: Color(0xFF667085)),
                  ),
                  const SizedBox(height: 14),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final cardWidth = constraints.maxWidth < 680
                          ? constraints.maxWidth
                          : (constraints.maxWidth - 16) / 2;
                      final month = selectedSummary.month;
                      return Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: [
                          SizedBox(
                            width: cardWidth,
                            child: FinancialBreakdownPieCard(
                              key: ValueKey('collection_${widget.year}_$month'),
                              title: 'Total Rental Collection',
                              icon: Icons.payments_rounded,
                              accentColor: const Color(0xFF16856B),
                              items: store.monthlyCollectionBreakdown(
                                widget.year,
                                month,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: cardWidth,
                            child: FinancialBreakdownPieCard(
                              key: ValueKey('expenses_${widget.year}_$month'),
                              title: tr(context, 'Total Expenses'),
                              icon: Icons.receipt_long_rounded,
                              accentColor: const Color(0xFFD16432),
                              items: store.monthlyExpenseBreakdown(
                                widget.year,
                                month,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FinancialChartTooltip extends StatelessWidget {
  const _FinancialChartTooltip({
    required this.year,
    required this.summary,
  });

  final int year;
  final MonthlyFinancialSummary summary;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(10),
      color: const Color(0xFF17233C),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${localizedMonthShort(context, summary.month)} $year',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              '${tr(context, 'Collection')}  ${money(summary.collection)}',
              style: const TextStyle(
                color: Color(0xFF7CE0C2),
                fontSize: 12,
              ),
            ),
            Text(
              '${tr(context, 'Expenses')}   ${money(summary.expenses)}',
              style: const TextStyle(
                color: Color(0xFFFFB18D),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FinancialBreakdownPieCard extends StatelessWidget {
  const FinancialBreakdownPieCard({
    required this.title,
    required this.icon,
    required this.accentColor,
    required this.items,
    super.key,
  });

  final String title;
  final IconData icon;
  final Color accentColor;
  final List<FinancialBreakdownItem> items;

  static const colors = [
    Color(0xFF16856B),
    Color(0xFF3156A3),
    Color(0xFFD16432),
    Color(0xFF8A4FA3),
    Color(0xFFDAA520),
    Color(0xFF2D8BA8),
    Color(0xFFB04A6F),
    Color(0xFF6A7B3F),
  ];

  @override
  Widget build(BuildContext context) {
    final total = items.fold<double>(0, (sum, item) => sum + item.amount);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: accentColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              money(total),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: accentColor,
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 116,
                  height: 116,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 750),
                    curve: Curves.easeOutBack,
                    builder: (context, progress, child) {
                      final visibleProgress = progress.clamp(0.0, 1.0);
                      return CustomPaint(
                        painter: FinancialPieChartPainter(
                          items: items,
                          colors: colors,
                          progress: visibleProgress,
                        ),
                        child: Opacity(
                          opacity: visibleProgress,
                          child: Transform.scale(
                            scale: 0.8 + visibleProgress * 0.2,
                            child: child,
                          ),
                        ),
                      );
                    },
                    child: Center(
                      child: Text(
                        items.isEmpty ? 'No data' : money(total),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: items.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.only(top: 12),
                          child: Text(
                            'No collection or expense recorded for this month.',
                            style: TextStyle(
                              color: Color(0xFF667085),
                              fontSize: 11,
                            ),
                          ),
                        )
                      : Column(
                          children: List.generate(items.length, (index) {
                            final item = items[index];
                            final percentage =
                                total == 0 ? 0 : item.amount / total * 100;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    margin: const EdgeInsets.only(top: 3),
                                    decoration: BoxDecoration(
                                      color: colors[index % colors.length],
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      item.label,
                                      style: const TextStyle(fontSize: 10),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        money(item.amount),
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      Text(
                                        '${percentage.toStringAsFixed(1)}%',
                                        style: const TextStyle(
                                          color: Color(0xFF667085),
                                          fontSize: 9,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          }),
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class FinancialPieChartPainter extends CustomPainter {
  FinancialPieChartPainter({
    required this.items,
    required this.colors,
    required this.progress,
  });

  final List<FinancialBreakdownItem> items;
  final List<Color> colors;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 * progress;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final total = items.fold<double>(0, (sum, item) => sum + item.amount);
    if (total <= 0) {
      canvas.drawCircle(
          center, radius, Paint()..color = const Color(0xFFE8EDF5));
    } else {
      var startAngle = -math.pi / 2;
      for (var index = 0; index < items.length; index++) {
        final sweepAngle = items[index].amount / total * math.pi * 2 * progress;
        canvas.drawArc(
          rect,
          startAngle,
          sweepAngle,
          true,
          Paint()..color = colors[index % colors.length],
        );
        startAngle += sweepAngle;
      }
    }
    canvas.drawCircle(
      center,
      radius * 0.52,
      Paint()..color = ThemeData.light().cardColor,
    );
  }

  @override
  bool shouldRepaint(FinancialPieChartPainter oldDelegate) =>
      oldDelegate.items != items ||
      oldDelegate.colors != colors ||
      oldDelegate.progress != progress;
}

int financialChartMonthIndex(double dx, double width, int monthCount) {
  if (monthCount <= 0 || width <= 16) return 0;
  final chartWidth = width - 16;
  final normalized = ((dx - 8) / chartWidth).clamp(0.0, 0.999999);
  return (normalized * monthCount).floor();
}

class ChartLegend extends StatelessWidget {
  const ChartLegend({
    required this.color,
    required this.label,
    super.key,
  });

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(label),
      ],
    );
  }
}

class FinancialChartPainter extends CustomPainter {
  FinancialChartPainter(
    this.summaries, {
    this.highlightedIndex,
    List<String>? monthLabels,
  }) : monthLabels = monthLabels ?? monthNames;

  final List<MonthlyFinancialSummary> summaries;
  final int? highlightedIndex;
  final List<String> monthLabels;

  static const monthNames = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  @override
  void paint(Canvas canvas, Size size) {
    const leftPadding = 8.0;
    const rightPadding = 8.0;
    const topPadding = 8.0;
    const bottomPadding = 28.0;
    final chartHeight = size.height - topPadding - bottomPadding;
    final chartWidth = size.width - leftPadding - rightPadding;
    final maxValue = summaries.fold<double>(1, (current, summary) {
      final monthMax = summary.collection > summary.expenses
          ? summary.collection
          : summary.expenses;
      return monthMax > current ? monthMax : current;
    });

    final gridPaint = Paint()
      ..color = const Color(0xFFE8EDF5)
      ..strokeWidth = 1;
    for (var line = 0; line <= 4; line++) {
      final y = topPadding + chartHeight * line / 4;
      canvas.drawLine(
        Offset(leftPadding, y),
        Offset(size.width - rightPadding, y),
        gridPaint,
      );
    }

    final groupWidth = chartWidth / summaries.length;
    final barWidth = groupWidth * 0.25;
    final collectionPaint = Paint()..color = const Color(0xFF16856B);
    final expensePaint = Paint()..color = const Color(0xFFD16432);

    for (var index = 0; index < summaries.length; index++) {
      final summary = summaries[index];
      final centerX = leftPadding + groupWidth * index + groupWidth / 2;
      final collectionHeight =
          chartHeight * (summary.collection / maxValue).clamp(0, 1);
      final expenseHeight =
          chartHeight * (summary.expenses / maxValue).clamp(0, 1);
      final bottom = topPadding + chartHeight;

      final isHighlighted = index == highlightedIndex;
      final collectionBarPaint = Paint()
        ..color =
            isHighlighted ? const Color(0xFF0F6D56) : collectionPaint.color;
      final expenseBarPaint = Paint()
        ..color = isHighlighted ? const Color(0xFFB64B20) : expensePaint.color;

      if (isHighlighted) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              centerX - groupWidth / 2 + 2,
              topPadding,
              groupWidth - 4,
              chartHeight,
            ),
            const Radius.circular(6),
          ),
          Paint()..color = const Color(0x123156A3),
        );
      }

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            centerX - barWidth - 1,
            bottom - collectionHeight,
            barWidth,
            collectionHeight,
          ),
          const Radius.circular(4),
        ),
        collectionBarPaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            centerX + 1,
            bottom - expenseHeight,
            barWidth,
            expenseHeight,
          ),
          const Radius.circular(4),
        ),
        expenseBarPaint,
      );

      final label = TextPainter(
        text: TextSpan(
          text: monthLabels[index],
          style: const TextStyle(
            color: Color(0xFF667085),
            fontSize: 10,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(
        canvas,
        Offset(centerX - label.width / 2, size.height - 18),
      );
    }
  }

  @override
  bool shouldRepaint(FinancialChartPainter oldDelegate) =>
      oldDelegate.summaries != summaries ||
      oldDelegate.highlightedIndex != highlightedIndex ||
      oldDelegate.monthLabels != monthLabels;
}

class MetricCard extends StatelessWidget {
  const MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    this.positive,
    this.color,
    this.fullWidth = false,
    this.onTap,
    super.key,
  });

  final String title;
  final String value;
  final IconData icon;
  final bool? positive;
  final Color? color;
  final bool fullWidth;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final accentColor = color ??
        (positive == null
            ? Theme.of(context).colorScheme.primary
            : positive!
                ? const Color(0xFF16856B)
                : const Color(0xFFC43D4B));
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 145;
        return SizedBox(
          width: fullWidth ? double.infinity : 250,
          height: compact ? 118 : 168,
          child: Card(
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(18),
              child: Padding(
                padding: EdgeInsets.all(compact ? 8 : 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: compact ? 30 : 42,
                          height: compact ? 30 : 42,
                          decoration: BoxDecoration(
                            color: accentColor.withOpacity(0.12),
                            borderRadius:
                                BorderRadius.circular(compact ? 9 : 12),
                          ),
                          child: Icon(
                            icon,
                            color: accentColor,
                            size: compact ? 17 : 22,
                          ),
                        ),
                        if (onTap != null) ...[
                          const Spacer(),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: accentColor,
                            size: compact ? 16 : 20,
                          ),
                        ],
                      ],
                    ),
                    const Spacer(),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: (compact
                              ? Theme.of(context).textTheme.labelSmall
                              : Theme.of(context).textTheme.bodyMedium)
                          ?.copyWith(
                        color: const Color(0xFF667085),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: compact ? 2 : 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        value,
                        style: (compact
                                ? Theme.of(context).textTheme.titleMedium
                                : Theme.of(context).textTheme.headlineSmall)
                            ?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF17233C),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class CostSummary extends StatelessWidget {
  const CostSummary({required this.facility, super.key});

  final Facility facility;

  @override
  Widget build(BuildContext context) {
    final store = RentalStoreScope.of(context);
    final version = store.costVersionForMonth(facility, store.currentMonth);
    final total = store.monthlyFacilityOutflow(
      facility,
      month: store.currentMonth,
    );
    final items = [
      (
        tr(context, 'Installment'),
        version.installmentAmount,
        Icons.account_balance_rounded,
        const Color(0xFF3156A3),
        '',
      ),
      (
        tr(context, 'Extra Payment'),
        version.extraInstallmentPayment,
        Icons.add_card_rounded,
        const Color(0xFF6B5CB8),
        '',
      ),
      (
        tr(context, 'Maintenance'),
        version.maintenanceFee,
        Icons.handyman_rounded,
        const Color(0xFFD16432),
        '',
      ),
      (
        '${tr(context, 'Fire Insurance')} \u2022 ${tr(context, insuranceFrequencyText(version.insuranceFrequency))}',
        version.insuranceFee,
        Icons.local_fire_department_rounded,
        const Color(0xFFC43D4B),
        localizedMonthShort(context, version.insuranceDueMonth),
      ),
      for (final commitment in facility.extraCommitments)
        (
          '${tr(context, commitment.name)} \u2022 ${tr(context, commitmentFrequencyText(commitment.frequency))}',
          commitment.amount,
          Icons.receipt_long_rounded,
          const Color(0xFF4F6B7A),
          localizedMonthShort(context, commitment.firstDueMonth),
        ),
    ];
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF17233C),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.receipt_long_rounded, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  tr(context, 'Monthly Recurring Commitment'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                money(total),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final narrowPhone = constraints.maxWidth < 390;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisExtent: narrowPhone ? 84 : 72,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
                  decoration: BoxDecoration(
                    color: item.$4.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: item.$4.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(item.$3, color: item.$4, size: 19),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.$1,
                              maxLines: narrowPhone ? 2 : 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                height: 1.15,
                                fontSize: 11,
                                color: Color(0xFF667085),
                              ),
                            ),
                            const SizedBox(height: 2),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                item.$5.isEmpty
                                    ? money(item.$2)
                                    : '${money(item.$2)} • ${item.$5}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}

class BillBreakdown extends StatelessWidget {
  const BillBreakdown({required this.bill, super.key});

  final MonthlyBill bill;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AmountRow(label: 'Rent', value: bill.rentAmount),
        AmountRow(label: 'Electricity', value: bill.electricityAmount),
        AmountRow(label: 'Water', value: bill.waterAmount),
        AmountRow(label: 'Internet', value: bill.internetAmount),
        const Divider(),
        AmountRow(label: 'Total Due', value: bill.totalAmount, bold: true),
      ],
    );
  }
}

class AmountRow extends StatelessWidget {
  const AmountRow({
    required this.label,
    required this.value,
    this.bold = false,
    super.key,
  });

  final String label;
  final double value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final style = bold
        ? Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            )
        : Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(moneyExact(value), style: style),
        ],
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip({required this.status, super.key});

  final PaymentStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      PaymentStatus.notSubmitted => ('Pending Owner Utilities', Colors.grey),
      PaymentStatus.pendingTenantPayment => (
          'Pending Tenant Payment',
          Colors.blue
        ),
      PaymentStatus.pendingApproval => ('Pending', Colors.orange),
      PaymentStatus.approved => ('Approved', Colors.green),
      PaymentStatus.rejected => ('Rejected', Colors.red),
    };
    return Chip(
      label: Text(tr(context, label)),
      side: BorderSide(color: color.shade300),
      backgroundColor: color.shade50,
      labelStyle: TextStyle(color: color.shade900),
    );
  }
}

class BillPerformanceCard extends StatelessWidget {
  const BillPerformanceCard({
    required this.bill,
    required this.tenant,
    this.compact = false,
    super.key,
  });

  final MonthlyBill bill;
  final AppUser tenant;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final invoiceReleaseDate = DateTime(bill.month.year, bill.month.month);
    final paidOn = bill.paymentDate ?? bill.submittedAt;
    final paymentDate = paidOn == null ? 'Not paid yet' : dateTimeLabel(paidOn);
    final paymentAmount = bill.amountPaid > 0 ? money(bill.amountPaid) : 'RM 0';
    return Card(
      elevation: 0,
      child: Padding(
        padding: EdgeInsets.all(compact ? 12 : 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(Icons.receipt_long_rounded, color: oceanDeep),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${tenant.name} • ${monthLabel(bill.month)}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Due ${money(bill.totalAmount)}',
                        style: const TextStyle(color: oceanMuted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                StatusChip(status: bill.status),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 16,
              runSpacing: 6,
              children: [
                _BillPerformanceMeta(
                  label: 'Payment date',
                  value: paymentDate,
                ),
                _BillPerformanceMeta(
                  label: 'Invoice release date',
                  value: dateLabel(invoiceReleaseDate),
                ),
                _BillPerformanceMeta(
                  label: 'Payment amount',
                  value: paymentAmount,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () => confirmAndShowInvoicePdf(context, bill),
                icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                label: const Text('View invoice PDF'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BillPerformanceMeta extends StatelessWidget {
  const _BillPerformanceMeta({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 150),
      child: RichText(
        text: TextSpan(
          style: DefaultTextStyle.of(context).style.copyWith(
                color: oceanText,
                fontSize: 12,
              ),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(
                color: oceanMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

String paymentStatusLabel(PaymentStatus status) {
  return switch (status) {
    PaymentStatus.notSubmitted => 'Pending Owner Utilities',
    PaymentStatus.pendingTenantPayment => 'Pending Tenant Payment',
    PaymentStatus.pendingApproval => 'Pending',
    PaymentStatus.approved => 'Approved',
    PaymentStatus.rejected => 'Rejected',
  };
}

class StatusChipText extends StatelessWidget {
  const StatusChipText({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(tr(context, label)),
      side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
    );
  }
}

String tenantStatusText(AppUser tenant, Tenancy tenancy) {
  if (!tenancy.active) return 'Inactive';
  if (tenant.accountCreated) return 'Active';
  return 'Pending verification';
}

class TenantStatusChip extends StatelessWidget {
  const TenantStatusChip({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final color = switch (label) {
      'Active' => Colors.green,
      'Inactive' => Colors.grey,
      _ => Colors.orange,
    };
    return Chip(
      label: Text(label),
      side: BorderSide(color: color.shade300),
      backgroundColor: color.shade50,
      labelStyle: TextStyle(color: color.shade900),
    );
  }
}

class MiniPill extends StatelessWidget {
  const MiniPill({required this.label, required this.value, super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text('$label: $value'),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(message, textAlign: TextAlign.center),
            if (action != null) ...[
              const SizedBox(height: 16),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

Future<Facility?> showAddFacilityDialog(BuildContext context) {
  final store = RentalStoreScope.of(context);
  final name = TextEditingController();
  final addressLine1 = TextEditingController();
  final addressLine2 = TextEditingController();
  final installment = TextEditingController();
  final maintenance = TextEditingController();
  final insurance = TextEditingController();
  String? selectedState;
  String? selectedCity;
  String? selectedPostcode;
  var insuranceFrequency = InsuranceFrequency.yearly;
  var insuranceDueMonth = 1;
  String? validationMessage;

  return showDialog<Facility>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) {
        return AlertDialog(
          title: const Text('Create New Facility'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppTextField(
                    controller: name,
                    label: 'Facility Name',
                  ),
                  AppTextField(
                    controller: addressLine1,
                    label: 'Address line 1 *',
                  ),
                  AppTextField(
                    controller: addressLine2,
                    label: 'Address line 2',
                  ),
                  MalaysiaAddressDropdowns(
                    state: selectedState,
                    city: selectedCity,
                    postcode: selectedPostcode,
                    onStateChanged: (value) {
                      setDialogState(() {
                        selectedState = value;
                        selectedCity = null;
                        selectedPostcode = null;
                      });
                    },
                    onCityChanged: (value) {
                      setDialogState(() {
                        selectedCity = value;
                        selectedPostcode = null;
                      });
                    },
                    onPostcodeChanged: (value) {
                      setDialogState(() => selectedPostcode = value);
                    },
                  ),
                  AppTextField(
                    controller: installment,
                    label: 'Monthly Installment',
                    prefixText: 'RM ',
                  ),
                  AppTextField(
                    controller: maintenance,
                    label: 'Maintenance',
                    prefixText: 'RM ',
                  ),
                  AppTextField(
                    controller: insurance,
                    label: 'Fire Insurance Premium',
                    prefixText: 'RM ',
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<InsuranceFrequency>(
                          value: insuranceFrequency,
                          decoration: const InputDecoration(
                            labelText: 'Insurance Frequency',
                            border: OutlineInputBorder(),
                          ),
                          items: InsuranceFrequency.values
                              .map(
                                (frequency) => DropdownMenuItem(
                                  value: frequency,
                                  child: Text(
                                    insuranceFrequencyText(frequency),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setDialogState(
                                () => insuranceFrequency = value,
                              );
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: insuranceDueMonth,
                          decoration: const InputDecoration(
                            labelText: 'First Payment Month',
                            border: OutlineInputBorder(),
                          ),
                          items: List.generate(
                            12,
                            (index) => DropdownMenuItem(
                              value: index + 1,
                              child: Text(
                                FinancialChartPainter.monthNames[index],
                              ),
                            ),
                          ),
                          onChanged: (value) {
                            if (value != null) {
                              setDialogState(() => insuranceDueMonth = value);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (validationMessage != null)
                    Text(
                      validationMessage!,
                      style: TextStyle(color: Colors.red.shade700),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () async {
                if (name.text.trim().isEmpty ||
                    addressLine1.text.trim().isEmpty ||
                    selectedPostcode == null ||
                    selectedCity == null ||
                    selectedState == null) {
                  setDialogState(() {
                    validationMessage =
                        'Facility name, address line 1, state, city and postcode are required.';
                  });
                  return;
                }
                if (!isValidMalaysiaLocation(
                  state: selectedState!,
                  city: selectedCity!,
                  postcode: selectedPostcode!,
                )) {
                  setDialogState(() {
                    validationMessage =
                        'Postcode, city and state do not match. Select a valid combination.';
                  });
                  return;
                }
                if (!isValidMoneyInput(installment.text) ||
                    !isValidMoneyInput(maintenance.text) ||
                    !isValidMoneyInput(insurance.text)) {
                  setDialogState(() {
                    validationMessage =
                        'Installment, maintenance and insurance must be valid numbers.';
                  });
                  return;
                }
                final confirmed = await showActionConfirmation(
                  dialogContext,
                  title: 'Create this facility?',
                  message:
                      '${name.text.trim()} will be created with a monthly installment of ${money(parseMoney(installment.text))}.',
                  confirmLabel: 'Create Facility',
                );
                if (!confirmed || !dialogContext.mounted) return;
                final facility = store.addFacility(
                  name: name.text.trim(),
                  addressLine: [
                    addressLine1.text.trim(),
                    if (addressLine2.text.trim().isNotEmpty)
                      addressLine2.text.trim(),
                  ].join(', '),
                  postcode: selectedPostcode!,
                  city: selectedCity!,
                  state: selectedState!,
                  installmentAmount: parseMoney(installment.text),
                  maintenanceFee: parseMoney(maintenance.text),
                  insuranceFee: parseMoney(insurance.text),
                  insuranceFrequency: insuranceFrequency,
                  insuranceDueMonth: insuranceDueMonth,
                );
                Navigator.pop(dialogContext, facility);
              },
              icon: const Icon(Icons.add_business_rounded),
              label: const Text('Create Facility'),
            ),
          ],
        );
      },
    ),
  );
}

void showAddTenantDialog(BuildContext context, Facility facility) {
  final store = RentalStoreScope.of(context);
  final fullName = TextEditingController();
  final email = TextEditingController();
  final phoneNumber = TextEditingController();
  final originAddressLine1 = TextEditingController();
  final originAddressLine2 = TextEditingController();
  final dateOfBirth = TextEditingController();
  final sex = TextEditingController();
  final unitName = TextEditingController();
  final monthlyRent = TextEditingController();
  final leaseStart = TextEditingController();
  final leaseEnd = TextEditingController();
  final carParkDetails = TextEditingController();
  var electricityIncluded = false;
  var waterIncluded = false;
  var internetIncluded = true;
  var carParkIncluded = false;
  String? selectedOriginState;
  String? selectedOriginCity;
  String? selectedOriginPostcode;

  showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) {
        return AlertDialog(
          title: Text('New Tenant • ${facility.name}'),
          content: SizedBox(
            width: 620,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Tenant Profile',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Enter known details now. The tenant can complete or confirm the profile after accepting the email invitation.',
                    style: TextStyle(color: Color(0xFF667085)),
                  ),
                  const SizedBox(height: 10),
                  AppTextField(
                    controller: fullName,
                    label: 'Full Name',
                  ),
                  AppTextField(
                    controller: email,
                    label: 'Email',
                  ),
                  AppTextField(
                    controller: phoneNumber,
                    label: 'WhatsApp / Phone Number',
                    keyboardType: TextInputType.phone,
                  ),
                  AppTextField(
                    controller: originAddressLine1,
                    label: 'Origin address line 1 *',
                  ),
                  AppTextField(
                    controller: originAddressLine2,
                    label: 'Origin address line 2',
                  ),
                  MalaysiaAddressDropdowns(
                    state: selectedOriginState,
                    city: selectedOriginCity,
                    postcode: selectedOriginPostcode,
                    onStateChanged: (value) {
                      setDialogState(() {
                        selectedOriginState = value;
                        selectedOriginCity = null;
                        selectedOriginPostcode = null;
                      });
                    },
                    onCityChanged: (value) {
                      setDialogState(() {
                        selectedOriginCity = value;
                        selectedOriginPostcode = null;
                      });
                    },
                    onPostcodeChanged: (value) {
                      setDialogState(() => selectedOriginPostcode = value);
                    },
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: AppTextField(
                          controller: dateOfBirth,
                          label: 'Date of Birth',
                          helperText: 'DD/MM/YYYY',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: AppTextField(
                          controller: sex,
                          label: 'Sex',
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 28),
                  Text(
                    'Contract & Package',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: AppTextField(
                          controller: unitName,
                          label: 'Room / Unit',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: AppTextField(
                          controller: monthlyRent,
                          label: 'Monthly Rent',
                          prefixText: 'RM ',
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: AppTextField(
                          controller: leaseStart,
                          label: 'Lease Start',
                          helperText: 'DD/MM/YYYY',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: AppTextField(
                          controller: leaseEnd,
                          label: 'Lease End',
                          helperText: 'DD/MM/YYYY',
                        ),
                      ),
                    ],
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Electricity included'),
                    value: electricityIncluded,
                    onChanged: (value) =>
                        setDialogState(() => electricityIncluded = value),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Water included'),
                    value: waterIncluded,
                    onChanged: (value) =>
                        setDialogState(() => waterIncluded = value),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Internet included'),
                    value: internetIncluded,
                    onChanged: (value) =>
                        setDialogState(() => internetIncluded = value),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Car park included'),
                    value: carParkIncluded,
                    onChanged: (value) =>
                        setDialogState(() => carParkIncluded = value),
                  ),
                  if (carParkIncluded)
                    AppTextField(
                      controller: carParkDetails,
                      label: 'Car Park Details',
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () async {
                if (!isValidHumanName(fullName.text)) {
                  showValidationMessage(
                    dialogContext,
                    'Full name must contain letters only, no numbers.',
                  );
                  return;
                }
                if (!isValidEmailInput(email.text)) {
                  showValidationMessage(dialogContext, 'Enter a valid email.');
                  return;
                }
                if (phoneNumber.text.trim().isNotEmpty &&
                    !isValidPhoneInput(phoneNumber.text)) {
                  showValidationMessage(
                    dialogContext,
                    'Enter a valid WhatsApp / phone number.',
                  );
                  return;
                }
                if (originAddressLine1.text.trim().isEmpty ||
                    selectedOriginState == null ||
                    selectedOriginCity == null ||
                    selectedOriginPostcode == null) {
                  showValidationMessage(
                    dialogContext,
                    'Origin address line 1, state, city and postcode are required.',
                  );
                  return;
                }
                if (!isValidMalaysiaLocation(
                  state: selectedOriginState!,
                  city: selectedOriginCity!,
                  postcode: selectedOriginPostcode!,
                )) {
                  showValidationMessage(
                    dialogContext,
                    'Origin postcode, city and state do not match.',
                  );
                  return;
                }
                final parsedDateOfBirth = parseDateInput(dateOfBirth.text);
                if (parsedDateOfBirth == null) {
                  showValidationMessage(
                    dialogContext,
                    'Date of birth must use DD/MM/YYYY.',
                  );
                  return;
                }
                if (!isValidMoneyInput(monthlyRent.text, allowZero: false)) {
                  showValidationMessage(
                    dialogContext,
                    'Monthly rent must be a valid amount above RM 0.',
                  );
                  return;
                }
                final parsedLeaseStart = parseDateInput(leaseStart.text);
                final parsedLeaseEnd = parseDateInput(leaseEnd.text);
                if (parsedLeaseStart == null || parsedLeaseEnd == null) {
                  showValidationMessage(
                    dialogContext,
                    'Lease start and lease end must use DD/MM/YYYY.',
                  );
                  return;
                }
                if (parsedLeaseEnd.isBefore(parsedLeaseStart)) {
                  showValidationMessage(
                    dialogContext,
                    'Lease end cannot be before lease start.',
                  );
                  return;
                }
                final confirmed = await showActionConfirmation(
                  dialogContext,
                  title: 'Create this tenant?',
                  message:
                      '${fullName.text.trim()} will be added to ${facility.name}, ${unitName.text.trim()}, at ${money(parseMoney(monthlyRent.text))} monthly rent.',
                  confirmLabel: 'Create Tenant',
                );
                if (!confirmed || !dialogContext.mounted) return;
                store.addTenantToFacility(
                  facility: facility,
                  fullName: fullName.text.trim(),
                  email: email.text.trim(),
                  phoneNumber: phoneNumber.text.trim(),
                  originAddress: combineAddress(
                    line1: originAddressLine1.text,
                    line2: originAddressLine2.text,
                    postcode: selectedOriginPostcode!,
                    city: selectedOriginCity!,
                    state: selectedOriginState!,
                  ),
                  dateOfBirth: parsedDateOfBirth,
                  sex: sex.text.trim(),
                  unitName: unitName.text.trim(),
                  monthlyRent: parseMoney(monthlyRent.text),
                  leaseStart: parsedLeaseStart,
                  leaseEnd: parsedLeaseEnd,
                  electricityPackage: electricityIncluded
                      ? UtilityPackage.included
                      : UtilityPackage.excluded,
                  waterPackage: waterIncluded
                      ? UtilityPackage.included
                      : UtilityPackage.excluded,
                  internetPackage: internetIncluded
                      ? UtilityPackage.included
                      : UtilityPackage.excluded,
                  carParkIncluded: carParkIncluded,
                  carParkDetails: carParkDetails.text.trim(),
                );
                Navigator.pop(dialogContext);
              },
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('Create Tenant'),
            ),
          ],
        );
      },
    ),
  );
}

void showSendInvitationDialog(BuildContext context, AppUser tenant) {
  final store = RentalStoreScope.of(context);

  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Send Tenant Invitation'),
      content: SizedBox(
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.mark_email_unread_rounded,
              size: 48,
              color: Color(0xFF3156A3),
            ),
            const SizedBox(height: 14),
            Text(
              tenant.email,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'The invitation asks ${tenant.name} to log in, create a password, and complete their personal profile.',
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7E6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Access is invitation-only. Supabase will email a secure account link to this exact tenancy address.',
              ),
            ),
            if (tenant.invitationSentAt != null) ...[
              const SizedBox(height: 12),
              Text(
                'Last invitation: ${dateTimeLabel(tenant.invitationSentAt!)}',
                style: const TextStyle(color: Color(0xFF667085)),
              ),
            ],
            if (tenant.accountCreatedAt != null) ...[
              const SizedBox(height: 6),
              Text(
                'Account created: ${dateTimeLabel(tenant.accountCreatedAt!)}',
                style: const TextStyle(
                  color: Color(0xFF16856B),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: tenant.accountCreated || tenant.invitationSent
              ? null
              : () async {
                  final confirmed = await showActionConfirmation(
                    dialogContext,
                    title: 'Send secure invitation?',
                    message:
                        'Supabase will send a one-time account invitation to ${tenant.email}.',
                    confirmLabel: 'Send Invitation',
                  );
                  if (!confirmed || !dialogContext.mounted) return;
                  try {
                    await store.sendSecureTenantInvitation(tenant);
                    if (!dialogContext.mounted) return;
                    Navigator.pop(dialogContext);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Secure invitation sent to ${tenant.email}.',
                        ),
                      ),
                    );
                  } on AuthException catch (error) {
                    if (!dialogContext.mounted) return;
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      SnackBar(content: Text(error.message)),
                    );
                  }
                },
          icon: const Icon(Icons.send_rounded),
          label: Text(
            tenant.accountCreated
                ? 'Account Created'
                : tenant.invitationSent
                    ? 'Invitation Sent'
                    : 'Send Invitation',
          ),
        ),
      ],
    ),
  );
}

Future<bool> showActionConfirmation(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  bool destructive = false,
}) async {
  return await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: Icon(
            destructive ? Icons.warning_amber_rounded : Icons.help_rounded,
            color:
                destructive ? const Color(0xFFC43D4B) : const Color(0xFF3156A3),
          ),
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: destructive
                  ? FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFC43D4B),
                    )
                  : null,
              child: Text(confirmLabel),
            ),
          ],
        ),
      ) ??
      false;
}

Future<void> confirmAndShowInvoicePdf(
  BuildContext context,
  MonthlyBill bill,
) async {
  final confirmed = await showActionConfirmation(
    context,
    title: 'View invoice PDF?',
    message: 'Do you want to proceed to view this generated invoice PDF?',
    confirmLabel: 'View PDF',
  );
  if (!confirmed || !context.mounted) return;
  await showInvoicePdfPreview(
    context,
    _rentalInvoiceFromBill(context, bill),
  );
}

Future<void> confirmLogout(BuildContext context) async {
  final store = RentalStoreScope.of(context);
  final confirmed = await showActionConfirmation(
    context,
    title: 'Log out?',
    message: 'You will return to the login page.',
    confirmLabel: 'Log Out',
    destructive: true,
  );
  if (confirmed) await store.cloudLogout();
}

void showEditCostsDialog(BuildContext context, Facility facility) {
  final store = RentalStoreScope.of(context);
  final installment = TextEditingController(
      text: facility.installmentAmount.toStringAsFixed(0));
  final extra = TextEditingController(
      text: facility.extraInstallmentPayment.toStringAsFixed(0));
  final maintenance =
      TextEditingController(text: facility.maintenanceFee.toStringAsFixed(0));

  showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Text('Edit ${facility.name} Costs'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8EEFC),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Changes apply from ${monthLabel(store.currentMonth)}. Previous months remain unchanged.',
                  style: const TextStyle(
                    color: Color(0xFF24498F),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              AppTextField(controller: installment, label: 'Installment'),
              AppTextField(
                controller: extra,
                label: 'Extra Installment Payment',
              ),
              AppTextField(controller: maintenance, label: 'Maintenance'),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(top: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFD6DEEB)),
                ),
                child: const Text(
                  'Fire insurance is now managed under Recurring Commitments.',
                  style: TextStyle(
                    color: Color(0xFF667085),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (!isValidMoneyInput(installment.text) ||
                  !isValidMoneyInput(extra.text) ||
                  !isValidMoneyInput(maintenance.text)) {
                showValidationMessage(
                  dialogContext,
                  'All facility cost fields must be valid numbers.',
                );
                return;
              }
              final confirmed = await showActionConfirmation(
                dialogContext,
                title: 'Apply facility cost changes?',
                message:
                    'The new costs will apply from ${monthLabel(store.currentMonth)}. Previous-month calculations will not change.',
                confirmLabel: 'Apply Changes',
              );
              if (!confirmed || !dialogContext.mounted) return;
              store.updateFacilityCosts(
                facility,
                installmentAmount: parseMoney(installment.text),
                extraInstallmentPayment: parseMoney(extra.text),
                maintenanceFee: parseMoney(maintenance.text),
                insuranceFee: facility.insuranceFee,
                insuranceFrequency: facility.insuranceFrequency,
                insuranceDueMonth: facility.insuranceDueMonth,
              );
              Navigator.pop(dialogContext);
            },
            child: const Text('Review & Apply'),
          ),
        ],
      ),
    ),
  );
}

void showPropertyExpenseEditorDialog(
  BuildContext context,
  Facility facility,
) {
  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('${facility.name} Expenses'),
      content: SizedBox(
        width: 540,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  child: Icon(Icons.account_balance_rounded),
                ),
                title: const Text('Main facility costs'),
                subtitle: const Text(
                  'Installment, extra payment and maintenance',
                ),
                trailing: const Icon(Icons.edit_rounded),
                onTap: () => showEditCostsDialog(context, facility),
              ),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  child: Icon(Icons.local_fire_department_rounded),
                ),
                title: const Text('Fire Insurance'),
                subtitle: Text(
                  '${insuranceFrequencyText(facility.insuranceFrequency)} • ${moneyExact(facility.insuranceFee)} • starts ${FinancialChartPainter.monthNames[facility.insuranceDueMonth - 1]}',
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => showRecurringCommitmentsSettingsDialog(
                  context,
                  initialFacility: facility,
                ),
              ),
              if (facility.extraCommitments.isEmpty)
                const ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('No additional recurring commitments'),
                )
              else
                ...facility.extraCommitments.map(
                  (commitment) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      child: Icon(Icons.receipt_long_rounded),
                    ),
                    title: Text(commitment.name),
                    subtitle: Text(
                      '${commitmentFrequencyText(commitment.frequency)} • ${moneyExact(commitment.amount)}',
                    ),
                    trailing: const Icon(Icons.edit_rounded),
                    onTap: () =>
                        showEditRecurringCommitmentDialog(context, commitment),
                  ),
                ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => showAddExpenseDialog(context, facility),
                    icon: const Icon(Icons.add_card_rounded),
                    label: const Text('Add One-off Expense'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () =>
                        showAddRecurringCommitmentDialog(context, facility),
                    icon: const Icon(Icons.repeat_rounded),
                    label: const Text('Add Recurring Expense'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

void showFacilityConfigurationDialog(BuildContext context) {
  final store = RentalStoreScope.of(context);
  final facilities = store.ownerFacilities;
  if (facilities.isEmpty) return;
  var facility = facilities.first;

  showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.apartment_rounded),
            SizedBox(width: 10),
            Text('Facility Configuration'),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<Facility>(
                  value: facility,
                  decoration: const InputDecoration(
                    labelText: 'Facility',
                    border: OutlineInputBorder(),
                  ),
                  items: facilities
                      .map(
                        (item) => DropdownMenuItem(
                          value: item,
                          child: Text(item.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => facility = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                ProfileInfoRow(label: 'Address', value: facility.address),
                ProfileInfoRow(
                  label: 'Status',
                  value: facilityStatusText(facility),
                ),
                const Divider(height: 24),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.payments_rounded),
                  title: Text(tr(context, 'Facility Costs')),
                  subtitle: const Text(
                      'Edit installment, extra payment and maintenance.'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => showEditCostsDialog(context, facility),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.history_rounded),
                  title: Text(tr(context, 'Cost Change History')),
                  subtitle: Text(
                    '${facility.costHistory.length} configuration record(s)',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.pop(dialogContext);
                    showFacilityCostHistoryDialog(context, facility);
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.receipt_long_rounded),
                  title: const Text('Recurring Commitments'),
                  subtitle: const Text(
                      'Add or edit scheduled commitments, including fire insurance.'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => showRecurringCommitmentsSettingsDialog(
                    context,
                    initialFacility: facility,
                  ),
                ),
                if (facility.status == FacilityStatus.active)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.sell_rounded,
                      color: Color(0xFFD16432),
                    ),
                    title: const Text('Mark Facility as Sold'),
                    subtitle: const Text(
                      'Stops active tenancy tracking but keeps the records.',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      Navigator.pop(dialogContext);
                      showMarkSoldDialog(context, facility);
                    },
                  ),
                if (facility.status == FacilityStatus.sold)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.delete_forever_rounded,
                      color: Color(0xFFC43D4B),
                    ),
                    title: const Text('Remove Sold Facility'),
                    subtitle: const Text(
                      'Available only after the facility is marked sold.',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      Navigator.pop(dialogContext);
                      showRemoveFacilityDialog(context, facility);
                    },
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    ),
  );
}

List<String> facilityCostChanges(
  FacilityCostVersion? previous,
  FacilityCostVersion current,
) {
  if (previous == null) return ['Initial facility cost configuration'];
  final changes = <String>[];
  void addMoneyChange(String label, double before, double after) {
    if (before != after) {
      changes.add('$label: ${money(before)} → ${money(after)}');
    }
  }

  addMoneyChange(
      'Installment', previous.installmentAmount, current.installmentAmount);
  addMoneyChange('Extra payment', previous.extraInstallmentPayment,
      current.extraInstallmentPayment);
  addMoneyChange(
      'Maintenance', previous.maintenanceFee, current.maintenanceFee);
  addMoneyChange('Fire insurance', previous.insuranceFee, current.insuranceFee);
  if (previous.insuranceFrequency != current.insuranceFrequency) {
    changes.add(
      'Insurance frequency: ${insuranceFrequencyText(previous.insuranceFrequency)} → ${insuranceFrequencyText(current.insuranceFrequency)}',
    );
  }
  if (previous.insuranceDueMonth != current.insuranceDueMonth) {
    changes.add(
      'Insurance month: ${FinancialChartPainter.monthNames[previous.insuranceDueMonth - 1]} → ${FinancialChartPainter.monthNames[current.insuranceDueMonth - 1]}',
    );
  }
  return changes.isEmpty
      ? ['Configuration saved with no value changes']
      : changes;
}

void showFacilityCostHistoryDialog(BuildContext context, Facility facility) {
  final versions = [...facility.costHistory]
    ..sort((a, b) => a.effectiveMonth.compareTo(b.effectiveMonth));
  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.history_rounded),
          const SizedBox(width: 10),
          Expanded(child: Text('${facility.name} • Cost History')),
        ],
      ),
      content: SizedBox(
        width: 620,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: versions.length,
          itemBuilder: (context, index) {
            final version = versions[index];
            final previous = index == 0 ? null : versions[index - 1];
            final changes = facilityCostChanges(previous, version);
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            version.initial
                                ? 'Initial Configuration'
                                : 'Effective ${monthLabel(version.effectiveMonth)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        if (!version.initial)
                          const StatusChipText(label: 'Scheduled'),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      version.initial
                          ? 'Baseline record'
                          : 'Configured ${dateTimeLabel(version.recordedAt)}',
                      style: const TextStyle(color: Color(0xFF667085)),
                    ),
                    const Divider(height: 18),
                    ...changes.map(
                      (change) => Padding(
                        padding: const EdgeInsets.only(bottom: 5),
                        child: Text('• $change'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

void showMarkSoldDialog(BuildContext context, Facility facility) {
  final store = RentalStoreScope.of(context);
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
      title: Text('Mark ${facility.name} as sold?'),
      content: const Text(
        'This will keep the facility records but mark it inactive and stop active tenancy tracking. You can remove it only after it is marked sold.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: () {
            store.markFacilitySold(facility);
            Navigator.pop(context);
          },
          icon: const Icon(Icons.sell_rounded),
          label: const Text('Confirm Sold'),
        ),
      ],
    ),
  );
}

void showRemoveFacilityDialog(BuildContext context, Facility facility) {
  final store = RentalStoreScope.of(context);
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Remove ${facility.name}?'),
      content: const Text(
        'This facility is already marked sold. Removing it will delete the prototype records for its tenancies, bills, and requests. This is not a direct delete.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Keep'),
        ),
        FilledButton.icon(
          onPressed: () {
            store.removeSoldFacility(facility);
            Navigator.pop(context);
          },
          icon: const Icon(Icons.delete_forever_rounded),
          label: const Text('Remove'),
        ),
      ],
    ),
  );
}

void showPaymentReviewDialog(
  BuildContext context,
  MonthlyBill bill, {
  bool readOnly = false,
  DateTime? reviewedAt,
  String? reviewReason,
}) {
  final store = RentalStoreScope.of(context);
  final tenant = store.userFor(bill.tenantId);
  final facility = store.facilityFor(bill.facilityId);
  showDialog<void>(
    context: context,
    builder: (dialogContext) {
      final compact = MediaQuery.sizeOf(dialogContext).width < 600;
      return Dialog(
        insetPadding: compact
            ? EdgeInsets.zero
            : const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(compact ? 0 : 28),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 430,
            maxHeight: MediaQuery.sizeOf(dialogContext).height,
          ),
          child: Column(
            children: [
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 16, 4),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        icon: const Icon(Icons.chevron_left_rounded),
                      ),
                      Text(
                        readOnly ? 'Payment details' : 'Verify payment',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [oceanSky, oceanBlue, oceanDeep],
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${tenant.name} · ${facility.name} · ${monthLabel(bill.month)}',
                                    style: const TextStyle(
                                      color: Color(0xDDFFFFFF),
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                                _PaymentReviewPill(
                                  label: readOnly
                                      ? paymentStatusLabel(bill.status)
                                      : 'Awaiting review',
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            const Text(
                              'Amount claimed',
                              style: TextStyle(
                                color: Color(0xCCFFFFFF),
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              money(bill.amountPaid),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 34,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      const _ReviewSectionLabel('SUBMITTED PAY SLIP'),
                      const SizedBox(height: 7),
                      Material(
                        color: const Color(0xFFF4F9FF),
                        borderRadius: BorderRadius.circular(17),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(17),
                          onTap: () => showPaymentSlipAttachmentDialog(
                            dialogContext,
                            bill,
                          ),
                          child: Container(
                            height: 206,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(17),
                              border:
                                  Border.all(color: const Color(0xFFE4EEF8)),
                            ),
                            child: Column(
                              children: [
                                Expanded(
                                  child: Center(
                                    child: bill.slipBytes != null &&
                                            isImageFileName(bill.slipFileName)
                                        ? ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(13),
                                            child: Image.memory(
                                              bill.slipBytes!,
                                              height: 128,
                                              width: 190,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) =>
                                                  _PaymentSlipPlaceholder(
                                                fileName: bill.slipFileName,
                                              ),
                                            ),
                                          )
                                        : _PaymentSlipPlaceholder(
                                            fileName: bill.slipFileName,
                                          ),
                                  ),
                                ),
                                Row(
                                  children: [
                                    const Expanded(
                                      child: Text(
                                        'Tap the button to review full attachment',
                                        style: TextStyle(
                                          color: oceanMuted,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                    TextButton.icon(
                                      onPressed: () =>
                                          showPaymentSlipAttachmentDialog(
                                        dialogContext,
                                        bill,
                                      ),
                                      icon: const Icon(
                                        Icons.open_in_full_rounded,
                                        size: 16,
                                      ),
                                      label: const Text('Review'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const _ReviewSectionLabel('DETAILS FROM TENANT'),
                      const SizedBox(height: 7),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 15),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(17),
                        ),
                        child: Column(
                          children: [
                            _ReviewDetailRow(
                                'Amount paid', money(bill.amountPaid)),
                            _ReviewDetailRow(
                              'Date paid',
                              (bill.paymentDate ?? bill.submittedAt) == null
                                  ? 'Not recorded'
                                  : dateLabel(
                                      bill.paymentDate ?? bill.submittedAt!,
                                    ),
                            ),
                            const _ReviewDetailRow('Method', 'Bank transfer'),
                            _ReviewDetailRow(
                              'Reference',
                              (bill.paymentReference?.trim().isNotEmpty ??
                                      false)
                                  ? bill.paymentReference!.trim()
                                  : bill.id.toUpperCase(),
                            ),
                            _ReviewDetailRow(
                                'Status', paymentStatusLabel(bill.status)),
                            if (reviewedAt != null)
                              _ReviewDetailRow(
                                'Reviewed at',
                                dateTimeLabel(reviewedAt),
                              ),
                            if (reviewReason != null &&
                                reviewReason.trim().isNotEmpty)
                              _ReviewDetailRow('Review note', reviewReason),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                  child: readOnly
                      ? FilledButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          child: const Text('Close'),
                        )
                      : Row(
                          children: [
                            Expanded(
                              child: FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFFFEE2E2),
                                  foregroundColor: const Color(0xFFDC2626),
                                ),
                                onPressed: () async {
                                  const reason =
                                      'Slip amount or payment reference needs checking.';
                                  final confirmed =
                                      await showActionConfirmation(
                                    dialogContext,
                                    title: 'Reject this payment?',
                                    message:
                                        'Tenant: ${tenant.name}\nBill month: ${monthLabel(bill.month)}\nClaimed amount: ${money(bill.amountPaid)}\nReason: $reason\n\nThis will move the bill back to tenant action.',
                                    confirmLabel: 'Reject Payment',
                                  );
                                  if (!confirmed || !dialogContext.mounted) {
                                    return;
                                  }
                                  store.rejectBill(bill, reason);
                                  Navigator.pop(dialogContext);
                                },
                                child: const Text('Reject'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 2,
                              child: FilledButton.icon(
                                onPressed: () async {
                                  final confirmed =
                                      await showActionConfirmation(
                                    dialogContext,
                                    title: 'Confirm payment received?',
                                    message:
                                        'Tenant: ${tenant.name}\nBill month: ${monthLabel(bill.month)}\nAmount paid: ${money(bill.amountPaid)}\nFacility: ${facility.name}\n\nThis will approve the payment and update collection records.',
                                    confirmLabel: 'Approve Payment',
                                  );
                                  if (!confirmed || !dialogContext.mounted) {
                                    return;
                                  }
                                  store.approveBill(bill);
                                  Navigator.pop(dialogContext);
                                },
                                icon: const Icon(Icons.check_rounded),
                                label: const Text('Confirm received'),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _PaymentReviewPill extends StatelessWidget {
  const _PaymentReviewPill({this.label = 'Awaiting review'});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.24),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(label,
            style: const TextStyle(
                color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
      );
}

class _PaymentSlipPlaceholder extends StatelessWidget {
  const _PaymentSlipPlaceholder({required this.fileName});

  final String? fileName;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(13),
          boxShadow: [
            BoxShadow(
              color: oceanBlue.withOpacity(0.12),
              blurRadius: 18,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.receipt_long_rounded,
              color: oceanBlue,
              size: 31,
            ),
            const SizedBox(height: 6),
            Text(
              fileName ?? 'No attachment',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: oceanDeep,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
}

void showPaymentSlipAttachmentDialog(BuildContext context, MonthlyBill bill) {
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Payment slip attachment'),
      content: SizedBox(
        width: 540,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              bill.slipFileName ?? 'No attachment',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            if (bill.slipBytes != null) ...[
              const SizedBox(height: 4),
              Text(
                fileSizeLabel(bill.slipBytes!.lengthInBytes),
                style: const TextStyle(color: oceanMuted),
              ),
            ],
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Container(
                constraints: const BoxConstraints(maxHeight: 520),
                color: oceanCanvas,
                child:
                    bill.slipBytes != null && isImageFileName(bill.slipFileName)
                        ? Image.memory(
                            bill.slipBytes!,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Padding(
                              padding: EdgeInsets.all(36),
                              child: Text(
                                'The payslip image could not be opened.',
                                textAlign: TextAlign.center,
                              ),
                            ),
                          )
                        : Padding(
                            padding: const EdgeInsets.all(34),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  bill.slipFileName == null
                                      ? Icons.image_not_supported_rounded
                                      : Icons.picture_as_pdf_rounded,
                                  color: oceanBlue,
                                  size: 52,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  bill.slipFileName == null
                                      ? 'No payment slip was uploaded for this record.'
                                      : 'This slip is recorded as a file. Image preview is available for JPG, PNG and WebP uploads.',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: oceanMuted),
                                ),
                              ],
                            ),
                          ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

class _ReviewSectionLabel extends StatelessWidget {
  const _ReviewSectionLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          color: oceanMuted,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: .7,
        ),
      );
}

class _ReviewDetailRow extends StatelessWidget {
  const _ReviewDetailRow(this.label, this.value);
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Expanded(
                child: Text(label, style: const TextStyle(color: oceanMuted))),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
      );
}

void showUtilityDialog(BuildContext context, MonthlyBill bill) {
  final store = RentalStoreScope.of(context);
  final electricityUsage = TextEditingController(
    text: bill.electricityUsageKwh > 0
        ? bill.electricityUsageKwh.toStringAsFixed(2)
        : '',
  );
  final water =
      TextEditingController(text: bill.waterAmount.toStringAsFixed(0));
  final internet =
      TextEditingController(text: bill.internetAmount.toStringAsFixed(0));
  final generalElectric = TextEditingController(
      text: bill.generalElectricAmount.toStringAsFixed(0));
  final parkingRental =
      TextEditingController(text: bill.parkingRentalAmount.toStringAsFixed(0));
  var evidenceFileName = bill.utilityEvidenceFileName;
  var evidenceBytes = bill.utilityEvidenceBytes;
  var extractingReading = false;
  var readingDetected = evidenceFileName != null;
  String? readingError;
  DetectedMeterReading? detectedReading;
  double electricityAmount =
      store.calculateElectricityCharge(bill.electricityUsageKwh);
  double totalUtilities = electricityAmount +
      bill.generalElectricAmount +
      bill.waterAmount +
      bill.internetAmount +
      bill.parkingRentalAmount;

  showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) {
        void recalculate() {
          final usage = parseMoney(electricityUsage.text);
          electricityAmount = store.calculateElectricityCharge(usage);
          totalUtilities = electricityAmount +
              parseMoney(generalElectric.text) +
              parseMoney(water.text) +
              parseMoney(internet.text) +
              parseMoney(parkingRental.text);
          setDialogState(() {});
        }

        return AlertDialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          backgroundColor: const Color(0xFFF4F7FC),
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          titlePadding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 18),
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              Text(
                'Utilities for ${monthLabel(bill.month)}',
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          contentPadding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
          content: SizedBox(
            width: 380,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppTextField(
                    controller: electricityUsage,
                    label: 'Air-con Electricity Usage',
                    suffixText: 'kWh',
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (value) {
                      readingDetected = parseMoney(value) > 0;
                      readingError = null;
                      detectedReading = null;
                      recalculate();
                    },
                    helperText: extractingReading
                        ? 'Reading attachment with AI...'
                        : readingError ??
                            (detectedReading == null
                                ? 'Upload for automatic detection, then review or correct the usage before generating.'
                                : 'Detected automatically. Review and edit if needed${detectedReading!.previousReading == null || detectedReading!.currentReading == null ? '' : ': ${detectedReading!.previousReading!.toStringAsFixed(2)} → ${detectedReading!.currentReading!.toStringAsFixed(2)} kWh'}'),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: AppTextField(
                          controller: generalElectric,
                          label: 'General Electricity',
                          prefixText: 'RM ',
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          onChanged: (_) => recalculate(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: AppTextField(
                          controller: water,
                          label: 'Water Charge',
                          prefixText: 'RM ',
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          onChanged: (_) => recalculate(),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: AppTextField(
                          controller: internet,
                          label: 'Internet Charge',
                          prefixText: 'RM ',
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          onChanged: (_) => recalculate(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: AppTextField(
                          controller: parkingRental,
                          label: 'Parking Rental',
                          prefixText: 'RM ',
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          onChanged: (_) => recalculate(),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFD6DEEB)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.image_outlined),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Meter Reading Attachment',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                              Text(
                                evidenceFileName ?? 'No file uploaded',
                                style: const TextStyle(
                                  color: oceanMuted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        OutlinedButton(
                          key: const Key('upload_meter_reading_button'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(84, 44),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            side: const BorderSide(color: oceanDeep),
                          ),
                          onPressed: extractingReading
                              ? null
                              : () async {
                                  PickedImageData? file;
                                  try {
                                    file = await pickImageForUpload();
                                  } catch (error) {
                                    setDialogState(() {
                                      readingError =
                                          'Your browser could not open the photo picker. Allow photo/file access, then try again.';
                                    });
                                    return;
                                  }
                                  if (file == null) return;
                                  final selectedFile = file;
                                  final bytes = Uint8List.fromList(
                                    selectedFile.bytes,
                                  );
                                  setDialogState(() {
                                    evidenceFileName = selectedFile.name;
                                    evidenceBytes = bytes;
                                    extractingReading = true;
                                    readingDetected = false;
                                    readingError = null;
                                  });
                                  try {
                                    final reading = await LocalMeterOcr().read(
                                      bytes: bytes,
                                      fileName: selectedFile.name,
                                    );
                                    electricityUsage.text =
                                        reading.usageKwh.toStringAsFixed(2);
                                    detectedReading = reading;
                                    readingDetected = true;
                                    recalculate();
                                  } catch (error) {
                                    final raw = error
                                        .toString()
                                        .replaceFirst('Exception: ', '');
                                    readingError = raw;
                                    electricityUsage.clear();
                                    detectedReading = null;
                                    readingDetected = false;
                                  } finally {
                                    extractingReading = false;
                                    setDialogState(() {});
                                  }
                                },
                          child: extractingReading
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  evidenceFileName == null
                                      ? 'Upload'
                                      : 'Replace',
                                ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F8EF),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Charge Summary',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        AmountRow(
                            label: 'Air-con electricity',
                            value: electricityAmount),
                        AmountRow(
                          label: 'General electricity',
                          value: parseMoney(generalElectric.text),
                        ),
                        AmountRow(
                            label: 'Water', value: parseMoney(water.text)),
                        AmountRow(
                          label: 'Internet',
                          value: parseMoney(internet.text),
                        ),
                        AmountRow(
                          label: 'Parking rental',
                          value: parseMoney(parkingRental.text),
                        ),
                        const Divider(),
                        AmountRow(
                          label: 'Total Utilities',
                          value: totalUtilities,
                          bold: true,
                        ),
                        AmountRow(
                          label: 'Bill Total with Rent',
                          value: bill.rentAmount + totalUtilities,
                          bold: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          actionsAlignment: MainAxisAlignment.spaceBetween,
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: oceanMuted,
                minimumSize: const Size(105, 52),
              ),
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            SizedBox(
              width: 225,
              child: FilledButton.icon(
                key: const Key('save_utility_charges_button'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                onPressed: evidenceFileName == null ||
                        !readingDetected ||
                        extractingReading
                    ? null
                    : () {
                        store.updateBillUtilities(
                          bill,
                          electricityUsageKwh:
                              parseMoney(electricityUsage.text),
                          waterAmount: parseMoney(water.text),
                          internetAmount: parseMoney(internet.text),
                          generalElectricAmount:
                              parseMoney(generalElectric.text),
                          parkingRentalAmount: parseMoney(parkingRental.text),
                          utilityEvidenceFileName: evidenceFileName!,
                          utilityEvidenceBytes: evidenceBytes,
                        );
                        Navigator.pop(dialogContext);
                        Future<void>.delayed(Duration.zero, () {
                          if (context.mounted) {
                            showGeneratedInvoicePreview(context, bill);
                          }
                        });
                      },
                icon: const Icon(Icons.description_outlined, size: 19),
                label: const Text('Generate Bill'),
              ),
            ),
          ],
        );
      },
    ),
  );
}

RentalInvoice _rentalInvoiceFromBill(BuildContext context, MonthlyBill bill) {
  final store = RentalStoreScope.of(context);
  final tenancy = store.tenancies.firstWhere(
    (item) =>
        item.tenantId == bill.tenantId && item.facilityId == bill.facilityId,
  );
  final tenant = store.userFor(bill.tenantId);
  final facility = store.facilityFor(bill.facilityId);
  final usageMonth = DateTime(bill.month.year, bill.month.month - 1);
  final phone = tenant.phoneNumber.trim().isNotEmpty
      ? tenant.phoneNumber.trim()
      : '+60100000000';
  return RentalInvoice(
    id: 'INV-${bill.id.toUpperCase()}',
    tenant: TenantAccount(
      id: tenant.id,
      name: tenant.name,
      email: tenant.email,
      phone: phone,
      property: facility.name,
      unit: tenancy.unitName,
      rent: bill.rentAmount,
      water: bill.waterAmount,
      internet: bill.internetAmount,
    ),
    period: monthLabel(bill.month),
    usagePeriod: monthLabel(usageMonth),
    previousReading: 0,
    currentReading: bill.electricityUsageKwh,
    evidenceName: bill.utilityEvidenceFileName ?? 'No meter evidence',
    evidenceBytes: bill.utilityEvidenceBytes,
    generalElectricAmount: bill.generalElectricAmount,
    parkingRentalAmount: bill.parkingRentalAmount,
    electricityTariffName: store.electricityTariffName,
    electricityRatePerKwh: store.electricityRatePerKwh,
    electricityAmountOverride: bill.electricityAmount,
    electricityTariffSummary: store.electricityTariffSummary(),
    dueDate: DateTime(bill.month.year, bill.month.month, 6),
  );
}

Future<Uri> _publishInvoiceForTenant(RentalInvoice invoice) async {
  final pdfPath = 'invoices/${invoice.id}.pdf';
  final pdfBytes = await invoicePdf(invoice);
  final storage = Supabase.instance.client.storage.from(RentFlowStore.bucket);
  await storage.uploadBinary(
    pdfPath,
    pdfBytes,
    fileOptions: const FileOptions(
      upsert: true,
      contentType: 'application/pdf',
    ),
  );
  await Supabase.instance.client.from('rentflow_test_invoices').upsert({
    'id': invoice.id,
    'tenant_id': invoice.tenant.id,
    'tenant_name': invoice.tenant.name,
    'tenant_email': invoice.tenant.email,
    'tenant_phone': invoice.tenant.phone,
    'property_name': invoice.tenant.property,
    'unit_name': invoice.tenant.unit,
    'rent': invoice.tenant.rent,
    'water': invoice.tenant.water,
    'internet': invoice.tenant.internet,
    'period': invoice.period,
    'usage_period': invoice.usagePeriod,
    'previous_reading': invoice.previousReading,
    'current_reading': invoice.currentReading,
    'electricity_tariff_name': invoice.electricityTariffName,
    'electricity_rate_per_kwh': invoice.electricityRatePerKwh,
    'electricity_amount': invoice.electricity,
    'electricity_tariff_summary': invoice.electricityTariffSummary,
    'general_electric': invoice.generalElectricAmount,
    'parking_rental': invoice.parkingRentalAmount,
    'evidence_name': invoice.evidenceName,
    'pdf_path': pdfPath,
    'due_date': invoice.dueDate.toIso8601String(),
    'status': invoice.status.name,
  });
  return Uri.parse(storage.getPublicUrl(pdfPath));
}

Future<void> showGeneratedInvoicePreview(
  BuildContext context,
  MonthlyBill bill,
) async {
  final invoice = _rentalInvoiceFromBill(context, bill);
  final electricityTariff = invoice.electricityTariffName;
  final electricityRate = invoice.electricityRatePerKwh.toStringAsFixed(3);
  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      final compact = MediaQuery.sizeOf(dialogContext).width < 600;
      return Dialog(
        insetPadding: compact
            ? EdgeInsets.zero
            : const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(compact ? 0 : 28),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 460,
            maxHeight: MediaQuery.sizeOf(dialogContext).height,
          ),
          child: Column(
            children: [
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 16, 4),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        icon: const Icon(Icons.chevron_left_rounded),
                      ),
                      const Text('Invoice preview',
                          style: TextStyle(
                              fontSize: 19, fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(17),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [oceanSky, oceanBlue, oceanDeep],
                          ),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'INVOICE\n#${invoice.id}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                const _PaymentReviewPill(),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'Bill to: ${invoice.tenant.name} · ${invoice.tenant.unit}\nDue ${dateLabel(invoice.dueDate)}',
                              style: const TextStyle(
                                color: Color(0xDDFFFFFF),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      _InvoicePreviewCharge(
                        label: 'Monthly rent',
                        detail: invoice.period,
                        amount: invoice.tenant.rent,
                      ),
                      _InvoicePreviewCharge(
                        label: 'Water',
                        detail: invoice.tenant.water == 0
                            ? 'Included in rent'
                            : 'Monthly charge',
                        amount: invoice.tenant.water,
                      ),
                      _InvoicePreviewCharge(
                        label: 'Internet',
                        detail: invoice.tenant.internet == 0
                            ? 'Included in rent'
                            : 'Monthly charge',
                        amount: invoice.tenant.internet,
                      ),
                      _InvoicePreviewCharge(
                        label: 'General electricity',
                        detail: 'Monthly charge',
                        amount: invoice.generalElectricAmount,
                      ),
                      _InvoicePreviewCharge(
                        label: 'Air-con electricity',
                        detail:
                            '${invoice.usagePeriod}: ${invoice.usage.toStringAsFixed(2)} kWh x $electricityTariff RM $electricityRate',
                        amount: invoice.electricity,
                      ),
                      _InvoicePreviewCharge(
                        label: 'Parking rental',
                        detail: 'Monthly parking charge',
                        amount: invoice.parkingRentalAmount,
                      ),
                      const Divider(height: 22),
                      Row(
                        children: [
                          const Expanded(
                            child: Text('Total due',
                                style: TextStyle(fontWeight: FontWeight.w900)),
                          ),
                          Text(
                            rm(invoice.total),
                            style: const TextStyle(
                              color: oceanDeep,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF8EF),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.check_circle_outline_rounded,
                                color: Color(0xFF16A34A), size: 18),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Rent and utilities merged automatically from the saved reading.',
                                style: TextStyle(
                                    color: Color(0xFF15803D), fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: () =>
                            showInvoicePdfPreview(dialogContext, invoice),
                        icon: const Icon(Icons.picture_as_pdf_outlined),
                        label: const Text('Review generated invoice PDF'),
                      ),
                    ],
                  ),
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.pop(dialogContext);
                            Future<void>.delayed(Duration.zero, () {
                              if (context.mounted) {
                                showUtilityDialog(context, bill);
                              }
                            });
                          },
                          child: const Text('Edit'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: FilledButton.icon(
                          onPressed: () async {
                            final confirmed = await showActionConfirmation(
                              dialogContext,
                              title: 'Send invoice to tenant?',
                              message:
                                  '${invoice.tenant.name} will receive ${rm(invoice.total)} with a secure invoice link.',
                              confirmLabel: 'Send WhatsApp',
                            );
                            if (!confirmed || !dialogContext.mounted) return;
                            try {
                              final pdfLink =
                                  await _publishInvoiceForTenant(invoice);
                              final link = tenantInvoiceLink(invoice.id);
                              await shareWhatsApp(
                                invoice,
                                link,
                                pdfLink: pdfLink,
                              );
                            } catch (error) {
                              if (!dialogContext.mounted) return;
                              await showDialog<void>(
                                context: dialogContext,
                                builder: (errorContext) => AlertDialog(
                                  title: const Text(
                                    'Unable to open WhatsApp',
                                  ),
                                  content: Text(
                                    'The invoice could not be prepared or WhatsApp could not be opened. $error',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(errorContext),
                                      child: const Text('Close'),
                                    ),
                                  ],
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.send_rounded),
                          label: const Text('Send via WhatsApp'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _InvoicePreviewCharge extends StatelessWidget {
  const _InvoicePreviewCharge({
    required this.label,
    required this.detail,
    required this.amount,
  });
  final String label;
  final String detail;
  final double amount;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(detail,
                      style: const TextStyle(color: oceanMuted, fontSize: 10)),
                ],
              ),
            ),
            Text(rm(amount),
                style: const TextStyle(fontWeight: FontWeight.w900)),
          ],
        ),
      );
}

// Retained temporarily as a design reference for the Figma meter-pair concept.
// ignore: unused_element
void _showUtilityDialogFigma(BuildContext context, MonthlyBill bill) {
  final store = RentalStoreScope.of(context);
  const waterRate = 2.30;
  final tenancy = store.tenancies.firstWhere(
    (item) =>
        item.tenantId == bill.tenantId && item.facilityId == bill.facilityId,
  );
  final tenant = store.userFor(bill.tenantId);
  final facility = store.facilityFor(bill.facilityId);
  final electricityPrevious = TextEditingController(text: '8940');
  final electricityCurrent = TextEditingController(
    text: (8940 + bill.electricityUsageKwh).toStringAsFixed(0),
  );
  final waterPrevious = TextEditingController(text: '1204');
  final waterCurrent = TextEditingController(
    text: (1204 + (bill.waterAmount / waterRate)).toStringAsFixed(0),
  );
  var evidenceFileName = bill.utilityEvidenceFileName;

  showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) {
        final electricityUsage = math
            .max(
              0,
              parseMoney(electricityCurrent.text) -
                  parseMoney(electricityPrevious.text),
            )
            .toDouble();
        final waterUsage = math
            .max(
              0,
              parseMoney(waterCurrent.text) - parseMoney(waterPrevious.text),
            )
            .toDouble();
        final compact = MediaQuery.sizeOf(dialogContext).width < 600;
        return Dialog(
          insetPadding: compact
              ? EdgeInsets.zero
              : const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(compact ? 0 : 28),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 430,
              maxHeight: MediaQuery.sizeOf(dialogContext).height,
            ),
            child: Column(
              children: [
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 16, 4),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          icon: const Icon(Icons.chevron_left_rounded),
                        ),
                        const Text('New utility reading',
                            style: TextStyle(
                                fontSize: 19, fontWeight: FontWeight.w900)),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '${facility.name} · ${tenancy.unitName} · ${tenant.name} · ${monthLabel(bill.month)}',
                          style:
                              const TextStyle(color: oceanMuted, fontSize: 11),
                        ),
                        const SizedBox(height: 18),
                        const _ReviewSectionLabel('ATTACH METER PHOTO'),
                        const SizedBox(height: 7),
                        InkWell(
                          key: const Key('upload_meter_reading_button'),
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => setDialogState(() {
                            evidenceFileName =
                                'meter_${monthLabel(bill.month).replaceAll(' ', '_')}.jpg';
                          }),
                          child: Container(
                            padding: const EdgeInsets.all(15),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF6FBFF),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: const Color(0xFF90C2F0), width: 1.2),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                        colors: [oceanSky, oceanBlue]),
                                    borderRadius: BorderRadius.circular(13),
                                  ),
                                  child: const Icon(Icons.camera_alt_outlined,
                                      color: Colors.white),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        evidenceFileName ??
                                            'Attach meter reading photo',
                                        style: const TextStyle(
                                            color: oceanDeep,
                                            fontWeight: FontWeight.w800),
                                      ),
                                      Text(
                                        evidenceFileName == null
                                            ? 'Required before saving'
                                            : 'Attached · reading auto-detected',
                                        style: const TextStyle(
                                            color: oceanMuted, fontSize: 10),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        _MeterReadingCard(
                          label: 'WATER',
                          unit: 'm³',
                          previous: waterPrevious,
                          current: waterCurrent,
                          usage: waterUsage,
                          rate: waterRate,
                          onChanged: () => setDialogState(() {}),
                        ),
                        const SizedBox(height: 16),
                        _MeterReadingCard(
                          label: 'ELECTRICITY',
                          unit: 'kWh',
                          previous: electricityPrevious,
                          current: electricityCurrent,
                          usage: electricityUsage,
                          rate: store.electricityRatePerKwh,
                          onChanged: () => setDialogState(() {}),
                        ),
                      ],
                    ),
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        key: const Key('save_utility_charges_button'),
                        onPressed: evidenceFileName == null
                            ? null
                            : () {
                                store.updateBillUtilities(
                                  bill,
                                  electricityUsageKwh: electricityUsage,
                                  waterAmount: waterUsage * waterRate,
                                  internetAmount: bill.internetAmount,
                                  generalElectricAmount:
                                      bill.generalElectricAmount,
                                  parkingRentalAmount: bill.parkingRentalAmount,
                                  utilityEvidenceFileName: evidenceFileName!,
                                );
                                Navigator.pop(dialogContext);
                              },
                        icon: const Icon(Icons.check_rounded),
                        label: const Text('Save utility reading'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

class _MeterReadingCard extends StatelessWidget {
  const _MeterReadingCard({
    required this.label,
    required this.unit,
    required this.previous,
    required this.current,
    required this.usage,
    required this.rate,
    required this.onChanged,
  });

  final String label;
  final String unit;
  final TextEditingController previous;
  final TextEditingController current;
  final double usage;
  final double rate;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ReviewSectionLabel(label),
          const SizedBox(height: 7),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(17),
            ),
            child: Column(
              children: [
                _MeterInputRow(
                  label: 'Previous',
                  controller: previous,
                  unit: unit,
                  onChanged: onChanged,
                ),
                const Divider(height: 1),
                _MeterInputRow(
                  label: 'Current',
                  controller: current,
                  unit: unit,
                  emphasized: true,
                  onChanged: onChanged,
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  child: Row(
                    children: [
                      const Text('Usage',
                          style: TextStyle(color: oceanMuted, fontSize: 12)),
                      const Spacer(),
                      Text(
                        '${usage.toStringAsFixed(usage == usage.roundToDouble() ? 0 : 1)} $unit × RM ${rate.toStringAsFixed(rate < 1 ? 3 : 2)}',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      );
}

class _MeterInputRow extends StatelessWidget {
  const _MeterInputRow({
    required this.label,
    required this.controller,
    required this.unit,
    required this.onChanged,
    this.emphasized = false,
  });
  final String label;
  final TextEditingController controller;
  final String unit;
  final VoidCallback onChanged;
  final bool emphasized;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Text(label,
                style: const TextStyle(color: oceanMuted, fontSize: 12)),
            const Spacer(),
            SizedBox(
              width: 150,
              child: TextField(
                controller: controller,
                textAlign: TextAlign.right,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => onChanged(),
                decoration: InputDecoration(
                  isDense: true,
                  suffixText: unit,
                  filled: emphasized,
                  fillColor:
                      emphasized ? const Color(0xFFEFF6FF) : Colors.white,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: oceanBlue),
                  ),
                ),
                style: TextStyle(
                  color: emphasized ? oceanDeep : oceanText,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      );
}

void showUploadTenancyAgreementDialog(
  BuildContext context, {
  required AppUser tenant,
  required Tenancy tenancy,
}) {
  final store = RentalStoreScope.of(context);
  PickedImageData? selectedFile;
  showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        icon: const Icon(Icons.upload_file_rounded),
        title: Text(
          tenancy.agreementFileName == null
              ? 'Upload Tenancy Agreement'
              : 'Replace Tenancy Agreement',
        ),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Tenant: ${tenant.name}'),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: oceanCanvas,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFD7E1EF)),
                ),
                child: Row(
                  children: [
                    Icon(
                      selectedFile == null
                          ? Icons.description_outlined
                          : Icons.task_rounded,
                      color: oceanDeep,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Agreement file',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            selectedFile == null
                                ? (tenancy.agreementFileName == null
                                    ? 'No file selected'
                                    : 'Current: ${tenancy.agreementFileName}')
                                : '${selectedFile!.name} • ${fileSizeLabel(selectedFile!.bytes.length)}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: oceanMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  try {
                    final picked = await pickDocumentForUpload();
                    if (picked == null) return;
                    setDialogState(() => selectedFile = picked);
                  } catch (error) {
                    if (!dialogContext.mounted) return;
                    showValidationMessage(
                      dialogContext,
                      error.toString().replaceFirst('Bad state: ', ''),
                    );
                  }
                },
                icon: const Icon(Icons.folder_open_rounded),
                label:
                    Text(selectedFile == null ? 'Choose File' : 'Replace File'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: selectedFile == null
                ? null
                : () async {
                    final picked = selectedFile!;
                    final confirmed = await showActionConfirmation(
                      dialogContext,
                      title: tenancy.agreementFileName == null
                          ? 'Upload agreement?'
                          : 'Replace existing agreement?',
                      message:
                          'Confirm ${picked.name} as the tenancy agreement for ${tenant.name}.',
                      confirmLabel: tenancy.agreementFileName == null
                          ? 'Upload Agreement'
                          : 'Replace Agreement',
                    );
                    if (!confirmed || !dialogContext.mounted) return;
                    store.updateTenancyAgreement(tenancy, picked.name);
                    Navigator.pop(dialogContext);
                  },
            icon: const Icon(Icons.cloud_upload_rounded),
            label: const Text('Save Agreement'),
          ),
        ],
      ),
    ),
  );
}

void showReviewTenancyAgreementDialog(
  BuildContext context, {
  required AppUser tenant,
  required Tenancy tenancy,
  required Facility facility,
}) {
  final hasAgreement = tenancy.agreementFileName != null;
  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      icon: Icon(
        hasAgreement ? Icons.description_rounded : Icons.file_present_rounded,
      ),
      title: Text(hasAgreement ? 'Review Tenancy Agreement' : 'No Agreement'),
      content: SizedBox(
        width: 520,
        child: hasAgreement
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ProfileInfoRow(label: 'Tenant', value: tenant.name),
                  ProfileInfoRow(label: 'Facility', value: facility.name),
                  ProfileInfoRow(label: 'Unit', value: tenancy.unitName),
                  ProfileInfoRow(
                    label: 'Lease period',
                    value:
                        '${dateLabel(tenancy.leaseStart)} – ${dateLabel(tenancy.leaseEnd)}',
                  ),
                  ProfileInfoRow(
                    label: 'Agreement file',
                    value: tenancy.agreementFileName!,
                  ),
                  ProfileInfoRow(
                    label: 'Uploaded',
                    value: tenancy.agreementUploadedAt == null
                        ? 'Date unavailable'
                        : dateTimeLabel(tenancy.agreementUploadedAt!),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.tonalIcon(
                    onPressed: () {},
                    icon: const Icon(Icons.open_in_new_rounded),
                    label: const Text('Open Agreement File'),
                  ),
                ],
              )
            : const Text(
                'Upload the tenancy agreement first, then return here to review its contract details and file.',
              ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

void showEditTenantProfileDialog(
  BuildContext context,
  AppUser tenant,
  Tenancy tenancy,
) {
  final store = RentalStoreScope.of(context);
  final name = TextEditingController(text: tenant.name);
  final email = TextEditingController(text: tenant.email);
  final phoneNumber = TextEditingController(text: tenant.phoneNumber);
  final originAddressLine1 =
      TextEditingController(text: tenant.originAddress ?? '');
  final originAddressLine2 = TextEditingController();
  final dateOfBirth = TextEditingController(
    text: tenant.dateOfBirth == null ? '' : dateLabel(tenant.dateOfBirth!),
  );
  final sex = TextEditingController(text: tenant.sex ?? '');
  final unitName = TextEditingController(text: tenancy.unitName);
  final monthlyRent =
      TextEditingController(text: tenancy.monthlyRent.toStringAsFixed(2));
  final leaseStart = TextEditingController(text: dateLabel(tenancy.leaseStart));
  final leaseEnd = TextEditingController(text: dateLabel(tenancy.leaseEnd));
  final carParkDetails = TextEditingController(text: tenancy.carParkDetails);
  var status = tenant.accountStatus;
  var electricityIncluded =
      tenancy.electricityPackage == UtilityPackage.included;
  var waterIncluded = tenancy.waterPackage == UtilityPackage.included;
  var internetIncluded = tenancy.internetPackage == UtilityPackage.included;
  var carParkIncluded = tenancy.carParkIncluded;
  String? selectedOriginState;
  String? selectedOriginCity;
  String? selectedOriginPostcode;

  showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text('Edit Tenant Profile'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppTextField(controller: name, label: 'Full name'),
                AppTextField(controller: email, label: 'Email'),
                AppTextField(
                  controller: phoneNumber,
                  label: 'WhatsApp / Phone Number',
                  helperText: 'Use international format, e.g. +60165666878',
                  keyboardType: TextInputType.phone,
                ),
                AppTextField(
                  controller: originAddressLine1,
                  label: 'Origin address line 1 *',
                ),
                AppTextField(
                  controller: originAddressLine2,
                  label: 'Origin address line 2',
                ),
                MalaysiaAddressDropdowns(
                  state: selectedOriginState,
                  city: selectedOriginCity,
                  postcode: selectedOriginPostcode,
                  onStateChanged: (value) {
                    setDialogState(() {
                      selectedOriginState = value;
                      selectedOriginCity = null;
                      selectedOriginPostcode = null;
                    });
                  },
                  onCityChanged: (value) {
                    setDialogState(() {
                      selectedOriginCity = value;
                      selectedOriginPostcode = null;
                    });
                  },
                  onPostcodeChanged: (value) {
                    setDialogState(() => selectedOriginPostcode = value);
                  },
                ),
                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        controller: dateOfBirth,
                        label: 'Date of birth',
                        helperText: 'DD/MM/YYYY',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: AppTextField(controller: sex, label: 'Sex'),
                    ),
                  ],
                ),
                DropdownButtonFormField<String>(
                  value: status,
                  decoration: const InputDecoration(
                    labelText: 'Tenant status',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Active', child: Text('Active')),
                    DropdownMenuItem(
                      value: 'Pending verification',
                      child: Text('Pending verification'),
                    ),
                    DropdownMenuItem(
                      value: 'Inactive',
                      child: Text('Inactive'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) setDialogState(() => status = value);
                  },
                ),
                const Divider(height: 30),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Contract & Package',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                const SizedBox(height: 10),
                AppTextField(controller: unitName, label: 'Unit / Room'),
                AppTextField(
                  controller: monthlyRent,
                  label: 'Monthly rent',
                  prefixText: 'RM ',
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        controller: leaseStart,
                        label: 'Lease start',
                        helperText: 'DD/MM/YYYY',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: AppTextField(
                        controller: leaseEnd,
                        label: 'Lease end',
                        helperText: 'DD/MM/YYYY',
                      ),
                    ),
                  ],
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Electricity included'),
                  value: electricityIncluded,
                  onChanged: (value) =>
                      setDialogState(() => electricityIncluded = value),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Water included'),
                  value: waterIncluded,
                  onChanged: (value) =>
                      setDialogState(() => waterIncluded = value),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Internet included'),
                  value: internetIncluded,
                  onChanged: (value) =>
                      setDialogState(() => internetIncluded = value),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Car park included'),
                  value: carParkIncluded,
                  onChanged: (value) =>
                      setDialogState(() => carParkIncluded = value),
                ),
                if (carParkIncluded)
                  AppTextField(
                    controller: carParkDetails,
                    label: 'Car park details',
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () async {
              if (!isValidHumanName(name.text)) {
                showValidationMessage(
                  dialogContext,
                  'Full name must contain letters only, no numbers.',
                );
                return;
              }
              if (!isValidEmailInput(email.text)) {
                showValidationMessage(dialogContext, 'Enter a valid email.');
                return;
              }
              if (phoneNumber.text.trim().isNotEmpty &&
                  !isValidPhoneInput(phoneNumber.text)) {
                showValidationMessage(
                  dialogContext,
                  'Enter a valid WhatsApp / phone number.',
                );
                return;
              }
              if (originAddressLine1.text.trim().isEmpty ||
                  selectedOriginState == null ||
                  selectedOriginCity == null ||
                  selectedOriginPostcode == null) {
                showValidationMessage(
                  dialogContext,
                  'Origin address line 1, state, city and postcode are required.',
                );
                return;
              }
              if (!isValidMalaysiaLocation(
                state: selectedOriginState!,
                city: selectedOriginCity!,
                postcode: selectedOriginPostcode!,
              )) {
                showValidationMessage(
                  dialogContext,
                  'Origin postcode, city and state do not match.',
                );
                return;
              }
              final parsedDateOfBirth = dateOfBirth.text.trim().isEmpty
                  ? null
                  : parseDateInput(dateOfBirth.text);
              if (dateOfBirth.text.trim().isNotEmpty &&
                  parsedDateOfBirth == null) {
                showValidationMessage(
                  dialogContext,
                  'Date of birth must use DD/MM/YYYY.',
                );
                return;
              }
              if (!isValidMoneyInput(monthlyRent.text, allowZero: false)) {
                showValidationMessage(
                  dialogContext,
                  'Monthly rent must be a valid amount above RM 0.',
                );
                return;
              }
              final parsedLeaseStart = parseDateInput(leaseStart.text);
              final parsedLeaseEnd = parseDateInput(leaseEnd.text);
              if (parsedLeaseStart == null || parsedLeaseEnd == null) {
                showValidationMessage(
                  dialogContext,
                  'Lease start and lease end must use DD/MM/YYYY.',
                );
                return;
              }
              if (parsedLeaseEnd.isBefore(parsedLeaseStart)) {
                showValidationMessage(
                  dialogContext,
                  'Lease end cannot be before lease start.',
                );
                return;
              }
              final confirmed = await showActionConfirmation(
                dialogContext,
                title: 'Save tenant profile changes?',
                message:
                    'The updated details will apply to ${name.text.trim()}.',
                confirmLabel: 'Save Changes',
              );
              if (!confirmed || !dialogContext.mounted) return;
              store.updateTenantProfile(
                tenant,
                name: name.text,
                email: email.text,
                phoneNumber: phoneNumber.text,
                originAddress: combineAddress(
                  line1: originAddressLine1.text,
                  line2: originAddressLine2.text,
                  postcode: selectedOriginPostcode!,
                  city: selectedOriginCity!,
                  state: selectedOriginState!,
                ),
                dateOfBirth: parsedDateOfBirth,
                sex: sex.text,
                accountStatus: status,
              );
              store.updateTenantContract(
                tenancy,
                unitName: unitName.text,
                monthlyRent: parseMoney(monthlyRent.text),
                leaseStart: parsedLeaseStart,
                leaseEnd: parsedLeaseEnd,
                electricityPackage: electricityIncluded
                    ? UtilityPackage.included
                    : UtilityPackage.excluded,
                waterPackage: waterIncluded
                    ? UtilityPackage.included
                    : UtilityPackage.excluded,
                internetPackage: internetIncluded
                    ? UtilityPackage.included
                    : UtilityPackage.excluded,
                carParkIncluded: carParkIncluded,
                carParkDetails:
                    carParkIncluded ? carParkDetails.text : 'Not included',
              );
              Navigator.pop(dialogContext);
            },
            icon: const Icon(Icons.save_rounded),
            label: const Text('Save Changes'),
          ),
        ],
      ),
    ),
  );
}

void showTenantProfileDialog(
  BuildContext context, {
  required AppUser tenant,
  required Tenancy tenancy,
}) {
  final store = RentalStoreScope.of(context);
  final facility = store.facilityFor(tenancy.facilityId);
  final paymentHistory = store
      .billsForTenant(tenant.id)
      .where((bill) =>
          bill.status == PaymentStatus.pendingApproval ||
          bill.status == PaymentStatus.approved ||
          bill.status == PaymentStatus.rejected)
      .toList();

  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
      contentPadding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      title: Row(
        children: [
          const CircleAvatar(
            child: Icon(Icons.person_rounded),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(tenant.name)),
        ],
      ),
      content: SizedBox(
        width: 680,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Tenant Profile',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              ProfileInfoRow(label: 'Full name', value: tenant.name),
              ProfileInfoRow(label: 'Email', value: tenant.email),
              ProfileInfoRow(
                label: 'WhatsApp / Phone',
                value: tenant.phoneNumber.isEmpty
                    ? 'Not provided'
                    : tenant.phoneNumber,
              ),
              ProfileInfoRow(
                label: 'Origin address',
                value: tenant.originAddress ?? 'Not provided',
              ),
              ProfileInfoRow(
                label: 'Date of birth',
                value: tenant.dateOfBirth == null
                    ? 'Not provided'
                    : dateLabel(tenant.dateOfBirth!),
              ),
              ProfileInfoRow(label: 'Sex', value: tenant.sex ?? 'Not provided'),
              ProfileInfoRow(
                label: 'Status',
                value: tenantStatusText(tenant, tenancy),
              ),
              ProfileInfoRow(
                label: 'Profile setup',
                value: tenant.accountCreated
                    ? tenant.accountCreatedAt == null
                        ? 'Account active'
                        : 'Account created ${dateTimeLabel(tenant.accountCreatedAt!)}'
                    : tenant.invitationSent
                        ? 'Invitation sent; awaiting acceptance'
                        : 'Invitation not sent',
              ),
              Container(
                margin: const EdgeInsets.only(top: 8, bottom: 4),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F7FC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFD7E0EF)),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 500;
                    final details = Row(
                      children: [
                        const CircleAvatar(
                          child: Icon(Icons.description_rounded),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Tenancy agreement',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                              Text(
                                tenancy.agreementFileName ??
                                    'No agreement uploaded',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF667085),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                    final upload = OutlinedButton.icon(
                      onPressed: () => showUploadTenancyAgreementDialog(
                        context,
                        tenant: tenant,
                        tenancy: tenancy,
                      ),
                      icon: const Icon(Icons.upload_file_rounded),
                      label: Text(
                        tenancy.agreementFileName == null
                            ? 'Upload'
                            : 'Replace',
                      ),
                    );
                    final review = FilledButton.tonalIcon(
                      onPressed: () => showReviewTenancyAgreementDialog(
                        context,
                        tenant: tenant,
                        tenancy: tenancy,
                        facility: facility,
                      ),
                      icon: const Icon(Icons.visibility_rounded),
                      label: const Text('Review'),
                    );
                    if (!compact) {
                      return Row(
                        children: [
                          Expanded(child: details),
                          upload,
                          const SizedBox(width: 8),
                          review,
                        ],
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        details,
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(child: upload),
                            const SizedBox(width: 8),
                            Expanded(child: review),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
              if (!tenant.accountCreated)
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: () => showSendInvitationDialog(context, tenant),
                    icon: const Icon(Icons.mark_email_unread_rounded),
                    label: Text(
                      tenant.invitationSent
                          ? 'Resend Profile Invitation'
                          : 'Send Profile Invitation',
                    ),
                  ),
                ),
              const Divider(height: 28),
              Text(
                'Contract & Package',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              ProfileInfoRow(label: 'Facility', value: facility.name),
              ProfileInfoRow(label: 'Unit', value: tenancy.unitName),
              ProfileInfoRow(
                label: 'Monthly rent',
                value: money(tenancy.monthlyRent),
              ),
              ProfileInfoRow(
                label: 'Lease period',
                value:
                    '${dateLabel(tenancy.leaseStart)} – ${dateLabel(tenancy.leaseEnd)}',
              ),
              ProfileInfoRow(
                label: 'Electricity',
                value: packageText(tenancy.electricityPackage),
              ),
              ProfileInfoRow(
                label: 'Water',
                value: packageText(tenancy.waterPackage),
              ),
              ProfileInfoRow(
                label: 'Internet',
                value: packageText(tenancy.internetPackage),
              ),
              ProfileInfoRow(
                label: 'Car park',
                value: tenancy.carParkIncluded
                    ? tenancy.carParkDetails
                    : 'Not included in agreement',
              ),
              const Divider(height: 28),
              Text(
                'Payment History',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              if (paymentHistory.isEmpty)
                const Text('No payment records yet.')
              else
                ...paymentHistory.map(
                  (bill) => Card(
                    color: const Color(0xFFF8FAFD),
                    child: ListTile(
                      onTap: () => showPaymentReviewDialog(
                        context,
                        bill,
                        readOnly: true,
                        reviewedAt: bill.reviewedAt,
                        reviewReason: bill.rejectReason,
                      ),
                      leading: const Icon(Icons.receipt_long_rounded),
                      title: Text(
                        '${monthLabel(bill.month)} • ${money(bill.totalAmount)}',
                      ),
                      subtitle: Text(
                        bill.submittedAt == null
                            ? 'No submission date'
                            : 'Submitted ${dateTimeLabel(bill.submittedAt!)}',
                      ),
                      trailing: StatusChip(status: bill.status),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        OutlinedButton.icon(
          onPressed: () =>
              showEditTenantProfileDialog(context, tenant, tenancy),
          icon: const Icon(Icons.edit_rounded),
          label: const Text('Edit Profile'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

void showSubmitSlipDialog(BuildContext context, MonthlyBill bill) {
  final store = RentalStoreScope.of(context);
  final fileName = TextEditingController(
      text: 'payment_slip_${monthLabel(bill.month).replaceAll(' ', '_')}.jpg');
  final amount =
      TextEditingController(text: bill.totalAmount.toStringAsFixed(0));
  PickedImageData? proof;

  showDialog<void>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text('Submit Payment Slip'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppTextField(controller: fileName, label: 'Slip File Name'),
            AppTextField(controller: amount, label: 'Amount Paid'),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: oceanCanvas,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFD7E1EF)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.upload_file_rounded, color: oceanDeep),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      proof == null
                          ? 'Attach JPG, PNG or PDF payment proof'
                          : '${proof!.name} • ${fileSizeLabel(proof!.bytes.length)}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  OutlinedButton(
                    onPressed: () async {
                      try {
                        final picked = await pickPaymentProof();
                        if (picked == null) return;
                        final normalized = isImageFileName(picked.name)
                            ? compressRequestPicture(picked)
                            : picked;
                        fileName.text = normalized.name;
                        setDialogState(() => proof = normalized);
                      } catch (error) {
                        if (!context.mounted) return;
                        showValidationMessage(
                          context,
                          error.toString().replaceFirst('Bad state: ', ''),
                        );
                      }
                    },
                    child: Text(proof == null ? 'Upload' : 'Replace'),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (fileName.text.trim().isEmpty) {
                showValidationMessage(context, 'Slip file name is required.');
                return;
              }
              if (!isValidMoneyInput(amount.text, allowZero: false)) {
                showValidationMessage(
                  context,
                  'Amount paid must be a valid amount above RM 0.',
                );
                return;
              }
              final confirmed = await showActionConfirmation(
                context,
                title: 'Submit payment slip?',
                message:
                    'Confirm the payment amount and attachment before sending.',
                confirmLabel: 'Submit Payment',
              );
              if (!confirmed || !context.mounted) return;
              store.submitPaymentSlip(
                bill,
                fileName.text,
                parseMoney(amount.text),
                slipBytes:
                    proof == null ? null : Uint8List.fromList(proof!.bytes),
              );
              Navigator.pop(context);
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    ),
  );
}

void showTenantRequestAttachmentDialog(
  BuildContext context,
  TenantRequest request,
  String tenantName,
) {
  final imageData = request.attachmentBase64;
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Tenant picture'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${request.title} • $tenantName',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              [
                request.attachmentFileName ?? 'Attached picture',
                if (request.attachmentSizeBytes != null)
                  fileSizeLabel(request.attachmentSizeBytes!),
              ].join(' • '),
              style: const TextStyle(color: oceanMuted),
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Container(
                constraints: const BoxConstraints(maxHeight: 420),
                color: oceanCanvas,
                child: imageData == null || imageData.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(36),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.image_not_supported_rounded,
                              size: 54,
                              color: oceanMuted,
                            ),
                            SizedBox(height: 12),
                            Text(
                              'Picture file name is recorded, but no preview data is available.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: oceanMuted),
                            ),
                          ],
                        ),
                      )
                    : Image.memory(
                        base64Decode(imageData),
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Padding(
                          padding: EdgeInsets.all(36),
                          child: Text(
                            'The picture preview could not be opened.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

void showAddRequestDialog(BuildContext context) {
  final store = RentalStoreScope.of(context);
  const requestTypes = [
    'Repair & Maintenance',
    'Extend Tenancy',
    'Early Move-out',
    'Agreement / Document',
    'Utility / Billing',
    'Access Card / Key',
    'Parking',
    'Neighbor / Noise',
    'General Enquiry',
  ];
  var requestType = requestTypes.first;
  final title = TextEditingController();
  final message = TextEditingController();
  PickedImageData? attachment;

  showDialog<void>(
    context: context,
    builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
              title: const Text('Create New Request'),
              content: SizedBox(
                width: 580,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<String>(
                      value: requestType,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Request Type',
                      ),
                      items: requestTypes
                          .map((item) =>
                              DropdownMenuItem(value: item, child: Text(item)))
                          .toList(),
                      onChanged: (value) => setDialogState(
                        () => requestType = value ?? requestType,
                      ),
                    ),
                    const SizedBox(height: 12),
                    AppTextField(controller: title, label: 'Request Title'),
                    TextField(
                      controller: message,
                      minLines: 5,
                      maxLines: 8,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Describe what you need',
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: oceanCanvas,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFD7E1EF)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            attachment == null
                                ? Icons.add_photo_alternate_outlined
                                : Icons.image_rounded,
                            color: oceanDeep,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Request picture',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  attachment == null
                                      ? 'Optional • maximum 1 picture • compressed below 2 MB'
                                      : '${attachment!.name} • ${fileSizeLabel(attachment!.bytes.length)}',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: oceanMuted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton(
                            onPressed: () async {
                              try {
                                final picked = await pickImageForUpload();
                                if (picked == null) return;
                                final compressed =
                                    compressRequestPicture(picked);
                                setDialogState(() => attachment = compressed);
                                if (!context.mounted) return;
                                final wasCompressed = compressed.bytes.length <
                                    picked.bytes.length;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      wasCompressed
                                          ? 'Picture compressed to ${fileSizeLabel(compressed.bytes.length)}.'
                                          : 'Picture attached (${fileSizeLabel(compressed.bytes.length)}).',
                                    ),
                                  ),
                                );
                              } catch (error) {
                                if (!context.mounted) return;
                                showValidationMessage(
                                  context,
                                  error.toString().replaceFirst(
                                        'Bad state: ',
                                        '',
                                      ),
                                );
                              }
                            },
                            child: Text(
                              attachment == null ? 'Upload' : 'Replace',
                            ),
                          ),
                          if (attachment != null)
                            IconButton(
                              tooltip: 'Remove picture',
                              onPressed: () =>
                                  setDialogState(() => attachment = null),
                              icon: const Icon(Icons.close_rounded),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    if (title.text.trim().isEmpty) {
                      showValidationMessage(
                        context,
                        'Request title is required.',
                      );
                      return;
                    }
                    if (message.text.trim().isEmpty) {
                      showValidationMessage(
                        context,
                        'Please describe what you need.',
                      );
                      return;
                    }
                    final confirmed = await showActionConfirmation(
                      context,
                      title: 'Send this request?',
                      message:
                          'The owner will receive your $requestType request.',
                      confirmLabel: 'Send Request',
                    );
                    if (!confirmed || !context.mounted) return;
                    store.addTenantRequest(
                      requestType: requestType,
                      title: title.text,
                      message: message.text,
                      attachmentFileName: attachment?.name,
                      attachmentBase64: attachment == null
                          ? null
                          : base64Encode(attachment!.bytes),
                      attachmentSizeBytes: attachment?.bytes.length,
                    );
                    Navigator.pop(context);
                  },
                  child: const Text('Submit'),
                ),
              ],
            )),
  );
}

void showAvatarPickerDialog(BuildContext context) {
  final store = RentalStoreScope.of(context);
  final user = store.currentUser!;
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Choose Profile Picture'),
      content: Wrap(
        spacing: 14,
        runSpacing: 14,
        children: List.generate(6, (index) {
          return InkWell(
            onTap: () async {
              final confirmed = await showActionConfirmation(
                context,
                title: 'Change profile picture?',
                message: 'Use this avatar for your account profile.',
                confirmLabel: 'Change Avatar',
              );
              if (!confirmed || !context.mounted) return;
              store.updateAvatar(index);
              Navigator.pop(context);
            },
            borderRadius: BorderRadius.circular(40),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: user.avatarStyle == index
                      ? Theme.of(context).colorScheme.primary
                      : Colors.transparent,
                  width: 3,
                ),
              ),
              child: ProfileAvatar(
                user: user,
                radius: 30,
                overrideStyle: index,
              ),
            ),
          );
        }),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    ),
  );
}

class _EditableElectricityTariffTier {
  _EditableElectricityTariffTier(ElectricityTariffTier tier)
      : from = TextEditingController(text: tier.fromKwh.toStringAsFixed(0)),
        to = TextEditingController(
          text: tier.toKwh == null ? '' : tier.toKwh!.toStringAsFixed(0),
        ),
        rate = TextEditingController(text: tier.ratePerKwh.toStringAsFixed(3));

  final TextEditingController from;
  final TextEditingController to;
  final TextEditingController rate;

  void dispose() {
    from.dispose();
    to.dispose();
    rate.dispose();
  }
}

void showBillingConfigurationDialog(BuildContext context) {
  final store = RentalStoreScope.of(context);
  final rows = (store.electricityTariffTiers.isEmpty
          ? RentalStore.defaultElectricityTariffTiers
          : store.electricityTariffTiers)
      .map(_EditableElectricityTariffTier.new)
      .toList();
  String? errorText;
  var acknowledgedLegalNotice = false;

  showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text('Billing configuration'),
        content: SizedBox(
          width: 620,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Set the electricity tariff tiers used for utility billing and generated invoices.',
                  style: TextStyle(color: oceanMuted),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Tariff slabs',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                      ),
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Add tier'),
                      onPressed: () {
                        setDialogState(() {
                          final previousTo = rows.isEmpty
                              ? null
                              : double.tryParse(rows.last.to.text.trim());
                          final nextFrom = previousTo == null
                              ? 0.0
                              : (previousTo + 1).roundToDouble();
                          rows.add(
                            _EditableElectricityTariffTier(
                              ElectricityTariffTier(
                                fromKwh: nextFrom,
                                toKwh: null,
                                ratePerKwh:
                                    RentalStore.defaultElectricityRatePerKwh,
                              ),
                            ),
                          );
                          errorText = null;
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                for (var index = 0; index < rows.length; index++) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFD8E2F1)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: oceanSoft,
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(
                                  color: oceanBlue,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Tier ${index + 1}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Remove tier',
                              onPressed: rows.length == 1
                                  ? null
                                  : () {
                                      setDialogState(() {
                                        rows.removeAt(index).dispose();
                                        errorText = null;
                                      });
                                    },
                              icon: const Icon(Icons.delete_outline_rounded),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: rows[index].from,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                decoration: const InputDecoration(
                                  labelText: 'From kWh',
                                  hintText: '0',
                                  suffixText: 'kWh',
                                ),
                                onChanged: (_) =>
                                    setDialogState(() => errorText = null),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: rows[index].to,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                decoration: const InputDecoration(
                                  labelText: 'To kWh',
                                  hintText: 'Blank = beyond',
                                  suffixText: 'kWh',
                                ),
                                onChanged: (_) =>
                                    setDialogState(() => errorText = null),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: rows[index].rate,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Rate per kWh',
                            prefixText: 'RM ',
                            hintText: '0.516',
                          ),
                          onChanged: (_) =>
                              setDialogState(() => errorText = null),
                        ),
                      ],
                    ),
                  ),
                ],
                if (errorText != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    errorText!,
                    style: const TextStyle(
                      color: Color(0xFFDC2626),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: const Text(
                    'Example: 0 to 100 kWh can be RM 0.516, 101 to 200 can use another rate, and a blank To kWh means 201 and beyond.',
                    style: TextStyle(
                      color: Color(0xFF3156A3),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  value: acknowledgedLegalNotice,
                  onChanged: (value) => setDialogState(() {
                    acknowledgedLegalNotice = value ?? false;
                    errorText = null;
                  }),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'I acknowledge this electricity rate has been agreed with the tenant.',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: const Text(
                    'Owner must ensure the billing rate complies with local government law and tenancy agreement. Reselling electricity may be illegal or regulated in some countries.',
                    style: TextStyle(color: oceanMuted),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.save_outlined, size: 18),
            label: const Text('Save tariff'),
            onPressed: () async {
              final parsed = <ElectricityTariffTier>[];
              for (final row in rows) {
                final from = double.tryParse(row.from.text.trim());
                final toText = row.to.text.trim();
                final to = toText.isEmpty ? null : double.tryParse(toText);
                final rate = double.tryParse(row.rate.text.trim());
                if (from == null ||
                    from < 0 ||
                    (toText.isNotEmpty && to == null) ||
                    (to != null && to < from) ||
                    rate == null ||
                    rate <= 0) {
                  parsed.clear();
                  break;
                }
                parsed.add(ElectricityTariffTier(
                  fromKwh: from,
                  toKwh: to,
                  ratePerKwh: rate,
                ));
              }
              parsed.sort((a, b) => a.fromKwh.compareTo(b.fromKwh));
              final hasOpenEnded =
                  parsed.isNotEmpty && parsed.last.toKwh == null;
              final startsAtZero =
                  parsed.isNotEmpty && parsed.first.fromKwh == 0;
              final hasInvalidOrder = parsed.indexed.any((entry) {
                final index = entry.$1;
                if (index == 0) return false;
                final previous = parsed[index - 1];
                final current = entry.$2;
                return previous.toKwh == null ||
                    current.fromKwh != previous.toKwh! + 1;
              });
              if (parsed.isEmpty ||
                  !startsAtZero ||
                  !hasOpenEnded ||
                  hasInvalidOrder) {
                setDialogState(
                  () => errorText =
                      'Tariff must start from 0 kWh, continue without gaps, and leave the final To kWh blank for beyond.',
                );
                return;
              }
              if (!acknowledgedLegalNotice) {
                setDialogState(
                  () => errorText =
                      'Please tick the acknowledgement before saving this tariff.',
                );
                return;
              }
              final confirmed = await showActionConfirmation(
                context,
                title: 'Update electricity tariff?',
                message:
                    'Future electric billing will use ${parsed.length} tariff tier(s).',
                confirmLabel: 'Update',
              );
              if (!confirmed) return;
              store.updateElectricityTariffTiers(parsed);
              if (dialogContext.mounted) Navigator.pop(dialogContext);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Electricity tariff tiers updated.'),
                  ),
                );
              }
            },
          ),
        ],
      ),
    ),
  );
}

void showOwnerAccountSetupDialog(BuildContext context) {
  final store = RentalStoreScope.of(context);
  final user = store.currentUser!;
  final name = TextEditingController(text: user.name);
  final email = TextEditingController(text: user.email);
  final phone = TextEditingController(text: user.phoneNumber);
  final businessName = TextEditingController(text: 'Platinum Victory');
  final businessAddress = TextEditingController(text: user.originAddress ?? '');
  final currentPassword = TextEditingController();
  final newPassword = TextEditingController();
  final confirmPassword = TextEditingController();
  var avatarStyle = user.avatarStyle;
  var changePassword = false;
  var obscurePasswords = true;

  showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text('Owner Account Setup'),
        content: SizedBox(
          width: 620,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [oceanSky, oceanBlue, oceanDeep],
                    ),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      ProfileAvatar(
                        user: user,
                        radius: 34,
                        overrideStyle: avatarStyle,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Owner workspace',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${store.ownerFacilities.length} properties • ${store.tenancies.where((item) => item.active).length} active tenants',
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Profile picture',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: List.generate(6, (index) {
                    return InkWell(
                      onTap: () => setDialogState(() => avatarStyle = index),
                      borderRadius: BorderRadius.circular(40),
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: avatarStyle == index
                                ? Theme.of(context).colorScheme.primary
                                : Colors.transparent,
                            width: 3,
                          ),
                        ),
                        child: ProfileAvatar(
                          user: user,
                          radius: 24,
                          overrideStyle: index,
                        ),
                      ),
                    );
                  }),
                ),
                const Divider(height: 28),
                Text(
                  'Owner details',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 10),
                AppTextField(
                  controller: name,
                  label: 'Full Name',
                ),
                AppTextField(
                  controller: email,
                  label: 'Email',
                ),
                AppTextField(
                  controller: phone,
                  label: 'WhatsApp / Phone Number',
                ),
                const Divider(height: 28),
                Text(
                  'Business / invoice identity',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 10),
                AppTextField(
                  controller: businessName,
                  label: 'Business Name',
                ),
                AppTextField(
                  controller: businessAddress,
                  label: 'Business Address',
                ),
                const Divider(height: 28),
                Text(
                  'Security',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Change password'),
                  subtitle:
                      const Text('Update the password used on this device.'),
                  value: changePassword,
                  onChanged: (value) => setDialogState(() {
                    changePassword = value;
                    if (!value) {
                      currentPassword.clear();
                      newPassword.clear();
                      confirmPassword.clear();
                    }
                  }),
                ),
                if (changePassword) ...[
                  const SizedBox(height: 6),
                  TextField(
                    controller: currentPassword,
                    obscureText: obscurePasswords,
                    decoration: InputDecoration(
                      labelText: 'Current password',
                      suffixIcon: IconButton(
                        onPressed: () => setDialogState(
                          () => obscurePasswords = !obscurePasswords,
                        ),
                        icon: Icon(
                          obscurePasswords
                              ? Icons.visibility_rounded
                              : Icons.visibility_off_rounded,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final twoColumns = constraints.maxWidth >= 520;
                      final newField = TextField(
                        controller: newPassword,
                        obscureText: obscurePasswords,
                        decoration: const InputDecoration(
                          labelText: 'New password',
                        ),
                      );
                      final confirmField = TextField(
                        controller: confirmPassword,
                        obscureText: obscurePasswords,
                        decoration: const InputDecoration(
                          labelText: 'Confirm new password',
                        ),
                      );
                      if (!twoColumns) {
                        return Column(
                          children: [
                            newField,
                            const SizedBox(height: 10),
                            confirmField,
                          ],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(child: newField),
                          const SizedBox(width: 10),
                          Expanded(child: confirmField),
                        ],
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () async {
              if (!isValidHumanName(name.text)) {
                showValidationMessage(
                  dialogContext,
                  'Owner name must contain letters only, no numbers.',
                );
                return;
              }
              if (!isValidEmailInput(email.text)) {
                showValidationMessage(dialogContext, 'Enter a valid email.');
                return;
              }
              if (phone.text.trim().isNotEmpty &&
                  !isValidPhoneInput(phone.text)) {
                showValidationMessage(
                  dialogContext,
                  'Enter a valid WhatsApp / phone number.',
                );
                return;
              }
              if (changePassword) {
                if (currentPassword.text.isEmpty) {
                  showValidationMessage(
                    dialogContext,
                    'Enter your current password.',
                  );
                  return;
                }
                if (newPassword.text.length < 8) {
                  showValidationMessage(
                    dialogContext,
                    'New password must be at least 8 characters.',
                  );
                  return;
                }
                if (newPassword.text != confirmPassword.text) {
                  showValidationMessage(
                    dialogContext,
                    'New password and confirmation do not match.',
                  );
                  return;
                }
              }
              final confirmed = await showActionConfirmation(
                dialogContext,
                title: 'Save owner account setup?',
                message:
                    'This updates your owner profile, contact details, avatar and reminder defaults.',
                confirmLabel: 'Save Setup',
              );
              if (!confirmed || !dialogContext.mounted) return;
              if (changePassword) {
                try {
                  store.changeLocalAccountPassword(
                    email: user.email,
                    role: user.role,
                    currentPassword: currentPassword.text,
                    newPassword: newPassword.text,
                  );
                } catch (error) {
                  if (!dialogContext.mounted) return;
                  showValidationMessage(
                    dialogContext,
                    error.toString().replaceFirst('Bad state: ', ''),
                  );
                  return;
                }
              }
              store.updateOwnerAccount(
                name: name.text,
                email: email.text,
                phoneNumber: phone.text,
                originAddress: businessAddress.text,
                avatarStyle: avatarStyle,
                paymentReminderAfterDays: user.paymentReminderAfterDays,
                paymentReminderFrequencyDays: user.paymentReminderFrequencyDays,
              );
              Navigator.pop(dialogContext);
            },
            icon: const Icon(Icons.save_rounded),
            label: const Text('Save Setup'),
          ),
        ],
      ),
    ),
  );
}

void showReminderSettingsDialog(BuildContext context) {
  final store = RentalStoreScope.of(context);
  final user = store.currentUser!;
  var afterDays = user.paymentReminderAfterDays;
  var frequencyDays = user.paymentReminderFrequencyDays;
  showDialog<void>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text('Payment Reminder Schedule'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('First reminder: $afterDays days after due date'),
              Slider(
                value: afterDays.toDouble(),
                min: 1,
                max: 14,
                divisions: 13,
                label: '$afterDays days',
                onChanged: (value) {
                  setDialogState(() => afterDays = value.round());
                },
              ),
              const SizedBox(height: 8),
              Text('Repeat reminder: every $frequencyDays days'),
              Slider(
                value: frequencyDays.toDouble(),
                min: 1,
                max: 14,
                divisions: 13,
                label: '$frequencyDays days',
                onChanged: (value) {
                  setDialogState(() => frequencyDays = value.round());
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final confirmed = await showActionConfirmation(
                context,
                title: 'Save reminder settings?',
                message:
                    'The first reminder will be sent after $afterDays days and repeat every $frequencyDays days.',
                confirmLabel: 'Save Settings',
              );
              if (!confirmed || !context.mounted) return;
              store.updateReminderSettings(
                afterDays: afterDays,
                frequencyDays: frequencyDays,
              );
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
}

void showAccountSettingsDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (_) => const _SettingsHubDialog(),
  );
}

Future<void> showDataExportDialog(BuildContext context) async {
  await Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const _DataBackupScreen()),
  );
}

Future<void> _prepareDataExport(BuildContext context, String format) async {
  final store = RentalStoreScope.of(context);
  final confirmed = await showActionConfirmation(
    context,
    title: 'Prepare $format export?',
    message: format == 'Share'
        ? 'A backup summary will be copied so you can paste it into WhatsApp, email, or Drive.'
        : 'A dated copy of the app records will be downloaded.',
    confirmLabel: 'Prepare Export',
  );
  if (!confirmed || !context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Preparing $format export...')),
  );
  final now = DateTime.now();
  final stamp =
      '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
  try {
    if (format == 'Excel Backup') {
      final fileName = 'rental_manager_backup_summary_$stamp.xlsx';
      await downloadBytesFile(
        fileName: fileName,
        mimeType:
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        bytes: store.exportBackupExcelWorkbookXlsx(),
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$fileName downloaded.')),
      );
      return;
    }
    if (format == 'Excel') {
      final fileName = 'rental_manager_detailed_export_$stamp.xlsx';
      await downloadBytesFile(
        fileName: fileName,
        mimeType:
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        bytes: store.exportDetailedExcelWorkbookXlsx(),
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$fileName downloaded.')),
      );
      return;
    }
    if (format == 'CSV') {
      final fileName = 'rental_manager_summary_$stamp.csv';
      await downloadTextFile(
        fileName: fileName,
        mimeType: 'text/csv;charset=utf-8',
        content: store.exportCsv(),
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$fileName downloaded.')),
      );
      return;
    }
    final backupJson =
        const JsonEncoder.withIndent('  ').convert(store.exportSnapshot());
    if (format == 'Share') {
      await Clipboard.setData(ClipboardData(text: backupJson));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Backup copied. Paste it where needed.')),
      );
      return;
    }
    final fileName = 'rental_manager_backup_$stamp.sqlite.json';
    await downloadTextFile(
      fileName: fileName,
      mimeType: 'application/json;charset=utf-8',
      content: backupJson,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$fileName downloaded.')),
    );
  } catch (error) {
    if (!context.mounted) return;
    showValidationMessage(
      context,
      error.toString().replaceFirst('Unsupported operation: ', ''),
    );
  }
}

class _DataBackupScreen extends StatefulWidget {
  const _DataBackupScreen();

  @override
  State<_DataBackupScreen> createState() => _DataBackupScreenState();
}

class _DataBackupScreenState extends State<_DataBackupScreen> {
  String location = 'internal';
  bool autoBackup = true;

  @override
  Widget build(BuildContext context) {
    final store = RentalStoreScope.of(context);
    final recordCount = store.facilities.length +
        store.tenancies.length +
        store.bills.length +
        store.tenantRequests.length;
    return Scaffold(
      appBar: AppBar(title: const Text('Data & backup')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 18),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [oceanSky, oceanBlue, oceanDeep],
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(.2),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: const Icon(Icons.storage_rounded,
                          color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Local database',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800)),
                          Text(
                            'rental_manager.db · $recordCount records',
                            style: const TextStyle(
                                color: Color(0xDDFFFFFF), fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF8EF),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: const Color(0xFFBCE8CA)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle_outline_rounded,
                        color: Color(0xFF16A34A), size: 18),
                    SizedBox(width: 8),
                    Text('Last backup: today 08:40 · internal storage',
                        style:
                            TextStyle(color: Color(0xFF15803D), fontSize: 11)),
                  ],
                ),
              ),
              const _BackupSectionLabel('EXPORT'),
              _BackupCard(
                children: [
                  _BackupAction(
                    icon: Icons.phone_iphone_rounded,
                    title: 'Export SQLite database',
                    subtitle: '.db file — full backup',
                    trailing: Icons.download_rounded,
                    onTap: () => _prepareDataExport(context, 'SQLite'),
                  ),
                  _BackupAction(
                    icon: Icons.grid_on_rounded,
                    title: 'Export Excel backup summary',
                    subtitle: '.xlsx workbook with previous backup columns',
                    trailing: Icons.download_rounded,
                    onTap: () => _prepareDataExport(context, 'Excel Backup'),
                  ),
                  _BackupAction(
                    icon: Icons.table_view_rounded,
                    title: 'Export detailed Excel workbook',
                    subtitle: '.xlsx: dashboard, tenants, bills, cashflow',
                    trailing: Icons.download_rounded,
                    onTap: () => _prepareDataExport(context, 'Excel'),
                  ),
                  _BackupAction(
                    icon: Icons.ios_share_rounded,
                    title: 'Share backup',
                    subtitle: 'WhatsApp, email, Drive',
                    onTap: () => _prepareDataExport(context, 'Share'),
                  ),
                ],
              ),
              const _BackupSectionLabel('BACKUP LOCATION'),
              _BackupCard(
                children: [
                  RadioListTile<String>(
                    value: 'internal',
                    groupValue: location,
                    onChanged: (value) => setState(() => location = value!),
                    title: const Text('Internal storage'),
                    secondary: const Icon(Icons.phone_iphone_rounded,
                        color: oceanBlue),
                  ),
                  RadioListTile<String>(
                    value: 'drive',
                    groupValue: location,
                    onChanged: (value) => setState(() => location = value!),
                    title: const Text('Google Drive'),
                    secondary:
                        const Icon(Icons.cloud_outlined, color: oceanMuted),
                  ),
                ],
              ),
              TextButton(
                onPressed: () {},
                child: const Text('Restore from file...'),
              ),
              _BackupCard(
                children: [
                  SwitchListTile(
                    value: autoBackup,
                    onChanged: (value) => setState(() => autoBackup = value),
                    title: const Text('Auto-backup daily'),
                    subtitle: const Text('02:00 · to selected location'),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [oceanSky, oceanBlue, oceanDeep]),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                  ),
                  onPressed: () => _prepareDataExport(context, 'SQLite'),
                  child: const Text('Back up now'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BackupSectionLabel extends StatelessWidget {
  const _BackupSectionLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 18, 2, 7),
        child: Text(text,
            style: const TextStyle(
                color: oceanMuted,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: .7)),
      );
}

class _BackupCard extends StatelessWidget {
  const _BackupCard({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(17)),
        child: Column(children: children),
      );
}

class _BackupAction extends StatelessWidget {
  const _BackupAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing = Icons.chevron_right_rounded,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final IconData trailing;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ListTile(
        leading: Icon(icon, color: oceanBlue),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: IconButton(
          tooltip: title,
          icon: Icon(trailing, color: oceanBlue, size: 18),
          onPressed: onTap,
        ),
        onTap: onTap,
      );
}

enum _SettingsSection { overview, reminders, facilities, income, dataExport }

class _SettingsHubDialog extends StatefulWidget {
  const _SettingsHubDialog();

  @override
  State<_SettingsHubDialog> createState() => _SettingsHubDialogState();
}

class _SettingsHubDialogState extends State<_SettingsHubDialog> {
  _SettingsSection section = _SettingsSection.overview;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final height = math.min(size.height - 40, 680.0);
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 920),
        child: SizedBox(
          height: height,
          child: Material(
            color: const Color(0xFFF7F9FC),
            borderRadius: BorderRadius.circular(26),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                _SettingsHeader(onClose: () => Navigator.pop(context)),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxWidth < 700;
                      if (compact) {
                        return Column(
                          children: [
                            _SettingsCompactNavigation(
                              selected: section,
                              onSelected: (value) {
                                setState(() => section = value);
                              },
                            ),
                            const Divider(height: 1),
                            Expanded(child: _buildContent(context)),
                          ],
                        );
                      }
                      return Row(
                        children: [
                          SizedBox(
                            width: 225,
                            child: _SettingsNavigation(
                              selected: section,
                              onSelected: (value) {
                                setState(() => section = value);
                              },
                            ),
                          ),
                          const VerticalDivider(width: 1),
                          Expanded(child: _buildContent(context)),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return switch (section) {
      _SettingsSection.overview => _SettingsOverview(
          onSelect: (value) => setState(() => section = value),
        ),
      _SettingsSection.reminders => const _ReminderSettingsPanel(),
      _SettingsSection.facilities => const _FacilitySettingsPanel(),
      _SettingsSection.income => const _IncomeSettingsPanel(),
      _SettingsSection.dataExport => const _DataExportSettingsPanel(),
    };
  }
}

class _SettingsHeader extends StatelessWidget {
  const _SettingsHeader({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 86,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF17233C), Color(0xFF3156A3)],
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.tune_rounded, color: Color(0xFFDDE7FF)),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Settings',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Control your portfolio from one organized workspace',
                  style: TextStyle(color: Color(0xFFB8CAD5)),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Close settings',
            onPressed: onClose,
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.1),
            ),
            icon: const Icon(Icons.close_rounded, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _SettingsNavigation extends StatelessWidget {
  const _SettingsNavigation({
    required this.selected,
    required this.onSelected,
  });

  final _SettingsSection selected;
  final ValueChanged<_SettingsSection> onSelected;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(10, 8, 10, 12),
              child: Text(
                'CONFIGURATION',
                style: TextStyle(
                  color: Color(0xFF98A2B3),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
            ),
            for (final item in _SettingsSection.values)
              _SettingsNavigationItem(
                section: item,
                selected: item == selected,
                onTap: () => onSelected(item),
              ),
          ],
        ),
      ),
    );
  }
}

class _SettingsCompactNavigation extends StatelessWidget {
  const _SettingsCompactNavigation({
    required this.selected,
    required this.onSelected,
  });

  final _SettingsSection selected;
  final ValueChanged<_SettingsSection> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 66,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        scrollDirection: Axis.horizontal,
        itemCount: _SettingsSection.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final item = _SettingsSection.values[index];
          return ChoiceChip(
            selected: item == selected,
            avatar: Icon(_settingsIcon(item), size: 17),
            label: Text(_settingsLabel(item)),
            onSelected: (_) => onSelected(item),
          );
        },
      ),
    );
  }
}

class _SettingsNavigationItem extends StatelessWidget {
  const _SettingsNavigationItem({
    required this.section,
    required this.selected,
    required this.onTap,
  });

  final _SettingsSection section;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: selected ? const Color(0xFFE8EEFC) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: ListTile(
          dense: true,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          leading: Icon(
            _settingsIcon(section),
            color: selected ? const Color(0xFF3156A3) : const Color(0xFF667085),
          ),
          title: Text(
            _settingsLabel(section),
            style: TextStyle(
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              color:
                  selected ? const Color(0xFF24498F) : const Color(0xFF344054),
            ),
          ),
          onTap: onTap,
        ),
      ),
    );
  }
}

String _settingsLabel(_SettingsSection section) => switch (section) {
      _SettingsSection.overview => 'Overview',
      _SettingsSection.reminders => 'Reminders',
      _SettingsSection.facilities => 'Facilities',
      _SettingsSection.income => 'Other Income',
      _SettingsSection.dataExport => 'Data Export',
    };

IconData _settingsIcon(_SettingsSection section) => switch (section) {
      _SettingsSection.overview => Icons.grid_view_rounded,
      _SettingsSection.reminders => Icons.notifications_active_rounded,
      _SettingsSection.facilities => Icons.apartment_rounded,
      _SettingsSection.income => Icons.add_card_rounded,
      _SettingsSection.dataExport => Icons.storage_rounded,
    };

class _SettingsPanelScaffold extends StatelessWidget {
  const _SettingsPanelScaffold({
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.child,
  });

  final String eyebrow;
  final String title;
  final String description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            eyebrow.toUpperCase(),
            style: const TextStyle(
              color: Color(0xFF3156A3),
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF17233C),
                ),
          ),
          const SizedBox(height: 6),
          Text(description, style: const TextStyle(color: Color(0xFF667085))),
          const SizedBox(height: 22),
          child,
        ],
      ),
    );
  }
}

class _SettingsOverview extends StatelessWidget {
  const _SettingsOverview({required this.onSelect});

  final ValueChanged<_SettingsSection> onSelect;

  @override
  Widget build(BuildContext context) {
    final store = RentalStoreScope.of(context);
    final user = store.currentUser!;
    return _SettingsPanelScaffold(
      eyebrow: 'Workspace',
      title: 'Everything in its place',
      description:
          'Choose a configuration area below. Changes apply across your owner workspace.',
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF17233C),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                ProfileAvatar(user: user, radius: 28),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${user.email} • ${store.ownerFacilities.length} facilities',
                        style: const TextStyle(color: Color(0xFFB8CAD5)),
                      ),
                    ],
                  ),
                ),
                const StatusChipText(label: 'Owner'),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _SettingsActionCard(
            icon: Icons.notifications_active_rounded,
            color: const Color(0xFF3156A3),
            title: 'Payment reminders',
            description: 'Control first notice and repeat frequency.',
            value: '${user.paymentReminderAfterDays} day start',
            onTap: () => onSelect(_SettingsSection.reminders),
          ),
          _SettingsActionCard(
            icon: Icons.apartment_rounded,
            color: const Color(0xFF3156A3),
            title: 'Facility configuration',
            description: 'Costs, commitments and facility lifecycle.',
            value: '${store.ownerFacilities.length} facilities',
            onTap: () => onSelect(_SettingsSection.facilities),
          ),
          _SettingsActionCard(
            icon: Icons.add_card_rounded,
            color: const Color(0xFFD16432),
            title: 'Other monthly income',
            description: 'Record parking, deposits or extra collections.',
            value: 'Add record',
            onTap: () => onSelect(_SettingsSection.income),
          ),
          _SettingsActionCard(
            icon: Icons.storage_rounded,
            color: const Color(0xFF16856B),
            title: 'Data export',
            description:
                'Extract Excel backup, detailed workbook, SQLite or share copy.',
            value: 'Excel backup / detailed',
            onTap: () => onSelect(_SettingsSection.dataExport),
          ),
        ],
      ),
    );
  }
}

class _DataExportSettingsPanel extends StatelessWidget {
  const _DataExportSettingsPanel();

  @override
  Widget build(BuildContext context) {
    final store = RentalStoreScope.of(context);
    return _SettingsPanelScaffold(
      eyebrow: 'Data portability',
      title: 'Extract your app records',
      description:
          'Prepare a portable copy of the internal mobile data for backup, audit or spreadsheet analysis.',
      child: Column(
        children: [
          const Card(
            child: Column(
              children: [
                ListTile(
                  leading: CircleAvatar(child: Icon(Icons.storage_rounded)),
                  title: Text('Mobile SQLite backup'),
                  subtitle:
                      Text('Full structured record copy for restoration.'),
                ),
                Divider(height: 1),
                ListTile(
                  leading: CircleAvatar(child: Icon(Icons.grid_on_rounded)),
                  title: Text('Excel backup summary'),
                  subtitle: Text('Previous compact backup columns.'),
                ),
                Divider(height: 1),
                ListTile(
                  leading: CircleAvatar(child: Icon(Icons.table_view_rounded)),
                  title: Text('Detailed Excel workbook'),
                  subtitle: Text('Dashboard, tenants, bills and cashflow.'),
                ),
              ],
            ),
          ),
          Card(
            child: ListTile(
              leading: Icon(
                store.persistenceError == null
                    ? Icons.verified_rounded
                    : Icons.error_outline_rounded,
                color: store.persistenceError == null
                    ? const Color(0xFF16856B)
                    : Theme.of(context).colorScheme.error,
              ),
              title: Text(
                store.persistenceError == null
                    ? 'Automatic persistence active'
                    : 'Storage needs attention',
              ),
              subtitle: Text(
                store.persistenceError ?? store.storageDescription,
              ),
            ),
          ),
          const SizedBox(height: 16),
          _SettingsPrimaryAction(
            icon: Icons.file_download_rounded,
            label: 'Prepare Data Export',
            onPressed: () => showDataExportDialog(context),
          ),
        ],
      ),
    );
  }
}

class _ReminderSettingsPanel extends StatelessWidget {
  const _ReminderSettingsPanel();

  @override
  Widget build(BuildContext context) {
    final user = RentalStoreScope.of(context).currentUser!;
    return _SettingsPanelScaffold(
      eyebrow: 'Automation',
      title: 'Tenant payment reminders',
      description:
          'Keep follow-ups consistent without manually checking every due bill.',
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _ReminderSettingTile(
                  label: 'First reminder',
                  value: '${user.paymentReminderAfterDays} days after due',
                  icon: Icons.schedule_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ReminderSettingTile(
                  label: 'Repeat frequency',
                  value: 'Every ${user.paymentReminderFrequencyDays} days',
                  icon: Icons.repeat_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SettingsPrimaryAction(
            icon: Icons.tune_rounded,
            label: 'Edit Reminder Schedule',
            onPressed: () => showReminderSettingsDialog(context),
          ),
        ],
      ),
    );
  }
}

class _FacilitySettingsPanel extends StatelessWidget {
  const _FacilitySettingsPanel();

  @override
  Widget build(BuildContext context) {
    final store = RentalStoreScope.of(context);
    return _SettingsPanelScaffold(
      eyebrow: 'Portfolio',
      title: 'Facility configuration',
      description:
          'A single source of truth for costs, recurring commitments, and facility status.',
      child: Column(
        children: [
          for (final facility in store.ownerFacilities)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE4EAF4)),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: Color(0xFFE8EEFC),
                    foregroundColor: Color(0xFF3156A3),
                    child: Icon(Icons.apartment_rounded),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          facility.name,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${facility.extraCommitments.length + 4} cost categories • ${facilityStatusText(facility)}',
                          style: const TextStyle(color: Color(0xFF667085)),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        money(store.monthlyFacilityOutflow(facility)),
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      TextButton.icon(
                        onPressed: () =>
                            showFacilityCostHistoryDialog(context, facility),
                        icon: const Icon(Icons.history_rounded, size: 17),
                        label: Text('History (${facility.costHistory.length})'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          const SizedBox(height: 6),
          _SettingsPrimaryAction(
            icon: Icons.settings_suggest_rounded,
            label: 'Manage Facility Configuration',
            onPressed: () => showFacilityConfigurationDialog(context),
          ),
        ],
      ),
    );
  }
}

class _IncomeSettingsPanel extends StatelessWidget {
  const _IncomeSettingsPanel();

  @override
  Widget build(BuildContext context) {
    return _SettingsPanelScaffold(
      eyebrow: 'Collections',
      title: 'Other monthly income',
      description:
          'Capture income outside standard rent while keeping monthly reporting accurate.',
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFF4EA), Color(0xFFFFFBF7)],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFF2D6BF)),
            ),
            child: const Row(
              children: [
                Icon(Icons.lightbulb_rounded, color: Color(0xFFD16432)),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Use this for parking fees, forfeited deposits, access cards, or any one-off collection.',
                    style: TextStyle(color: Color(0xFF7A472E), height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SettingsPrimaryAction(
            icon: Icons.add_circle_outline_rounded,
            label: 'Add Other Monthly Income',
            onPressed: () => showAddIncomeDialog(context),
          ),
        ],
      ),
    );
  }
}

class _SettingsActionCard extends StatelessWidget {
  const _SettingsActionCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String description;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(description),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(value,
                style: TextStyle(color: color, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            const Icon(Icons.arrow_forward_rounded, size: 18),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}

class _SettingsPrimaryAction extends StatelessWidget {
  const _SettingsPrimaryAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF3156A3),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }
}

void showRecurringCommitmentsSettingsDialog(
  BuildContext context, {
  Facility? initialFacility,
}) {
  final store = RentalStoreScope.of(context);
  final facilities = store.ownerFacilities;
  if (facilities.isEmpty) return;
  var selectedFacility =
      initialFacility != null && facilities.contains(initialFacility)
          ? initialFacility
          : facilities.first;
  RecurringCommitment? selectedCommitment =
      selectedFacility.extraCommitments.isEmpty
          ? null
          : selectedFacility.extraCommitments.first;

  void loadFacility(Facility facility) {
    selectedFacility = facility;
    selectedCommitment = facility.extraCommitments.isEmpty
        ? null
        : facility.extraCommitments.first;
  }

  showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text('Facility Commitments'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<Facility>(
                  value: selectedFacility,
                  decoration: const InputDecoration(
                    labelText: 'Facility',
                    border: OutlineInputBorder(),
                  ),
                  items: facilities
                      .map(
                        (facility) => DropdownMenuItem(
                          value: facility,
                          child: Text(facility.name),
                        ),
                      )
                      .toList(),
                  onChanged: (facility) {
                    if (facility != null) {
                      setDialogState(() => loadFacility(facility));
                    }
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Commitments',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () async {
                        final added = await showAddRecurringCommitmentDialog(
                          context,
                          selectedFacility,
                        );
                        if (added == true) setDialogState(() {});
                      },
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add New'),
                    ),
                  ],
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.local_fire_department_rounded),
                  title: const Text('Fire Insurance'),
                  subtitle: Text(
                    '${insuranceFrequencyText(selectedFacility.insuranceFrequency)} • ${moneyExact(selectedFacility.insuranceFee)} • starts ${FinancialChartPainter.monthNames[selectedFacility.insuranceDueMonth - 1]}',
                  ),
                  trailing: const Icon(Icons.edit_rounded),
                  onTap: () async {
                    final edited = await showEditFireInsuranceCommitmentDialog(
                      context,
                      selectedFacility,
                    );
                    if (edited == true) setDialogState(() {});
                  },
                ),
                if (selectedFacility.extraCommitments.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text('No recurring commitments yet.'),
                  )
                else ...[
                  DropdownButtonFormField<RecurringCommitment>(
                    value: selectedCommitment,
                    decoration: const InputDecoration(
                      labelText: 'Select commitment to edit',
                      border: OutlineInputBorder(),
                    ),
                    items: selectedFacility.extraCommitments
                        .map(
                          (commitment) => DropdownMenuItem(
                            value: commitment,
                            child: Text(commitment.name),
                          ),
                        )
                        .toList(),
                    onChanged: (commitment) {
                      setDialogState(() => selectedCommitment = commitment);
                    },
                  ),
                  const SizedBox(height: 10),
                  if (selectedCommitment != null)
                    FilledButton.icon(
                      onPressed: () async {
                        final edited = await showEditRecurringCommitmentDialog(
                          context,
                          selectedCommitment!,
                        );
                        if (edited == true) setDialogState(() {});
                      },
                      icon: const Icon(Icons.edit_rounded),
                      label: Text('Edit ${selectedCommitment!.name}'),
                    ),
                  const SizedBox(height: 8),
                  ...selectedFacility.extraCommitments.map(
                    (commitment) => ListTile(
                      selected: commitment == selectedCommitment,
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.receipt_long_rounded),
                      title: Text(commitment.name),
                      subtitle: Text(
                        '${commitmentFrequencyText(commitment.frequency)} • starts ${FinancialChartPainter.monthNames[commitment.firstDueMonth - 1]}',
                      ),
                      trailing: Text(
                        money(commitment.amount),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      onTap: () {
                        setDialogState(() => selectedCommitment = commitment);
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    ),
  );
}

Future<bool?> showEditFireInsuranceCommitmentDialog(
  BuildContext context,
  Facility facility,
) {
  final store = RentalStoreScope.of(context);
  final amount = TextEditingController(
    text: facility.insuranceFee.toStringAsFixed(0),
  );
  var frequency = facility.insuranceFrequency;
  var dueMonth = facility.insuranceDueMonth;

  return showDialog<bool>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text('Edit Fire Insurance'),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppTextField(
                controller: amount,
                label: 'Amount',
                prefixText: 'RM ',
              ),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<InsuranceFrequency>(
                      value: frequency,
                      decoration: const InputDecoration(
                        labelText: 'Frequency',
                        border: OutlineInputBorder(),
                      ),
                      items: InsuranceFrequency.values
                          .map(
                            (item) => DropdownMenuItem(
                              value: item,
                              child: Text(insuranceFrequencyText(item)),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => frequency = value);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: MonthDropdownField(
                      label: 'First Payment Month',
                      value: dueMonth,
                      onChanged: (value) {
                        setDialogState(() => dueMonth = value);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () async {
              if (!isValidMoneyInput(amount.text, allowZero: false)) {
                showValidationMessage(
                  dialogContext,
                  'Amount must be a valid number above RM 0.',
                );
                return;
              }
              final confirmed = await showActionConfirmation(
                dialogContext,
                title: 'Save fire insurance schedule?',
                message:
                    'Fire insurance will be updated to ${money(parseMoney(amount.text))} on a ${insuranceFrequencyText(frequency).toLowerCase()} schedule.',
                confirmLabel: 'Save Changes',
              );
              if (!confirmed || !dialogContext.mounted) return;
              store.updateFacilityCosts(
                facility,
                installmentAmount: facility.installmentAmount,
                extraInstallmentPayment: facility.extraInstallmentPayment,
                maintenanceFee: facility.maintenanceFee,
                insuranceFee: parseMoney(amount.text),
                insuranceFrequency: frequency,
                insuranceDueMonth: dueMonth,
              );
              Navigator.pop(dialogContext, true);
            },
            icon: const Icon(Icons.save_rounded),
            label: const Text('Save Fire Insurance'),
          ),
        ],
      ),
    ),
  );
}

Future<bool?> showAddRecurringCommitmentDialog(
  BuildContext context,
  Facility facility,
) {
  final store = RentalStoreScope.of(context);
  final name = TextEditingController(text: commitmentTypeOptions.first);
  final amount = TextEditingController(text: '0');
  var frequency = CommitmentFrequency.monthly;
  var dueMonth = 1;
  var selectedType = commitmentTypeOptions.first;

  return showDialog<bool>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Text('Add Commitment to ${facility.name}'),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedType,
                decoration: const InputDecoration(
                  labelText: 'Commitment Type',
                  border: OutlineInputBorder(),
                ),
                items: commitmentTypeOptions
                    .map(
                      (type) => DropdownMenuItem(
                        value: type,
                        child: Text(type),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setDialogState(() {
                    selectedType = value;
                    name.text = value == customCommitmentType ? '' : value;
                  });
                },
              ),
              const SizedBox(height: 10),
              AppTextField(controller: name, label: 'Commitment Name'),
              AppTextField(
                controller: amount,
                label: 'Amount',
                prefixText: 'RM ',
              ),
              CommitmentScheduleFields(
                frequency: frequency,
                dueMonth: dueMonth,
                onFrequencyChanged: (value) {
                  setDialogState(() => frequency = value);
                },
                onDueMonthChanged: (value) {
                  setDialogState(() => dueMonth = value);
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () async {
              if (name.text.trim().isEmpty) {
                showValidationMessage(
                  dialogContext,
                  'Commitment name is required.',
                );
                return;
              }
              if (!isValidMoneyInput(amount.text, allowZero: false)) {
                showValidationMessage(
                  dialogContext,
                  'Amount must be a valid number above RM 0.',
                );
                return;
              }
              final confirmed = await showActionConfirmation(
                dialogContext,
                title: 'Add recurring commitment?',
                message:
                    '${name.text.trim()} at ${money(parseMoney(amount.text))} will be added to ${facility.name}.',
                confirmLabel: 'Add Commitment',
              );
              if (!confirmed || !dialogContext.mounted) return;
              store.addRecurringCommitment(
                facility: facility,
                name: name.text,
                amount: parseMoney(amount.text),
                frequency: frequency,
                firstDueMonth: dueMonth,
              );
              Navigator.pop(dialogContext, true);
            },
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add Commitment'),
          ),
        ],
      ),
    ),
  );
}

Future<bool?> showEditRecurringCommitmentDialog(
  BuildContext context,
  RecurringCommitment commitment,
) {
  final store = RentalStoreScope.of(context);
  final name = TextEditingController(text: commitment.name);
  final amount =
      TextEditingController(text: commitment.amount.toStringAsFixed(0));
  var frequency = commitment.frequency;
  var dueMonth = commitment.firstDueMonth;
  var selectedType = commitmentTypeOptions.contains(commitment.name)
      ? commitment.name
      : customCommitmentType;

  return showDialog<bool>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Text('Edit ${commitment.name}'),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedType,
                decoration: const InputDecoration(
                  labelText: 'Commitment Type',
                  border: OutlineInputBorder(),
                ),
                items: commitmentTypeOptions
                    .map(
                      (type) => DropdownMenuItem(
                        value: type,
                        child: Text(type),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setDialogState(() {
                    selectedType = value;
                    name.text = value == customCommitmentType ? '' : value;
                  });
                },
              ),
              const SizedBox(height: 10),
              AppTextField(controller: name, label: 'Commitment Name'),
              AppTextField(
                controller: amount,
                label: 'Amount',
                prefixText: 'RM ',
              ),
              CommitmentScheduleFields(
                frequency: frequency,
                dueMonth: dueMonth,
                onFrequencyChanged: (value) {
                  setDialogState(() => frequency = value);
                },
                onDueMonthChanged: (value) {
                  setDialogState(() => dueMonth = value);
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () async {
              if (name.text.trim().isEmpty) {
                showValidationMessage(
                  dialogContext,
                  'Commitment name is required.',
                );
                return;
              }
              if (!isValidMoneyInput(amount.text, allowZero: false)) {
                showValidationMessage(
                  dialogContext,
                  'Amount must be a valid number above RM 0.',
                );
                return;
              }
              final confirmed = await showActionConfirmation(
                dialogContext,
                title: 'Save commitment changes?',
                message:
                    '${commitment.name} will be updated to ${money(parseMoney(amount.text))} on a ${commitmentFrequencyText(frequency).toLowerCase()} schedule.',
                confirmLabel: 'Save Changes',
              );
              if (!confirmed || !dialogContext.mounted) return;
              store.updateRecurringCommitment(
                commitment,
                name: name.text,
                amount: parseMoney(amount.text),
                frequency: frequency,
                firstDueMonth: dueMonth,
              );
              Navigator.pop(dialogContext, true);
            },
            icon: const Icon(Icons.save_rounded),
            label: const Text('Save Commitment'),
          ),
        ],
      ),
    ),
  );
}

void showAddIncomeDialog(BuildContext context, [Facility? initialFacility]) {
  final store = RentalStoreScope.of(context);
  final facilities = store.ownerFacilities;
  if (facilities.isEmpty) return;
  Facility selectedFacility = initialFacility ?? facilities.first;
  final selectedMonth = store.currentMonth;
  final category = TextEditingController();
  final amount = TextEditingController();
  final note = TextEditingController();

  showDialog<void>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text('Add Other Monthly Income'),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<Facility>(
                  value: selectedFacility,
                  decoration: const InputDecoration(labelText: 'Facility'),
                  items: facilities
                      .map(
                        (facility) => DropdownMenuItem(
                          value: facility,
                          child: Text(facility.name),
                        ),
                      )
                      .toList(),
                  onChanged: (facility) {
                    if (facility != null) {
                      setDialogState(() => selectedFacility = facility);
                    }
                  },
                ),
                const SizedBox(height: 10),
                ProfileInfoRow(
                  label: 'Month',
                  value: '${monthLabel(selectedMonth)} • current month only',
                ),
                const SizedBox(height: 10),
                AppTextField(
                  controller: category,
                  label: 'Income Category',
                  hintText: 'e.g. Parking rental, deposit, access card',
                ),
                AppTextField(
                  controller: amount,
                  label: 'Amount',
                  prefixText: 'RM ',
                  hintText: '0.00',
                ),
                AppTextField(
                  controller: note,
                  label: 'Note',
                  hintText: 'Optional note for this income',
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () async {
              if (category.text.trim().isEmpty) {
                showValidationMessage(context, 'Income category is required.');
                return;
              }
              if (!isValidMoneyInput(amount.text, allowZero: false)) {
                showValidationMessage(
                  context,
                  'Income amount must be a valid amount above RM 0.',
                );
                return;
              }
              final confirmed = await showActionConfirmation(
                context,
                title: 'Add this income record?',
                message:
                    '${category.text.trim()} of ${money(parseMoney(amount.text))} will be recorded for ${monthLabel(selectedMonth)}.',
                confirmLabel: 'Add Income',
              );
              if (!confirmed || !context.mounted) return;
              store.addAdditionalIncome(
                facility: selectedFacility,
                month: selectedMonth,
                category: category.text.trim(),
                amount: parseMoney(amount.text),
                note: note.text.trim(),
              );
              Navigator.pop(context);
            },
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add Income'),
          ),
        ],
      ),
    ),
  );
}

void showAddExpenseDialog(BuildContext context, Facility facility) {
  final store = RentalStoreScope.of(context);
  final category = TextEditingController();
  final amount = TextEditingController();
  final note = TextEditingController();
  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Add One-time Expense'),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ProfileInfoRow(label: 'Facility', value: facility.name),
            ProfileInfoRow(
              label: 'Month',
              value: '${monthLabel(store.currentMonth)} • current month only',
            ),
            AppTextField(
              controller: category,
              label: 'Expense Category',
              hintText: 'e.g. Repair, bank fee, one-off service',
            ),
            AppTextField(
              controller: amount,
              label: 'Amount',
              prefixText: 'RM ',
              hintText: '0.00',
            ),
            AppTextField(
              controller: note,
              label: 'Note',
              hintText: 'Optional note for this expense',
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: () async {
            if (category.text.trim().isEmpty) {
              showValidationMessage(
                dialogContext,
                'Expense category is required.',
              );
              return;
            }
            if (!isValidMoneyInput(amount.text, allowZero: false)) {
              showValidationMessage(
                dialogContext,
                'Expense amount must be a valid amount above RM 0.',
              );
              return;
            }
            final confirmed = await showActionConfirmation(
              dialogContext,
              title: 'Add this expense?',
              message:
                  '${category.text.trim()} of ${money(parseMoney(amount.text))} will be recorded for ${monthLabel(store.currentMonth)}.',
              confirmLabel: 'Add Expense',
            );
            if (!confirmed || !dialogContext.mounted) return;
            store.addAdditionalExpense(
              facility: facility,
              category: category.text,
              amount: parseMoney(amount.text),
              note: note.text,
            );
            Navigator.pop(dialogContext);
          },
          icon: const Icon(Icons.add_rounded),
          label: const Text('Review & Add'),
        ),
      ],
    ),
  );
}

void showNotifications(BuildContext context) {
  final store = RentalStoreScope.of(context);
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      return AnimatedBuilder(
        animation: store,
        builder: (context, _) {
          final unread = store.unreadNotificationCount;
          final grouped = <String, List<AppNotification>>{};
          for (final notification in store.notifications) {
            final category = notificationCategoryFor(notification.message);
            grouped.putIfAbsent(category, () => []).add(notification);
          }
          const categoryOrder = [
            'Bill review',
            'Payment proof',
            'Tenant related',
            'Property changes',
            'Profile & settings',
            'Utility reading',
            'Requests',
            'System',
          ];
          final categories = [
            ...categoryOrder.where(grouped.containsKey),
            ...grouped.keys.where((item) => !categoryOrder.contains(item)),
          ];
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Notifications',
                  style: Theme.of(context).textTheme.titleLarge),
              if (store.notifications.isNotEmpty)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: unread == 0,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text(
                    'Mark all as read',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    unread == 0
                        ? 'All notifications have been read'
                        : '$unread unread notification${unread == 1 ? '' : 's'}',
                  ),
                  onChanged: unread == 0
                      ? null
                      : (_) => store.markAllNotificationsRead(),
                ),
              const Divider(),
              if (store.notifications.isEmpty)
                const ListTile(title: Text('No notifications yet')),
              for (final category in categories) ...[
                _NotificationCategoryHeader(
                  category: category,
                  notifications: grouped[category]!,
                ),
                ...grouped[category]!.map(
                  (notification) => _NotificationTile(
                    notification: notification,
                    onTap: () => store.markNotificationRead(notification),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ],
          );
        },
      );
    },
  );
}

class _NotificationCategoryHeader extends StatelessWidget {
  const _NotificationCategoryHeader({
    required this.category,
    required this.notifications,
  });

  final String category;
  final List<AppNotification> notifications;

  @override
  Widget build(BuildContext context) {
    final unread = notifications.where((item) => !item.isRead).length;
    final color = notificationCategoryColor(category);
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(notificationCategoryIcon(category),
                color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              category,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: unread > 0 ? color.withOpacity(0.12) : oceanCanvas,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              unread > 0 ? '$unread unread' : '${notifications.length} read',
              style: TextStyle(
                color: unread > 0 ? color : oceanMuted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.onTap,
  });

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final category = notificationCategoryFor(notification.message);
    final color = notificationCategoryColor(category);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: Icon(
        notification.isRead
            ? Icons.notifications_none_rounded
            : Icons.notifications_active_rounded,
        color: notification.isRead ? const Color(0xFF98A2B3) : color,
      ),
      title: Text(
        notification.message,
        style: TextStyle(
          fontWeight: notification.isRead ? FontWeight.w400 : FontWeight.w700,
        ),
      ),
      subtitle: Text(dateTimeLabel(notification.createdAt)),
      onTap: onTap,
    );
  }
}

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    required this.user,
    required this.radius,
    this.overrideStyle,
    super.key,
  });

  final AppUser user;
  final double radius;
  final int? overrideStyle;

  @override
  Widget build(BuildContext context) {
    const colors = [
      Color(0xFF3156A3),
      Color(0xFF16856B),
      Color(0xFFD16432),
      Color(0xFF6B5CB8),
      Color(0xFFC43D4B),
      Color(0xFF247BA0),
    ];
    const icons = [
      Icons.person_rounded,
      Icons.face_rounded,
      Icons.account_circle_rounded,
      Icons.sentiment_satisfied_alt_rounded,
      Icons.person_pin_rounded,
      Icons.manage_accounts_rounded,
    ];
    final style = overrideStyle ?? user.avatarStyle;
    return CircleAvatar(
      radius: radius,
      backgroundColor: colors[style % colors.length].withOpacity(0.15),
      foregroundColor: colors[style % colors.length],
      child: Icon(icons[style % icons.length], size: radius),
    );
  }
}

class TenantGenderAvatar extends StatelessWidget {
  const TenantGenderAvatar({
    required this.tenant,
    this.radius = 20,
    super.key,
  });

  final AppUser tenant;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final sex = (tenant.sex ?? '').trim().toLowerCase();
    final isFemale = sex.startsWith('f') || sex.contains('female');
    final color = isFemale ? const Color(0xFFE14D6E) : oceanBlue;
    return CircleAvatar(
      radius: radius,
      backgroundColor: color,
      foregroundColor: Colors.white,
      child: Icon(Icons.person_rounded, size: radius),
    );
  }
}

class _ReminderSettingTile extends StatelessWidget {
  const _ReminderSettingTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F7FC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE4EAF4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: Color(0xFF667085))),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class ProfileInfoRow extends StatelessWidget {
  const ProfileInfoRow({
    required this.label,
    required this.value,
    super.key,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 260;
        final labelText = Text(
          label,
          style: const TextStyle(
            color: Color(0xFF667085),
            fontWeight: FontWeight.w600,
          ),
        );
        final valueText = Text(
          value,
          softWrap: true,
          style: const TextStyle(fontWeight: FontWeight.w600),
        );
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: stacked
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    labelText,
                    const SizedBox(height: 2),
                    valueText,
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 4, child: labelText),
                    const SizedBox(width: 10),
                    Expanded(flex: 6, child: valueText),
                  ],
                ),
        );
      },
    );
  }
}

class AppTextField extends StatelessWidget {
  const AppTextField({
    required this.controller,
    required this.label,
    this.helperText,
    this.hintText,
    this.prefixText,
    this.suffixText,
    this.keyboardType,
    this.onChanged,
    this.readOnly = false,
    this.inputFormatters,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final String? helperText;
  final String? hintText;
  final String? prefixText;
  final String? suffixText;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final bool readOnly;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    final resolvedKeyboardType = keyboardType ?? _keyboardTypeFor(label);
    final resolvedFormatters = inputFormatters ?? _formattersFor(label);
    final resolvedHintText =
        hintText?.trim().startsWith('Example:') == true ? null : hintText;
    final resolvedHelperText =
        helperText?.trim().startsWith('Example:') == true ? null : helperText;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        readOnly: readOnly,
        keyboardType: resolvedKeyboardType,
        inputFormatters: resolvedFormatters,
        onChanged: onChanged,
        decoration: InputDecoration(
          border: const OutlineInputBorder(),
          labelText: label,
          hintText: resolvedHintText,
          helperText: resolvedHelperText,
          helperMaxLines: 3,
          prefixText: prefixText,
          suffixText: suffixText,
        ),
      ),
    );
  }

  static TextInputType? _keyboardTypeFor(String label) {
    final normalized = label.toLowerCase();
    if (_isMoneyLabel(normalized) || normalized.contains('usage')) {
      return const TextInputType.numberWithOptions(decimal: true);
    }
    if (_isDateLabel(normalized)) return TextInputType.datetime;
    if (normalized.contains('phone') || normalized.contains('whatsapp')) {
      return TextInputType.phone;
    }
    if (normalized == 'email' || normalized.contains('email')) {
      return TextInputType.emailAddress;
    }
    return null;
  }

  static List<TextInputFormatter>? _formattersFor(String label) {
    final normalized = label.toLowerCase();
    if (_isDateLabel(normalized)) {
      return [FilteringTextInputFormatter.allow(RegExp(r'[0-9/]'))];
    }
    if (_isMoneyLabel(normalized) || normalized.contains('usage')) {
      return [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))];
    }
    if (normalized.contains('phone') || normalized.contains('whatsapp')) {
      return [FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-() ]'))];
    }
    if (_isHumanNameLabel(normalized)) {
      return [FilteringTextInputFormatter.deny(RegExp(r'[0-9]'))];
    }
    if (normalized == 'sex' || normalized == 'city' || normalized == 'state') {
      return [FilteringTextInputFormatter.deny(RegExp(r'[0-9]'))];
    }
    return null;
  }

  static bool _isDateLabel(String normalized) =>
      normalized.contains('date') ||
      normalized.contains('birth') ||
      normalized.contains('lease start') ||
      normalized.contains('lease end');

  static bool _isMoneyLabel(String normalized) =>
      normalized.contains('rent') ||
      normalized.contains('amount') ||
      normalized.contains('installment') ||
      normalized.contains('maintenance') ||
      normalized.contains('insurance') ||
      normalized.contains('charge') ||
      normalized.contains('premium') ||
      normalized.contains('payment');

  static bool _isHumanNameLabel(String normalized) =>
      normalized == 'full name' ||
      normalized == 'full name *' ||
      normalized == 'tenant' ||
      normalized == 'beneficiary';
}

class MalaysiaAddressDropdowns extends StatelessWidget {
  const MalaysiaAddressDropdowns({
    required this.state,
    required this.city,
    required this.postcode,
    required this.onStateChanged,
    required this.onCityChanged,
    required this.onPostcodeChanged,
    super.key,
  });

  final String? state;
  final String? city;
  final String? postcode;
  final ValueChanged<String?> onStateChanged;
  final ValueChanged<String?> onCityChanged;
  final ValueChanged<String?> onPostcodeChanged;

  @override
  Widget build(BuildContext context) {
    final states = malaysiaStates();
    final cities = malaysiaCitiesForState(state);
    final postcodes = malaysiaPostcodesFor(state, city);
    return Column(
      children: [
        DropdownButtonFormField<String>(
          value: state,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'State',
          ),
          items: states
              .map((item) => DropdownMenuItem(value: item, child: Text(item)))
              .toList(),
          onChanged: onStateChanged,
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final cityField = DropdownButtonFormField<String>(
              value: cities.contains(city) ? city : null,
              isExpanded: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'City',
              ),
              items: cities
                  .map((item) => DropdownMenuItem(
                        value: item,
                        child: Text(item, overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
              onChanged: state == null ? null : onCityChanged,
            );
            final postcodeField = DropdownButtonFormField<String>(
              value: postcodes.contains(postcode) ? postcode : null,
              isExpanded: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Postcode',
              ),
              items: postcodes
                  .map((item) => DropdownMenuItem(
                        value: item,
                        child: Text(item, overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
              onChanged: city == null ? null : onPostcodeChanged,
            );
            if (constraints.maxWidth < 360) {
              return Column(
                children: [
                  cityField,
                  const SizedBox(height: 10),
                  postcodeField,
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: cityField),
                const SizedBox(width: 10),
                Expanded(child: postcodeField),
              ],
            );
          },
        ),
        const SizedBox(height: 10),
      ],
    );
  }
}

class MonthDropdownField extends StatelessWidget {
  const MonthDropdownField({
    required this.label,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<int>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: List.generate(
        12,
        (index) => DropdownMenuItem(
          value: index + 1,
          child: Text(FinancialChartPainter.monthNames[index]),
        ),
      ),
      onChanged: (month) {
        if (month != null) onChanged(month);
      },
    );
  }
}

class CommitmentScheduleFields extends StatelessWidget {
  const CommitmentScheduleFields({
    required this.frequency,
    required this.dueMonth,
    required this.onFrequencyChanged,
    required this.onDueMonthChanged,
    super.key,
  });

  final CommitmentFrequency frequency;
  final int dueMonth;
  final ValueChanged<CommitmentFrequency> onFrequencyChanged;
  final ValueChanged<int> onDueMonthChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<CommitmentFrequency>(
            value: frequency,
            decoration: const InputDecoration(
              labelText: 'Frequency',
              border: OutlineInputBorder(),
            ),
            items: CommitmentFrequency.values
                .map(
                  (item) => DropdownMenuItem(
                    value: item,
                    child: Text(commitmentFrequencyText(item)),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) onFrequencyChanged(value);
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: MonthDropdownField(
            label: frequency == CommitmentFrequency.monthly
                ? 'Start Month'
                : 'First Payment Month',
            value: dueMonth,
            onChanged: onDueMonthChanged,
          ),
        ),
      ],
    );
  }
}

String money(double value) {
  final sign = value < 0 ? '-' : '';
  final abs = value.abs();
  final whole = abs.round().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < whole.length; i++) {
    final remaining = whole.length - i;
    buffer.write(whole[i]);
    if (remaining > 1 && remaining % 3 == 1) buffer.write(',');
  }
  return '${sign}RM ${buffer.toString()}';
}

String tr(BuildContext context, String key) {
  final language = RentalStoreScope.of(context).appLanguage;
  if (language == AppLanguage.english) return key;
  const chinese = <String, String>{
    'Home': '主页',
    'Properties': '房产',
    'Payments': '付款',
    'Requests': '请求',
    'Profile': '账户',
    'Notifications': '通知',
    'Logout': '登出',
    'Portfolio overview': '投资组合概览',
    'Total Rental Collection': '租金总收入',
    'Total Expenses': '总支出',
    'Properties count': '房产数量',
    'Active tenants': '活跃租户',
    'Utility readings left': '待处理水电读数',
    'Occupancy': '出租率',
    'Inflow / outflow': '收入／支出',
    'ROI': '投资回报率',
    'Account details': '账户资料',
    'Payment methods': '付款方式',
    'Payment reminders': '付款提醒',
    'Facility configuration': '房产设置',
    'Other monthly income': '其他每月收入',
    'Activity history': '操作记录',
    'Data & backup': '数据与备份',
    'Language': '语言',
    'Help & support': '帮助与支持',
    'Log out': '登出',
    'Apply': '应用',
    'Applies across the whole app': '应用于整个应用程序',
  };
  const malay = <String, String>{
    'Home': 'Utama',
    'Properties': 'Hartanah',
    'Payments': 'Bayaran',
    'Requests': 'Permintaan',
    'Profile': 'Akaun',
    'Notifications': 'Notifikasi',
    'Logout': 'Log keluar',
    'Portfolio overview': 'Ringkasan portfolio',
    'Total Rental Collection': 'Jumlah kutipan sewa',
    'Total Expenses': 'Jumlah perbelanjaan',
    'Properties count': 'Hartanah',
    'Active tenants': 'Penyewa aktif',
    'Utility readings left': 'Bacaan utiliti belum selesai',
    'Occupancy': 'Penghunian',
    'Inflow / outflow': 'Aliran masuk / keluar',
    'ROI': 'Pulangan pelaburan',
    'Account details': 'Butiran akaun',
    'Payment methods': 'Kaedah bayaran',
    'Payment reminders': 'Peringatan bayaran',
    'Facility configuration': 'Konfigurasi hartanah',
    'Other monthly income': 'Pendapatan bulanan lain',
    'Activity history': 'Sejarah aktiviti',
    'Data & backup': 'Data & sandaran',
    'Language': 'Bahasa',
    'Help & support': 'Bantuan & sokongan',
    'Log out': 'Log keluar',
    'Apply': 'Gunakan',
    'Applies across the whole app': 'Digunakan di seluruh aplikasi',
  };
  const chineseOverride = <String, String>{
    'Owner': '业主',
    'Property Agent': '物业代理',
    'properties': '房产',
    'property': '房产',
    'records': '记录',
    'record': '记录',
    'Home': '主页',
    'Properties': '房产',
    'Payments': '付款',
    'Requests': '请求',
    'Profile': '个人资料',
    'Notifications': '通知',
    'Logout': '退出登录',
    'Log out': '退出登录',
    'Portfolio overview': '资产概览',
    'Total Rental Collection': '租金总收入',
    'Total Expenses': '总支出',
    'Properties count': '房产数量',
    'Active tenants': '活跃租户',
    'Readings left': '待处理读数',
    'Utility readings left': '待处理水电读数',
    'Occupancy': '入住率',
    'Inflow / outflow': '收入 / 支出',
    'ROI': '投资回报率',
    'Account details': '账户资料',
    'Payment methods': '付款方式',
    'Payment reminders': '付款提醒',
    'Facility configuration': '房产配置',
    'Other monthly income': '其他月收入',
    'Activity history': '操作记录',
    'Data & backup': '数据与备份',
    'Language': '语言',
    'Help & support': '帮助与支持',
    'Apply': '应用',
    'Applies across the whole app': '应用于整个应用',
    'English': '英语',
    'Chinese (Simplified)': '简体中文',
    'Malay': '马来语',
    'Bahasa Melayu': '马来语',
    'Good evening': '晚上好',
    'Good morning': '早上好',
    'Good afternoon': '下午好',
    'Tap a facility for performance': '点击房产查看表现',
    'Rental Collection': '租金收入',
    'Facility Expenses': '房产支出',
    'Net Rental Income': '净租金收入',
    'Monthly Recurring Commitment': '每月固定承诺',
    'Installment': '分期付款',
    'Extra Payment': '额外付款',
    'Maintenance': '维修费',
    'Fire Insurance': '火灾保险',
    'Indah Water': '英达丽水',
    'DBKL Assessment': '市政评估费',
    'Tenants': '租户',
    'All Tenants': '全部租户',
    'New Tenant': '新增租户',
    'Add': '新增',
    'Edit': '编辑',
    'Save': '保存',
    'Cancel': '取消',
    'Close': '关闭',
    'Accept': '接受',
    'Reject': '拒绝',
    'Approve': '批准',
    'Active': '活跃',
    'Inactive': '非活跃',
    'Pending verification': '待验证',
    'Approved': '已批准',
    'Rejected': '已拒绝',
    'Pending Action': '待处理',
    'History': '历史',
    'Open': '打开',
    'Closed': '已关闭',
    'Accepted': '已接受',
    'In Progress': '处理中',
    'Pending': '待处理',
    'Pending Owner Utilities': '待业主填写水电',
    'Pending Tenant Payment': '待租户付款',
    'Bill Performance': '账单表现',
    'Due': '应付',
    'Paid': '已付',
    'Amount': '金额',
    'Amount Paid': '已付金额',
    'Status': '状态',
    'Facility': '房产',
    'Month': '月份',
    'Full Name': '姓名',
    'Email': '电邮',
    'WhatsApp / Phone Number': 'WhatsApp / 电话号码',
    'Origin Address': '原住址',
    'Date of Birth': '出生日期',
    'Sex': '性别',
    'Room / Unit': '房间 / 单位',
    'Monthly Rent': '月租',
    'Lease Start': '租约开始',
    'Lease End': '租约结束',
    'Billing configuration': '\u8ba1\u8d39\u914d\u7f6e',
    'Facility Costs': '\u623f\u4ea7\u6210\u672c',
    'No tenants assigned to this facility.':
        '\u8fd9\u4e2a\u623f\u4ea7\u8fd8\u6ca1\u6709\u79df\u6237\u3002',
    'Rent': '\u79df\u91d1',
    'Review Payment': '\u5ba1\u6838\u4ed8\u6b3e',
    'Cost Change History': '\u6210\u672c\u53d8\u66f4\u5386\u53f2',
    'Rental collection': '\u79df\u91d1\u6536\u5165',
    'Expenses': '\u652f\u51fa',
    'Collection & Expenses': '\u6536\u652f',
    'Collection': '\u6536\u5165',
    'Breakdown': '\u660e\u7ec6',
    'Monthly': '\u6bcf\u6708',
    'Quarterly': '\u6bcf\u5b63\u5ea6',
    'Half-yearly': '\u6bcf\u534a\u5e74',
    'Yearly': '\u6bcf\u5e74',
    'Monthly amounts; select a month to see its breakdown':
        '\u6bcf\u6708\u91d1\u989d\uff1b\u9009\u62e9\u6708\u4efd\u67e5\u770b\u660e\u7ec6',
    'Select a month above to view its collection and expense charts.':
        '\u8bf7\u5728\u4e0a\u65b9\u9009\u62e9\u6708\u4efd\u67e5\u770b\u6536\u5165\u548c\u652f\u51fa\u56fe\u8868\u3002',
    'See who contributed to collection and where expenses went.':
        '\u67e5\u770b\u8c01\u8d21\u732e\u4e86\u6536\u5165\u4ee5\u53ca\u652f\u51fa\u7528\u9014\u3002',
    'Previous year': '\u4e0a\u4e00\u5e74',
    'Next year': '\u4e0b\u4e00\u5e74',
    'Hide breakdown': '\u9690\u85cf\u660e\u7ec6',
    'Create Tenant': '创建租户',
  };
  const malayOverride = <String, String>{
    'Owner': 'Pemilik',
    'Property Agent': 'Ejen hartanah',
    'properties': 'hartanah',
    'property': 'hartanah',
    'records': 'rekod',
    'record': 'rekod',
    'English': 'Inggeris',
    'Chinese (Simplified)': 'Cina (Ringkas)',
    'Malay': 'Melayu',
    'Bahasa Melayu': 'Bahasa Melayu',
    'Good evening': 'Selamat petang',
    'Good morning': 'Selamat pagi',
    'Good afternoon': 'Selamat tengah hari',
    'Tap a facility for performance': 'Tekan hartanah untuk prestasi',
    'Rental Collection': 'Kutipan sewa',
    'Facility Expenses': 'Perbelanjaan hartanah',
    'Net Rental Income': 'Pendapatan sewa bersih',
    'Monthly Recurring Commitment': 'Komitmen bulanan berulang',
    'Installment': 'Ansuran',
    'Extra Payment': 'Bayaran tambahan',
    'Maintenance': 'Penyelenggaraan',
    'Fire Insurance': 'Insurans kebakaran',
    'Indah Water': 'Indah Water',
    'DBKL Assessment': 'Cukai taksiran DBKL',
    'Tenants': 'Penyewa',
    'All Tenants': 'Semua penyewa',
    'New Tenant': 'Penyewa baru',
    'Add': 'Tambah',
    'Edit': 'Edit',
    'Save': 'Simpan',
    'Cancel': 'Batal',
    'Close': 'Tutup',
    'Accept': 'Terima',
    'Reject': 'Tolak',
    'Approve': 'Lulus',
    'Active': 'Aktif',
    'Inactive': 'Tidak aktif',
    'Pending verification': 'Menunggu pengesahan',
    'Approved': 'Diluluskan',
    'Rejected': 'Ditolak',
    'Pending Action': 'Tindakan tertunda',
    'History': 'Sejarah',
    'Open': 'Buka',
    'Closed': 'Ditutup',
    'Accepted': 'Diterima',
    'In Progress': 'Sedang diproses',
    'Pending': 'Tertunda',
    'Pending Owner Utilities': 'Menunggu utiliti pemilik',
    'Pending Tenant Payment': 'Menunggu bayaran penyewa',
    'Bill Performance': 'Prestasi bil',
    'Due': 'Perlu dibayar',
    'Paid': 'Dibayar',
    'Amount': 'Jumlah',
    'Amount Paid': 'Jumlah dibayar',
    'Status': 'Status',
    'Facility': 'Hartanah',
    'Month': 'Bulan',
    'Full Name': 'Nama penuh',
    'Email': 'E-mel',
    'WhatsApp / Phone Number': 'WhatsApp / Nombor telefon',
    'Origin Address': 'Alamat asal',
    'Date of Birth': 'Tarikh lahir',
    'Sex': 'Jantina',
    'Room / Unit': 'Bilik / Unit',
    'Monthly Rent': 'Sewa bulanan',
    'Lease Start': 'Mula sewa',
    'Lease End': 'Tamat sewa',
    'Billing configuration': 'Konfigurasi bil',
    'Facility Costs': 'Kos hartanah',
    'No tenants assigned to this facility.':
        'Tiada penyewa untuk hartanah ini.',
    'Rent': 'Sewa',
    'Review Payment': 'Semak bayaran',
    'Cost Change History': 'Sejarah perubahan kos',
    'Rental collection': 'Kutipan sewa',
    'Expenses': 'Perbelanjaan',
    'Collection & Expenses': 'Kutipan & Perbelanjaan',
    'Collection': 'Kutipan',
    'Breakdown': 'Pecahan',
    'Monthly': 'Bulanan',
    'Quarterly': 'Suku tahunan',
    'Half-yearly': 'Setengah tahunan',
    'Yearly': 'Tahunan',
    'Monthly amounts; select a month to see its breakdown':
        'Jumlah bulanan; pilih bulan untuk melihat pecahan',
    'Select a month above to view its collection and expense charts.':
        'Pilih bulan di atas untuk melihat carta kutipan dan perbelanjaan.',
    'See who contributed to collection and where expenses went.':
        'Lihat siapa menyumbang kutipan dan ke mana perbelanjaan digunakan.',
    'Previous year': 'Tahun sebelumnya',
    'Next year': 'Tahun seterusnya',
    'Hide breakdown': 'Sembunyikan pecahan',
    'Create Tenant': 'Cipta penyewa',
  };
  final override =
      language == AppLanguage.chinese ? chineseOverride : malayOverride;
  final base = language == AppLanguage.chinese ? chinese : malay;
  return override[key] ?? base[key] ?? key;
}

String trCount(
  BuildContext context,
  int count,
  String singularKey,
  String pluralKey,
) {
  final language = RentalStoreScope.of(context).appLanguage;
  if (language == AppLanguage.chinese) {
    final unit = switch (pluralKey) {
      'properties' => '房产',
      'records' => '记录',
      _ => tr(context, pluralKey),
    };
    return '$count $unit';
  }
  if (language == AppLanguage.malay) {
    return '$count ${tr(context, pluralKey)}';
  }
  return '$count ${count == 1 ? singularKey : pluralKey}';
}

String trDayStart(BuildContext context, int days) {
  final language = RentalStoreScope.of(context).appLanguage;
  if (language == AppLanguage.chinese) return '$days 天开始';
  if (language == AppLanguage.malay) return '$days hari mula';
  return '$days day start';
}

String moneyExact(double value) {
  final sign = value < 0 ? '-' : '';
  final parts = value.abs().toStringAsFixed(2).split('.');
  final digits = parts.first;
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    final remaining = digits.length - i;
    buffer.write(digits[i]);
    if (remaining > 1 && remaining % 3 == 1) buffer.write(',');
  }
  return '${sign}RM ${buffer.toString()}.${parts.last}';
}

const int requestPictureMaxBytes = 2 * 1024 * 1024;

PickedImageData compressRequestPicture(PickedImageData picked) {
  final originalBytes = Uint8List.fromList(picked.bytes);
  if (originalBytes.lengthInBytes <= requestPictureMaxBytes) {
    return picked;
  }

  final decoded = image_tools.decodeImage(originalBytes);
  if (decoded == null) {
    throw StateError(
      'This picture is larger than 2 MB and cannot be compressed. Please choose a JPG, PNG or WebP photo.',
    );
  }

  var width = decoded.width;
  var height = decoded.height;
  var quality = 82;
  var working = decoded;
  var output = Uint8List.fromList(
    image_tools.encodeJpg(working, quality: quality),
  );

  while (output.lengthInBytes > requestPictureMaxBytes &&
      (quality > 45 || math.max(width, height) > 900)) {
    if (quality > 45) {
      quality -= 8;
    } else {
      width = math.max(640, (width * 0.84).round());
      height = math.max(640, (height * 0.84).round());
      working = image_tools.copyResize(
        decoded,
        width: width,
        height: height,
        interpolation: image_tools.Interpolation.average,
      );
      quality = 78;
    }
    output = Uint8List.fromList(
      image_tools.encodeJpg(working, quality: quality),
    );
  }

  if (output.lengthInBytes > requestPictureMaxBytes) {
    throw StateError(
      'This picture is still above 2 MB after compression. Please choose a clearer smaller photo.',
    );
  }

  final baseName = picked.name.replaceAll(RegExp(r'\.[^.]+$'), '');
  return PickedImageData(name: '$baseName-compressed.jpg', bytes: output);
}

String fileSizeLabel(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
}

bool isImageFileName(String? fileName) {
  final lower = (fileName ?? '').toLowerCase();
  return lower.endsWith('.jpg') ||
      lower.endsWith('.jpeg') ||
      lower.endsWith('.png') ||
      lower.endsWith('.webp');
}

String monthLabel(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[date.month - 1]} ${date.year}';
}

String localizedMonthShort(BuildContext context, int month) {
  const english = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  const chinese = [
    '1月',
    '2月',
    '3月',
    '4月',
    '5月',
    '6月',
    '7月',
    '8月',
    '9月',
    '10月',
    '11月',
    '12月',
  ];
  const malay = [
    'Jan',
    'Feb',
    'Mac',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Ogo',
    'Sep',
    'Okt',
    'Nov',
    'Dis',
  ];
  final language = RentalStoreScope.of(context).appLanguage;
  final labels = switch (language) {
    AppLanguage.chinese => chinese,
    AppLanguage.malay => malay,
    AppLanguage.english => english,
  };
  return labels[(month - 1).clamp(0, 11)];
}

String localizedMonthYear(BuildContext context, DateTime date) =>
    '${localizedMonthShort(context, date.month)} ${date.year}';

String packageText(UtilityPackage package) {
  return package == UtilityPackage.included ? 'Included' : 'Excluded';
}

String insuranceFrequencyText(InsuranceFrequency frequency) {
  return switch (frequency) {
    InsuranceFrequency.halfYearly => 'Half-yearly',
    InsuranceFrequency.yearly => 'Yearly',
  };
}

String commitmentFrequencyText(CommitmentFrequency frequency) {
  return switch (frequency) {
    CommitmentFrequency.monthly => 'Monthly',
    CommitmentFrequency.quarterly => 'Quarterly',
    CommitmentFrequency.halfYearly => 'Half-yearly',
    CommitmentFrequency.yearly => 'Yearly',
  };
}

String firstName(String fullName) {
  final trimmed = fullName.trim();
  if (trimmed.isEmpty) return 'there';
  return trimmed.split(RegExp(r'\s+')).first;
}

String timeGreeting(DateTime time) {
  if (time.hour < 12) return 'Good morning';
  if (time.hour < 18) return 'Good afternoon';
  return 'Good evening';
}

String facilityStatusText(Facility facility) {
  if (facility.status == FacilityStatus.sold) {
    final soldAt = facility.soldAt;
    return soldAt == null ? 'Sold' : 'Sold on ${dateLabel(soldAt)}';
  }
  return 'Active';
}

String dateLabel(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

String dateTimeLabel(DateTime date) {
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '${dateLabel(date)} $hour:$minute';
}

String notificationCategoryFor(String message) {
  final lower = message.toLowerCase();
  if (lower.contains('approved') ||
      lower.contains('rejected') ||
      lower.contains('review') ||
      lower.contains('resubmit') ||
      lower.contains('pending tenant payment')) {
    return 'Bill review';
  }
  if (lower.contains('payment slip') ||
      lower.contains('slip') ||
      lower.contains('paid') ||
      lower.contains('payment proof')) {
    return 'Payment proof';
  }
  if (lower.contains('profile') ||
      lower.contains('avatar') ||
      lower.contains('account') ||
      lower.contains('settings') ||
      lower.contains('reminder') ||
      lower.contains('language')) {
    return 'Profile & settings';
  }
  if (lower.contains('utility') ||
      lower.contains('reading') ||
      lower.contains('bill') ||
      lower.contains('invoice')) {
    return 'Utility reading';
  }
  if (lower.contains('facility') ||
      lower.contains('property') ||
      lower.contains('commitment') ||
      lower.contains('cost') ||
      lower.contains('expense') ||
      lower.contains('income') ||
      lower.contains('sold') ||
      lower.contains('removed')) {
    return 'Property changes';
  }
  if (lower.contains('request')) return 'Requests';
  if (lower.contains('tenant') ||
      lower.contains('agreement') ||
      lower.contains('invitation')) {
    return 'Tenant related';
  }
  return 'System';
}

IconData notificationCategoryIcon(String category) {
  return switch (category) {
    'Bill review' => Icons.fact_check_rounded,
    'Payment proof' => Icons.payments_rounded,
    'Tenant related' => Icons.people_alt_rounded,
    'Property changes' => Icons.apartment_rounded,
    'Profile & settings' => Icons.manage_accounts_rounded,
    'Utility reading' => Icons.receipt_long_rounded,
    'Requests' => Icons.handyman_rounded,
    _ => Icons.notifications_rounded,
  };
}

Color notificationCategoryColor(String category) {
  return switch (category) {
    'Bill review' => const Color(0xFF2563EB),
    'Payment proof' => const Color(0xFF0F766E),
    'Tenant related' => const Color(0xFF6B5CB8),
    'Property changes' => const Color(0xFF3156A3),
    'Profile & settings' => const Color(0xFF64748B),
    'Utility reading' => const Color(0xFF0E7490),
    'Requests' => const Color(0xFFD25B2A),
    _ => const Color(0xFF64748B),
  };
}

double parseMoney(String text) {
  return double.tryParse(
          text.replaceAll(',', '').replaceAll('\$', '').trim()) ??
      0;
}

bool isValidMoneyInput(String text, {bool allowZero = true}) {
  final cleaned = text.replaceAll(',', '').replaceAll('\$', '').trim();
  if (cleaned.isEmpty) return false;
  final value = double.tryParse(cleaned);
  if (value == null) return false;
  return allowZero ? value >= 0 : value > 0;
}

bool isValidHumanName(String text) {
  final value = text.trim();
  if (value.length < 2) return false;
  return !RegExp(r'[0-9]').hasMatch(value);
}

bool isValidEmailInput(String text) {
  return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(text.trim());
}

bool isValidPhoneInput(String text) {
  final digits = text.replaceAll(RegExp(r'\D'), '');
  return digits.length >= 8 && digits.length <= 15;
}

DateTime? parseDateInput(String text) {
  final parts = text.trim().split('/');
  if (parts.length != 3) return null;
  final day = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final year = int.tryParse(parts[2]);
  if (day == null || month == null || year == null) return null;
  if (year < 1900 || year > 2100 || month < 1 || month > 12 || day < 1) {
    return null;
  }
  final parsed = DateTime(year, month, day);
  if (parsed.year != year || parsed.month != month || parsed.day != day) {
    return null;
  }
  return parsed;
}

void showValidationMessage(BuildContext context, String message) {
  ScaffoldMessenger.maybeOf(context)
    ?..clearSnackBars()
    ..showSnackBar(SnackBar(content: Text(message)));
}
