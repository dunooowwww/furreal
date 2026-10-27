import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../shared/analytics.dart';
import '../../../shared/errors.dart';
import '../../../shared/widgets/discard_photos_dialog.dart';
import '../../../shared/widgets/error_text.dart';
import '../../camera/data/captured_photos.dart';
import '../data/ai_identification.dart';
import '../data/area_locator.dart';
import '../data/catch_repository.dart';
import '../../../shared/widgets/remote_photo.dart';
import '../../collection/data/collection_models.dart';
import '../../collection/state/collection_providers.dart';
import '../../feed/state/feed_providers.dart';
import '../state/catch_providers.dart';

enum _Phase { uploading, identifying, uploadFailed, ready }

/// Hasil tangkapan: upload foto → AI kenali hewan → user koreksi → posting.
class CatchResultScreen extends ConsumerStatefulWidget {
  const CatchResultScreen({super.key, required this.photos});

  final CapturedPhotos photos;

  @override
  ConsumerState<CatchResultScreen> createState() => _CatchResultScreenState();
}

class _CatchResultScreenState extends ConsumerState<CatchResultScreen> {
  // Disimpan supaya tetap bisa dipakai di dispose().
  late final CatchRepository _repository = ref.read(catchRepositoryProvider);
  final _name = TextEditingController();
  final _manualType = TextEditingController();
  final _personality = TextEditingController();

  _Phase _phase = _Phase.uploading;
  PreparedCatch? _prepared;
  bool _posted = false;
  String? _uploadError;

  AiIdentification? _ai;
  AiFailure? _aiFailure;
  String? _pickedType;
  bool _manual = false;

  /// "ketemu lagi" hewan lama milik sendiri.
  bool _reencounter = false;
  CollectionAnimal? _existing;

