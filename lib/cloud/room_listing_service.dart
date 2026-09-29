import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../file_upload/picked_image_data.dart';

const roomListingBucket = 'room-listings';

class RoomListing {
  const RoomListing({
    required this.id,
    required this.publisherId,
    required this.publisherName,
    required this.publisherRole,
    required this.title,
    required this.description,
    required this.propertyType,
    required this.roomType,
    required this.monthlyRent,
    required this.depositAmount,
    required this.addressLine,
    required this.postcode,
    required this.city,
    required this.state,
    required this.bedrooms,
    required this.bathrooms,
    required this.furnishing,
    required this.genderPreference,
    required this.availableFrom,
    required this.amenities,
    required this.imagePaths,
    required this.imageUrls,
    required this.contactName,
    required this.contactPhone,
    required this.status,
    required this.isFeatured,
    required this.createdAt,
    required this.updatedAt,
    this.sourceFacilityId,
  });

  factory RoomListing.fromMap(Map<String, dynamic> row) => RoomListing(
        id: row['id'] as String,
        publisherId: row['publisher_id'] as String,
        publisherName: row['publisher_name'] as String? ?? 'HomeOps360 host',
        publisherRole: row['publisher_role'] as String? ?? 'owner',
        sourceFacilityId: row['source_facility_id'] as String?,
        title: row['title'] as String? ?? 'Room for rent',
        description: row['description'] as String? ?? '',
        propertyType: row['property_type'] as String? ?? 'Condominium',
        roomType: row['room_type'] as String? ?? 'Private room',
        monthlyRent: _number(row['monthly_rent']),
        depositAmount: _number(row['deposit_amount']),
        addressLine: row['address_line'] as String? ?? '',
        postcode: row['postcode'] as String? ?? '',
        city: row['city'] as String? ?? '',
        state: row['state'] as String? ?? '',
        bedrooms: _integer(row['bedrooms'], 1),
        bathrooms: _integer(row['bathrooms'], 1),
        furnishing: row['furnishing'] as String? ?? 'Partly furnished',
        genderPreference: row['gender_preference'] as String? ?? 'Any',
        availableFrom:
            DateTime.tryParse(row['available_from']?.toString() ?? '') ??
                DateTime.now(),
        amenities: _strings(row['amenities']),
        imagePaths: _strings(row['image_paths']),
        imageUrls: const [],
        contactName: row['contact_name'] as String? ?? '',
        contactPhone: row['contact_phone'] as String? ?? '',
        status: row['status'] as String? ?? 'draft',
        isFeatured: row['is_featured'] as bool? ?? false,
        createdAt: DateTime.tryParse(row['created_at']?.toString() ?? '') ??
            DateTime.now(),
        updatedAt: DateTime.tryParse(row['updated_at']?.toString() ?? '') ??
            DateTime.now(),
      );

  final String id;
  final String publisherId;
  final String publisherName;
  final String publisherRole;
  final String? sourceFacilityId;
  final String title;
  final String description;
  final String propertyType;
  final String roomType;
  final double monthlyRent;
  final double depositAmount;
  final String addressLine;
  final String postcode;
  final String city;
  final String state;
  final int bedrooms;
  final int bathrooms;
  final String furnishing;
  final String genderPreference;
  final DateTime availableFrom;
  final List<String> amenities;
  final List<String> imagePaths;
  final List<String> imageUrls;
  final String contactName;
  final String contactPhone;
  final String status;
  final bool isFeatured;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get location =>
      [city, state].where((value) => value.isNotEmpty).join(', ');
  bool get isPublished => status == 'published';

  RoomListing withImageUrls(List<String> urls) => RoomListing(
        id: id,
        publisherId: publisherId,
        publisherName: publisherName,
        publisherRole: publisherRole,
        sourceFacilityId: sourceFacilityId,
        title: title,
        description: description,
        propertyType: propertyType,
        roomType: roomType,
        monthlyRent: monthlyRent,
        depositAmount: depositAmount,
        addressLine: addressLine,
        postcode: postcode,
        city: city,
        state: state,
        bedrooms: bedrooms,
        bathrooms: bathrooms,
        furnishing: furnishing,
        genderPreference: genderPreference,
        availableFrom: availableFrom,
        amenities: amenities,
        imagePaths: imagePaths,
        imageUrls: urls,
        contactName: contactName,
        contactPhone: contactPhone,
        status: status,
        isFeatured: isFeatured,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

  static double _number(Object? value) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
  static int _integer(Object? value, int fallback) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? fallback;
  static List<String> _strings(Object? value) =>
      value is List ? value.map((item) => '$item').toList() : const [];
}

class RoomListingDraft {
  const RoomListingDraft({
    required this.title,
    required this.description,
    required this.propertyType,
    required this.roomType,
    required this.monthlyRent,
    required this.depositAmount,
    required this.addressLine,
    required this.postcode,
    required this.city,
    required this.state,
    required this.bedrooms,
    required this.bathrooms,
    required this.furnishing,
    required this.genderPreference,
    required this.availableFrom,
    required this.amenities,
    required this.contactName,
    required this.contactPhone,
    required this.status,
    required this.isFeatured,
    this.sourceFacilityId,
  });

