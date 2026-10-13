import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:food_user_application/config/theme/app_colors.dart';
import 'package:food_user_application/features/advertisements/domain/advertisement_model.dart';
import 'package:food_user_application/features/advertisements/presentation/controllers/advertisement_controller.dart';
import 'package:food_user_application/features/advertisements/presentation/widgets/ad_widgets.dart';
import 'package:food_user_application/features/registration/presentation/widgets/image_picker_tile.dart'
    show pickImageWithSourceSheet;

const _maxFileBytes = 5 * 1024 * 1024;

/// Create a new advertisement.
class NewAdvertisementScreen extends StatelessWidget {
  const NewAdvertisementScreen({super.key});

  @override
  Widget build(BuildContext context) => const _AdFormScaffold(initial: null);
}

/// Edit an existing advertisement (loads it by [adId]).
class EditAdvertisementScreen extends ConsumerWidget {
  const EditAdvertisementScreen({super.key, required this.adId});

  final String adId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(advertisementDetailProvider(adId));
    return async.when(
      data: (ad) => _AdFormScaffold(initial: ad),
      loading: () => Scaffold(
        backgroundColor: adBackground(context),
        appBar: AppBar(title: const Text('Edit Advertisement')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: adBackground(context),
        appBar: AppBar(title: const Text('Edit Advertisement')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  adErrorText(e, 'Failed to load advertisement'),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => ref.invalidate(advertisementDetailProvider(adId)),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AdFormScaffold extends ConsumerStatefulWidget {
  const _AdFormScaffold({required this.initial});

  final AdvertisementModel? initial;

  @override
  ConsumerState<_AdFormScaffold> createState() => _AdFormScaffoldState();
}

class _AdFormScaffoldState extends ConsumerState<_AdFormScaffold> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _description;
  late String _category;
  DateTime? _start;
  DateTime? _end;
  XFile? _image;
  XFile? _video;
  bool _saving = false;

  final _fmt = DateFormat('yyyy-MM-dd');

  bool get _isEdit => widget.initial != null;
  bool get _isVideo => _category == 'Video Promotion';

  @override
  void initState() {
    super.initState();
    final ad = widget.initial;
    _title = TextEditingController(text: ad?.title ?? '');
    _description = TextEditingController(text: ad?.description ?? '');
    _category = advertisementTypes.contains(ad?.adsType)
        ? ad!.adsType
        : 'Image Promotion';
    if (ad != null) {
      final (s, e) = ad.validityRange;
      _start = s;
      _end = e;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  DateTime get _today {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  Future<void> _pickStart() async {
    final today = _today;
    final initial = _start ?? today;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(today) ? today : initial,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365 * 3)),
    );
    if (picked == null) return;
    setState(() {
      _start = picked;
      if (_end != null && _end!.isBefore(picked)) _end = null;
    });
  }

  Future<void> _pickEnd() async {
    if (_start == null) {
      adShowSnack(context, 'Please select a start date first', error: true);
      return;
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: _end ?? _start!,
      firstDate: _start!,
      lastDate: _start!.add(const Duration(days: 365 * 3)),
    );
    if (picked != null) setState(() => _end = picked);
  }

  Future<void> _pickImage() async {
    final file = await pickImageWithSourceSheet(context);
    if (file == null) return;
    if (await file.length() > _maxFileBytes) {
      if (mounted) {
        adShowSnack(context, 'Image size too large. Max 5MB allowed.', error: true);
      }
      return;
    }
    if (mounted) setState(() => _image = file);
  }

  Future<void> _pickVideo() async {
    final file = await ImagePicker().pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(minutes: 2),
    );
    if (file == null) return;
    if (await file.length() > _maxFileBytes) {
      if (mounted) {
        adShowSnack(context, 'Video size too large. Max 5MB allowed.', error: true);
      }
      return;
    }
    if (mounted) setState(() => _video = file);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final start = _start;
    final end = _end;
    if (start == null || end == null) {
      adShowSnack(context, 'Start Date and End Date are required', error: true);
      return;
    }
    final ad = widget.initial;
    final (origStart, _) = ad?.validityRange ?? (null, null);
    final startUnchanged = origStart != null &&
        DateUtils.isSameDay(origStart, start);
    if (start.isBefore(_today) && !startUnchanged) {
      adShowSnack(context, 'Start date cannot be in the past', error: true);
      return;
    }
    if (end.isBefore(start)) {
      adShowSnack(context, 'End date must be on or after start date', error: true);
      return;
    }
    final hasImage = _image != null || (ad?.imageUrl.isNotEmpty ?? false);
    final hasVideo = _video != null || (ad?.videoUrl.isNotEmpty ?? false);
    if (_isVideo && !hasVideo) {
      adShowSnack(context, 'Please upload a video for Video Promotion', error: true);
      return;
    }
    if (!_isVideo && !hasImage) {
      adShowSnack(
        context,
        'Please upload an image for this advertisement type',
        error: true,
      );
      return;
    }

    // Only send the media relevant to the chosen type.
    final image = _isVideo ? null : _image;
    final video = _isVideo ? _video : null;
    final validity = '${_fmt.format(start)} to ${_fmt.format(end)}';
    final controller = ref.read(advertisementControllerProvider.notifier);

    setState(() => _saving = true);
    try {
      if (_isEdit) {
        await controller.updateAd(
          ad!.id,
          title: _title.text.trim(),
          description: _description.text.trim(),
          adsType: _category,
          validity: validity,
          fileDescription: image?.name ?? ad.fileDescription,
          videoDescription: video?.name ?? ad.videoDescription,
          image: image,
          video: video,
        );
        ref.invalidate(advertisementDetailProvider(ad.id));
      } else {
        await controller.create(
          title: _title.text.trim(),
          description: _description.text.trim(),
          adsType: _category,
          validity: validity,
          fileDescription: image?.name ?? '',
          videoDescription: video?.name ?? '',
          image: image,
          video: video,
        );
      }
      if (!mounted) return;
      adShowSnack(
        context,
        _isEdit
            ? 'Advertisement updated and pending approval'
            : 'Advertisement submitted for approval',
      );
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/advertisements');
      }
    } catch (e) {
      if (mounted) {
        adShowSnack(
          context,
          adErrorText(
            e,
            _isEdit
                ? 'Failed to update advertisement'
                : 'Failed to create advertisement',
          ),
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  InputDecoration _decoration(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: adIsDark(context)
          ? AppColors.surfaceVariantDark
          : AppColors.surfaceVariantLight,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: adBorder(context)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: adBorder(context)),
      ),
    );
  }

  Widget _dateField(String label, DateTime? value, VoidCallback onTap) {
    return InkWell(
      onTap: _saving ? null : onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: _decoration(label).copyWith(
          suffixIcon: const Icon(
            Icons.calendar_today_outlined,
            size: 18,
            color: AppColors.primaryButton,
          ),
        ),
        child: Text(
          value == null ? 'Select' : _fmt.format(value),
          style: TextStyle(
            color: value == null
                ? adTextSecondary(context)
                : adTextPrimary(context),
          ),
        ),
      ),
    );
  }

  Widget _mediaBlock() {
    final ad = widget.initial;
    if (_isVideo) {
      final existing = ad?.videoUrl.isNotEmpty ?? false;
      return _UploadBox(
        title: 'Upload Video (max 5MB)',
        icon: Icons.videocam_outlined,
        onTap: _saving ? null : _pickVideo,
        preview: _video != null
            ? _FileRow(
                name: _video!.name,
                onRemove: () => setState(() => _video = null),
              )
            : existing
            ? const _FileRow(name: 'Current video attached (pick to replace)')
            : null,
      );
    }
    final existingUrl = ad?.imageUrl ?? '';
    return _UploadBox(
      title: 'Upload Image (max 5MB)',
      icon: Icons.image_outlined,
      onTap: _saving ? null : _pickImage,
      preview: _image != null
          ? Stack(
              children: [
                AdPickedImage(file: _image!),
                Positioned(
                  top: 4,
                  right: 4,
                  child: IconButton.filled(
                    onPressed: () => setState(() => _image = null),
                    icon: const Icon(Icons.close, size: 18),
                  ),
                ),
              ],
            )
          : existingUrl.isNotEmpty
          ? AdNetworkImage(url: existingUrl)
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: adBackground(context),
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Advertisement' : 'New Advertisement'),
        backgroundColor: adCard(context),
        foregroundColor: adTextPrimary(context),
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AdCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Category Info',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: adTextPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _category,
                    isExpanded: true,
                    decoration: _decoration('Ad type'),
                    items: [
                      for (final c in advertisementTypes)
                        DropdownMenuItem(value: c, child: Text(c)),
                    ],
                    onChanged: _saving
                        ? null
                        : (v) {
                            if (v == null) return;
                            setState(() {
                              _category = v;
                              if (v == 'Video Promotion') {
                                _image = null;
                              } else {
                                _video = null;
                              }
                            });
                          },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _dateField('Start Date *', _start, _pickStart),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: _dateField('End Date *', _end, _pickEnd)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            AdCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _title,
                    maxLength: 100,
                    enabled: !_saving,
                    decoration: _decoration('Title *'),
                    validator: (v) => (v ?? '').trim().isEmpty
                        ? 'Title is required'
                        : null,
                  ),
                  const SizedBox(height: 4),
                  TextFormField(
                    controller: _description,
                    maxLength: 500,
                    maxLines: 4,
                    enabled: !_saving,
                    decoration: _decoration('Description *'),
                    validator: (v) => (v ?? '').trim().isEmpty
                        ? 'Description is required'
                        : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _mediaBlock(),
            const SizedBox(height: 20),
            SizedBox(
              height: 50,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryButton,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(_isEdit ? 'Update' : 'Submit'),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Advertisements are reviewed by admin before going live.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: adTextSecondary(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UploadBox extends StatelessWidget {
  const _UploadBox({
    required this.title,
    required this.icon,
    required this.onTap,
    this.preview,
  });

  final String title;
  final IconData icon;
  final VoidCallback? onTap;
  final Widget? preview;

  @override
  Widget build(BuildContext context) {
    return AdCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (preview != null) ...[preview!, const SizedBox(height: 10)],
          OutlinedButton.icon(
            onPressed: onTap,
            icon: Icon(icon),
            label: Text(preview == null ? title : 'Replace'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primaryButton,
              minimumSize: const Size.fromHeight(46),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FileRow extends StatelessWidget {
  const _FileRow({required this.name, this.onRemove});

  final String name;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.insert_drive_file_outlined,
            color: AppColors.primaryButton),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: adTextPrimary(context)),
          ),
        ),
        if (onRemove != null)
          IconButton(onPressed: onRemove, icon: const Icon(Icons.close)),
      ],
    );
  }
}