  AnimalKind _kind = AnimalKind.pet;
  AreaResult? _area;
  bool _hideLocation = false;
  bool _posting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _locate();
    _prepareAndIdentify();
  }

  @override
  void dispose() {
    // Batal posting (foto ulang atau back, setelah dikonfirmasi): buang foto
    // yang sudah ter-upload. Kalau posting sebenarnya berhasil tapi balasannya
    // hilang, server menolak menghapus foto catch yang sudah terposting.
    final prepared = _prepared;
    if (prepared != null && !_posted) _repository.discard(prepared);
    _name.dispose();
    _manualType.dispose();
    _personality.dispose();
    super.dispose();
  }

  Future<void> _locate() async {
    final area = await ref.read(areaLocatorProvider).currentArea();
    if (mounted) setState(() => _area = area);
  }

  Future<void> _prepareAndIdentify() async {
    setState(() {
      _phase = _Phase.uploading;
      _uploadError = null;
    });
    final PreparedCatch prepared;
    try {
      prepared = await _repository.prepare(widget.photos);
    } catch (e) {
      if (mounted) {
        setState(() {
          _phase = _Phase.uploadFailed;
          _uploadError = friendlyError(e);
        });
      }
      return;
    }
    if (!mounted) {
      _repository.discard(prepared);
      return;
    }
    setState(() {
      _prepared = prepared;
      _phase = _Phase.identifying;
    });

    AiIdentification? ai;
    AiFailure? failure;
    try {
      ai = await _repository.identify(prepared);
    } on AiFailure catch (e) {
      failure = e;
    } catch (_) {
      failure = const AiFailure('ai_unavailable');
    }
    if (!mounted) return;
    setState(() {
      _ai = ai;
      _aiFailure = failure;
      _pickedType = ai?.animalType;
      _manual = ai?.animalType == null;
      _personality.text = ai?.personality ?? '';
      _phase = _Phase.ready;
    });
  }

  bool get _aiFoundAnimal => _ai?.animalType != null;

  String? get _finalType {
    final type = (_manual ? _manualType.text : _pickedType)?.trim();
    return (type == null || type.isEmpty) ? null : type.toLowerCase();
  }

  String? get _aiMessage {
    if (_aiFailure case final failure?) return failure.message;
    if (!_aiFoundAnimal) {
      return 'AI nggak nemu hewan di foto ini. isi jenisnya sendiri ya.';
    }
    return null;
  }

  String? get _areaLabel => switch (_area) {
    AreaFound(:final label) when !_hideLocation => label,
    _ => null,
  };

  Future<void> _post() async {
    final prepared = _prepared;
    if (prepared == null) return;
    final existing = _reencounter ? _existing : null;
    final name = existing?.name ?? _name.text.trim();
    if (_reencounter && existing == null) {
      setState(() => _error = 'pilih dulu hewan yang lo temuin lagi.');
      return;
    }
    if (name.isEmpty) {
      setState(() => _error = 'kasih nama dulu hewannya.');
      return;
    }
    setState(() {
      _posting = true;
      _error = null;
    });
    try {
      final areaLabel = _areaLabel;
      final personality = _personality.text.trim();
      final timing = await _repository.submit(
        prepared,
        CatchDetails(
          animalName: name,
          kind: existing?.kind ?? _kind,
          existingAnimalId: existing?.id,
          animalType: _finalType,
          personality: personality.isEmpty ? null : personality,
          areaLabel: areaLabel,
          locationHidden: areaLabel == null,
        ),
      );
      _posted = true;
      // Kabari circle tanpa menunggu; gagal kirim tidak membatalkan catch.
      unawaited(
        _repository.notifyCircle(prepared.id).catchError((Object _) {}),
      );
      ref
          .read(analyticsProvider)
          .catchCreated(
            encounter: existing == null ? 'new' : 'again',
            timing: timing.dbValue,
          );
      ref.invalidate(todayCatchProvider);
      ref.invalidate(feedControllerProvider);
      for (final p in catchDerivedProviders) {
        ref.invalidate(p);
      }
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      context.go(Routes.home);
      messenger.showSnackBar(
        const SnackBar(content: Text('catch terposting ke circle!')),
      );
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  Future<void> _retake() async {
    if (!await confirmDiscardPhotos(context, retake: true)) return;
    if (mounted) context.pushReplacement(Routes.camera);
  }

  /// Back sistem: tanya dulu, foto belum diposting bakal kebuang.
  Future<void> _leave() async {
    if (_posting) return;
    if (!await confirmDiscardPhotos(context)) return;
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: _buildPhase(context),
    );
  }

  Widget _buildPhase(BuildContext context) {
    return switch (_phase) {
      _Phase.uploading => const _LoadingScreen(
        title: 'nyimpen fotonya dulu…',
        subtitle: 'bentar ya',
      ),
      _Phase.identifying => const _LoadingScreen(
        title: 'AI lagi ngenalin hewannya…',
        subtitle: 'kartu kepribadian lagi ditulis',
      ),
      _Phase.uploadFailed => _UploadFailed(
        message: _uploadError,
        onRetry: _prepareAndIdentify,
        onRetake: _retake,
      ),
      _Phase.ready => _buildForm(context),
    };
  }

  Widget _buildForm(BuildContext context) {
    final label = FurrealText.mono(fontSize: 12)
        .copyWith(color: FurrealColors.textSecondary, letterSpacing: 0.5);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        tooltip: 'foto ulang',
                        onPressed: _posting ? null : _retake,
                        icon: const Icon(Icons.arrow_back, size: 18),
                        style: IconButton.styleFrom(
                          fixedSize: const Size.square(
                            FurrealShape.minTouchTarget,
                          ),
                          side: const BorderSide(
                            color: FurrealColors.ink,
                            width: FurrealShape.borderWidth,
                          ),
                        ),
                      ),
                      Text('CATCH HARI INI', style: label),
                      const SizedBox.square(
                        dimension: FurrealShape.minTouchTarget,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text('dapet!', style: FurrealText.display(fontSize: 38)),
                  const SizedBox(height: 16),
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _Photos(
                          photos: widget.photos,
                          badge: _reencounter ? 'ketemu lagi' : 'hewan baru',
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                          child: _buildAiSection(label),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('PERNAH KETEMU DIA?', style: label),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _PillToggle(
                          label: 'hewan baru',
                          selected: !_reencounter,
                          onTap: () => setState(() => _reencounter = false),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _PillToggle(
                          label: 'ketemu lagi',
                          selected: _reencounter,
                          onTap: () => setState(() => _reencounter = true),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_reencounter)
                    _ReencounterList(
                      // urutkan berdasarkan jenis pilihan user / hasil AI
                      type: _finalType ?? _ai?.animalType,
                      selected: _existing,
                      onSelect: (a) => setState(() => _existing = a),
                    )
                  else ...[
                    Text('KASIH NAMA', style: label),
                    const SizedBox(height: 8),
                    TextField(
                      key: const Key('animal-name'),
                      controller: _name,
                      maxLength: animalNameMaxLength,
                      style: FurrealText.display(fontSize: 22)
                          .copyWith(fontWeight: FontWeight.w700),
                      decoration: const InputDecoration(
                        hintText: 'mis. Milo',
                        counterText: '',
                        border: _fieldBorder,
                        enabledBorder: _fieldBorder,
                        focusedBorder: _fieldBorder,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('PELIHARAAN ATAU LIAR?', style: label),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        for (final kind in AnimalKind.values) ...[
                          if (kind != AnimalKind.values.first)
                            const SizedBox(width: 8),
                          Expanded(
                            child: _PillToggle(
                              label: kind.label,
                              selected: _kind == kind,
                              onTap: () => setState(() => _kind = kind),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                  const SizedBox(height: 16),
                  _buildLocation(),
                ],
              ),
            ),
            _buildPostBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildAiSection(TextStyle label) {
    final ai = _ai;
    final aiMessage = _aiMessage;
    final edited =
        ai?.personality != null && _personality.text.trim() != ai!.personality;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (aiMessage != null) ...[
          Text(
            aiMessage,
            key: const Key('ai-message'),
            style: const TextStyle(fontSize: 14, height: 1.4),
          ),
          const SizedBox(height: 10),
        ],
        if (_aiFoundAnimal && !_manual) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  _pickedType ?? '',
                  key: const Key('ai-type'),
                  style: FurrealText.display(fontSize: 22)
                      .copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              if (_pickedType == ai!.animalType)
                Text(
                  'yakin ${ai.confidencePercent}%',
                  style: FurrealText.mono(fontSize: 12)
                      .copyWith(color: FurrealColors.textSecondary),
                ),
            ],
          ),
          const SizedBox(height: 10),
        ] else ...[
          TextField(
            key: const Key('animal-type'),
            controller: _manualType,
            maxLength: animalTypeMaxLength,
            textCapitalization: TextCapitalization.none,
            decoration: const InputDecoration(
              labelText: 'jenis hewan',
              hintText: 'mis. kucing',
              counterText: '',
            ),
          ),
          const SizedBox(height: 10),
        ],
        if (_aiFoundAnimal)
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                'bukan ini?',
                style: TextStyle(
                  fontSize: 13,
                  color: FurrealColors.textSecondary,
                ),
              ),
              for (final candidate in ai!.candidates)
                _Chip(
                  label: candidate,
                  selected: !_manual && _pickedType == candidate,
                  onTap: () => setState(() {
                    _manual = false;
                    _pickedType = candidate;
                  }),
                ),
              _Chip(
                label: 'lainnya',
                selected: _manual,
                onTap: () => setState(() => _manual = true),
              ),
            ],
          ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F3F3),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.auto_awesome_outlined,
                    size: 14,
                    color: FurrealColors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      ai?.personality != null
                          ? 'KARTU KEPRIBADIAN · DITULIS AI${edited ? ' · DIEDIT' : ''}'
                          : 'KARTU KEPRIBADIAN',
                      style: FurrealText.mono(fontSize: 11).copyWith(
                        color: FurrealColors.textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.edit_outlined,
                    size: 14,
                    color: FurrealColors.textSecondary,
                  ),
                ],
              ),
              TextField(
                key: const Key('personality'),
                controller: _personality,
                maxLength: personalityMaxLength,
                minLines: 1,
                maxLines: 4,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(fontSize: 15, height: 1.4),
                decoration: const InputDecoration(
                  hintText: 'tulis kepribadiannya sendiri (opsional)',
                  counterText: '',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 6),
                  isDense: true,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPostBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(
            color: FurrealColors.ink,
            width: FurrealShape.borderWidth,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null) ...[
            ErrorText(_error),
            const SizedBox(height: 12),
          ],
          FilledButton(
            onPressed: _posting ? null : _post,
            style: FilledButton.styleFrom(
              backgroundColor: FurrealColors.ink,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(56),
              shape: const StadiumBorder(),
            ),
            child: _posting
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'posting ke circle',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(width: 10),
                      Icon(
                        Icons.arrow_forward,
                        color: FurrealColors.accent,
                        size: 18,
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocation() {
    final area = _area;
    final text = switch (area) {
      null => 'lagi cari area…',
      AreaFound(:final label) when !_hideLocation =>
        '$label · lokasi disamarkan',
      AreaFound() => 'lokasi disembunyikan',
      AreaDenied() => 'izin lokasi ditolak · lokasi disembunyikan',
      AreaUnavailable() => 'area nggak ketemu · lokasi disembunyikan',
    };
    return Row(
      children: [
        const Icon(
          Icons.place_outlined,
          size: 18,
          color: FurrealColors.textSecondary,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              color: FurrealColors.textSecondary,
            ),
          ),
        ),
        if (area is AreaFound)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('sembunyikan', style: TextStyle(fontSize: 13)),
              Switch(
                key: const Key('hide-location'),
                value: _hideLocation,
                activeTrackColor: FurrealColors.ink,
                onChanged: (v) => setState(() => _hideLocation = v),
              ),
            ],
          ),
      ],
    );
  }
}

