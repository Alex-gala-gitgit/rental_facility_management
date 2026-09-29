import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../cloud/room_listing_service.dart';
import '../file_upload/image_file_picker.dart';

const _ink = Color(0xFF111827);
const _muted = Color(0xFF667085);
const _blue = Color(0xFF2574D9);
const _canvas = Color(0xFFF5F7FB);

class TenantExploreTab extends StatefulWidget {
  const TenantExploreTab({required this.languageCode, super.key});

  final String languageCode;

  @override
  State<TenantExploreTab> createState() => _TenantExploreTabState();
}

class _TenantExploreTabState extends State<TenantExploreTab> {
  // Explore is live: signed-in tenants can browse all published owner and
  // agent listings, with featured properties sorted first.
  static const maintenanceMode = false;
  final queryController = TextEditingController();
  final savedIds = <String>{};
  late Future<List<RoomListing>> listingsFuture;
  String filter = 'For you';

  String maintenanceCopy(String english) {
    const chinese = {
      'Explore is under maintenance': '探索目前正在维护',
      'Room browsing is temporarily closed while we improve listing quality and safety.':
          '我们正在提升房源质量与安全，因此暂时关闭浏览功能。',
      'Owners can continue preparing and promoting other available properties. They will appear here when Explore reopens.':
          '业主仍可继续准备并推广其他可出租房产。探索重新开放后，这些房源会显示在这里。',
    };
    const malay = {
      'Explore is under maintenance': 'Explore sedang diselenggara',
      'Room browsing is temporarily closed while we improve listing quality and safety.':
          'Pelayaran bilik ditutup sementara kami meningkatkan kualiti dan keselamatan iklan.',
      'Owners can continue preparing and promoting other available properties. They will appear here when Explore reopens.':
          'Pemilik boleh terus menyediakan dan mempromosikan hartanah lain yang tersedia. Iklan akan dipaparkan apabila Explore dibuka semula.',
    };
    return switch (widget.languageCode) {
      'chinese' => chinese[english] ?? english,
      'malay' => malay[english] ?? english,
      _ => english,
    };
  }

  RoomListingService get service =>
      RoomListingService(Supabase.instance.client);

  @override
  void initState() {
    super.initState();
    listingsFuture = maintenanceMode
        ? Future<List<RoomListing>>.value(const [])
        : service.loadPublished();
  }

  @override
  void dispose() {
    queryController.dispose();
    super.dispose();
  }

  Future<void> refresh() async {
    final future = service.loadPublished();
    setState(() => listingsFuture = future);
    await future;
  }

  List<RoomListing> filtered(List<RoomListing> source) {
    final query = queryController.text.trim().toLowerCase();
    final results = source.where((listing) {
      if (query.isNotEmpty &&
          ![
            listing.title,
            listing.description,
            listing.city,
            listing.state,
            listing.roomType,
            ...listing.amenities,
          ].join(' ').toLowerCase().contains(query)) {
        return false;
      }
      return switch (filter) {
        'Under RM800' => listing.monthlyRent < 800,
        'Whole unit' => listing.roomType == 'Whole unit',
        'Move in now' => !listing.availableFrom.isAfter(DateTime.now()),
        'Saved' => savedIds.contains(listing.id),
        _ => true,
      };
    }).toList();
    if (filter == 'Lowest rent') {
      results.sort((a, b) => a.monthlyRent.compareTo(b.monthlyRent));
    }
    return results;
  }

