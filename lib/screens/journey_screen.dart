import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

import '../services/notification_service.dart';
import '../theme/app_theme.dart';

import 'package:flutter/foundation.dart';

import 'dart:async';
import 'dart:ui';

class JourneyScreen extends StatefulWidget {
  const JourneyScreen({super.key});

  @override
  State<JourneyScreen> createState() => _JourneyScreenState();
}

class _JourneyScreenState extends State<JourneyScreen> {
  final String? _uid = FirebaseAuth.instance.currentUser?.uid;
  bool _reminderCheckRunning = false;
  String? _lastReminderSignature;

  late final ValueNotifier<DateTime> _nowNotifier;
  Timer? _ticker;

  String _getPairId(String myUid, String partnerUid) {
    final ids = [myUid, partnerUid]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  String _displayNameFromUser(Map<String, dynamic> data) {
    final first = (data['firstName'] ?? '').toString().trim();
    final last = (data['lastName'] ?? '').toString().trim();
    final full = '$first $last'.trim();
    return full.isEmpty ? 'Kullanıcı' : full;
  }

  Future<void> _checkMilestoneReminders({
    required String pairId,
    required List<Map<String, dynamic>> milestones,
  }) async {
    if (_reminderCheckRunning) return;
    _reminderCheckRunning = true;

    try {
      final sp = await SharedPreferences.getInstance();
      final now = DateTime.now();

      for (final item in milestones) {
        final title = (item['title'] ?? '').toString().trim();
        final id = (item['id'] ?? '').toString().trim();
        final ts = item['date'] as Timestamp?;

        if (title.isEmpty || id.isEmpty || ts == null) continue;

        final target = ts.toDate();
        if (target.isBefore(now)) continue;

        final diff = target.difference(now);
        final daysLeft = diff.inDays;

        int? triggerDay;
        String? body;

        if (daysLeft == 10) {
          triggerDay = 10;
          body = '$title için 10 gün kaldı 💗';
        } else if (daysLeft == 5) {
          triggerDay = 5;
          body = '$title için 5 gün kaldı 💗';
        } else if (daysLeft == 2) {
          triggerDay = 2;
          body = '$title için 2 gün kaldı 💗';
        } else if (daysLeft == 1) {
          triggerDay = 1;
          body = 'Yarın $title var 💗';
        }

        if (triggerDay == null || body == null) continue;

        final key = 'journey_reminder_${pairId}_${id}_$triggerDay';
        if (sp.getBool(key) == true) continue;

        await NotificationService.instance.showLocal(
          title: 'Yaklaşan Gün 💞',
          body: body,
        );

        await sp.setBool(key, true);
      }
    } catch (_) {
    } finally {
      _reminderCheckRunning = false;
    }
  }

  @override
  void initState() {
    super.initState();
    _nowNotifier = ValueNotifier<DateTime>(DateTime.now());
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      _nowNotifier.value = DateTime.now();
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _nowNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_uid == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream:
          FirebaseFirestore.instance.collection('users').doc(_uid).snapshots(),
      builder: (context, userSnap) {
        if (!userSnap.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final userData = userSnap.data!.data() ?? {};
        final partnerUid = (userData['pairedUserId'] ?? '').toString().trim();

        if (partnerUid.isEmpty) {
          return Scaffold(
            body: Center(
              child: Text(
                'Henüz bir bağ kurulmamış.',
                style: TextStyle(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          );
        }

        final myDisplayName = _displayNameFromUser(userData);
        final pairId = _getPairId(_uid!, partnerUid);

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            title: Text(
              'YOLCULUĞUMUZ',
              style: TextStyle(
                color: cs.onSurface,
                fontWeight: FontWeight.w900,
                fontSize: 18,
                letterSpacing: 0.5,
              ),
            ),
            centerTitle: true,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            elevation: 0,
            actions: [
              IconButton(
                icon: const Icon(
                  Icons.add_circle,
                  color: AppTheme.primary,
                  size: 30,
                ),
                onPressed: () => _showAddSheet(
                  context: context,
                  pairId: pairId,
                  editorName: myDisplayName,
                ),
              ),
            ],
          ),
          body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('pairs')
                .doc(pairId)
                .snapshots(),
            builder: (context, pairSnap) {
              if (!pairSnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final rawMilestones = List<Map<String, dynamic>>.from(
                pairSnap.data?.data()?['milestones'] ?? const [],
              );

              if (rawMilestones.isEmpty) {
                return Center(
                  child: Text(
                    'Anılarınızı eklemeye başlayın!',
                    style: TextStyle(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                );
              }

              rawMilestones.sort(
                (a, b) =>
                    (b['date'] as Timestamp).compareTo(a['date'] as Timestamp),
              );

              final reminderSignature = rawMilestones
                  .map(
                    (e) =>
                        '${e['id']}_${(e['date'] as Timestamp).millisecondsSinceEpoch}',
                  )
                  .join('|');

              if (_lastReminderSignature != reminderSignature) {
                _lastReminderSignature = reminderSignature;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  _checkMilestoneReminders(
                    pairId: pairId,
                    milestones: rawMilestones,
                  );
                });
              }

              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: rawMilestones.length,
                itemBuilder: (context, index) {
                  return _MilestoneCard(
                    milestone: rawMilestones[index],
                    pairId: pairId,
                    currentUid: _uid!,
                    currentUserName: myDisplayName,
                    nowListenable: _nowNotifier,
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  void _showAddSheet({
    required BuildContext context,
    required String pairId,
    required String editorName,
  }) {
    final titleController = TextEditingController();
    final noteController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    bool isSaving = false;
    String? formError;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (sheetContext) {
        final cs = Theme.of(sheetContext).colorScheme;

        return StatefulBuilder(
          builder: (sheetContext, setModalState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 20,
                  bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Yeni Şafak / Anı Ekle',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: titleController,
                        decoration: const InputDecoration(
                          labelText: 'Başlık (Örn: Tanıştık)',
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: noteController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Not (isteğe bağlı)',
                          hintText: 'Bu gün için kısa not...',
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Tarih: ${DateFormat('d MMMM y', 'tr_TR').format(selectedDate)}',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: cs.onSurface,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: sheetContext,
                                locale: const Locale('tr', 'TR'),
                                initialDate: selectedDate,
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                              );
                              if (picked != null) {
                                setModalState(() => selectedDate = picked);
                              }
                            },
                            child: const Text('Seç'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (formError != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          formError!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          minimumSize: const Size(double.infinity, 45),
                        ),
                        onPressed: isSaving
                            ? null
                            : () async {
                                final title = titleController.text.trim();
                                final note = noteController.text.trim();

                                if (title.isEmpty) {
                                  setModalState(() {
                                    formError = 'Başlık boş bırakılamaz.';
                                  });
                                  return;
                                }

                                setModalState(() {
                                  isSaving = true;
                                  formError = null;
                                });

                                try {
                                  final docRef = FirebaseFirestore.instance
                                      .collection('pairs')
                                      .doc(pairId);

                                  final snap = await docRef.get();
                                  final data =
                                      snap.data() ?? <String, dynamic>{};

                                  final currentMilestones =
                                      List<Map<String, dynamic>>.from(
                                          data['milestones'] ?? const []);

                                  currentMilestones.add({
                                    'id': DateTime.now()
                                        .microsecondsSinceEpoch
                                        .toString(),
                                    'title': title,
                                    'date': Timestamp.fromDate(selectedDate),
                                    'createdAt': Timestamp.now(),
                                    'createdBy': _uid,
                                    'lastEditedBy': editorName,
                                    'lastEditedByUid': _uid,
                                    'lastEditedAt': Timestamp.now(),
                                    'lastEditNote': note,
                                  });

                                  await docRef.set({
                                    'milestones': currentMilestones,
                                  }, SetOptions(merge: true));

                                  if (sheetContext.mounted) {
                                    Navigator.pop(sheetContext);
                                  }
                                } catch (e) {
                                  setModalState(() {
                                    formError =
                                        'Kayıt sırasında hata oluştu: $e';
                                  });
                                } finally {
                                  if (sheetContext.mounted) {
                                    setModalState(() {
                                      isSaving = false;
                                    });
                                  }
                                }
                              },
                        child: isSaving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Kaydet',
                                style: TextStyle(color: Colors.white),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _MilestoneCard extends StatelessWidget {
  final Map<String, dynamic> milestone;
  final String pairId;
  final String currentUid;
  final String currentUserName;
  final ValueListenable<DateTime> nowListenable;

  const _MilestoneCard({
    required this.milestone,
    required this.pairId,
    required this.currentUid,
    required this.currentUserName,
    required this.nowListenable,
  });

  String _formatDate(DateTime d) => DateFormat('d MMMM y', 'tr_TR').format(d);

  String _formatDateTime(DateTime d) =>
      DateFormat('d MMMM y • HH:mm', 'tr_TR').format(d);

  Future<void> _replaceMilestone({
    required Map<String, dynamic> oldItem,
    required Map<String, dynamic> newItem,
  }) async {
    final docRef = FirebaseFirestore.instance.collection('pairs').doc(pairId);

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      final data = snap.data() ?? <String, dynamic>{};
      final currentList =
          List<Map<String, dynamic>>.from(data['milestones'] ?? const []);
      final index = currentList.indexWhere(
        (e) => (e['id'] ?? '') == (oldItem['id'] ?? ''),
      );
      if (index == -1) return;
      currentList[index] = newItem;
      tx.set(docRef, {'milestones': currentList}, SetOptions(merge: true));
    });
  }

  Future<void> _deleteMilestone(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Bu anıyı silmek istiyor musunuz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Sil', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final docRef = FirebaseFirestore.instance.collection('pairs').doc(pairId);

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      final data = snap.data() ?? <String, dynamic>{};
      final currentList =
          List<Map<String, dynamic>>.from(data['milestones'] ?? const []);
      currentList.removeWhere(
        (e) => (e['id'] ?? '') == (milestone['id'] ?? ''),
      );
      if (currentList.isEmpty) {
        tx.delete(docRef);
      } else {
        tx.set(docRef, {'milestones': currentList}, SetOptions(merge: true));
      }
    });
  }

  Future<void> _editMilestone(BuildContext context) async {
    final titleController =
        TextEditingController(text: (milestone['title'] ?? '').toString());
    final noteController = TextEditingController(
        text: (milestone['lastEditNote'] ?? '').toString());
    DateTime selectedDate = (milestone['date'] as Timestamp).toDate();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (sheetContext) {
        final cs = Theme.of(sheetContext).colorScheme;

        return StatefulBuilder(
          builder: (sheetContext, setModalState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 20,
                  bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Anıyı Düzenle',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: titleController,
                        decoration: const InputDecoration(labelText: 'Başlık'),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: noteController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Değişiklik Notu',
                          hintText: 'Ne değişti?',
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Tarih: ${_formatDate(selectedDate)}',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: cs.onSurface,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: sheetContext,
                                locale: const Locale('tr', 'TR'),
                                initialDate: selectedDate,
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                              );
                              if (picked != null) {
                                setModalState(() => selectedDate = picked);
                              }
                            },
                            child: const Text('Seç'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: () async {
                          final newTitle = titleController.text.trim();
                          if (newTitle.isEmpty) return;

                          final updated = Map<String, dynamic>.from(milestone)
                            ..['title'] = newTitle
                            ..['date'] = Timestamp.fromDate(selectedDate)
                            ..['lastEditedBy'] = currentUserName
                            ..['lastEditedByUid'] = currentUid
                            ..['lastEditedAt'] = Timestamp.now()
                            ..['lastEditNote'] = noteController.text.trim();

                          await _replaceMilestone(
                            oldItem: milestone,
                            newItem: updated,
                          );

                          if (sheetContext.mounted) {
                            Navigator.pop(sheetContext);
                          }
                        },
                        child: const Text(
                          'Güncelle',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final date = (milestone['date'] as Timestamp).toDate();
    final title = (milestone['title'] ?? '').toString().trim();
    final lastEditedBy = (milestone['lastEditedBy'] ?? '').toString().trim();
    final lastEditNote = (milestone['lastEditNote'] ?? '').toString().trim();
    final lastEditedAtTs = milestone['lastEditedAt'] as Timestamp?;
    final lastEditedAt = lastEditedAtTs?.toDate();
    final hasEditInfo = lastEditedBy.isNotEmpty && lastEditedAt != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).dividerColor.withAlpha(40)),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withAlpha(40)
                : Colors.black.withAlpha(12),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              title.toUpperCase(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
                fontSize: 15,
                color: AppTheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            runSpacing: 6,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withAlpha(10)
                      : Colors.black.withAlpha(6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Tarih: ${_formatDate(date)}',
                  style: TextStyle(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Düzenle',
                    onPressed: () => _editMilestone(context),
                    icon: const Icon(
                      Icons.edit_outlined,
                      color: AppTheme.primary,
                      size: 22,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Sil',
                    onPressed: () => _deleteMilestone(context),
                    icon: const Icon(
                      Icons.delete_sweep_outlined,
                      color: Colors.redAccent,
                      size: 22,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Divider(),
          const SizedBox(height: 8),
          _CountdownCircles(
            date: date,
            nowListenable: nowListenable,
          ),
          const SizedBox(height: 12),
          if (hasEditInfo)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.07),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.primary.withAlpha(35)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$lastEditedBy, ${_formatDateTime(lastEditedAt!)} tarihinde bu gün ile alakalı değişiklik yaptı.',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      height: 1.45,
                      color: cs.onSurface,
                    ),
                  ),
                  if (lastEditNote.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Not: $lastEditNote',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        height: 1.45,
                        color: cs.onSurface.withAlpha(230),
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _CountdownCircles extends StatelessWidget {
  final DateTime date;
  final ValueListenable<DateTime> nowListenable;

  const _CountdownCircles({
    required this.date,
    required this.nowListenable,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ValueListenableBuilder<DateTime>(
      valueListenable: nowListenable,
      builder: (context, now, _) {
        final isFuture = date.isAfter(now);
        final diff = isFuture ? date.difference(now) : now.difference(date);
        final totalSeconds = diff.inSeconds.abs();

        final years = totalSeconds ~/ (365 * 24 * 3600);
        final months = (totalSeconds % (365 * 24 * 3600)) ~/ (30 * 24 * 3600);
        final days = (totalSeconds % (30 * 24 * 3600)) ~/ (24 * 3600);
        final hours = (totalSeconds % (24 * 3600)) ~/ 3600;
        final minutes = (totalSeconds % 3600) ~/ 60;
        final seconds = totalSeconds % 60;

        final items = <_CircleTimeData>[
          _CircleTimeData(label: 'SN', value: seconds, progress: seconds / 60),
          _CircleTimeData(label: 'DK', value: minutes, progress: minutes / 60),
          _CircleTimeData(label: 'SA', value: hours, progress: hours / 24),
          _CircleTimeData(label: 'GÜN', value: days, progress: days / 30),
          _CircleTimeData(label: 'AY', value: months, progress: months / 12),
          _CircleTimeData(
            label: 'YIL',
            value: years,
            progress: years == 0 ? 0 : 1,
          ),
        ];

        return Column(
          children: [
            Text(
              isFuture ? 'KALAN SÜRE' : 'GEÇEN SÜRE',
              style: TextStyle(
                fontSize: 12,
                color: cs.onSurface,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children:
                  items.map((item) => _MiniProgressCircle(data: item)).toList(),
            ),
          ],
        );
      },
    );
  }
}

class _CircleTimeData {
  final String label;
  final int value;
  final double progress;

  const _CircleTimeData({
    required this.label,
    required this.value,
    required this.progress,
  });
}

class _MiniProgressCircle extends StatelessWidget {
  final _CircleTimeData data;

  const _MiniProgressCircle({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: 92,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withAlpha(6) : theme.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppTheme.primary.withOpacity(isDark ? 0.22 : 0.14),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withAlpha(35)
                : Colors.black.withAlpha(10),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            width: 58,
            height: 58,
            child: Stack(
              alignment: Alignment.center,
              children: [
                TweenAnimationBuilder<double>(
                  key: ValueKey('${data.label}_${data.value}'),
                  tween: Tween<double>(end: data.progress.clamp(0.0, 1.0)),
                  duration: const Duration(milliseconds: 450),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) {
                    return SizedBox(
                      width: 58,
                      height: 58,
                      child: CircularProgressIndicator(
                        value: value,
                        strokeWidth: 6,
                        backgroundColor: AppTheme.primary.withOpacity(0.12),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          AppTheme.primary,
                        ),
                      ),
                    );
                  },
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${data.value}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: cs.onSurface,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      data.label,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: cs.onSurface.withAlpha(210),
                        height: 1,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