const _fieldBorder = OutlineInputBorder(
  borderRadius: BorderRadius.all(Radius.circular(16)),
  borderSide: BorderSide(
    color: FurrealColors.ink,
    width: FurrealShape.borderWidth,
  ),
);

/// Layar gelap selama upload & AI bekerja (prototype "analyzing").
class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFF0E0E0E),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Semantics(
              liveRegion: true,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox.square(
                    dimension: 56,
                    child: CircularProgressIndicator(
                      strokeWidth: 4,
                      color: FurrealColors.accent,
                      backgroundColor: Color(0xFF333333),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: FurrealText.display(fontSize: 24).copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    subtitle,
                    style: FurrealText.mono(fontSize: 12)
                        .copyWith(color: const Color(0xFFB0B0B0)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _UploadFailed extends StatelessWidget {
  const _UploadFailed({
    required this.message,
    required this.onRetry,
    required this.onRetake,
  });

  final String? message;
  final VoidCallback onRetry;
  final VoidCallback onRetake;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Text(
                'foto belum kesimpen',
                textAlign: TextAlign.center,
                style: FurrealText.display(fontSize: 28),
              ),
              const SizedBox(height: 8),
              Text(
                message ?? 'coba lagi ya.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: FurrealColors.textSecondary),
              ),
              const Spacer(),
              FilledButton(onPressed: onRetry, child: const Text('coba lagi')),
              const SizedBox(height: 8),
              TextButton(onPressed: onRetake, child: const Text('foto ulang')),
            ],
          ),
        ),
      ),
    );
  }
}