  @override
  Widget build(BuildContext context) {
    if (maintenanceMode) {
      return ColoredBox(
        color: _canvas,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(26),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF3FF),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: const Icon(
                          Icons.construction_rounded,
                          color: _blue,
                          size: 36,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        maintenanceCopy('Explore is under maintenance'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _ink,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 9),
                      Text(
                        maintenanceCopy(
                            'Room browsing is temporarily closed while we improve listing quality and safety.'),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: _muted, height: 1.45),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(13),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F8F4),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.campaign_outlined,
                                color: Color(0xFF16856B), size: 20),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Text(
                                maintenanceCopy(
                                    'Owners can continue preparing and promoting other available properties. They will appear here when Explore reopens.'),
                                style: const TextStyle(
                                    color: Color(0xFF16624F), height: 1.4),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
    return ColoredBox(
      color: Colors.white,
      child: RefreshIndicator(
        onRefresh: refresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _header()),
            FutureBuilder<List<RoomListing>>(
              future: listingsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: _ExploreMessage(
                      icon: Icons.cloud_off_rounded,
                      title: 'Explore is unavailable',
                      message: _friendlyError(snapshot.error),
                      actionLabel: 'Try again',
                      onAction: refresh,
                    ),
                  );
                }
                final items = filtered(snapshot.data ?? const []);
                if (items.isEmpty) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: _ExploreMessage(
                      icon: filter == 'Saved'
                          ? Icons.favorite_border_rounded
                          : Icons.home_work_outlined,
                      title: filter == 'Saved'
                          ? 'No saved rooms yet'
                          : 'No rooms match this search',
                      message: filter == 'Saved'
                          ? 'Tap the heart on a room to keep it here.'
                          : 'Try another location or filter. New owner and agent posts will appear here.',
                    ),
                  );
                }
                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(10, 4, 10, 28),
                  sliver: SliverGrid(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final listing = items[index];
                        return _ExploreRoomCard(
                          listing: listing,
                          saved: savedIds.contains(listing.id),
                          onSaved: () => setState(() {
                            if (!savedIds.add(listing.id)) {
                              savedIds.remove(listing.id);
                            }
                          }),
                          onTap: () => Navigator.of(context).push<void>(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  RoomListingDetailScreen(listing: listing),
                            ),
                          ),
                        );
                      },
                      childCount: items.length,
                    ),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 10,
                      childAspectRatio: 0.59,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() => Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Explore rooms',
                          style: TextStyle(
                            color: _ink,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.6,
                          )),
                      Text('Real spaces from verified HomeOps360 hosts',
                          style: TextStyle(color: _muted, fontSize: 12)),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF3FF),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.verified_user_outlined,
                          color: _blue, size: 16),
                      SizedBox(width: 5),
                      Text('Signed-in only',
                          style: TextStyle(
                              color: _blue,
                              fontSize: 10,
                              fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: queryController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search area, room type or amenity',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: queryController.text.isEmpty
                    ? const Icon(Icons.tune_rounded, size: 20)
                    : IconButton(
                        onPressed: () {
                          queryController.clear();
                          setState(() {});
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
                fillColor: _canvas,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 37,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final item in const [
                    'For you',
                    'Move in now',
                    'Under RM800',
                    'Whole unit',
                    'Lowest rent',
                    'Saved',
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 7),
                      child: ChoiceChip(
                        label: Text(item),
                        selected: filter == item,
                        showCheckmark: false,
                        onSelected: (_) => setState(() => filter = item),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _ExploreRoomCard extends StatelessWidget {
  const _ExploreRoomCard({
    required this.listing,
    required this.saved,
    required this.onSaved,
    required this.onTap,
  });

  final RoomListing listing;
  final bool saved;
  final VoidCallback onSaved;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 6,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _ListingImage(url: listing.imageUrls.firstOrNull),
                    Positioned(
                      left: 8,
                      bottom: 8,
                      child: _TinyBadge(
                        label: listing.roomType,
                        color: Colors.white.withOpacity(0.92),
                      ),
                    ),
                    Positioned(
                      right: 7,
                      top: 7,
                      child: Material(
                        color: Colors.white.withOpacity(0.92),
                        shape: const CircleBorder(),
                        child: IconButton(
                          constraints: const BoxConstraints.tightFor(
                              width: 34, height: 34),
                          padding: EdgeInsets.zero,
                          onPressed: onSaved,
                          icon: Icon(
                            saved
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            size: 19,
                            color: saved ? const Color(0xFFE84C5B) : _ink,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 5,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(9, 8, 9, 9),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        listing.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _ink,
                          fontSize: 13,
                          height: 1.2,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                          'RM ${listing.monthlyRent.toStringAsFixed(0)} / month',
                          style: const TextStyle(
                            color: _blue,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          )),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined,
                              size: 13, color: _muted),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Text(
                              listing.location,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  const TextStyle(color: _muted, fontSize: 10),
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 10,
                            backgroundColor: const Color(0xFFEAF3FF),
                            child: Text(
                              listing.publisherName.isEmpty
                                  ? 'H'
                                  : listing.publisherName[0].toUpperCase(),
                              style: const TextStyle(
                                  color: _blue,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900),
                            ),
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              listing.publisherName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  const TextStyle(color: _muted, fontSize: 9),
                            ),
                          ),
                          const Icon(Icons.verified_rounded,
                              size: 13, color: _blue),
                        ],
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

class RoomListingDetailScreen extends StatefulWidget {
  const RoomListingDetailScreen({required this.listing, super.key});

  final RoomListing listing;

  @override
  State<RoomListingDetailScreen> createState() =>
      _RoomListingDetailScreenState();
}

class _RoomListingDetailScreenState extends State<RoomListingDetailScreen> {
  int photoIndex = 0;

  RoomListing get listing => widget.listing;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text('Room details'),
          backgroundColor: Colors.white,
          actions: [
            IconButton(
              tooltip: 'Share',
              onPressed: () async {
                await Clipboard.setData(ClipboardData(
                  text:
                      '${listing.title}\nRM ${listing.monthlyRent.toStringAsFixed(0)} / month\n${listing.location}',
                ));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Listing summary copied.')),
                  );
                }
              },
              icon: const Icon(Icons.ios_share_rounded),
            ),
          ],
        ),
        body: ListView(
          padding: EdgeInsets.zero,
          children: [
            AspectRatio(
              aspectRatio: 1.15,
              child: Stack(
                children: [
                  if (listing.imageUrls.isEmpty)
                    const Positioned.fill(child: _ListingImage())
                  else
                    Positioned.fill(
                      child: PageView.builder(
                        itemCount: listing.imageUrls.length,
                        onPageChanged: (value) =>
                            setState(() => photoIndex = value),
                        itemBuilder: (_, index) =>
                            _ListingImage(url: listing.imageUrls[index]),
                      ),
                    ),
                  if (listing.imageUrls.length > 1)
                    Positioned(
                      right: 14,
                      bottom: 14,
                      child: _TinyBadge(
                        label: '${photoIndex + 1}/${listing.imageUrls.length}',
                        color: const Color(0xCC111827),
                        foreground: Colors.white,
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(listing.title,
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 24,
                        height: 1.15,
                        fontWeight: FontWeight.w900,
                      )),
                  const SizedBox(height: 8),
                  Text('RM ${listing.monthlyRent.toStringAsFixed(0)} / month',
                      style: const TextStyle(
                        color: _blue,
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                      )),
                  const SizedBox(height: 10),
                  Row(children: [
                    const Icon(Icons.location_on_outlined,
                        color: _muted, size: 18),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        [
                          listing.addressLine,
                          listing.postcode,
                          listing.location
                        ].where((item) => item.trim().isNotEmpty).join(', '),
                        style: const TextStyle(color: _muted),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _InfoPill(Icons.home_work_outlined, listing.propertyType),
                      _InfoPill(Icons.bed_outlined, listing.roomType),
                      _InfoPill(Icons.chair_outlined, listing.furnishing),
                      _InfoPill(Icons.people_outline_rounded,
                          '${listing.genderPreference} tenant'),
                    ],
                  ),
                  const SizedBox(height: 22),
                  const Divider(),
                  const SizedBox(height: 14),
                  const Text('About this room',
                      style: TextStyle(
                          color: _ink,
                          fontSize: 17,
                          fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  Text(
                    listing.description.isEmpty
                        ? 'Contact the host for more information about this room.'
                        : listing.description,
                    style: const TextStyle(color: _ink, height: 1.55),
                  ),
                  if (listing.amenities.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const Text('Amenities',
                        style: TextStyle(
                            color: _ink,
                            fontSize: 17,
                            fontWeight: FontWeight.w900)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: listing.amenities
                          .map((item) => Chip(label: Text(item)))
                          .toList(),
                    ),
                  ],
                  const SizedBox(height: 22),
                  Card(
                    color: const Color(0xFFF7FAFE),
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFE3F0FF),
                        child: Icon(Icons.person_rounded, color: _blue),
                      ),
                      title: Text(listing.publisherName,
                          style: const TextStyle(fontWeight: FontWeight.w900)),
                      subtitle: Text(
                          '${listing.publisherRole == 'property_agent' ? 'Property agent' : 'Owner'} · HomeOps360 verified account'),
                      trailing:
                          const Icon(Icons.verified_rounded, color: _blue),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _contact,
                      icon: const Icon(Icons.chat_bubble_outline_rounded),
                      label: Text('WhatsApp ${listing.contactName}'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Safety reminder: view the room and verify the host before transferring any deposit.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _muted, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Future<void> _contact() async {
    final digits = listing.contactPhone.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('The publisher did not provide a valid contact number.')),
      );
      return;
    }
    final message = Uri.encodeComponent(
      'Hi ${listing.contactName}, I found your "${listing.title}" listing on HomeOps360 Explore. Is it still available?',
    );
    final uri = Uri.parse('https://wa.me/$digits?text=$message');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('WhatsApp could not be opened.')),
      );
    }
  }
}

class RoomListingFacilityOption {
  const RoomListingFacilityOption({
    required this.id,
    required this.name,
    required this.addressLine,
    required this.postcode,
    required this.city,
    required this.state,
  });

  final String id;
  final String name;
  final String addressLine;
  final String postcode;
  final String city;
  final String state;
}

class RoomListingManagerScreen extends StatefulWidget {
  const RoomListingManagerScreen({
    required this.facilities,
    required this.publisherName,
    required this.contactPhone,
    required this.listingLimit,
    super.key,
  });

  final List<RoomListingFacilityOption> facilities;
  final String publisherName;
  final String contactPhone;
  final int listingLimit;

  @override
  State<RoomListingManagerScreen> createState() =>
      _RoomListingManagerScreenState();
}

class _RoomListingManagerScreenState extends State<RoomListingManagerScreen> {
  late Future<List<RoomListing>> future;
  RoomListingService get service =>
      RoomListingService(Supabase.instance.client);

  @override
  void initState() {
    super.initState();
    future = service.loadMine();
  }

  void reload() => setState(() => future = service.loadMine());

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: _canvas,
        appBar: AppBar(
          title: const Text('Room listings'),
          actions: [
            IconButton(
              tooltip: 'New listing',
              onPressed: () => edit(),
              icon: const Icon(Icons.add_rounded),
            ),
          ],
        ),
        body: FutureBuilder<List<RoomListing>>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _ExploreMessage(
                icon: Icons.cloud_off_rounded,
                title: 'Listings are unavailable',
                message: _friendlyError(snapshot.error),
                actionLabel: 'Try again',
                onAction: reload,
              );
            }
            final listings = snapshot.data ?? const [];
            if (listings.isEmpty) {
              return _ExploreMessage(
                icon: Icons.add_home_work_outlined,
                title: 'Publish your first room',
                message:
                    'Add photos, rent, location and availability. Published posts appear in every tenant Explore feed.',
                actionLabel: 'Create listing',
                onAction: () => edit(),
              );
            }
            return RefreshIndicator(
              onRefresh: () async {
                reload();
                await future;
              },
              child: ListView.separated(
                padding: const EdgeInsets.all(14),
                itemCount: listings.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, index) => _ManagerListingCard(
                  listing: listings[index],
                  onEdit: () => edit(listings[index]),
                  onStatus: (status) async {
                    await service.updateStatus(listings[index].id, status);
                    reload();
                  },
                  onDelete: () => remove(listings[index]),
                ),
              ),
            );
          },
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => edit(),
          child: const Icon(Icons.add_rounded),
        ),
      );

  Future<void> edit([RoomListing? listing]) async {
    if (listing == null) {
      final existing = await service.loadMine();
      if (!mounted) return;
      if (existing.length >= widget.listingLimit) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            'Your account limit is ${widget.listingLimit} Explore listings. Contact HomeOps360 administration to increase it.',
          ),
        ));
        return;
      }
    }
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => RoomListingEditorScreen(
          facilities: widget.facilities,
          publisherName: widget.publisherName,
          contactPhone: widget.contactPhone,
          listing: listing,
        ),
      ),
    );
    if (changed == true) reload();
  }

  Future<void> remove(RoomListing listing) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Delete listing?'),
            content: Text(
                '“${listing.title}” and its uploaded photos will be removed.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel')),
              FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Delete')),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    await service.delete(listing);
    reload();
  }
}

