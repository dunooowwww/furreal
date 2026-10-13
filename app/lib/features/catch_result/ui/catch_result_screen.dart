import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../shared/errors.dart';
import '../../../shared/widgets/error_text.dart';
import '../../camera/data/captured_photos.dart';
import '../data/area_locator.dart';
import '../data/catch_repository.dart';
import '../state/catch_providers.dart';

/// Hasil tangkapan versi M2: foto, nama, peliharaan/liar, area, posting.
/// Jenis hewan & kartu kepribadian AI menyusul di M3.
class CatchResultScreen extends ConsumerStatefulWidget {
  const CatchResultScreen({super.key, required this.photos});

  final CapturedPhotos photos;

  @override
  ConsumerState<CatchResultScreen> createState() => _CatchResultScreenState();
}

class _CatchResultScreenState extends ConsumerState<CatchResultScreen> {
  final _name = TextEditingController();
  AnimalKind _kind = AnimalKind.pet;
  AreaResult? _area;
  bool _hideLocation = false;
  bool _posting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _locate();
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _locate() async {
    final area = await ref.read(areaLocatorProvider).currentArea();
    if (mounted) setState(() => _area = area);
  }

  String? get _areaLabel => switch (_area) {
    AreaFound(:final label) when !_hideLocation => label,
    _ => null,
  };

  Future<void> _post() async {
    final name = _name.text.trim();
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
      await ref
          .read(catchRepositoryProvider)
          .submit(
            NewCatch(
              animalPhoto: widget.photos.animal,
              selfiePhoto: widget.photos.selfie,
              animalName: name,
              kind: _kind,
              areaLabel: areaLabel,
              locationHidden: areaLabel == null,
            ),
          );
      ref.invalidate(todayCatchProvider);
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

  @override
  Widget build(BuildContext context) {
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
                        onPressed: _posting
                            ? null
                            : () => context.pushReplacement(Routes.camera),
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
                      Text('TANGKAPAN BARU', style: label),
                      const SizedBox.square(
                        dimension: FurrealShape.minTouchTarget,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text('dapet!', style: FurrealText.display(fontSize: 38)),
                  const SizedBox(height: 16),
                  _PhotoCard(photos: widget.photos),
                  const SizedBox(height: 16),
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
                  _buildLocation(),
                ],
              ),
            ),
            Container(
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
            ),
          ],
        ),
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

class _PhotoCard extends StatelessWidget {
  const _PhotoCard({required this.photos});

  final CapturedPhotos photos;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: 300,
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: FurrealColors.accent,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: FurrealColors.ink,
                    width: FurrealShape.borderWidth,
                  ),
                ),
                child: Text(
                  'hewan baru',
                  style: FurrealText.mono(fontSize: 11),
                ),
              ),
            ),
          ],
        ),
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