  final String title;
  final String description;
  final String propertyType;
  final String roomType;
  final double monthlyRent;
  final double depositAmount;
  final String addressLine;
  final String postcode;
  final String city;
  final String state;
  final int bedrooms;
  final int bathrooms;
  final String furnishing;
  final String genderPreference;
  final DateTime availableFrom;
  final List<String> amenities;
  final String contactName;
  final String contactPhone;
  final String status;
  final bool isFeatured;
  final String? sourceFacilityId;

  Map<String, dynamic> toMap(String publisherId) => {
        'publisher_id': publisherId,
        'publisher_name': 'Publisher',
        'publisher_role': 'owner',
        'source_facility_id': sourceFacilityId,
        'title': title.trim(),
        'description': description.trim(),
        'property_type': propertyType,
        'room_type': roomType,
        'monthly_rent': monthlyRent,
        'deposit_amount': depositAmount,
        'address_line': addressLine.trim(),
        'postcode': postcode.trim(),
        'city': city.trim(),
        'state': state.trim(),
        'bedrooms': bedrooms,
        'bathrooms': bathrooms,
        'furnishing': furnishing,
        'gender_preference': genderPreference,
        'available_from': _date(availableFrom),
        'amenities': amenities,
        'contact_name': contactName.trim(),
        'contact_phone': contactPhone.trim(),
        'status': status,
        'is_featured': isFeatured,
      };

  static String _date(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

class RoomListingService {
  const RoomListingService(this.client);

  final SupabaseClient client;

  Future<List<RoomListing>> loadPublished() async {
    final rows = await client
        .from('room_listings')
        .select()
        .eq('status', 'published')
        .order('is_featured', ascending: false)
        .order('created_at', ascending: false)
        .limit(100);
    return _hydrate(rows);
  }

  Future<List<RoomListing>> loadMine() async {
    final user = _user();
    final rows = await client
        .from('room_listings')
        .select()
        .eq('publisher_id', user.id)
        .order('updated_at', ascending: false);
    return _hydrate(rows);
  }

  Future<RoomListing> save({
    String? listingId,
    required RoomListingDraft draft,
    List<String> retainedImagePaths = const [],
    List<PickedImageData> newImages = const [],
  }) async {
    final user = _user();
    late final String id;
    if (listingId == null) {
      final row = await client
          .from('room_listings')
          .insert(draft.toMap(user.id))
          .select('id')
          .single();
      id = row['id'] as String;
    } else {
      id = listingId;
      await client
          .from('room_listings')
          .update(draft.toMap(user.id))
          .eq('id', id)
          .eq('publisher_id', user.id);
    }

    final uploaded = await _uploadImages(id, newImages);
    final paths = [...retainedImagePaths, ...uploaded].take(6).toList();
    final row = await client
        .from('room_listings')
        .update({'image_paths': paths})
        .eq('id', id)
        .eq('publisher_id', user.id)
        .select()
        .single();
    return _hydrateOne(RoomListing.fromMap(Map<String, dynamic>.from(row)));
  }

  Future<void> updateStatus(String listingId, String status) async {
    final user = _user();
    await client
        .from('room_listings')
        .update({'status': status})
        .eq('id', listingId)
        .eq('publisher_id', user.id);
  }

  Future<void> delete(RoomListing listing) async {
    final user = _user();
    await client
        .from('room_listings')
        .delete()
        .eq('id', listing.id)
        .eq('publisher_id', user.id);
    if (listing.imagePaths.isNotEmpty) {
      await client.storage.from(roomListingBucket).remove(listing.imagePaths);
    }
  }

  Future<List<RoomListing>> _hydrate(List<dynamic> rows) async =>
      Future.wait(rows.map((row) => _hydrateOne(
            RoomListing.fromMap(Map<String, dynamic>.from(row as Map)),
          )));

  Future<RoomListing> _hydrateOne(RoomListing listing) async {
    final urls = <String>[];
    for (final path in listing.imagePaths.take(6)) {
      try {
        final url = await client.storage
            .from(roomListingBucket)
            .createSignedUrl(path, 60 * 60);
        if (url.isNotEmpty) urls.add(url);
      } catch (_) {
        // A missing image must not hide the rest of the listing.
      }
    }
    return listing.withImageUrls(urls);
  }

  Future<List<String>> _uploadImages(
    String listingId,
    List<PickedImageData> images,
  ) async {
    final user = _user();
    final paths = <String>[];
    for (var index = 0; index < images.length && index < 6; index++) {
      final image = images[index];
      if (image.bytes.isEmpty || image.bytes.length > 5 * 1024 * 1024) {
        throw const StorageException(
            'Each room photo must be smaller than 5 MB.');
      }
      final extension = _extension(image.name);
      final path =
          '${user.id}/$listingId/${DateTime.now().microsecondsSinceEpoch}-$index.$extension';
      await client.storage.from(roomListingBucket).uploadBinary(
            path,
            Uint8List.fromList(image.bytes),
            fileOptions: FileOptions(
              contentType: _mime(extension),
              upsert: false,
            ),
          );
      paths.add(path);
    }
    return paths;
  }

  User _user() {
    final user = client.auth.currentUser;
    if (user == null) {
      throw const AuthException('Please sign in to use the room marketplace.');
    }
    return user;
  }

  static String _extension(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'png';
    if (lower.endsWith('.webp')) return 'webp';
    return 'jpg';
  }

  static String _mime(String extension) => switch (extension) {
        'png' => 'image/png',
        'webp' => 'image/webp',
        _ => 'image/jpeg',
      };
}