class _ManagerListingCard extends StatelessWidget {
  const _ManagerListingCard({
    required this.listing,
    required this.onEdit,
    required this.onStatus,
    required this.onDelete,
  });

  final RoomListing listing;
  final VoidCallback onEdit;
  final ValueChanged<String> onStatus;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: SizedBox(
                  width: 92,
                  height: 108,
                  child: _ListingImage(url: listing.imageUrls.firstOrNull),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text(listing.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style:
                                const TextStyle(fontWeight: FontWeight.w900)),
                      ),
                      PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'edit') onEdit();
                          if (value == 'delete') onDelete();
                          if (value.startsWith('status:')) {
                            onStatus(value.substring(7));
                          }
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                              value: 'edit', child: Text('Edit')),
                          PopupMenuItem(
                            value: listing.isPublished
                                ? 'status:archived'
                                : 'status:published',
                            child: Text(
                                listing.isPublished ? 'Unpublish' : 'Publish'),
                          ),
                          const PopupMenuItem(
                              value: 'status:rented',
                              child: Text('Mark rented')),
                          const PopupMenuDivider(),
                          const PopupMenuItem(
                              value: 'delete', child: Text('Delete')),
                        ],
                      ),
                    ]),
                    const SizedBox(height: 5),
                    Row(children: [
                      _TinyBadge(
                        label: listing.status == 'published'
                            ? 'Published'
                            : listing.status == 'rented'
                                ? 'Rented'
                                : listing.status == 'archived'
                                    ? 'Archived'
                                    : 'Draft',
                        color: listing.isPublished
                            ? const Color(0xFFE7F7ED)
                            : const Color(0xFFF0F2F5),
                        foreground: listing.isPublished
                            ? const Color(0xFF19703A)
                            : _muted,
                      ),
                      const SizedBox(width: 7),
                      if (listing.isFeatured) ...[
                        const _TinyBadge(
                          label: 'Promoted',
                          color: Color(0xFFFFF4E5),
                          foreground: Color(0xFFB54708),
                        ),
                        const SizedBox(width: 7),
                      ],
                      Text('RM ${listing.monthlyRent.toStringAsFixed(0)}',
                          style: const TextStyle(
                              color: _blue, fontWeight: FontWeight.w900)),
                    ]),
                    const SizedBox(height: 7),
                    Text(listing.location,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: _muted, fontSize: 11)),
                    const SizedBox(height: 9),
                    Row(children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: onEdit,
                          child: const Text('Edit'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => onStatus(
                              listing.isPublished ? 'archived' : 'published'),
                          child: Text(
                              listing.isPublished ? 'Unpublish' : 'Publish'),
                        ),
                      ),
                    ]),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