class _Photos extends StatelessWidget {
  const _Photos({required this.photos, required this.badge});

  final CapturedPhotos photos;
  final String badge;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 260,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.memory(
            photos.animal,
            key: const Key('result-animal-photo'),
            fit: BoxFit.cover,
          ),
          Positioned(
            top: 12,
            left: 12,
            width: 60,
            height: 80,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white, width: 2),
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.memory(
                photos.selfie,
                key: const Key('result-selfie-photo'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          Positioned(
            left: 12,
            bottom: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: FurrealColors.accent,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: FurrealColors.ink,
                  width: FurrealShape.borderWidth,
                ),
              ),
              child: Text(badge, style: FurrealText.mono(fontSize: 11)),
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          backgroundColor: selected ? FurrealColors.ink : Colors.white,
          foregroundColor: selected ? Colors.white : FurrealColors.ink,
          textStyle: const TextStyle(fontSize: 13),
        ),
        child: Text(label),
      ),
    );
  }
}

class _PillToggle extends StatelessWidget {
  const _PillToggle({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          backgroundColor: selected ? FurrealColors.ink : Colors.white,
          foregroundColor: selected ? Colors.white : FurrealColors.ink,
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        child: Text(label),
      ),
    );
  }
}

/// Daftar hewan milik user untuk "ketemu lagi": jenis sama dengan [type] di atas.
class _ReencounterList extends ConsumerWidget {
  const _ReencounterList({
    required this.type,
    required this.selected,
    required this.onSelect,
  });

  final String? type;
  final CollectionAnimal? selected;
  final ValueChanged<CollectionAnimal> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collection = ref.watch(collectionProvider);
    final photo = ref.watch(remotePhotoBuilderProvider);

    return switch (collection) {
      AsyncData(:final value) when value.isEmpty => const Text(
        'koleksi lo masih kosong. pilih "hewan baru" dulu ya.',
        key: Key('reencounter-empty'),
        style: TextStyle(color: FurrealColors.textSecondary),
      ),
      AsyncData(:final value) => Column(
        key: const Key('reencounter-list'),
        children: [
          for (final animal in sortForReencounter(value, type))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: selected?.id == animal.id
                    ? FurrealColors.accent
                    : FurrealColors.background,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: const BorderSide(
                    color: FurrealColors.ink,
                    width: FurrealShape.borderWidth,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  key: Key('reencounter-${animal.id}'),
                  onTap: () => onSelect(animal),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox.square(
                            dimension: 48,
                            child: animal.lastPhotoPath == null
                                ? const RemotePhotoPlaceholder()
                                : photo(
                                    context,
                                    animal.lastPhotoUrl,
                                    animal.lastPhotoPath!,
                                  ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                animal.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                              Text(
                                animal.animalType ?? 'jenis belum diisi',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: FurrealColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          'ketemu ${animal.encounterCount}x',
                          style: FurrealText.mono(fontSize: 11),
                        ),
                        if (selected?.id == animal.id) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.check_circle, size: 20),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      AsyncError() => TextButton(
        onPressed: () => ref.invalidate(collectionProvider),
        child: const Text('gagal memuat koleksi. coba lagi'),
      ),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }
}