class RoomListingEditorScreen extends StatefulWidget {
  const RoomListingEditorScreen({
    required this.facilities,
    required this.publisherName,
    required this.contactPhone,
    this.listing,
    super.key,
  });

  final List<RoomListingFacilityOption> facilities;
  final String publisherName;
  final String contactPhone;
  final RoomListing? listing;

  @override
  State<RoomListingEditorScreen> createState() =>
      _RoomListingEditorScreenState();
}

class _RoomListingEditorScreenState extends State<RoomListingEditorScreen> {
  final formKey = GlobalKey<FormState>();
  late final title = TextEditingController(text: widget.listing?.title ?? '');
  late final description =
      TextEditingController(text: widget.listing?.description ?? '');
  late final rent = TextEditingController(
      text: widget.listing?.monthlyRent.toStringAsFixed(0) ?? '');
  late final deposit = TextEditingController(
      text: widget.listing?.depositAmount.toStringAsFixed(0) ?? '0');
  late final address =
      TextEditingController(text: widget.listing?.addressLine ?? '');
  late final postcode =
      TextEditingController(text: widget.listing?.postcode ?? '');
  late final city = TextEditingController(text: widget.listing?.city ?? '');
  late final state = TextEditingController(text: widget.listing?.state ?? '');
  late final contactName = TextEditingController(
      text: widget.listing?.contactName ?? widget.publisherName);
  late final contactPhone = TextEditingController(
      text: widget.listing?.contactPhone ?? widget.contactPhone);
  late String propertyType = widget.listing?.propertyType ?? 'Condominium';
  late String roomType = widget.listing?.roomType ?? 'Private room';
  late String furnishing = widget.listing?.furnishing ?? 'Partly furnished';
  late String gender = widget.listing?.genderPreference ?? 'Any';
  late DateTime availableFrom = widget.listing?.availableFrom ?? DateTime.now();
  late String status = widget.listing?.status ?? 'draft';
  late bool isFeatured = widget.listing?.isFeatured ?? false;
  late String? facilityId = widget.listing?.sourceFacilityId;
  late final retainedPaths = [...?widget.listing?.imagePaths];
  final newImages = <PickedImageData>[];
  final amenities = <String>{};
  bool saving = false;

  static const amenityOptions = [
    'Wi-Fi',
    'Air conditioning',
    'Washing machine',
    'Water heater',
    'Parking',
    'Gym',
    'Pool',
    'Security',
    'Cooking allowed',
    'Near public transport',
  ];

  @override
  void initState() {
    super.initState();
    amenities.addAll(widget.listing?.amenities ?? const []);
  }

  @override
  void dispose() {
    for (final controller in [
      title,
      description,
      rent,
      deposit,
      address,
      postcode,
      city,
      state,
      contactName,
      contactPhone,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: _canvas,
        appBar: AppBar(
          title: Text(
              widget.listing == null ? 'New room listing' : 'Edit listing'),
        ),
        body: Form(
          key: formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _section(
                'Room photos',
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 94,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          for (var index = 0;
                              index < retainedPaths.length;
                              index++)
                            _PhotoToken(
                              label: 'Saved photo ${index + 1}',
                              onRemove: () =>
                                  setState(() => retainedPaths.removeAt(index)),
                            ),
                          for (var index = 0; index < newImages.length; index++)
                            _PhotoToken(
                              label: newImages[index].name,
                              onRemove: () =>
                                  setState(() => newImages.removeAt(index)),
                            ),
                          if (retainedPaths.length + newImages.length < 6)
                            InkWell(
                              onTap: addPhoto,
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                width: 94,
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEAF3FF),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                      color: const Color(0xFFBFD7F5)),
                                ),
                                child: const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.add_photo_alternate_outlined,
                                        color: _blue),
                                    SizedBox(height: 4),
                                    Text('Add photo',
                                        style: TextStyle(
                                            color: _blue,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800)),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 7),
                    const Text(
                        'Up to 6 JPG, PNG or WebP photos · maximum 5 MB each',
                        style: TextStyle(color: _muted, fontSize: 10)),
                  ],
                ),
              ),
              _section(
                'Listing basics',
                Column(children: [
                  if (widget.facilities.isNotEmpty)
                    DropdownButtonFormField<String?>(
                      value: facilityId,
                      decoration: const InputDecoration(
                          labelText: 'Use property details (optional)'),
                      items: [
                        const DropdownMenuItem<String?>(
                            value: null, child: Text('Enter another property')),
                        ...widget.facilities
                            .map((facility) => DropdownMenuItem<String?>(
                                  value: facility.id,
                                  child: Text(facility.name),
                                )),
                      ],
                      onChanged: applyFacility,
                    ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: title,
                    maxLength: 120,
                    decoration: const InputDecoration(
                        labelText: 'Listing title',
                        hintText: 'Bright master room near MRT'),
                    validator: (value) => (value?.trim().length ?? 0) < 5
                        ? 'Enter at least 5 characters.'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: description,
                    maxLines: 5,
                    maxLength: 3000,
                    decoration: const InputDecoration(
                        labelText: 'Description',
                        hintText: 'Tell tenants what makes the room special.'),
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                        child: _dropdown(
                            'Property type',
                            propertyType,
                            const [
                              'Condominium',
                              'Apartment',
                              'Terrace',
                              'Studio',
                              'Shoplot'
                            ],
                            (value) => setState(() => propertyType = value))),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _dropdown(
                            'Room type',
                            roomType,
                            const [
                              'Private room',
                              'Master room',
                              'Shared room',
                              'Whole unit'
                            ],
                            (value) => setState(() => roomType = value))),
                  ]),
                ]),
              ),
              _section(
                'Rent & availability',
                Column(children: [
                  Row(children: [
                    Expanded(
                        child: _moneyField(rent, 'Monthly rent (RM)', false)),
                    const SizedBox(width: 10),
                    Expanded(child: _moneyField(deposit, 'Deposit (RM)', true)),
                  ]),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: const BorderSide(color: Color(0xFFD6DEEB)),
                    ),
                    leading: const Icon(Icons.event_available_rounded),
                    title: const Text('Available from'),
                    subtitle: Text(_dateLabel(availableFrom)),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: chooseDate,
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                        child: _dropdown(
                            'Furnishing',
                            furnishing,
                            const [
                              'Fully furnished',
                              'Partly furnished',
                              'Unfurnished'
                            ],
                            (value) => setState(() => furnishing = value))),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _dropdown(
                            'Tenant preference',
                            gender,
                            const ['Any', 'Female', 'Male', 'Couple'],
                            (value) => setState(() => gender = value))),
                  ]),
                ]),
              ),
              _section(
                'Location',
                Column(children: [
                  TextFormField(
                    controller: address,
                    decoration: const InputDecoration(labelText: 'Address'),
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: postcode,
                        keyboardType: TextInputType.number,
                        decoration:
                            const InputDecoration(labelText: 'Postcode'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: city,
                        decoration: const InputDecoration(labelText: 'City'),
                        validator: requiredValue,
                      ),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: state,
                    decoration: const InputDecoration(labelText: 'State'),
                    validator: requiredValue,
                  ),
                ]),
              ),
              _section(
                'Amenities',
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: amenityOptions
                      .map((item) => FilterChip(
                            label: Text(item),
                            selected: amenities.contains(item),
                            onSelected: (selected) => setState(() => selected
                                ? amenities.add(item)
                                : amenities.remove(item)),
                          ))
                      .toList(),
                ),
              ),
              _section(
                'Contact & publishing',
                Column(children: [
                  TextFormField(
                    controller: contactName,
                    decoration:
                        const InputDecoration(labelText: 'Contact name'),
                    validator: requiredValue,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: contactPhone,
                    keyboardType: TextInputType.phone,
                    decoration:
                        const InputDecoration(labelText: 'WhatsApp / phone'),
                    validator: (value) =>
                        (value ?? '').replaceAll(RegExp(r'\D'), '').length < 8
                            ? 'Enter a valid phone number.'
                            : null,
                  ),
                  const SizedBox(height: 12),
                  _dropdown(
                      'Post status',
                      status,
                      const ['draft', 'published', 'archived'],
                      (value) => setState(() => status = value)),
                  const SizedBox(height: 8),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: isFeatured,
                    onChanged: (value) => setState(() => isFeatured = value),
                    title: const Text('Promote this property'),
                    subtitle: const Text(
                      'Show this listing before standard posts when tenant Explore reopens.',
                    ),
                    secondary: const Icon(Icons.campaign_outlined),
                  ),
                ]),
              ),
              const SizedBox(height: 4),
              FilledButton.icon(
                onPressed: saving ? null : save,
                icon: saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(status == 'published'
                        ? Icons.public_rounded
                        : Icons.save_outlined),
                label: Text(saving
                    ? 'Saving…'
                    : status == 'published'
                        ? 'Save & publish'
                        : 'Save listing'),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      );

  Widget _section(String titleText, Widget child) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titleText,
                    style: const TextStyle(
                        color: _ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w900)),
                const SizedBox(height: 13),
                child,
              ],
            ),
          ),
        ),
      );

  Widget _dropdown(
    String label,
    String value,
    List<String> values,
    ValueChanged<String> changed,
  ) =>
      DropdownButtonFormField<String>(
        value: value,
        isExpanded: true,
        decoration: InputDecoration(labelText: label),
        items: values
            .map((item) => DropdownMenuItem(value: item, child: Text(item)))
            .toList(),
        onChanged: (item) {
          if (item != null) changed(item);
        },
      );

  Widget _moneyField(
          TextEditingController controller, String label, bool allowZero) =>
      TextFormField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))
        ],
        decoration: InputDecoration(labelText: label),
        validator: (value) {
          final parsed = double.tryParse(value ?? '');
          if (parsed == null || parsed < 0 || (!allowZero && parsed <= 0)) {
            return 'Enter a valid amount.';
          }
          return null;
        },
      );

  String? requiredValue(String? value) =>
      value?.trim().isEmpty ?? true ? 'This field is required.' : null;

  void applyFacility(String? id) {
    setState(() => facilityId = id);
    if (id == null) return;
    final facility = widget.facilities.firstWhere((item) => item.id == id);
    address.text = facility.addressLine;
    postcode.text = facility.postcode;
    city.text = facility.city;
    state.text = facility.state;
  }

  Future<void> addPhoto() async {
    final image = await pickImageForUpload();
    if (image == null || !mounted) return;
    if (image.bytes.length > 5 * 1024 * 1024) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Each room photo must be smaller than 5 MB.')),
      );
      return;
    }
    setState(() => newImages.add(image));
  }

  Future<void> chooseDate() async {
    final chosen = await showDatePicker(
      context: context,
      initialDate: availableFrom,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (chosen != null) setState(() => availableFrom = chosen);
  }

  Future<void> save() async {
    if (!(formKey.currentState?.validate() ?? false)) return;
    if (status == 'published' && retainedPaths.isEmpty && newImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Add at least one photo before publishing.')),
      );
      return;
    }
    setState(() => saving = true);
    try {
      await RoomListingService(Supabase.instance.client).save(
        listingId: widget.listing?.id,
        retainedImagePaths: retainedPaths,
        newImages: newImages,
        draft: RoomListingDraft(
          title: title.text,
          description: description.text,
          propertyType: propertyType,
          roomType: roomType,
          monthlyRent: double.parse(rent.text),
          depositAmount: double.parse(deposit.text),
          addressLine: address.text,
          postcode: postcode.text,
          city: city.text,
          state: state.text,
          bedrooms: roomType == 'Whole unit' ? 1 : 0,
          bathrooms: 1,
          furnishing: furnishing,
          genderPreference: gender,
          availableFrom: availableFrom,
          amenities: amenities.toList()..sort(),
          contactName: contactName.text,
          contactPhone: contactPhone.text,
          status: status,
          isFeatured: isFeatured,
          sourceFacilityId: facilityId,
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyError(error))),
      );
      setState(() => saving = false);
    }
  }
}

class _PhotoToken extends StatelessWidget {
  const _PhotoToken({required this.label, required this.onRemove});

  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => Container(
        width: 94,
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFF86BDF1), Color(0xFF286FC3)]),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Stack(
          children: [
            const Align(
              alignment: Alignment.center,
              child: Icon(Icons.image_rounded, color: Colors.white, size: 30),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 9)),
            ),
            Align(
              alignment: Alignment.topRight,
              child: InkWell(
                onTap: onRemove,
                child: const Icon(Icons.cancel_rounded,
                    color: Colors.white, size: 19),
              ),
            ),
          ],
        ),
      );
}

class _ListingImage extends StatelessWidget {
  const _ListingImage({this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFD9EBFC), Color(0xFF8ABDEB), Color(0xFF377FC8)],
        ),
      ),
      child: const Center(
        child:
            Icon(Icons.bedroom_parent_rounded, color: Colors.white, size: 48),
      ),
    );
    if (url == null || url!.isEmpty) return fallback;
    return Image.network(
      url!,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => fallback,
    );
  }
}

class _TinyBadge extends StatelessWidget {
  const _TinyBadge({
    required this.label,
    required this.color,
    this.foreground = _ink,
  });

  final String label;
  final Color color;
  final Color foreground;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
            color: color, borderRadius: BorderRadius.circular(20)),
        child: Text(label,
            style: TextStyle(
                color: foreground, fontSize: 9, fontWeight: FontWeight.w800)),
      );
}

class _InfoPill extends StatelessWidget {
  const _InfoPill(this.icon, this.label);

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF2F6FB),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: _blue),
          const SizedBox(width: 5),
          Text(label,
              style:
                  const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
        ]),
      );
}

class _ExploreMessage extends StatelessWidget {
  const _ExploreMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 58, color: const Color(0xFF76AEE5)),
              const SizedBox(height: 14),
              Text(title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: _ink, fontSize: 19, fontWeight: FontWeight.w900)),
              const SizedBox(height: 7),
              Text(message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: _muted, height: 1.4)),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 16),
                FilledButton(onPressed: onAction, child: Text(actionLabel!)),
              ],
            ],
          ),
        ),
      );
}

String _dateLabel(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

String _friendlyError(Object? error) {
  final message = error
      .toString()
      .replaceFirst('PostgrestException(message: ', '')
      .replaceFirst('AuthException(message: ', '')
      .replaceFirst('StorageException(message: ', '')
      .split(', code:')
      .first
      .replaceAll(')', '')
      .trim();
  if (message.contains('room_listings') || message.contains('room-listings')) {
    return 'The room marketplace has not been enabled on this environment yet.';
  }
  return message.isEmpty ? 'Please try again.' : message;
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
